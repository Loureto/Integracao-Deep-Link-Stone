import 'package:core/core.dart';

/// Pagamentos fake para teste na Cielo Smart ou no Emulador Cielo. O valor de cada pagamento é a soma
/// dos itens, em centavos.
abstract final class CieloPaymentsMock {
  static const all = <({String label, CieloPaymentModel request})>[
    (
      label: 'Débito à vista • R\$ 1,00',
      request: CieloPaymentModel(
        items: [CieloItemModel(sku: '1001', name: 'Produto de teste', unitPrice: 100)],
        paymentCode: CieloPaymentCode.debitoAvista,
      ),
    ),
    (
      label: 'Crédito à vista • R\$ 10,00',
      request: CieloPaymentModel(
        items: [CieloItemModel(sku: '1002', name: 'Produto de teste', unitPrice: 1000)],
        paymentCode: CieloPaymentCode.creditoAvista,
      ),
    ),
    (
      label: 'Crédito 3x pela loja • R\$ 30,00',
      request: CieloPaymentModel(
        items: [CieloItemModel(sku: '1003', name: 'Produto de teste', unitPrice: 1000, quantity: 3)],
        paymentCode: CieloPaymentCode.creditoParceladoLoja,
        installments: 3,
      ),
    ),
    (
      label: 'PIX • R\$ 1,00',
      request: CieloPaymentModel(
        items: [CieloItemModel(sku: '1004', name: 'Produto de teste', unitPrice: 100)],
        paymentCode: CieloPaymentCode.pix,
      ),
    ),
    (
      label: 'Voucher refeição • R\$ 5,00',
      request: CieloPaymentModel(
        items: [CieloItemModel(sku: '1005', name: 'Produto de teste', unitPrice: 500)],
        paymentCode: CieloPaymentCode.voucherRefeicao,
      ),
    ),
    (
      label: 'Forma de pagamento escolhida no app Cielo • R\$ 5,00',
      request: CieloPaymentModel(
        items: [CieloItemModel(sku: '1006', name: 'Produto de teste', unitPrice: 500)],
      ),
    ),
  ];
}
