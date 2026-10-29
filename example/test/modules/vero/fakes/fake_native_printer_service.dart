import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';

class FakeNativePrinterService implements INativePrinterService {
  /// Impressões recebidas, com o texto, a NFC-e ou o bitmap, na ordem.
  final calls = <(String, Object?)>[];
  Either<NativePrinterFailure, Unit> result = right(unit);

  Future<Either<NativePrinterFailure, Unit>> _record(String method, Object? argument) async {
    calls.add((method, argument));
    return result;
  }

  @override
  Future<Either<NativePrinterFailure, Unit>> printTxt(String text) => _record('printTxt', text);

  @override
  Future<Either<NativePrinterFailure, Unit>> printNfc(String nfcBase64) => _record('printNfc', nfcBase64);

  @override
  Future<Either<NativePrinterFailure, Unit>> testPrint() => _record('testPrint', null);

  @override
  Future<Either<NativePrinterFailure, Unit>> printReceipt({required Uint8List bitmap}) =>
      _record('printReceipt', bitmap);
}
