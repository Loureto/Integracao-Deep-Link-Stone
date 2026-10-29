import 'package:dependencies/dependencies.dart';

/// Transação aprovada pelo app da Rede. Classe e campos têm os nomes do `RedeTransactionResult` do plugin
/// `flutter_rede_sdk`, para o `AcquirerTransactionResult.fromRedeTransaction` do flutter_acquirers_sdk lê-la sem
/// mudança.
class RedeTransactionResult extends Equatable {
  final String flag, nsu, authorization, installments, cardNumber;

  /// Valor do recibo da Rede, em reais.
  final double amount;

  const RedeTransactionResult({
    required this.flag,
    required this.nsu,
    required this.authorization,
    required this.installments,
    required this.amount,
    required this.cardNumber,
  });

  /// Lê a resposta do Android, com as chaves do plugin. No `CARD_NUMBER` vem o tipo da operação, como lá.
  ///
  /// No plugin, um campo nulo quebrava o Dart com erro de tipo; aqui ele vira texto vazio, ou 0 no valor.
  factory RedeTransactionResult.fromMap(Map<dynamic, dynamic> map) {
    String read(String key) => map[key]?.toString() ?? '';

    return RedeTransactionResult(
      flag: read('FLAG'),
      nsu: read('NSU_SITEF'),
      authorization: read('AUTHORIZATION'),
      installments: read('INSTALLMENTS'),
      amount: double.tryParse(read('AMOUNT')) ?? 0,
      cardNumber: read('CARD_NUMBER'),
    );
  }

  @override
  List<Object?> get props => [flag, nsu, authorization, installments, amount, cardNumber];
}
