import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lê as chaves do plugin flutter_rede_sdk', () {
    final result = RedeTransactionResult.fromMap({
      'FLAG': 'VISA',
      'NSU_SITEF': '123',
      'AUTHORIZATION': 'A1',
      'INSTALLMENTS': 2,
      'AMOUNT': 10.5,
      'CARD_NUMBER': 'Crédito',
    });

    expect(
      result,
      const RedeTransactionResult(
        flag: 'VISA',
        nsu: '123',
        authorization: 'A1',
        installments: '2',
        amount: 10.5,
        cardNumber: 'Crédito',
      ),
    );
  });

  test('AMOUNT inteiro ou em texto vira double', () {
    expect(RedeTransactionResult.fromMap({'AMOUNT': 1}).amount, 1.0);
    expect(RedeTransactionResult.fromMap({'AMOUNT': '2.5'}).amount, 2.5);
  });

  test('campo ausente ou nulo vira texto vazio e valor 0', () {
    for (final map in [
      <dynamic, dynamic>{},
      <dynamic, dynamic>{'FLAG': null, 'AUTHORIZATION': null, 'AMOUNT': null},
    ]) {
      final result = RedeTransactionResult.fromMap(map);

      expect([result.flag, result.authorization, result.installments, result.amount], ['', '', '', 0]);
    }
  });
}
