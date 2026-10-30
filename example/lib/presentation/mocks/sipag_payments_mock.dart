import '../views/sipag/sipag.state.dart';

/// Pagamentos fake para teste nos terminais da Sipag. Valores em reais, como no `SiPagPayment` do
/// flutter_acquirers_sdk.
abstract final class SipagPaymentsMock {
  static const all = <({String label, SipagPaymentType type, double amount})>[
    (label: 'Crédito • R\$ 1,00', type: SipagPaymentType.credit, amount: 1.00),
    (label: 'Débito • R\$ 1,00', type: SipagPaymentType.debit, amount: 1.00),
    (label: 'Pix • R\$ 1,00', type: SipagPaymentType.pix, amount: 1.00),
  ];
}
