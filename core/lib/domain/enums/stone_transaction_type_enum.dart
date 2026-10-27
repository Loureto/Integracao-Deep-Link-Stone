/// Valores aceitos em `transaction_type` pelo deeplink de pagamento Stone.
enum StoneTransactionType {
  debit('DEBIT'),
  credit('CREDIT'),
  voucher('VOUCHER'),
  instantPayment('INSTANT_PAYMENT'),
  pix('PIX');

  const StoneTransactionType(this.value);

  final String value;

  static StoneTransactionType? fromValue(String? value) {
    for (final type in values) {
      if (type.value == value?.toUpperCase()) return type;
    }
    return null;
  }
}
