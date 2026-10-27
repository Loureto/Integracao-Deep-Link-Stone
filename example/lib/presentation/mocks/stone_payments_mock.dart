import 'package:core/core.dart';

/// Pagamentos fake para teste no POS, montados a partir dos cenários da
/// página "Testes com Projeto Demo" da documentação Stone. Valores em centavos.
abstract final class StonePaymentsMock {
  static const all = <({String label, StonePaymentModel request})>[
    (
      label: 'Débito • R\$ 1,00',
      request: StonePaymentModel(
        amount: 100,
        editableAmount: false,
        transactionType: StoneTransactionType.debit,
      ),
    ),
    (
      label: 'Crédito à vista • R\$ 10,00',
      request: StonePaymentModel(
        amount: 1000,
        editableAmount: false,
        transactionType: StoneTransactionType.credit,
        installmentType: StoneInstallmentType.none,
      ),
    ),
    (
      label: 'Crédito 3x sem juros • R\$ 30,00',
      request: StonePaymentModel(
        amount: 3000,
        editableAmount: false,
        transactionType: StoneTransactionType.credit,
        installmentType: StoneInstallmentType.merchant,
        installmentCount: 3,
      ),
    ),
    (
      label: 'Crédito 2x com juros • R\$ 20,00',
      request: StonePaymentModel(
        amount: 2000,
        editableAmount: false,
        transactionType: StoneTransactionType.credit,
        installmentType: StoneInstallmentType.issuer,
        installmentCount: 2,
      ),
    ),
    (
      label: 'PIX • R\$ 1,00',
      request: StonePaymentModel(
        amount: 100,
        editableAmount: false,
        transactionType: StoneTransactionType.pix,
      ),
    ),
    (
      label: 'Valor editável no app Stone • R\$ 5,00',
      request: StonePaymentModel(amount: 500, editableAmount: true),
    ),
    (
      label: 'Fluxo completo no app Stone',
      request: StonePaymentModel(),
    ),
  ];
}
