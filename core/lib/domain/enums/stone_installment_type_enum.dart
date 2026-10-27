/// Valores aceitos em `installment_type` pelo deeplink de pagamento Stone.
enum StoneInstallmentType {
  /// Parcelado sem juros.
  merchant('MERCHANT'),

  /// Parcelado com juros.
  issuer('ISSUER'),

  /// À vista.
  none('NONE');

  const StoneInstallmentType(this.value);

  final String value;

  static StoneInstallmentType? fromValue(String? value) {
    for (final type in values) {
      if (type.value == value?.toUpperCase()) return type;
    }
    return null;
  }
}
