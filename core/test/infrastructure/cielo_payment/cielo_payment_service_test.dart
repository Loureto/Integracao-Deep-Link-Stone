import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('cieloDeeplinkChannel');
  const environment = Environment(cieloClientID: 'client-id', cieloAccessToken: 'access-token');
  const credentials = {'clientID': 'client-id', 'accessToken': 'access-token'};
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late CieloPaymentService service;
  late List<MethodCall> calls;

  const payment = CieloPaymentModel(
    items: [CieloItemModel(sku: '10', name: 'Geral', unitPrice: 500, quantity: 2)],
    paymentCode: CieloPaymentCode.creditoParceladoLoja,
    installments: 2,
    reference: 'pedido-1',
  );

  setUp(() {
    calls = [];
    service = CieloPaymentService(channel, environment);
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  void mockAndroid(Future<Object?> Function(MethodCall call)? handler) {
    messenger.setMockMethodCallHandler(
      channel,
      handler == null
          ? null
          : (call) {
              calls.add(call);
              return handler(call);
            },
    );
  }

  String? actionOf(MethodCall call) => (call.arguments as Map)['action'] as String?;

  Object? requestOf(MethodCall call) {
    final request = (call.arguments as Map)['request'] as String?;
    return request == null ? null : jsonDecode(request);
  }

  Future<void> receive(Map<String, String?> arguments) async {
    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(MethodCall('onCieloResponse', arguments)),
      (_) {},
    );
  }

  test('envia o pagamento com as credenciais e os campos documentados', () async {
    mockAndroid((_) async => true);

    final result = await service.sendPayment(payment);

    expect(result.isRight(), isTrue);
    expect(calls.single.method, 'sendCieloDeeplink');
    expect(actionOf(calls.single), 'payment');
    expect(requestOf(calls.single), {
      ...credentials,
      'value': '1000',
      'installments': 2,
      'items': [
        {'sku': '10', 'name': 'Geral', 'unitPrice': 500, 'quantity': 2, 'unitOfMeasure': 'unidade'},
      ],
      'paymentCode': 'CREDITO_PARCELADO_LOJA',
      'reference': 'pedido-1',
    });
  });

  test('cancelamento e consultas enviam as credenciais junto com os campos da ação', () async {
    mockAndroid((_) async => true);

    await service.cancelPayment(
      const CieloCancelModel(orderId: 'pedido', cieloCode: '910792', authCode: '142941', value: 3620),
    );
    await service.listOrders();
    await service.findOrder(const CieloOrderQueryModel(orderId: 'pedido'));
    await service.listEnabledProducts();
    await service.listEstablishments();

    expect(calls.map(actionOf), ['payment-reversal', 'orders', 'order', 'enabledproducts', 'establishments']);
    expect(calls.map(requestOf), [
      {...credentials, 'id': 'pedido', 'cieloCode': '910792', 'authCode': '142941', 'value': 3620},
      {...credentials, 'page': 0, 'pageSize': 5},
      {...credentials, 'orderId': 'pedido'},
      credentials,
      credentials,
    ]);
  });

  test('impressão e informações do terminal não levam credenciais', () async {
    mockAndroid((_) async => true);

    await service.printText(
      const CieloPrintModel(operation: CieloPrintOperation.text, values: ['LINHA 1\nLINHA 2\n\n']),
    );
    await service.getTerminalInfo();

    expect(calls.map(actionOf), ['print', 'terminalinfo']);
    expect(calls.map(requestOf), [
      {
        'operation': 'PRINT_TEXT',
        'styles': [{}],
        'value': ['LINHA 1\nLINHA 2\n\n'],
      },
      null,
    ]);
  });

  test('sem credenciais, só abre a impressão e as informações do terminal', () async {
    mockAndroid((_) async => true);
    service = CieloPaymentService(channel, const Environment(cieloClientID: '', cieloAccessToken: ''));

    final failure = (await service.sendPayment(payment)).getLeft().toNullable();
    await service.getTerminalInfo();

    expect(failure?.code, 'MISSING_CREDENTIALS');
    expect(calls.map(actionOf), ['terminalinfo']);
  });

  test('não abre o app da Cielo com requisição inválida', () async {
    mockAndroid((_) async => true);

    final results = [
      await service.sendPayment(const CieloPaymentModel(items: [])),
      await service.sendPayment(
        const CieloPaymentModel(
          items: [CieloItemModel(sku: '1', name: 'Brinde', unitPrice: 0)],
        ),
      ),
      await service.sendPayment(
        const CieloPaymentModel(
          items: [CieloItemModel(sku: '1', name: 'Item', unitPrice: 100, quantity: 0)],
        ),
      ),
      await service.sendPayment(CieloPaymentModel(items: payment.items, installments: -1)),
      await service.cancelPayment(
        const CieloCancelModel(orderId: '', cieloCode: '910792', authCode: '142941', value: 3620),
      ),
      await service.printText(const CieloPrintModel(operation: CieloPrintOperation.text, values: [])),
      await service.printText(
        const CieloPrintModel(
          operation: CieloPrintOperation.multiColumnText,
          values: ['A', 'B'],
          styles: [CieloPrintStyleModel()],
        ),
      ),
      await service.findOrder(const CieloOrderQueryModel(orderId: 'pedido', amount: 3620)),
      await service.listOrders(const CieloOrderListModel(pageSize: 6)),
      await service.listOrders(const CieloOrderListModel(page: -1)),
    ];

    expect(results.map((result) => result.getLeft().toNullable()?.code), [
      'INVALID_VALUE',
      'INVALID_VALUE',
      'INVALID_VALUE',
      'INVALID_INSTALLMENTS',
      'INVALID_CANCEL',
      'INVALID_PRINT',
      'INVALID_PRINT',
      'INVALID_ORDER_QUERY',
      'INVALID_ORDER_LIST',
      'INVALID_ORDER_LIST',
    ]);
    expect(calls, isEmpty);
  });

  test('mantém o código e a mensagem do erro enviado pelo Android', () async {
    mockAndroid(
      (_) async => throw PlatformException(
        code: 'PAYMENT_APP_NOT_FOUND',
        message: 'Nenhum aplicativo da Cielo disponível para processar a operação.',
      ),
    );

    final failure = (await service.getTerminalInfo()).getLeft().toNullable();

    expect(failure?.code, 'PAYMENT_APP_NOT_FOUND');
    expect(failure?.message, 'Nenhum aplicativo da Cielo disponível para processar a operação.');
  });

  test('retorna NOT_STARTED quando o Android não confirma a abertura', () async {
    mockAndroid((_) async => false);

    expect((await service.getTerminalInfo()).getLeft().toNullable()?.code, 'NOT_STARTED');
  });

  test('retorna NOT_SUPPORTED quando o canal não existe na plataforma', () async {
    mockAndroid(null);

    expect((await service.getTerminalInfo()).getLeft().toNullable()?.code, 'NOT_SUPPORTED');
  });

  test('publica em responses o onCieloResponse enviado pelo Android', () async {
    final response = service.responses.first;

    await receive({
      'action': 'payment',
      'responseCode': '0',
      'response': '{"code":1,"reason":"CANCELADO PELO USUÁRIO"}',
    });

    expect((await response).action, CieloAction.payment);
    expect((await response).isSuccess, isFalse);
    expect((await response).message, 'CANCELADO PELO USUÁRIO');
  });

  test('ignora o retorno de uma ação desconhecida', () async {
    final responses = <CieloResponse>[];
    final subscription = service.responses.listen(responses.add);

    await receive({'action': 'refund', 'response': '{}'});
    await receive({'action': 'print', 'response': '{"code":0,"message":"SUCCESS"}'});
    await Future<void>.delayed(Duration.zero);

    expect(responses.map((response) => response.action), [CieloAction.print]);
    await subscription.cancel();
  });
}
