/// Consulta de um pedido pelo `id` ou, informando também [amount], [authCode] e [cieloCode], pelo valor,
/// pelo NSU e pelo código de autorização do pagamento.
class CieloOrderQueryModel {
  final String orderId;

  /// Valor do pagamento, em centavos.
  final int? amount;

  final String? authCode;

  /// NSU do pagamento.
  final String? cieloCode;

  const CieloOrderQueryModel({
    required this.orderId,
    this.amount,
    this.authCode,
    this.cieloCode,
  });

  /// A busca pelo pagamento precisa dos três campos.
  bool get isValid {
    final paymentFields = [amount, authCode, cieloCode];
    return orderId.isNotEmpty &&
        (paymentFields.every((field) => field == null) || !paymentFields.contains(null));
  }

  static Map<String, dynamic> toMap(CieloOrderQueryModel data) {
    return {
      'orderId': data.orderId,
      if (data.amount != null) 'amount': data.amount,
      if (data.authCode != null) 'authCode': data.authCode,
      if (data.cieloCode != null) 'cieloCode': data.cieloCode,
    };
  }
}
