import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CieloResponse response(CieloAction action, Object? data) {
    return CieloResponse.fromMap({
      'action': action.value,
      'responseCode': '0',
      'response': data == null ? null : jsonEncode(data),
    })!;
  }

  Map<String, dynamic> payment({
    required String cieloCode,
    required String statusCode,
    String original = '0',
  }) {
    return {
      'id': 'pagamento-$cieloCode',
      'amount': 3620,
      'authCode': '142941',
      'cieloCode': cieloCode,
      'mask': '************0000',
      'installments': 0,
      'paymentFields': {
        'statusCode': statusCode,
        'originalTransactionId': original,
        'productName': 'CREDITO A VISTA - I',
      },
    };
  }

  // Campos do exemplo de retorno de cancelamento da documentação Cielo.
  final paidOrder = {
    'id': 'f7a8f226-2949-400b-9778-913b0d169389',
    'reference': 'Reference',
    'status': 'ENTERED',
    'price': 3620,
    'paidAmount': 0,
    'pendingAmount': 3620,
    'payments': [payment(cieloCode: '910792', statusCode: '1')],
  };

  test('erro de pagamento tem code diferente de 0 e o motivo em reason', () {
    final error = response(CieloAction.payment, {'code': 1, 'reason': 'CANCELADO PELO USUÁRIO'});

    expect(error.isSuccess, isFalse);
    expect(error.code, 1);
    expect(error.message, 'CANCELADO PELO USUÁRIO');
    expect(error.order, isNull);
  });

  test('impressão usa code 0 para sucesso e message para o motivo', () {
    expect(response(CieloAction.print, {'code': 0, 'message': 'SUCCESS'}).isSuccess, isTrue);

    final withoutPaper = response(CieloAction.print, {'code': 1, 'message': 'WITHOUT PAPER'});
    expect(withoutPaper.isSuccess, isFalse);
    expect(withoutPaper.message, 'WITHOUT PAPER');
  });

  test('retornos sem code são sucesso, inclusive listas', () {
    expect(response(CieloAction.payment, paidOrder).isSuccess, isTrue);
    expect(
      response(CieloAction.establishments, [
        {'code': '0010000244470001', 'name': 'LOJA ON'},
      ]).isSuccess,
      isTrue,
    );
    expect(response(CieloAction.enabledProducts, ['CREDITO_AVISTA', 'DEBITO_AVISTA']).isSuccess, isTrue);
    expect(
      response(CieloAction.terminalInfo, {'deviceModel': 'DX8000', 'batteryLevel': 1.0}).isSuccess,
      isTrue,
    );
  });

  test('retorno sem dados ou com JSON inválido não é sucesso', () {
    final invalid = CieloResponse.fromMap({'action': 'payment', 'response': '{json inválido'})!;

    expect(response(CieloAction.payment, null).isSuccess, isFalse);
    expect(invalid.data, isNull);
    expect(invalid.isSuccess, isFalse);
  });

  test('ação desconhecida não gera retorno', () {
    expect(CieloResponse.fromMap({'action': 'refund', 'response': '{}'}), isNull);
  });

  test('lê o pedido pago com valores em centavos e o statusCode do pagamento', () {
    final order = response(CieloAction.payment, paidOrder).order!;

    expect(order.id, 'f7a8f226-2949-400b-9778-913b0d169389');
    expect(order.price, 3620);
    expect(order.payments.single.cieloCode, '910792');
    expect(order.payments.single.productName, 'CREDITO A VISTA - I');
    expect(order.payments.single.isAuthorized, isTrue);
    expect(order.cancelablePayment?.cieloCode, '910792');
  });

  test('pagamento já cancelado não volta a ser cancelável', () {
    final order = response(CieloAction.paymentReversal, {
      ...paidOrder,
      'payments': [
        payment(cieloCode: '910792', statusCode: '1'),
        payment(cieloCode: '910794', statusCode: '2', original: '910792'),
      ],
    }).order!;

    expect(order.payments.last.isCancellation, isTrue);
    expect(order.cancelablePayment, isNull);
  });

  test('consulta de pedido traz os pagamentos em transactions', () {
    final order = response(CieloAction.order, {
      'id': 'da257167-e82a-4c7c-b5e0-f0769d81843c',
      'status': 'PAID',
      'transactions': [payment(cieloCode: '108144', statusCode: '1')],
    }).order!;

    expect(order.payments.single.cieloCode, '108144');
  });

  test('cancela o valor total do pagamento devolvido pela Cielo', () {
    final order = response(CieloAction.payment, paidOrder).order!;

    final cancel = CieloCancelModel.fromPayment(order, order.cancelablePayment!);

    expect(CieloCancelModel.toMap(cancel), {
      'id': 'f7a8f226-2949-400b-9778-913b0d169389',
      'cieloCode': '910792',
      'authCode': '142941',
      'value': 3620,
    });
  });
}
