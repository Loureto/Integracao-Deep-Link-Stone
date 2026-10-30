import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lê as chaves do plugin flutter_sipag_sdk', () {
    final result = SiPagTransactionResult.fromMap({
      'MESSAGE': 'Operação efetuada com sucesso!',
      'FLAG': 'VISA',
      'NSU_SITEF': '123',
      'CARD_NUMBER': '************1234',
      'AUTHORIZATION': 'A1',
      'COMPANY_RECEIPT': 'VIA LOJA',
      'CLIENT_RECEIPT': 'VIA CLIENTE',
      'INSTALLMENTS': 1,
      'AMOUNT': 10.5,
    });

    expect(
      result,
      const SiPagTransactionResult(
        flag: 'VISA',
        nsu: '123',
        authorization: 'A1',
        cardNumber: '************1234',
        merchantReceipt: 'VIA LOJA',
        customerReceipt: 'VIA CLIENTE',
        installments: '1',
        amount: 10.5,
      ),
    );
  });

  test('AMOUNT inteiro ou em texto vira double', () {
    expect(SiPagTransactionResult.fromMap({'AMOUNT': 10}).amount, 10.0);
    expect(SiPagTransactionResult.fromMap({'AMOUNT': '2.5'}).amount, 2.5);
  });

  test('campo ausente ou nulo vira texto vazio ou 0', () {
    final result = SiPagTransactionResult.fromMap({'FLAG': null, 'AMOUNT': null});

    expect(
      [
        result.flag,
        result.nsu,
        result.authorization,
        result.cardNumber,
        result.merchantReceipt,
        result.customerReceipt,
        result.installments,
      ],
      everyElement(''),
    );
    expect(result.amount, 0.0);
  });
}
