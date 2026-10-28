/// Tipo de estorno: PIX e QR Code são estornados como [qrCode], e os cartões como [payment]. O Android
/// calcula o tipo de cada transação, pela regra do demo oficial do PagBank.
enum PagBankVoidType {
  payment('PAYMENT'),
  qrCode('QRCODE');

  const PagBankVoidType(this.value);

  final String value;

  static PagBankVoidType? fromValue(String? value) {
    for (final type in values) {
      if (type.value == value) return type;
    }
    return null;
  }
}
