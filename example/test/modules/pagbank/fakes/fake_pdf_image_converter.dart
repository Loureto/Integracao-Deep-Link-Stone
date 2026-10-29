import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';

/// PNG que o conversor fake devolve, diferente da imagem de teste do mock.
final convertedPng = Uint8List.fromList([137, 80, 78, 71, 13, 10]);

class FakePdfImageConverter implements IPdfImageConverter {
  /// PDFs recebidos, na ordem.
  final pdfs = <String>[];
  Either<PdfImageFailure, Uint8List> result = right(convertedPng);

  @override
  Future<Either<PdfImageFailure, Uint8List>> firstPageToPng(String pdfBase64) async {
    pdfs.add(pdfBase64);
    return result;
  }
}
