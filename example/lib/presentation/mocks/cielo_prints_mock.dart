import 'package:core/core.dart';

/// Impressões de teste, montadas a partir dos exemplos da documentação Cielo. Os textos não têm acento
/// para não depender da fonte da impressora.
abstract final class CieloPrintsMock {
  static const all = <({String label, CieloPrintModel request})>[
    (
      label: 'Texto em várias linhas',
      request: CieloPrintModel(
        operation: CieloPrintOperation.text,
        values: ['TESTE DE IMPRESSAO\nPAYMENT INTEGRATIONS\nCIELO SMART\n\n'],
      ),
    ),
    (
      label: 'Três colunas com estilos',
      request: CieloPrintModel(
        operation: CieloPrintOperation.multiColumnText,
        values: ['Esquerda\n\n\n', 'Centro\n\n\n', 'Direita\n\n\n'],
        styles: [
          CieloPrintStyleModel(align: CieloPrintAlign.left, textSize: 30, typeface: 0),
          CieloPrintStyleModel(align: CieloPrintAlign.center, textSize: 20, typeface: 1),
          CieloPrintStyleModel(align: CieloPrintAlign.right, textSize: 15, typeface: 2),
        ],
      ),
    ),
  ];
}
