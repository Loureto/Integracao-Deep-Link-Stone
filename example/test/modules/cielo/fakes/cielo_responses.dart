import 'dart:convert';

import 'package:core/core.dart';

/// Retorno como o Android entrega ao Dart: o JSON do `response` já decodificado do Base64.
CieloResponse cieloResponse(CieloAction action, Object? data) {
  return CieloResponse.fromMap({'action': action.value, 'response': jsonEncode(data)})!;
}

Map<String, dynamic> cieloPayment({
  required String cieloCode,
  required String statusCode,
  String original = '0',
}) {
  return {
    'id': 'pagamento-$cieloCode',
    'amount': 3620,
    'authCode': '142941',
    'cieloCode': cieloCode,
    'paymentFields': {
      'statusCode': statusCode,
      'originalTransactionId': original,
      'productName': 'CREDITO A VISTA - I',
    },
  };
}

/// Pedido pago, com os valores do exemplo de cancelamento da documentação Cielo.
final paidCieloOrder = {
  'id': 'pedido-1',
  'status': 'PAID',
  'price': 3620,
  'payments': [cieloPayment(cieloCode: '910792', statusCode: '1')],
};

/// O mesmo pedido depois do cancelamento, que entra como outro pagamento com `statusCode` 2.
final cancelledCieloOrder = {
  ...paidCieloOrder,
  'payments': [
    cieloPayment(cieloCode: '910792', statusCode: '1'),
    cieloPayment(cieloCode: '910794', statusCode: '2', original: '910792'),
  ],
};
