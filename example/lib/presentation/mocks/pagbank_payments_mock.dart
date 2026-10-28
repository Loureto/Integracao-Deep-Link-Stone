import 'package:core/core.dart';

/// Pagamentos fake para teste no terminal de debug do PagBank, com a via do estabelecimento impressa,
/// como no demo oficial. Valores em centavos.
abstract final class PagBankPaymentsMock {
  static const all = <({String label, PagBankPaymentModel request})>[
    (
      label: 'Débito • R\$ 1,00',
      request: PagBankPaymentModel(type: PagBankPaymentType.debit, amount: 100, printReceipt: true),
    ),
    (
      label: 'Crédito à vista • R\$ 10,00',
      request: PagBankPaymentModel(type: PagBankPaymentType.credit, amount: 1000, printReceipt: true),
    ),
    (
      label: 'Crédito 3x sem juros • R\$ 30,00',
      request: PagBankPaymentModel(
        type: PagBankPaymentType.credit,
        amount: 3000,
        installmentType: PagBankInstallmentType.parceladoVendedor,
        installments: 3,
        printReceipt: true,
      ),
    ),
    (
      label: 'Crédito 2x com juros • R\$ 20,00',
      request: PagBankPaymentModel(
        type: PagBankPaymentType.credit,
        amount: 2000,
        installmentType: PagBankInstallmentType.parceladoComprador,
        installments: 2,
        printReceipt: true,
      ),
    ),
    (
      label: 'Voucher • R\$ 5,00',
      request: PagBankPaymentModel(type: PagBankPaymentType.voucher, amount: 500, printReceipt: true),
    ),
    (
      label: 'PIX • R\$ 1,00',
      request: PagBankPaymentModel(type: PagBankPaymentType.pix, amount: 100, printReceipt: true),
    ),
    (
      label: 'Débito com código da venda • R\$ 2,00',
      request: PagBankPaymentModel(
        type: PagBankPaymentType.debit,
        amount: 200,
        userReference: 'VENDA01',
        printReceipt: true,
      ),
    ),
  ];
}
