/// Tipos de parcelamento do PlugPagServiceWrapper.
enum PagBankInstallmentType {
  /// À vista, em 1 parcela.
  aVista('A_VISTA'),

  /// Parcelado sem juros para o comprador.
  parceladoVendedor('PARC_VENDEDOR'),

  /// Parcelado com juros para o comprador.
  parceladoComprador('PARC_COMPRADOR');

  const PagBankInstallmentType(this.value);

  final String value;
}
