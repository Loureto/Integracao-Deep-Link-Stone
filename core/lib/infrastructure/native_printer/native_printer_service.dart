import 'package:dependencies/dependencies.dart';
import 'package:flutter/services.dart';

import '../../data/data.dart';
import '../../domain/domain.dart';
import '../receipt_image/bottom_margin.dart';

/// [INativePrinterService] pelo canal `acquirers_sdk`, com os métodos e códigos do `NativePrinter` do
/// flutter_acquirers_sdk.
class NativePrinterService implements INativePrinterService {
  static const _printReceipt = 'printReceipt';
  static const _printTxt = 'printTxt';
  static const _testPrint = 'testPrint';

  /// Erros depois dos quais o pedido é repetido uma vez. No `NativePrinter`, a precedência do `&&` deixava o
  /// `IMPRESSORA_INDISPONIVEL` repetir sem limite.
  static const _retryCodes = {'ERRO_DESCONHECIDO', 'IMPRESSORA_INDISPONIVEL'};

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
      image = await withBottomMargin(bitmap);
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
}
