/// Valores aceitos em `paymentCode` pelo deep link de pagamento Cielo. Sem `paymentCode`, a forma de
/// pagamento é escolhida no app da Cielo.
enum CieloPaymentCode {
  cartaoLojaAvista('CARTAO_LOJA_AVISTA'),
  cartaoLojaPagtoFaturaCheque('CARTAO_LOJA_PAGTO_FATURA_CHEQUE'),
  cartaoLojaPagtoFaturaDinheiro('CARTAO_LOJA_PAGTO_FATURA_DINHEIRO'),
  cartaoLojaParcelado('CARTAO_LOJA_PARCELADO'),
  cartaoLojaParceladoBanco('CARTAO_LOJA_PARCELADO_BANCO'),
  cartaoLojaParceladoLoja('CARTAO_LOJA_PARCELADO_LOJA'),
  crediarioSimulacao('CREDIARIO_SIMULACAO'),
  crediarioVenda('CREDIARIO_VENDA'),
  creditoAvista('CREDITO_AVISTA'),
  creditoCrediarioCredito('CREDITO_CREDIARIO_CREDITO'),
  creditoParceladoAdm('CREDITO_PARCELADO_ADM'),
  creditoParceladoBnco('CREDITO_PARCELADO_BNCO'),
  creditoParceladoLoja('CREDITO_PARCELADO_LOJA'),
  debitoAvista('DEBITO_AVISTA'),
  debitoPagtoFaturaDebito('DEBITO_PAGTO_FATURA_DEBITO'),
  frotas('FROTAS'),
  pix('PIX'),
  preAutorizacao('PRE_AUTORIZACAO'),
  voucherAlimentacao('VOUCHER_ALIMENTACAO'),
  voucherAuto('VOUCHER_AUTO'),
  voucherAutomotivo('VOUCHER_AUTOMOTIVO'),
  voucherBeneficios('VOUCHER_BENEFICIOS'),
  voucherConsultaSaldo('VOUCHER_CONSULTA_SALDO'),
  voucherCultura('VOUCHER_CULTURA'),
  voucherPedagio('VOUCHER_PEDAGIO'),
  voucherRefeicao('VOUCHER_REFEICAO'),
  voucherValePedagio('VOUCHER_VALE_PEDAGIO');

  const CieloPaymentCode(this.value);

  final String value;

  static CieloPaymentCode? fromValue(String? value) {
    for (final code in values) {
      if (code.value == value?.toUpperCase()) return code;
    }
    return null;
  }
}
