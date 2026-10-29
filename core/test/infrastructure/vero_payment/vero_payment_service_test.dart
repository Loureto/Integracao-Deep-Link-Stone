import 'dart:async';

import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('vero_flutter');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _FakePrinter printer;
  late VeroPaymentService service;
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    printer = _FakePrinter();
    service = VeroPaymentService(channel, printer);
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

  test('cada pagamento chama o método do plugin com o valor em centavos arredondado', () async {
    mockAndroid((_) async => {'AUTORIZACAO': 'A1', 'NSU': '1'});

    await service.creditCardPayment(0.29);
    await service.debitCardPayment(4.35);
    await service.pixPayment(33.30);
    await service.acquirerPayment(1.00);

    // Com o truncamento do centralizer seriam 28, 434 e 3329 centavos.
    expect(calls.map((c) => [c.method, c.arguments]), [
      [
        'payCredit',
        {'amount': 29},
      ],
      [
        'payDebit',
        {'amount': 435},
      ],
      [
        'payPix',
        {'amount': 3330},
      ],
      [
        'wallet',
        {'amount': 100},
      ],
    ]);
  });

  test('pagamento aprovado devolve a transação e imprime o comprovante do cliente', () async {
    mockAndroid((_) async => {'AUTORIZACAO': 'A1', 'NSU': '123', 'COMPROVANTE_CLIENTE_TXT': 'VIA CLIENTE'});

    final result = (await service.creditCardPayment(10)).getRight().toNullable();

    expect([result?.nsu, result?.authorization], ['123', 'A1']);
    expect(printer.texts, ['VIA CLIENTE']);
  });

  test('estorno aprovado também imprime o comprovante do cliente', () async {
    mockAndroid((_) async => {'AUTORIZACAO': 'A1', 'COMPROVANTE_CLIENTE_TXT': 'ESTORNO'});

    final result = await service.refundPayment('123');

    expect(result.isRight(), isTrue);
    expect(
      [calls.single.method, calls.single.arguments],
      [
        'refund',
        {'nsu': '123'},
      ],
    );
    expect(printer.texts, ['ESTORNO']);
  });

  test('falha na impressão do comprovante não muda o resultado', () async {
    printer.result = left(
      const NativePrinterFailure(code: 'ERRO_SEM_PAPEL', message: 'Impressora sem papel, verifique!'),
    );
    mockAndroid((_) async => {'AUTORIZACAO': 'A1', 'NSU': '123', 'COMPROVANTE_CLIENTE_TXT': 'VIA CLIENTE'});

    final result = (await service.debitCardPayment(1)).getRight().toNullable();

    expect(result?.nsu, '123');
    expect(printer.texts, hasLength(1));
  });

  test('sem comprovante do cliente a aprovação volta sem imprimir', () async {
    mockAndroid((_) async => {'AUTORIZACAO': 'A1', 'NSU': '123'});
    final withoutReceipt = await service.creditCardPayment(1);

    mockAndroid((_) async => {'AUTORIZACAO': 'A1', 'NSU': '124', 'COMPROVANTE_CLIENTE_TXT': ' \n '});
    final blankReceipt = await service.creditCardPayment(1);

    expect([withoutReceipt.isRight(), blankReceipt.isRight()], [true, true]);
    expect(printer.texts, isEmpty);
  });

  testWidgets('comprovante que o driver não responde segura a aprovação por no máximo 60 s', (tester) async {
    printer.pending = Completer();
    mockAndroid((_) async => {'AUTORIZACAO': 'A1', 'NSU': '123', 'COMPROVANTE_CLIENTE_TXT': 'VIA CLIENTE'});

    Either<VeroFailure, VeroTransactionResult>? result;
    unawaited(service.creditCardPayment(1).then((value) => result = value));

    await tester.pump(const Duration(seconds: 59));
    expect(result, isNull);

    await tester.pump(const Duration(seconds: 1));
    expect(result?.getRight().toNullable()?.nsu, '123');
  });

  test('erro sem mensagem usa a stack trace e, sem ela, o texto do erro', () async {
    // O MethodChannel do Android manda só a stack trace quando escapa uma exceção sem mensagem.
    final withTrace = VeroPaymentService(
      _FailingChannel(PlatformException(code: 'error', stacktrace: 'at VeroPaymentHandler.start')),
      printer,
    );
    final bare = VeroPaymentService(_FailingChannel(PlatformException(code: 'error')), printer);

    expect((await withTrace.pixPayment(1)).getLeft().toNullable()?.message, 'at VeroPaymentHandler.start');
    expect(
      (await bare.pixPayment(1)).getLeft().toNullable()?.message,
      'PlatformException(error, null, null, null)',
    );
  });

  test('erro do app da Vero volta com o mesmo código e mensagem, sem imprimir', () async {
    mockAndroid(
      (_) async =>
          throw PlatformException(code: 'ERRO_DESCONHECIDO', message: 'Operação cancelada pelo usuário!'),
    );

    final failure = (await service.pixPayment(1)).getLeft().toNullable();

    expect([failure?.code, failure?.message], ['ERRO_DESCONHECIDO', 'Operação cancelada pelo usuário!']);
    expect(printer.texts, isEmpty);
  });

  test('estorno com NSU em branco não chama o Android', () async {
    mockAndroid((_) async => {'AUTORIZACAO': 'A1'});

    final failure = (await service.refundPayment('  ')).getLeft().toNullable();

    expect(
      [failure?.code, failure?.message],
      [
        'nsu.not.informed',
        'O campo: nsu não foi informado! Corrija-o e tente novamente!',
      ],
    );
    expect(calls, isEmpty);
  });

  test('canal inexistente vira <método>.not.implemented', () async {
    mockAndroid(null);

    final failure = (await service.creditCardPayment(1)).getLeft().toNullable();

    expect(
      [failure?.code, failure?.message],
      ['payCredit.not.implemented', 'payCredit() has not been implemented.'],
    );
  });

  test('resposta vazia vira unknown.error', () async {
    mockAndroid((_) async => null);

    final failure = (await service.acquirerPayment(1)).getLeft().toNullable();

    expect([failure?.code, failure?.message], ['unknown.error', 'Erro desconhecido, tente novamente']);
    expect(printer.texts, isEmpty);
  });
}

/// Canal em que o Android responde com [error]. O mock de canal do Flutter não repassa a stack trace.
class _FailingChannel extends MethodChannel {
  final PlatformException error;

  _FailingChannel(this.error) : super('vero_flutter');

  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async => throw error;
}

class _FakePrinter implements INativePrinterService {
  /// Textos recebidos em [printTxt], na ordem.
  final texts = <String>[];
  Either<NativePrinterFailure, Unit> result = right(unit);

  /// Quando definida, a impressão só responde quando ela completar, como um driver que não chama o listener.
  Completer<Either<NativePrinterFailure, Unit>>? pending;

  @override
  Future<Either<NativePrinterFailure, Unit>> printTxt(String text) async {
    texts.add(text);
    return pending?.future ?? result;
  }

  @override
  Future<Either<NativePrinterFailure, Unit>> printNfc(String nfcBase64) => throw UnimplementedError();

  @override
  Future<Either<NativePrinterFailure, Unit>> testPrint() => throw UnimplementedError();

  @override
  Future<Either<NativePrinterFailure, Unit>> printReceipt({required Uint8List bitmap}) =>
      throw UnimplementedError();
}
