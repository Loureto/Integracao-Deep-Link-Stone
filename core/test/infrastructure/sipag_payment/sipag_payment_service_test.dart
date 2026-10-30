import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('sipag_sdk');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const service = SiPagPaymentService(channel);
  late List<MethodCall> calls;

  /// Resposta do Android a um crédito aprovado, com as chaves do plugin.
  const approved = {
    'MESSAGE': 'Operação efetuada com sucesso!',
    'FLAG': 'VISA',
    'NSU_SITEF': '123',
    'CARD_NUMBER': '************1234',
    'AUTHORIZATION': 'A1',
    'COMPANY_RECEIPT': 'VIA LOJA',
    'CLIENT_RECEIPT': 'VIA CLIENTE',
    'INSTALLMENTS': 1,
    'AMOUNT': 1.0,
  };

  setUp(() => calls = []);

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

  List<Object?> methodsAndArguments() => calls.map((c) => [c.method, c.arguments]).toList();

  group('pagamentos', () {
    test('cada pagamento chama o método do plugin com o valor em reais, duas casas e vírgula', () async {
      mockAndroid((_) async => approved);

      await service.creditCardPayment(0.29);
      await service.debitCardPayment(4.35);
      await service.pixPayment(33.3);
      await service.creditCardPayment(1000);

      expect(methodsAndArguments(), [
        [
          'pay_credit',
          {'amount': '0,29'},
        ],
        [
          'pay_debit',
          {'amount': '4,35'},
        ],
        [
          'pay_pix',
          {'amount': '33,30'},
        ],
        [
          'pay_credit',
          {'amount': '1000,00'},
        ],
      ]);
    });

    test('pagamento aprovado devolve a transação, sem comprovante automático', () async {
      mockAndroid((_) async => approved);

      final result = await service.creditCardPayment(1);

      expect(result, right(SiPagTransactionResult.fromMap(approved)));
      expect(calls.map((c) => c.method), ['pay_credit']);
    });

    test('a última operação chama get_last_operation sem argumentos', () async {
      mockAndroid((_) async => approved);

      final result = await service.getLastOperation();

      expect(calls.single.method, 'get_last_operation');
      expect(calls.single.arguments, anyOf(isNull, isEmpty));
      expect(result.isRight(), isTrue);
    });
  });

  group('estorno', () {
    test('type 1 estorna o Pix, e 0 (o genérico do PDV) ou negativo, o cartão', () async {
      mockAndroid((_) async => approved);

      for (final type in [1, 0, -1]) {
        await service.refundPayment(type, '9');
      }

      expect(methodsAndArguments(), [
        for (final method in ['refund_pix', 'refund', 'refund'])
          [
            method,
            {'nsu': '9'},
          ],
      ]);
    });

    test('type maior que 1 responde type.is.invalid sem chamar o Android', () async {
      // No PaymentService do centralizer, a Sipag recusa até o 2 (crédito) e o 3 (débito) da fachada.
      mockAndroid((_) async => approved);

      for (final type in [2, 3, 4]) {
        expect(await service.refundPayment(type, '9'), left(SiPagFailure.invalidRefundType()));
      }
      expect(calls, isEmpty);
    });

    test('NSU em branco responde antes do type e sem chamar o Android', () async {
      mockAndroid((_) async => approved);

      final result = await service.refundPayment(4, '  ');

      expect(result, left(SiPagFailure.nsuNotInformed()));
      expect(calls, isEmpty);
    });
  });

  group('erros', () {
    test('erro do Android volta com o mesmo código e mensagem', () async {
      mockAndroid(
        (_) async => throw PlatformException(code: 'LICENCA_INVALIDA', message: 'Licença expirada.'),
      );

      final result = await service.debitCardPayment(1);

      expect(result, left(const SiPagFailure(code: 'LICENCA_INVALIDA', message: 'Licença expirada.')));
    });

    test('erro sem mensagem usa a stack trace e, sem ela, o texto do erro', () async {
      // O MethodChannel do Android manda só a stack trace quando escapa uma exceção sem mensagem.
      final withTrace = SiPagPaymentService(
        _FailingChannel(PlatformException(code: 'error', stacktrace: 'at SipagPaymentHandler.handle')),
      );
      final bare = SiPagPaymentService(_FailingChannel(PlatformException(code: 'error')));

      expect(
        (await withTrace.pixPayment(1)).getLeft().toNullable()?.message,
        'at SipagPaymentHandler.handle',
      );
      expect(
        (await bare.pixPayment(1)).getLeft().toNullable()?.message,
        'PlatformException(error, null, null, null)',
      );
    });

    test('canal inexistente vira <método>.not.implemented', () async {
      mockAndroid(null);

      final result = await service.creditCardPayment(1);

      expect(result, left(SiPagFailure.notImplemented('pay_credit')));
    });

    test('resposta vazia vira unknown.error', () async {
      mockAndroid((_) async => null);

      final result = await service.pixPayment(1);

      expect(result, left(SiPagFailure.unknown()));
    });
  });
}

class _FailingChannel extends MethodChannel {
  final PlatformException error;

  _FailingChannel(this.error) : super('sipag_sdk');

  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async => throw error;
}
