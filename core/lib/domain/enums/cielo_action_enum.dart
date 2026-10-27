/// Ações do deep link `lio://` da Cielo Smart. O valor também é o host do `urlCallback` declarado no
/// AndroidManifest, então o retorno informa a ação que o originou.
enum CieloAction {
  payment('payment'),
  paymentReversal('payment-reversal'),
  print('print', requiresCredentials: false),
  order('order'),
  orders('orders'),
  enabledProducts('enabledproducts'),
  establishments('establishments'),
  terminalInfo('terminalinfo', requiresCredentials: false);

  const CieloAction(this.value, {this.requiresCredentials = true});

  final String value;

  /// Pela documentação, a impressão e as informações do terminal não levam `clientID` e `accessToken`.
  final bool requiresCredentials;

  static CieloAction? fromValue(String? value) {
    for (final action in values) {
      if (action.value == value) return action;
    }
    return null;
  }
}
