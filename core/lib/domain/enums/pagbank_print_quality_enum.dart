/// Qualidade da impressão livre do PlugPagServiceWrapper, de 1 (menor) a 4 (maior). A documentação atual do
/// SDK não lista os valores: a escala vem da documentação anterior do PlugPag.
enum PagBankPrintQuality {
  low(1),
  medium(2),
  high(3),
  max(4);

  const PagBankPrintQuality(this.value);

  final int value;
}
