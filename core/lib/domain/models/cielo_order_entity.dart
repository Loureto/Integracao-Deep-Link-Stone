/// Pedido (order) devolvido pela Cielo no pagamento, no cancelamento e na consulta de pedido.
class CieloOrder {
  final String id;
  final String? reference;

  /// Status do pedido, como `ENTERED` ou `PAID`.
  final String? status;

  /// Valores em centavos.
  final int price;
  final int paidAmount;
  final int pendingAmount;

  /// Pagamentos e cancelamentos do pedido, na ordem em que aconteceram.
  final List<CieloOrderPayment> payments;

  const CieloOrder({
    required this.id,
    this.reference,
    this.status,
    this.price = 0,
    this.paidAmount = 0,
    this.pendingAmount = 0,
    this.payments = const [],
  });

  /// A consulta de pedido traz os pagamentos em `transactions`; o pagamento e o cancelamento, em `payments`.
  static CieloOrder fromMap(Map<String, dynamic> map) {
    final payments = map['payments'] ?? map['transactions'];

    return CieloOrder(
      id: map['id']?.toString() ?? '',
      reference: map['reference']?.toString(),
      status: map['status']?.toString(),
      price: _toInt(map['price']),
      paidAmount: _toInt(map['paidAmount']),
      pendingAmount: _toInt(map['pendingAmount']),
      payments: [
        if (payments is List)
          for (final payment in payments.whereType<Map<String, dynamic>>())
            CieloOrderPayment.fromMap(payment),
      ],
    );
  }

  /// Último pagamento autorizado que ainda não foi cancelado. Um cancelamento entra no pedido como outro
  /// pagamento, com `statusCode` 2 e o NSU do pagamento original em `originalTransactionId`.
  CieloOrderPayment? get cancelablePayment {
    final cancelled = {
      for (final payment in payments)
        if (payment.isCancellation) payment.originalTransactionId,
    };

    return payments
        .where((payment) => payment.isAuthorized && !cancelled.contains(payment.cieloCode))
        .lastOrNull;
  }
}

class CieloOrderPayment {
  final String id;

  /// Valor, em centavos.
  final int amount;

  final String? authCode;

  /// NSU da transação.
  final String? cieloCode;

  final String? brand;

  /// Cartão mascarado, como `424242-4242`.
  final String? mask;

  final int installments;

  /// `paymentFields.statusCode`: 0 para Pix, 1 para autorizada e 2 para cancelamento.
  final String? statusCode;

  /// Forma de pagamento descrita pela Cielo, como `CREDITO A VISTA - I`.
  final String? productName;

  /// Em um cancelamento, o NSU (`cieloCode`) do pagamento cancelado.
  final String? originalTransactionId;

  const CieloOrderPayment({
    required this.id,
    this.amount = 0,
    this.authCode,
    this.cieloCode,
    this.brand,
    this.mask,
    this.installments = 0,
    this.statusCode,
    this.productName,
    this.originalTransactionId,
  });

  static CieloOrderPayment fromMap(Map<String, dynamic> map) {
    final fields = map['paymentFields'];
    final paymentFields = fields is Map<String, dynamic> ? fields : const <String, dynamic>{};

    return CieloOrderPayment(
      id: map['id']?.toString() ?? '',
      amount: _toInt(map['amount']),
      authCode: map['authCode']?.toString(),
      cieloCode: map['cieloCode']?.toString(),
      brand: map['brand']?.toString(),
      mask: map['mask']?.toString(),
      installments: _toInt(map['installments']),
      statusCode: paymentFields['statusCode']?.toString(),
      productName: paymentFields['productName']?.toString(),
      originalTransactionId: paymentFields['originalTransactionId']?.toString(),
    );
  }

  bool get isAuthorized => statusCode == '0' || statusCode == '1';

  bool get isCancellation => statusCode == '2';
}

int _toInt(Object? value) => value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? 0;
