import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PagBankPaymentModel payment({
    int amount = 1000,
    PagBankInstallmentType installmentType = PagBankInstallmentType.aVista,
    int installments = 1,
    String? userReference,
  }) {
    return PagBankPaymentModel(
      type: PagBankPaymentType.credit,
      amount: amount,
      installmentType: installmentType,
      installments: installments,
      userReference: userReference,
    );
  }

  test('amount aceita de 1 centavo ao máximo do Int do SDK', () {
    for (final amount in [1, PagBankPaymentModel.maxAmount]) {
      expect(payment(amount: amount).isAmountValid, isTrue, reason: '$amount');
    }
    for (final amount in [0, -1, PagBankPaymentModel.maxAmount + 1]) {
      expect(payment(amount: amount).isAmountValid, isFalse, reason: '$amount');
    }
  });

  test('à vista usa 1 parcela, e o parcelado, 2 ou mais', () {
    expect(payment().isInstallmentsValid, isTrue);
    expect(payment(installments: 2).isInstallmentsValid, isFalse);

    for (final type in [
      PagBankInstallmentType.parceladoVendedor,
      PagBankInstallmentType.parceladoComprador,
    ]) {
      expect(payment(installmentType: type, installments: 2).isInstallmentsValid, isTrue, reason: '$type');
      expect(payment(installmentType: type, installments: 1).isInstallmentsValid, isFalse, reason: '$type');
    }
  });

  test('userReference aceita até 10 letras sem acento e números, ou nada', () {
    for (final reference in [null, '', 'VENDA01', 'ABCDE12345']) {
      expect(payment(userReference: reference).isUserReferenceValid, isTrue, reason: '$reference');
    }
    for (final reference in ['VENDA-01', 'AÇÃO', 'ABCDE123456', 'VENDA 1']) {
      expect(payment(userReference: reference).isUserReferenceValid, isFalse, reason: reference);
    }
  });

  test('toMap envia os nomes que o Android converte nas constantes do SDK', () {
    const data = PagBankPaymentModel(
      type: PagBankPaymentType.pix,
      amount: 100,
      userReference: 'VENDA01',
      printReceipt: true,
    );

    expect(PagBankPaymentModel.toMap(data), {
      'type': 'PIX',
      'amount': 100,
      'installmentType': 'A_VISTA',
      'installments': 1,
      'userReference': 'VENDA01',
      'printReceipt': true,
    });
  });
}
