import 'package:core/core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('pagbankChannel');
  const payment = PagBankPaymentModel(
    type: PagBankPaymentType.credit,
    amount: 3000,
    installmentType: PagBankInstallmentType.parceladoVendedor,
    installments: 3,
  );
  const approved = {
    'result': 0,
    'errorCode': '0000',
    'transactionCode': 'TC1',
    'transactionId': 'TID1',
    'amount': '3000',
    'paymentType': 'CREDIT',
    'voidType': 'PAYMENT',
  };
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late PagBankPaymentService service;
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    service = PagBankPaymentService(channel);
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

  test('envia o pagamento e devolve a transação aprovada', () async {
    mockAndroid((_) async => approved);

    final result = await service.sendPayment(payment);

    expect(calls.single.method, 'doPayment');
    expect(calls.single.arguments, {
      'type': 'CREDIT',
      'amount': 3000,
      'installmentType': 'PARC_VENDEDOR',
      'installments': 3,
      'userReference': null,
      'printReceipt': false,
    });
    expect(result.getRight().toNullable()?.transactionCode, 'TC1');
  });

  test('transação negada vira falha com o errorCode e a transação', () async {
    mockAndroid((_) async => {'result': -1, 'errorCode': 'R 51', 'message': 'SALDO INSUFICIENTE'});

    final failure = (await service.sendPayment(payment)).getLeft().toNullable();

    expect(failure?.code, 'R 51');
    expect(failure?.message, 'SALDO INSUFICIENTE');
    expect(failure?.transaction?.isApproved, isFalse);
  });

  test('não chama o terminal com valor, parcelas ou código da venda inválidos', () async {
    mockAndroid((_) async => approved);

    final failures = [
      for (final data in [
        const PagBankPaymentModel(type: PagBankPaymentType.debit, amount: 0),
        const PagBankPaymentModel(type: PagBankPaymentType.credit, amount: 1000, installments: 2),
        const PagBankPaymentModel(type: PagBankPaymentType.debit, amount: 1000, userReference: 'VENDA-01'),
      ])
        (await service.sendPayment(data)).getLeft().toNullable()?.code,
    ];

    expect(failures, ['INVALID_AMOUNT', 'INVALID_INSTALLMENTS', 'INVALID_USER_REFERENCE']);
    expect(calls, isEmpty);
  });

  test('mantém o código e a mensagem do erro enviado pelo Android', () async {
    mockAndroid(
      (_) async => throw PlatformException(code: 'SERVICE_BUSY', message: 'O PlugPagService está ocupado.'),
    );

    final failure = (await service.sendPayment(payment)).getLeft().toNullable();

    expect(failure?.code, 'SERVICE_BUSY');
    expect(failure?.message, 'O PlugPagService está ocupado.');
  });

  test('retorna NOT_SUPPORTED quando o canal não existe na plataforma', () async {
    mockAndroid(null);

    expect((await service.sendPayment(payment)).getLeft().toNullable()?.code, 'NOT_SUPPORTED');
  });

  test('retorno que não é uma transação vira INVALID_RESPONSE', () async {
    mockAndroid((_) async => true);

    expect((await service.sendPayment(payment)).getLeft().toNullable()?.code, 'INVALID_RESPONSE');
  });

  test('estorna com o tipo de estorno da transação', () async {
    mockAndroid((_) async => approved);
    final transaction = PagBankTransaction.fromMap({...approved, 'voidType': 'QRCODE'})!;

    final result = await service.voidPayment(PagBankVoidModel.fromTransaction(transaction));

    expect(calls.single.method, 'voidPayment');
    expect(calls.single.arguments, {
      'transactionCode': 'TC1',
      'transactionId': 'TID1',
      'voidType': 'QRCODE',
      'printReceipt': false,
    });
    expect(result.isRight(), isTrue);
  });

  test('não estorna sem o código e o id da transação', () async {
    mockAndroid((_) async => approved);

    final failure = await service.voidPayment(
      const PagBankVoidModel(transactionCode: 'TC1', transactionId: ''),
    );

    expect(failure.getLeft().toNullable()?.code, 'INVALID_VOID');
    expect(calls, isEmpty);
  });

  test('abort só é sucesso com result 0', () async {
    mockAndroid((_) async => 0);
    expect((await service.abort()).isRight(), isTrue);
    expect(calls.single.method, 'abort');

    mockAndroid((_) async => -1);
    expect((await service.abort()).getLeft().toNullable()?.code, 'NOT_ABORTED');
  });

  test('a última transação aprovada sem código e id vira NO_TRANSACTION', () async {
    mockAndroid((_) async => approved);
    expect((await service.getLastApprovedTransaction()).getRight().toNullable()?.transactionId, 'TID1');

    mockAndroid((_) async => {'result': 0, 'transactionCode': '', 'transactionId': ''});
    expect((await service.getLastApprovedTransaction()).getLeft().toNullable()?.code, 'NO_TRANSACTION');
  });

  test('reimpressão só é sucesso com result 0', () async {
    mockAndroid(
      (call) async => call.method == 'reprintCustomerReceipt'
          ? {'result': 0, 'errorCode': null, 'message': null}
          : {'result': -1, 'errorCode': 'P05', 'message': 'SEM PAPEL'},
    );

    expect((await service.reprintCustomerReceipt()).isRight(), isTrue);

    final failure = (await service.reprintEstablishmentReceipt()).getLeft().toNullable();
    expect(failure?.code, 'P05');
    expect(failure?.message, 'SEM PAPEL');
  });

  group('printImage', () {
    final image = Uint8List.fromList([137, 80, 78, 71]);

    test('envia a imagem, a qualidade e o avanço de papel, e só é sucesso com result 0', () async {
      mockAndroid((_) async => {'result': 0, 'errorCode': null, 'message': null});

      final result = await service.printImage(
        PagBankPrintModel(image: image, quality: PagBankPrintQuality.high, steps: 90),
      );

      expect(calls.single.method, 'printImage');
      expect(calls.single.arguments, {'image': image, 'quality': 3, 'steps': 90});
      expect(result.isRight(), isTrue);

      mockAndroid((_) async => {'result': -1, 'errorCode': 'P05', 'message': 'SEM PAPEL'});

      final failure = (await service.printImage(PagBankPrintModel(image: image))).getLeft().toNullable();
      expect(failure?.code, 'P05');
      expect(failure?.message, 'SEM PAPEL');
    });

    test('não chama o terminal com imagem vazia ou avanço abaixo do mínimo', () async {
      mockAndroid((_) async => {'result': 0});

      final failures = [
        for (final data in [
          PagBankPrintModel(image: Uint8List(0)),
          PagBankPrintModel(image: image, steps: 69),
        ])
          (await service.printImage(data)).getLeft().toNullable()?.code,
      ];

      expect(failures, ['INVALID_PRINT', 'INVALID_PRINT']);
      expect(calls, isEmpty);
    });

    test('falha sem mensagem do terminal não fala em reimpressão', () async {
      mockAndroid((_) async => {'result': -1, 'errorCode': null, 'message': null});

      final failure = (await service.printImage(PagBankPrintModel(image: image))).getLeft().toNullable();

      expect(failure?.message, allOf(isNotEmpty, isNot(contains('reimprimir'))));
    });
  });

  test('publica em events o onPagBankEvent enviado pelo Android', () async {
    final event = service.events.first;

    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(const MethodCall('onPagBankEvent', {'code': 16, 'message': null})),
      (_) {},
    );

    expect((await event).isPasswordDigit, isTrue);
  });
}
