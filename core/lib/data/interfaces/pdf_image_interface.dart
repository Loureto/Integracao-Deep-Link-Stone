import 'dart:typed_data';

import 'package:dependencies/dependencies.dart';

import '../../domain/domain.dart';

/// Converte o PDF de um documento, como a NFC-e, na imagem que a impressão livre das adquirentes recebe.
abstract class IPdfImageConverter {
  /// PNG da primeira página do PDF em [pdfBase64], na largura da bobina dos terminais e com fundo branco. As
  /// sobras em branco em volta do conteúdo são cortadas, e o conteúdo fica centralizado.
  Future<Either<PdfImageFailure, Uint8List>> firstPageToPng(String pdfBase64);
}
