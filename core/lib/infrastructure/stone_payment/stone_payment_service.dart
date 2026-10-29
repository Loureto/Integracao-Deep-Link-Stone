import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:dependencies/dependencies.dart';
import 'package:flutter/services.dart';

import '../../data/data.dart';
import '../../domain/domain.dart';

class StonePaymentService implements IStonePaymentService {
  static const _sendDeeplink = 'sendStoneDeeplink';
  static const _onPaymentResponse = 'onStonePaymentResponse';

  /// Método e argumento com os nomes do stone_sdk, usado hoje pelo flutter_acquirers_sdk.
  static const _printReceipt = 'print_receipt';
  static const _imageBase64 = 'image_base64';
  static const _printerInitError = 'PRINTER_INIT_ERROR';

  /// A imagem vai dentro do deeplink, e o Android limita a cerca de 1 MB o que passa de um app para outro: acima
  /// disso a impressão trava sem retorno, avisa a documentação da Stone. Este tanto de base64 ocupa uns 425 KB no
  /// Intent, que guarda o texto em UTF-16.
  static const maxImageBase64Length = 200000;

  /// 1 cm de papel na impressora de 8 pontos por milímetro.
  static const _bottomMargin = 80;

  final MethodChannel _channel;
  final IPdfImageConverter _pdfImage;
  final _responses = StreamController<StonePaymentResponse>.broadcast();

  StonePaymentService(this._channel, this._pdfImage) {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  @override
  Stream<StonePaymentResponse> get responses => _responses.stream;

  @override
  Future<Either<StonePaymentFailure, Unit>> sendPayment(StonePaymentModel data) async {
    if (!data.isAmountValid) return left(StonePaymentFailure.invalidAmount());
    if (!data.isInstallmentCountValid) return left(StonePaymentFailure.invalidInstallmentCount());

    try {
      final opened = await _channel.invokeMethod<bool>(_sendDeeplink, StonePaymentModel.toMap(data));
      if (opened ?? false) return right(unit);

      return left(StonePaymentFailure.paymentNotStarted());
    } on PlatformException catch (e) {
      return left(StonePaymentFailure.fromPlatform(code: e.code, message: e.message));
    } on MissingPluginException {
      return left(StonePaymentFailure.notSupported());
    }
  }

  @override
  Future<Either<StonePaymentFailure, Unit>> printNfc(String nfcBase64) async {
    final image = await _pdfImage.firstPageToPng(nfcBase64);

    return image.match<Future<Either<StonePaymentFailure, Unit>>>(
      (failure) async => left(StonePaymentFailure.fromPrinter(code: failure.code, message: failure.message)),
      (png) => printReceipt(bitmap: png),
    );
  }

  @override
  Future<Either<StonePaymentFailure, Unit>> printReceipt({required Uint8List bitmap}) async {
    final String imageBase64;
    try {
      imageBase64 = base64Encode(await _forStonePrinter(bitmap));
    } on Exception {
      return left(StonePaymentFailure.printerUnsupportedFormat());
    }
    if (imageBase64.length > maxImageBase64Length) return left(StonePaymentFailure.printerInvalidData());

    return _print({_imageBase64: imageBase64});
  }

  /// Envia a impressão e, se a impressora não inicializar, tenta mais uma vez, como o stone_sdk.
  Future<Either<StonePaymentFailure, Unit>> _print(
    Map<String, String> arguments, {
    bool isRetry = false,
  }) async {
    try {
      await _channel.invokeMethod<String>(_printReceipt, arguments);
      return right(unit);
    } on PlatformException catch (e) {
      if (e.code == _printerInitError && !isRetry) return _print(arguments, isRetry: true);

      return left(StonePaymentFailure.fromPrinter(code: e.code, message: e.message));
    } on MissingPluginException {
      return left(StonePaymentFailure.notSupported());
    }
  }

  /// Prepara a imagem para o app de impressão da Stone.
  ///
  /// A impressora térmica só imprime preto e branco: mandar a imagem já assim deixa o PNG umas dez vezes menor,
  /// e a NFC-e cabe no deeplink. Abaixo de 128 vira preto; o resto, inclusive o transparente, vira papel.
  ///
  /// No fim entram [_bottomMargin] linhas em branco: o app da Stone não avança o papel o bastante depois da
  /// imagem, e sem elas a última linha da NFC-e ficava antes da serrilha. O PagBank avança sozinho.
  static Future<Uint8List> _forStonePrinter(Uint8List png) async {
    final codec = await ui.instantiateImageCodec(png);
    final source = (await codec.getNextFrame()).image;
    try {
      final width = source.width;
      final height = source.height + _bottomMargin;
      final output = Uint8List(width * height * 4)..fillRange(0, width * height * 4, 255);

      // Cores com alfa pré-multiplicado: o pixel sobre o papel branco é a cor mais o que falta de opacidade.
      final pixels = (await source.toByteData())!.buffer.asUint8List();
      for (var i = 0; i < pixels.length; i += 4) {
        final luma = (299 * pixels[i] + 587 * pixels[i + 1] + 114 * pixels[i + 2]) ~/ 1000;
        if (luma + 255 - pixels[i + 3] < 128) output.fillRange(i, i + 3, 0);
      }

      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(output, width, height, ui.PixelFormat.rgba8888, completer.complete);
      final image = await completer.future;
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        return bytes!.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      source.dispose();
      codec.dispose();
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != _onPaymentResponse) throw MissingPluginException();

    final data = Map<String, String?>.from(call.arguments as Map);
    _responses.add(StonePaymentResponse(data));
  }
}
