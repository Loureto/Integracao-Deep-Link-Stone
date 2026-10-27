/// Operações de impressão de texto aceitas pelo `lio://print`. A impressão de imagem (`PRINT_IMAGE`) não
/// está aqui porque exige salvar o arquivo no armazenamento externo, com `MANAGE_EXTERNAL_STORAGE`.
enum CieloPrintOperation {
  /// Um único texto com as linhas separadas por `\n`: a Cielo recomenda não imprimir linha a linha.
  text('PRINT_TEXT'),

  /// Um texto por coluna, cada um com o seu estilo.
  multiColumnText('PRINT_MULTI_COLUMN_TEXT');

  const CieloPrintOperation(this.value);

  final String value;
}
