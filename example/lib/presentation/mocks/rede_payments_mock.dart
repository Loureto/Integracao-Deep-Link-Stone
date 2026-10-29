import '../views/rede/rede.state.dart';

/// Pagamentos fake para teste no L400 da Rede. Valores em reais, como no `RedeIntegration` do
/// flutter_acquirers_sdk.
abstract final class RedePaymentsMock {
  static const all = <({String label, RedePaymentType type, double amount})>[
    (label: 'Crédito • R\$ 1,00', type: RedePaymentType.credit, amount: 1.00),
    (label: 'Débito • R\$ 1,00', type: RedePaymentType.debit, amount: 1.00),
    (label: 'Pix • R\$ 1,00', type: RedePaymentType.pix, amount: 1.00),
  ];
}
