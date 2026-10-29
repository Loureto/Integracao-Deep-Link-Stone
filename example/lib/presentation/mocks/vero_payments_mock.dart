import '../views/vero/vero.state.dart';

/// Pagamentos fake para teste no terminal da Vero. Valores em reais, como no `VeroPayment` do
/// flutter_acquirers_sdk.
abstract final class VeroPaymentsMock {
  static const all = <({String label, VeroPaymentType type, double amount})>[
    (label: 'Crédito • R\$ 1,00', type: VeroPaymentType.credit, amount: 1.00),
    (label: 'Débito • R\$ 1,00', type: VeroPaymentType.debit, amount: 1.00),
    (label: 'Pix • R\$ 1,00', type: VeroPaymentType.pix, amount: 1.00),
    (label: 'Carteira Vero • R\$ 1,00', type: VeroPaymentType.wallet, amount: 1.00),
  ];
}
