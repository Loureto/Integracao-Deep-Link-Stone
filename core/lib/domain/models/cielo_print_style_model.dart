import '../enums/enums.dart';

/// Estilo de um texto impresso. Campos nulos ficam com o padrão do terminal.
class CieloPrintStyleModel {
  final CieloPrintAlign? align;
  final int? textSize;

  /// Fonte, de 0 a 8.
  final int? typeface;

  final int? marginLeft;
  final int? marginRight;
  final int? marginTop;
  final int? marginBottom;
  final int? lineSpace;

  /// Peso da coluna na impressão em múltiplas colunas.
  final int? weight;

  const CieloPrintStyleModel({
    this.align,
    this.textSize,
    this.typeface,
    this.marginLeft,
    this.marginRight,
    this.marginTop,
    this.marginBottom,
    this.lineSpace,
    this.weight,
  });

  static Map<String, int> toMap(CieloPrintStyleModel data) {
    return {
      if (data.align != null) 'key_attributes_align': data.align!.value,
      if (data.textSize != null) 'key_attributes_textsize': data.textSize!,
      if (data.typeface != null) 'key_attributes_typeface': data.typeface!,
      if (data.marginLeft != null) 'key_attributes_marginleft': data.marginLeft!,
      if (data.marginRight != null) 'key_attributes_marginright': data.marginRight!,
      if (data.marginTop != null) 'key_attributes_margintop': data.marginTop!,
      if (data.marginBottom != null) 'key_attributes_marginbottom': data.marginBottom!,
      if (data.lineSpace != null) 'key_attributes_linespace': data.lineSpace!,
      if (data.weight != null) 'key_attributes_weight': data.weight!,
    };
  }
}
