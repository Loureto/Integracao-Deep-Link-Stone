import 'package:core/core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('stoneDeeplinkChannel');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late StonePaymentService service;
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    service = StonePaymentService(channel);
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

  Future<StonePaymentFailure?> send([StonePaymentModel data = const StonePaymentModel()]) async {
    final result = await service.sendPayment(data);
    return result.getLeft().toNullable();
  }

  test('envia o pagamento com os valores documentados', () async {
    mockAndroid((_) async => true);

    final failure = await send(
      const StonePaymentModel(
        amount: 3000,
        editableAmount: false,
        transactionType: StoneTransactionType.credit,
        installmentType: StoneInstallmentType.merchant,
        installmentCount: 3,
      ),
    );

    expect(failure, isNull);
    expect(calls.single.method, 'sendStoneDeeplink');
    expect(calls.single.arguments, {
      'amount': 3000,
      'editableAmount': false,
      'transactionType': 'CREDIT',
      'installmentType': 'MERCHANT',
      'installmentCount': 3,
      'orderId': null,
    });
  });

  test('pagamento sem campos envia tudo nulo (fluxo completo no app Stone)', () async {
    mockAndroid((_) async => true);

    await send();

    expect((calls.single.arguments as Map).values, everyElement(isNull));
  });

  test('não abre o app de Pagamento com amount fora de 0 a 999999999', () async {
    mockAndroid((_) async => true);

    final failure = await send(const StonePaymentModel(amount: 1000000000));

    expect(failure?.code, 'INVALID_AMOUNT');
    expect(calls, isEmpty);
  });

  test('não abre o app de Pagamento com installmentCount fora de 2 a 99', () async {
    mockAndroid((_) async => true);

    final failure = await send(const StonePaymentModel(installmentCount: 1));

    expect(failure?.code, 'INVALID_INSTALLMENT_COUNT');
    expect(failure?.message, 'A quantidade de parcelas deve estar entre 2 e 99.');
    expect(calls, isEmpty);
  });

  test('mantém o código e a mensagem do erro enviado pelo Android', () async {
    mockAndroid(
      (_) async => throw PlatformException(
        code: 'PAYMENT_APP_NOT_FOUND',
        message: 'Nenhum aplicativo disponível para processar o pagamento.',
      ),
    );

    final failure = await send();

    expect(failure?.code, 'PAYMENT_APP_NOT_FOUND');
    expect(failure?.message, 'Nenhum aplicativo disponível para processar o pagamento.');
  });

  test('usa a mensagem padrão quando o Android não envia mensagem', () async {
    mockAndroid((_) async => throw PlatformException(code: 'PAYMENT_START_ERROR'));

    expect((await send())?.message, 'Não foi possível iniciar o pagamento.');
  });

  test('retorna falha quando o Android não confirma a abertura', () async {
    mockAndroid((_) async => false);

    expect((await send())?.code, 'PAYMENT_NOT_STARTED');
  });

  test('retorna NOT_SUPPORTED quando o canal não existe na plataforma', () async {
    mockAndroid(null);

    expect((await send())?.code, 'NOT_SUPPORTED');
  });

  test('publica em responses o onStonePaymentResponse enviado pelo Android', () async {
    final response = service.responses.first;

    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(
        const MethodCall('onStonePaymentResponse', {
          'code': '-6',
          'reason': '1016',
          'message': 'Não autorizada',
        }),
      ),
      (_) {},
    );

    expect((await response).data, {'code': '-6', 'reason': '1016', 'message': 'Não autorizada'});
    expect((await response).isApproved, isFalse);
  });
}
