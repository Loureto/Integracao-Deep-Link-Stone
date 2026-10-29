import 'dart:ui' as ui;

import 'package:dependencies/dependencies.dart';
import 'package:flutter/services.dart';

import '../../data/data.dart';
import '../../domain/domain.dart';

/// [INativePrinterService] pelo canal `acquirers_sdk`, com os métodos e códigos do `NativePrinter` do
/// flutter_acquirers_sdk.
class NativePrinterService implements INativePrinterService {
  static const _printReceipt = 'printReceipt';
  static const _printTxt = 'printTxt';
  static const _testPrint = 'testPrint';

  /// Erros depois dos quais o pedido é repetido uma vez. No `NativePrinter`, a precedência do `&&` deixava o
  /// `IMPRESSORA_INDISPONIVEL` repetir sem limite.
  static const _retryCodes = {'ERRO_DESCONHECIDO', 'IMPRESSORA_INDISPONIVEL'};

  /// 1 cm de papel na impressora de 8 pontos por milímetro. A NFC-e chega do conversor sem a sobra do PDF, e
  /// sem esta margem a última linha pode ficar antes da serrilha, como aconteceu na Stone.
  static const _bottomMargin = 80;

  final MethodChannel _channel;
  final IPdfImageConverter _pdfImage;

  const NativePrinterService(this._channel, this._pdfImage);

  @override
  Future<Either<NativePrinterFailure, Unit>> printTxt(String text) => _print(_printTxt, {'text': text});

  @override
  Future<Either<NativePrinterFailure, Unit>> testPrint() => _print(_testPrint, {});

  @override
  Future<Either<NativePrinterFailure, Unit>> printNfc(String nfcBase64) async {
    final image = await _pdfImage.firstPageToPng(nfcBase64);

    return image.match<Future<Either<NativePrinterFailure, Unit>>>(
      (failure) async => left(NativePrinterFailure(code: failure.code, message: failure.message)),
      (png) => printReceipt(bitmap: png),
    );
  }

  @override
  Future<Either<NativePrinterFailure, Unit>> printReceipt({required Uint8List bitmap}) async {
    final Uint8List image;
    try {
      image = await _withBottomMargin(bitmap);
    } on Exception {
      return left(NativePrinterFailure.invalidImage());
    }

    return _print(_printReceipt, {'bitmap': image});
  }

  Future<Either<NativePrinterFailure, Unit>> _print(
    String method,
    Map<String, Object> arguments, {
    bool isRetry = false,
  }) async {
    try {
      await _channel.invokeMethod<String>(method, arguments);
      return right(unit);
    } on PlatformException catch (e) {
      if (_retryCodes.contains(e.code) && !isRetry) return _print(method, arguments, isRetry: true);

      return left(NativePrinterFailure(code: e.code, message: e.message ?? e.stacktrace ?? e.toString()));
    } on MissingPluginException {
      return left(NativePrinterFailure.notSupported());
    }
  }

  static Future<Uint8List> _withBottomMargin(Uint8List png) async {
    final codec = await ui.instantiateImageCodec(png);
    final image = (await codec.getNextFrame()).image;
    try {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder)
        ..drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src)
        ..drawImage(image, ui.Offset.zero, ui.Paint());
      final picture = recorder.endRecording();
      final ui.Image withMargin;
      try {
        withMargin = await picture.toImage(image.width, image.height + _bottomMargin);
      } finally {
        picture.dispose();
      }
      try {
        final bytes = await withMargin.toByteData(format: ui.ImageByteFormat.png);
        return bytes!.buffer.asUint8List();
      } finally {
        withMargin.dispose();
      }
    } finally {
      image.dispose();
      codec.dispose();
    }
  }
}
