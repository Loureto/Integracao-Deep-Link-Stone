import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final image = Uint8List.fromList([137, 80, 78, 71]);

  test('só imprime imagem com conteúdo e avanço de no mínimo 70 linhas', () {
    expect(PagBankPrintModel(image: image).isValid, isTrue);
    expect(PagBankPrintModel(image: image, steps: 70).isValid, isTrue);

    expect(PagBankPrintModel(image: image, steps: 69).isValid, isFalse);
    expect(PagBankPrintModel(image: Uint8List(0)).isValid, isFalse);
  });

  test('toMap envia a imagem, a qualidade de 1 a 4 do SDK e o avanço de papel', () {
    final data = PagBankPrintModel(image: image, quality: PagBankPrintQuality.medium, steps: 100);

    expect(PagBankPrintModel.toMap(data), {'image': image, 'quality': 2, 'steps': 100});
  });

  test('sem qualidade e avanço, imprime na qualidade 4 e avança as 70 linhas mínimas', () {
    expect(PagBankPrintModel.toMap(PagBankPrintModel(image: image)), {
      'image': image,
      'quality': 4,
      'steps': 70,
    });
  });
}
