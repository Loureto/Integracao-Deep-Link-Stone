import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/images.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('rede_sdk');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _FakePdfImageConverter converter;
  late RedePaymentService service;
  late List<MethodCall> calls;

  /// Resposta do Android a um crédito aprovado, com as chaves do plugin.
  const approved = {
    'FLAG': 'VISA',
    'NSU_SITEF': '123',
    'AUTHORIZATION': 'A1',
    'INSTALLMENTS': 1,
    'AMOUNT': 1.0,
    'CARD_NUMBER': 'Crédito',
  };

  setUp(() {
    calls = [];
    converter = _FakePdfImageConverter();
    service = RedePaymentService(channel, converter);
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

  group('pagamentos', () {
    test('cada pagamento chama o método do plugin com o valor em centavos arredondado', () async {
      mockAndroid((_) async => approved);

      await service.creditCardPayment(0.29);
      await service.debitCardPayment(4.35);
      await service.pixPayment(33.30);

      // Com o truncamento do plugin seriam 28, 434 e 3329 centavos.
      expect(calls.map((c) => [c.method, c.arguments]), [
        [
          'credit_payment',
          {'amount': 29},
        ],
        [
          'debit_payment',
          {'amount': 435},
        ],
        [
          'pix_payment',
          {'amount': 3330},
        ],
      ]);
    });

    test('pagamento aprovado devolve a transação, sem comprovante automático', () async {
      mockAndroid((_) async => approved);

      final result = (await service.creditCardPayment(1)).getRight().toNullable();

      expect([result?.nsu, result?.authorization, result?.amount], ['123', 'A1', 1.0]);
      expect(calls.map((c) => c.method), ['credit_payment']);
    });

    test('estorno manda o NSU', () async {
      mockAndroid((_) async => {'FLAG': 'Estorno'});

      final result = (await service.refundPayment('123')).getRight().toNullable();

      expect(
        [calls.single.method, calls.single.arguments],
        [
          'refund',
          {'nsu': '123'},
        ],
      );
      expect(result?.flag, 'Estorno');
    });

    test('estorno com NSU em branco não chama o Android', () async {
      mockAndroid((_) async => approved);

      final failure = (await service.refundPayment('  ')).getLeft().toNullable();

      expect(
        [failure?.code, failure?.message],
        ['nsu.not.informed', 'O campo: nsu não foi informado! Corrija-o e tente novamente!'],
      );
      expect(calls, isEmpty);
    });

    test('erro do Android volta com o mesmo código e mensagem', () async {
      mockAndroid(
        (_) async => throw PlatformException(code: 'TRANSACTION_DENY', message: 'Operação negada!'),
      );

      final failure = (await service.debitCardPayment(1)).getLeft().toNullable();

      expect([failure?.code, failure?.message], ['TRANSACTION_DENY', 'Operação negada!']);
    });

    test('erro sem mensagem usa a stack trace e, sem ela, o texto do erro', () async {
      // O MethodChannel do Android manda só a stack trace quando escapa uma exceção sem mensagem.
      final withTrace = RedePaymentService(
        _FailingChannel(PlatformException(code: 'error', stacktrace: 'at RedePaymentHandler.start')),
        converter,
      );
      final bare = RedePaymentService(_FailingChannel(PlatformException(code: 'error')), converter);

      expect((await withTrace.pixPayment(1)).getLeft().toNullable()?.message, 'at RedePaymentHandler.start');
      expect(
        (await bare.pixPayment(1)).getLeft().toNullable()?.message,
        'PlatformException(error, null, null, null)',
      );
    });

    test('canal inexistente vira <método>.not.implemented', () async {
      mockAndroid(null);

      final payment = (await service.creditCardPayment(1)).getLeft().toNullable();
      final print = (await service.printTxt('X')).getLeft().toNullable();

      expect(
        [payment?.code, payment?.message],
        ['credit_payment.not.implemented', 'credit_payment() has not been implemented.'],
      );
      expect(print?.code, 'print_txt.not.implemented');
    });

    test('resposta vazia vira unknown.error', () async {
      mockAndroid((_) async => null);

      final failure = (await service.pixPayment(1)).getLeft().toNullable();

      expect([failure?.code, failure?.message], ['unknown.error', 'Erro desconhecido, tente novamente']);
    });
  });

  group('impressão', () {
    test('printTxt e testPrint usam os nomes do plugin', () async {
      mockAndroid((_) async => 'Sucesso ao efetuar a impressão');

      expect((await service.printTxt('LINHA')).isRight(), isTrue);
      expect((await service.testPrint()).isRight(), isTrue);

      expect(calls.map((c) => c.method), ['print_txt', 'test_print']);
      expect(calls.first.arguments, {'text': 'LINHA'});
    });

    test('printReceipt manda o bitmap com 1 cm de papel em branco no fim', () async {
      mockAndroid((_) async => 'Sucesso ao efetuar a impressão');

      await service.printReceipt(bitmap: await png([0, 0, 0]));

      expect(calls.single.method, 'print_receipt');
      final sent = await decodePng((calls.single.arguments as Map)['bitmap'] as Uint8List);
      expect([sent.width, sent.height], [3, 81]);
    });

    test('printReceipt não manda o que não é imagem', () async {
      mockAndroid((_) async => 'Sucesso ao efetuar a impressão');

      final failure = (await service.printReceipt(
        bitmap: Uint8List.fromList([1, 2, 3]),
      )).getLeft().toNullable();

      expect([failure?.code, failure?.message], ['ERRO_DESCONHECIDO', 'Erro na impressão']);
      expect(calls, isEmpty);
    });

    test('printNfc converte a NFC-e e imprime a imagem', () async {
      mockAndroid((_) async => 'Sucesso ao efetuar a impressão');
      converter.result = right(await png([0, 255]));

      final result = await service.printNfc('JVBERi0=');

      expect(result.isRight(), isTrue);
      expect(converter.pdfs.single, 'JVBERi0=');
      expect(calls.single.method, 'print_receipt');
    });

    test('printNfc devolve a falha do conversor sem chamar o Android', () async {
      mockAndroid((_) async => 'Sucesso ao efetuar a impressão');
      converter.result = left(PdfImageFailure.invalidPdf('PDF corrompido'));

      final failure = (await service.printNfc('JVBERi0=')).getLeft().toNullable();

      expect([failure?.code, failure?.message], ['INVALID_PDF', 'PDF corrompido']);
      expect(calls, isEmpty);
    });

    test('tenta mais uma vez em IMPRESSORA_INDISPONIVEL e não nos outros códigos', () async {
      for (final (code, attempts) in [
        ('IMPRESSORA_INDISPONIVEL', 2),
        ('ERRO_SEM_PAPEL', 1),
        ('ERRO_DESCONHECIDO', 1),
      ]) {
        calls.clear();
        mockAndroid((_) async => throw PlatformException(code: code, message: 'Falha na impressão'));

        final failure = (await service.printTxt('X')).getLeft().toNullable();

        expect(failure?.code, code);
        expect(calls, hasLength(attempts), reason: code);
      }
    });

    test('a nova tentativa que dá certo devolve sucesso', () async {
      var attempts = 0;
      mockAndroid((_) async {
        if (++attempts == 1) {
          throw PlatformException(
            code: 'IMPRESSORA_INDISPONIVEL',
            message: 'Módulo de impressão não inicializado',
          );
        }
        return 'Sucesso ao efetuar a impressão';
      });

      expect((await service.testPrint()).isRight(), isTrue);
      expect(calls, hasLength(2));
    });
  });
}

/// Canal em que o Android responde com [error]. O mock de canal do Flutter não repassa a stack trace.
class _FailingChannel extends MethodChannel {
  final PlatformException error;

  _FailingChannel(this.error) : super('rede_sdk');

  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async => throw error;
}

class _FakePdfImageConverter implements IPdfImageConverter {
  final pdfs = <String>[];
  late Either<PdfImageFailure, Uint8List> result;

  @override
  Future<Either<PdfImageFailure, Uint8List>> firstPageToPng(String pdfBase64) async {
    pdfs.add(pdfBase64);
    return result;
  }
}
