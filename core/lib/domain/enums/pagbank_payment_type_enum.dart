/// Tipos de pagamento do PlugPagServiceWrapper usados pelo app. O Android troca o nome pela constante do SDK.
enum PagBankPaymentType {
  credit('CREDIT'),
  debit('DEBIT'),
  voucher('VOUCHER'),
  pix('PIX');

  const PagBankPaymentType(this.value);

  final String value;

  static PagBankPaymentType? fromValue(String? value) {
    for (final type in values) {
      if (type.value == value) return type;
    }
    return null;
  }
}
