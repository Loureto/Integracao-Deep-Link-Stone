import 'dart:typed_data';

import 'package:dependencies/dependencies.dart';

import '../../domain/domain.dart';

/// Driver genérico de impressão (`posmpapi`), para as adquirentes sem impressão própria, como a Vero. Os nomes
/// são os do `NativePrinter` do flutter_acquirers_sdk, para a migração para este core não mudar o contrato.
abstract class INativePrinterService {
  /// Imprime o [text], que o nativo desenha em fonte monoespaçada.
  Future<Either<NativePrinterFailure, Unit>> printTxt(String text);

  /// Converte a primeira página da NFC-e em [nfcBase64] numa imagem e a imprime com [printReceipt].
  Future<Either<NativePrinterFailure, Unit>> printNfc(String nfcBase64);

  /// Imprime "Impressao teste".
  Future<Either<NativePrinterFailure, Unit>> testPrint();

  /// Imprime a imagem PNG [bitmap], com 1 cm de papel em branco no fim.
  Future<Either<NativePrinterFailure, Unit>> printReceipt({required Uint8List bitmap});
}
