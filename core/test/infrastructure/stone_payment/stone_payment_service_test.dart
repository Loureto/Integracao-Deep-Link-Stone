import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('stoneDeeplinkChannel');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _FakePdfImageConverter converter;
  late StonePaymentService service;
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    converter = _FakePdfImageConverter();
    service = StonePaymentService(channel, converter);
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

  group('impressão', () {
    Future<StonePaymentFailure?> printReceipt(Uint8List bitmap) async {
      return (await service.printReceipt(bitmap: bitmap)).getLeft().toNullable();
    }

    Future<_Image> sentImage() async {
      final imageBase64 = (calls.single.arguments as Map)['image_base64'] as String;
      return _decode(base64Decode(imageBase64));
    }

    test('printReceipt envia a imagem em preto e branco no print_receipt do stone_sdk', () async {
      mockAndroid((_) async => 'SUCCESS');
      // Preto, cinza escuro, cinza claro, branco e um pixel transparente.
      final bitmap = await _png([0, 100, 160, 255, null]);

      final failure = await printReceipt(bitmap);

      expect(failure, isNull);
      expect(calls.single.method, 'print_receipt');
      // Abaixo de 128 vira preto; o resto, inclusive o transparente, vira papel em branco.
      expect((await sentImage()).tones.take(5), [0, 0, 255, 255, 255]);
    });

    test('printReceipt acrescenta 1 cm de papel em branco no fim, que o app da Stone não avança', () async {
      mockAndroid((_) async => 'SUCCESS');

      await printReceipt(await _png([0, 0, 0]));

      // A impressora tem 8 pontos por milímetro: 1 cm são 80 linhas abaixo da última linha da imagem.
      final sent = await sentImage();
      expect([sent.width, sent.height], [3, 81]);
      expect(sent.tones.take(3), [0, 0, 0]);
      expect(sent.tones.skip(3), everyElement(255));
    });

    test('printReceipt tenta mais uma vez quando a impressora não inicializa, como o stone_sdk', () async {
      var attempts = 0;
      mockAndroid((_) async {
        if (++attempts == 1) throw PlatformException(code: 'PRINTER_INIT_ERROR');
        return 'SUCCESS';
      });

      final failure = await printReceipt(await _png([0]));

      expect(failure, isNull);
      expect(calls, hasLength(2));
    });

    test(
      'printReceipt devolve a falha de inicialização quando ela se repete, sem terceira tentativa',
      () async {
        mockAndroid(
          (_) async => throw PlatformException(
            code: 'PRINTER_INIT_ERROR',
            message: 'Erro ao inicializar a impressora.',
          ),
        );

        final failure = await printReceipt(await _png([0]));

        expect(failure?.code, 'PRINTER_INIT_ERROR');
        expect(failure?.message, 'Erro ao inicializar a impressora.');
        expect(calls, hasLength(2));
      },
    );

    test('printReceipt mantém o código e a mensagem do retorno da impressora', () async {
      mockAndroid(
        (_) async => throw PlatformException(
          code: 'PRINTER_OUT_OF_PAPER',
          message: 'Impressora sem papel ou com a tampa de bobina aberta.',
        ),
      );

      final failure = await printReceipt(await _png([0]));

      expect(failure?.code, 'PRINTER_OUT_OF_PAPER');
      expect(failure?.message, 'Impressora sem papel ou com a tampa de bobina aberta.');
      expect(calls, hasLength(1));
    });

    test('printReceipt usa a mensagem genérica da impressora quando o Android não envia mensagem', () async {
      mockAndroid((_) async => throw PlatformException(code: 'PRINTER_PRINT_ERROR'));

      expect((await printReceipt(await _png([0])))?.message, 'Erro genérico da impressora.');
    });

    test('printReceipt não envia a imagem que passa do tamanho aceito no deeplink', () async {
      mockAndroid((_) async => 'SUCCESS');
      // Ruído não comprime: mesmo em preto e branco, o PNG de 384 x 4000 tem uns 190 KB.
      final random = Random(7);
      final noise = await _png([
        for (var i = 0; i < 384 * 4000; i++) random.nextBool() ? 0 : 255,
      ], width: 384);

      final failure = await printReceipt(noise);

      expect(failure?.code, 'PRINTER_INVALID_DATA');
      expect(failure?.message, 'Limite máximo do buffer foi ultrapassado.');
      expect(calls, isEmpty);
    });

    test('printReceipt não envia o que não é imagem', () async {
      mockAndroid((_) async => 'SUCCESS');

      final failure = await printReceipt(Uint8List.fromList([1, 2, 3]));

      expect(failure?.code, 'PRINTER_UNSUPPORTED_FORMAT');
      expect(
        failure?.message,
        'Algum formato enviado não corresponde ao padrão de texto, imagem ou texto customizado.',
      );
      expect(calls, isEmpty);
    });

    test('printReceipt retorna NOT_SUPPORTED quando o canal não existe na plataforma', () async {
      mockAndroid(null);

      expect((await printReceipt(await _png([0])))?.code, 'NOT_SUPPORTED');
    });

    test(
      'printNfc converte a primeira página da NFC-e e imprime a imagem, como o StoneIntegration',
      () async {
        mockAndroid((_) async => 'SUCCESS');
        converter.result = right(await _png([0, 255]));

        final result = await service.printNfc('JVBERi0=');

        expect(result.isRight(), isTrue);
        expect(converter.pdfs.single, 'JVBERi0=');
        expect(calls.single.method, 'print_receipt');
        expect((await sentImage()).tones.take(2), [0, 255]);
      },
    );

    test('printNfc devolve a falha do conversor sem chamar o Android', () async {
      mockAndroid((_) async => 'SUCCESS');
      converter.result = left(PdfImageFailure.invalidPdf('PDF corrompido'));

      final failure = (await service.printNfc('JVBERi0=')).getLeft().toNullable();

      expect(failure?.code, 'INVALID_PDF');
      expect(failure?.message, 'PDF corrompido');
      expect(calls, isEmpty);
    });
  });
}

/// PNG com [tones] de cinza em linhas de [width] pontos; `null` é um pixel transparente.
Future<Uint8List> _png(List<int?> tones, {int? width}) async {
  final columns = width ?? tones.length;
  final pixels = Uint8List(tones.length * 4);
  for (final (i, tone) in tones.indexed) {
    pixels.setAll(i * 4, tone == null ? [0, 0, 0, 0] : [tone, tone, tone, 255]);
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

class _FakePdfImageConverter implements IPdfImageConverter {
  final pdfs = <String>[];
  late Either<PdfImageFailure, Uint8List> result;

  @override
  Future<Either<PdfImageFailure, Uint8List>> firstPageToPng(String pdfBase64) async {
    pdfs.add(pdfBase64);
    return result;
  }
}
