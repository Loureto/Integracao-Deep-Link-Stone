import '../enums/enums.dart';
import 'cielo_print_style_model.dart';

class CieloPrintModel {
  final CieloPrintOperation operation;

  /// Em [CieloPrintOperation.text], um único texto com as linhas separadas por `\n`. Em
  /// [CieloPrintOperation.multiColumnText], um texto por coluna.
  final List<String> values;

  /// Um estilo para cada item de [values]. Vazio usa o estilo padrão em todos.
  final List<CieloPrintStyleModel> styles;

  const CieloPrintModel({
    required this.operation,
    required this.values,
    this.styles = const [],
  });

  bool get isValid => values.isNotEmpty && (styles.isEmpty || styles.length == values.length);

  /// Sem estilos, envia um estilo vazio por texto, como no exemplo de `PRINT_TEXT` da documentação.
  static Map<String, dynamic> toMap(CieloPrintModel data) {
    return {
      'operation': data.operation.value,
      'styles': data.styles.isEmpty
          ? [for (final _ in data.values) <String, int>{}]
          : data.styles.map(CieloPrintStyleModel.toMap).toList(),
      'value': data.values,
    };
  }
}
