import 'dart:typed_data';

import '../enums/enums.dart';

/// Impressão livre na impressora do terminal, como a da NFC-e. O `printFromFile` do SDK recebe o caminho de
/// um arquivo, então o Android grava a imagem num arquivo antes de imprimir.
class PagBankPrintModel {
  /// Imagem a imprimir, em PNG.
  final Uint8List image;

  final PagBankPrintQuality quality;

  /// Linhas de papel avançadas depois da impressão, de no mínimo [minSteps].
  final int steps;

  const PagBankPrintModel({
    required this.image,
    this.quality = PagBankPrintQuality.max,
    this.steps = minSteps,
  });

  /// `PlugPag.MIN_PRINTER_STEPS`.
  static const minSteps = 70;

  bool get isValid => image.isNotEmpty && steps >= minSteps;

  static Map<String, dynamic> toMap(PagBankPrintModel data) {
    return {
      'image': data.image,
      'quality': data.quality.value,
      'steps': data.steps,
    };
  }
}
