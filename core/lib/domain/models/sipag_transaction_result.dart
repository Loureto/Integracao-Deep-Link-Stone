import 'package:dependencies/dependencies.dart';

/// Transação aprovada pela Sipag, no DX8000, na X990 ou no P2. Classe e campos têm os nomes do
/// `SiPagTransactionResult` do plugin `flutter_sipag_sdk`, para o `AcquirerTransactionResult.fromSiPagTransaction`
/// do flutter_acquirers_sdk lê-la sem mudança.
class SiPagTransactionResult extends Equatable {
  final String flag, nsu, authorization, cardNumber, merchantReceipt, customerReceipt, installments;

  /// Valor da transação, em reais.
  final double amount;

  const SiPagTransactionResult({
    required this.flag,
    required this.nsu,
    required this.authorization,
    required this.cardNumber,
    required this.merchantReceipt,
    required this.customerReceipt,
    required this.installments,
    required this.amount,
  });

  /// Lê a resposta do Android, com as chaves do plugin. O `MESSAGE` que o Android também manda não é lido, como
  /// lá.
  ///
  /// No plugin, um campo nulo, como o comprovante do cliente de uma via só, quebrava o Dart com erro de tipo;
  /// aqui ele vira texto vazio, ou 0 no valor.
  factory SiPagTransactionResult.fromMap(Map<dynamic, dynamic> map) {
    String read(String key) => map[key]?.toString() ?? '';

    return SiPagTransactionResult(
      flag: read('FLAG'),
      nsu: read('NSU_SITEF'),
      authorization: read('AUTHORIZATION'),
      cardNumber: read('CARD_NUMBER'),
      merchantReceipt: read('COMPANY_RECEIPT'),
      customerReceipt: read('CLIENT_RECEIPT'),
      installments: read('INSTALLMENTS'),
      amount: double.tryParse(read('AMOUNT')) ?? 0,
    );
  }

  @override
  List<Object?> get props => [
    flag,
    nsu,
    authorization,
    cardNumber,
    merchantReceipt,
    customerReceipt,
    installments,
    amount,
  ];
}
