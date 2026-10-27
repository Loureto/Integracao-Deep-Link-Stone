import 'cielo_order_entity.dart';

class CieloCancelModel {
  /// `id` do pedido (order) do pagamento.
  final String orderId;

  /// NSU do pagamento.
  final String cieloCode;

  /// Código de autorização do pagamento.
  final String authCode;

  /// Valor a cancelar, em centavos.
  final int value;

  const CieloCancelModel({
    required this.orderId,
    required this.cieloCode,
    required this.authCode,
    required this.value,
  });

  /// Cancelamento do valor total de um pagamento devolvido pela Cielo.
  static CieloCancelModel fromPayment(CieloOrder order, CieloOrderPayment payment) {
    return CieloCancelModel(
      orderId: order.id,
      cieloCode: payment.cieloCode ?? '',
      authCode: payment.authCode ?? '',
      value: payment.amount,
    );
  }

  bool get isValid => orderId.isNotEmpty && cieloCode.isNotEmpty && authCode.isNotEmpty && value > 0;

  static Map<String, dynamic> toMap(CieloCancelModel data) {
    return {
      'id': data.orderId,
      'cieloCode': data.cieloCode,
      'authCode': data.authCode,
      'value': data.value,
    };
  }
}
