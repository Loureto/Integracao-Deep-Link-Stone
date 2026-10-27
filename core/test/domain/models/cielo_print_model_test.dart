import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('texto sem estilo envia um estilo vazio, como no exemplo da documentação', () {
    final map = CieloPrintModel.toMap(
      const CieloPrintModel(
        operation: CieloPrintOperation.text,
        values: ['PRIMEIRA LINHA\nSEGUNDA LINHA\n\n'],
      ),
    );

    expect(map, {
      'operation': 'PRINT_TEXT',
      'styles': [<String, int>{}],
      'value': ['PRIMEIRA LINHA\nSEGUNDA LINHA\n\n'],
    });
  });

  test('múltiplas colunas envia um estilo por coluna com as chaves key_attributes', () {
    final map = CieloPrintModel.toMap(
      const CieloPrintModel(
        operation: CieloPrintOperation.multiColumnText,
        values: ['Esquerda', 'Centro'],
        styles: [
          CieloPrintStyleModel(align: CieloPrintAlign.left, textSize: 30, typeface: 0),
          CieloPrintStyleModel(align: CieloPrintAlign.center, marginTop: 5, lineSpace: 2, weight: 1),
        ],
      ),
    );

    expect(map['operation'], 'PRINT_MULTI_COLUMN_TEXT');
    expect(map['styles'], [
      {'key_attributes_align': 1, 'key_attributes_textsize': 30, 'key_attributes_typeface': 0},
      {
        'key_attributes_align': 0,
        'key_attributes_margintop': 5,
        'key_attributes_linespace': 2,
        'key_attributes_weight': 1,
      },
    ]);
  });

  test('precisa de texto e, com estilos, um estilo por texto', () {
    const style = CieloPrintStyleModel();

    expect(const CieloPrintModel(operation: CieloPrintOperation.text, values: ['A']).isValid, isTrue);
    expect(const CieloPrintModel(operation: CieloPrintOperation.text, values: []).isValid, isFalse);
    expect(
      const CieloPrintModel(
        operation: CieloPrintOperation.multiColumnText,
        values: ['A', 'B'],
        styles: [style],
      ).isValid,
      isFalse,
    );
  });
}
