import 'dart:async';
import 'dart:ui' as ui;

import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('acquirers_sdk');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _FakePdfImageConverter converter;
  late NativePrinterService service;
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    converter = _FakePdfImageConverter();
    service = NativePrinterService(channel, converter);
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

  test('printTxt e testPrint usam os nomes do NativePrinter', () async {
    mockAndroid((_) async => 'Sucesso ao efetuar a impressão');

    expect((await service.printTxt('LINHA')).isRight(), isTrue);
    expect((await service.testPrint()).isRight(), isTrue);

    expect(calls.map((c) => c.method), ['printTxt', 'testPrint']);
    expect(calls.first.arguments, {'text': 'LINHA'});
  });

  test('printReceipt manda o bitmap com 1 cm de papel em branco no fim', () async {
    mockAndroid((_) async => 'Sucesso ao efetuar a impressão');

    await service.printReceipt(bitmap: await _png([0, 0, 0]));

    expect(calls.single.method, 'printReceipt');
    // A impressora tem 8 pontos por milímetro: 1 cm são 80 linhas abaixo da última linha da imagem.
    final sent = await _decode((calls.single.arguments as Map)['bitmap'] as Uint8List);
    expect([sent.width, sent.height], [3, 81]);
    expect(sent.tones.take(3), [0, 0, 0]);
    expect(sent.tones.skip(3), everyElement(255));
  });

  test('printReceipt libera o Picture usado para a margem', () async {
    mockAndroid((_) async => 'Sucesso ao efetuar a impressão');
    final png = await _png([0, 0, 0]);
    final created = <ui.Picture>[];
    final disposed = <ui.Picture>[];
    ui.Picture.onCreate = created.add;
    ui.Picture.onDispose = disposed.add;
    addTearDown(() {
      ui.Picture.onCreate = null;
      ui.Picture.onDispose = null;
    });

    await service.printReceipt(bitmap: png);

    expect(created, hasLength(1));
    expect(disposed, created);
  });

  test('printReceipt não manda o que não é imagem', () async {
    mockAndroid((_) async => 'Sucesso ao efetuar a impressão');

    final failure = (await service.printReceipt(
      bitmap: Uint8List.fromList([1, 2, 3]),
    )).getLeft().toNullable();

    expect([failure?.code, failure?.message], ['ERRO_DESCONHECIDO', 'Erro na impressão']);
    expect(calls, isEmpty);
  });

  test(
    'tenta mais uma vez em ERRO_DESCONHECIDO e em IMPRESSORA_INDISPONIVEL, e não em ERRO_SEM_PAPEL',
    () async {
      for (final code in ['ERRO_DESCONHECIDO', 'IMPRESSORA_INDISPONIVEL']) {
        calls.clear();
        mockAndroid((_) async => throw PlatformException(code: code, message: 'Erro na impressão'));

        final failure = (await service.printTxt('X')).getLeft().toNullable();

        expect(failure?.code, code);
        expect(calls, hasLength(2), reason: code);
      }

      calls.clear();
      mockAndroid(
        (_) async =>
            throw PlatformException(code: 'ERRO_SEM_PAPEL', message: 'Impressora sem papel, verifique!'),
      );

      final failure = (await service.printTxt('X')).getLeft().toNullable();

      expect([failure?.code, failure?.message], ['ERRO_SEM_PAPEL', 'Impressora sem papel, verifique!']);
      expect(calls, hasLength(1));
    },
  );

  test('a nova tentativa que dá certo devolve sucesso', () async {
    var attempts = 0;
    mockAndroid((_) async {
      if (++attempts == 1) throw PlatformException(code: 'ERRO_DESCONHECIDO', message: 'Erro na impressão');
      return 'Sucesso ao efetuar a impressão';
    });

    expect((await service.testPrint()).isRight(), isTrue);
    expect(calls, hasLength(2));
  });

  test('printNfc converte a NFC-e e imprime a imagem', () async {
    mockAndroid((_) async => 'Sucesso ao efetuar a impressão');
    converter.result = right(await _png([0, 255]));

    final result = await service.printNfc('JVBERi0=');

    expect(result.isRight(), isTrue);
    expect(converter.pdfs.single, 'JVBERi0=');
    expect(calls.single.method, 'printReceipt');
  });

  test('printNfc devolve a falha do conversor sem chamar o Android', () async {
    mockAndroid((_) async => 'Sucesso ao efetuar a impressão');
    converter.result = left(PdfImageFailure.invalidPdf('PDF corrompido'));

    final failure = (await service.printNfc('JVBERi0=')).getLeft().toNullable();

    expect([failure?.code, failure?.message], ['INVALID_PDF', 'PDF corrompido']);
    expect(calls, isEmpty);
  });

  test('erro sem mensagem usa a stack trace e, sem ela, o texto do erro', () async {
    // O MethodChannel do Android manda só a stack trace quando escapa uma exceção sem mensagem.
    final withTrace = NativePrinterService(
      _FailingChannel(PlatformException(code: 'error', stacktrace: 'at ServicePrinter.printBitmap')),
      converter,
    );
    final bare = NativePrinterService(_FailingChannel(PlatformException(code: 'error')), converter);

    expect((await withTrace.printTxt('X')).getLeft().toNullable()?.message, 'at ServicePrinter.printBitmap');
    expect(
      (await bare.printTxt('X')).getLeft().toNullable()?.message,
      'PlatformException(error, null, null, null)',
    );
  });

  test('canal inexistente vira NOT_SUPPORTED', () async {
    mockAndroid(null);

    final failure = (await service.testPrint()).getLeft().toNullable();

    expect(
      [failure?.code, failure?.message],
      ['NOT_SUPPORTED', 'Driver de impressão indisponível nesta plataforma.'],
    );
  });
}

/// PNG com [tones] de cinza em linhas de [width] pontos.
Future<Uint8List> _png(List<int> tones, {int? width}) async {
  final columns = width ?? tones.length;
  final pixels = Uint8List(tones.length * 4);
  for (final (i, tone) in tones.indexed) {
    pixels.setAll(i * 4, [tone, tone, tone, 255]);
  }
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    columns,
    tones.length ~/ columns,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  final image = await completer.future;
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

/// Largura e altura do PNG e o tom de cinza de cada pixel, linha a linha.
typedef _Image = ({int width, int height, List<int> tones});

Future<_Image> _decode(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final image = (await codec.getNextFrame()).image;
  final pixels = (await image.toByteData())!.buffer.asUint8List();
  return (
    width: image.width,
    height: image.height,
    tones: [for (var i = 0; i < pixels.length; i += 4) pixels[i]],
  );
}

/// Canal em que o Android responde com [error]. O mock de canal do Flutter não repassa a stack trace.
class _FailingChannel extends MethodChannel {
  final PlatformException error;

  _FailingChannel(this.error) : super('acquirers_sdk');

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
