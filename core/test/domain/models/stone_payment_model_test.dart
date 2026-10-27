import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('amount aceita de 0 a 999999999 centavos, ou nulo', () {
    for (final amount in [null, 0, 999999999]) {
      expect(StonePaymentModel(amount: amount).isAmountValid, isTrue, reason: '$amount');
    }
    for (final amount in [-1, 1000000000]) {
      expect(StonePaymentModel(amount: amount).isAmountValid, isFalse, reason: '$amount');
    }
  });

  test('installmentCount aceita de 2 a 99 parcelas, ou nulo', () {
    for (final count in [null, 2, 99]) {
      expect(StonePaymentModel(installmentCount: count).isInstallmentCountValid, isTrue, reason: '$count');
    }
    for (final count in [0, 1, 100]) {
      expect(StonePaymentModel(installmentCount: count).isInstallmentCountValid, isFalse, reason: '$count');
    }
  });
}
