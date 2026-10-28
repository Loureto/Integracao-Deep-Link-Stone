import '../enums/enums.dart';

/// Transação devolvida pelo PlugPagService: pagamento, estorno ou a consulta da última aprovada.
class PagBankTransaction {
  final Map<String, Object?> data;

  const PagBankTransaction(this.data);

  /// Nulo quando o Android não respondeu com um mapa.
  static PagBankTransaction? fromMap(Object? map) {
    if (map is! Map) return null;

    return PagBankTransaction({for (final MapEntry(:key, :value) in map.entries) '$key': value});
  }

  String? _string(String key) => switch (data[key]) {
    String value => value,
    _ => null,
  };

  int? _int(String key) => switch (data[key]) {
    int value => value,
    _ => null,
  };

  /// 0 (`PlugPag.RET_OK`) indica sucesso.
  int? get result => _int('result');

  /// Código do PlugPagService, como `0000` (aprovada), `C13` (cancelada no terminal) ou `SV03` (serviço
  /// ocupado).
  String? get errorCode => _string('errorCode');

  String? get message => _string('message');

  String? get transactionCode => _string('transactionCode');

  String? get transactionId => _string('transactionId');

  /// Valor em centavos. O SDK o envia como texto.
  int? get amount => int.tryParse(_string('amount') ?? '');

  int? get installments => _int('installments');

  /// Nulo para tipos que o app não usa, como a pré-autorização.
  PagBankPaymentType? get paymentType => PagBankPaymentType.fromValue(_string('paymentType'));

  /// Tipo de estorno desta transação, calculado no Android.
  PagBankVoidType get voidType => PagBankVoidType.fromValue(_string('voidType')) ?? PagBankVoidType.payment;

  String? get cardBrand => _string('cardBrand');

  String? get nsu => _string('nsu');

  String? get autoCode => _string('autoCode');

  String? get date => _string('date');

  String? get time => _string('time');

  bool get isApproved => result == 0;

  /// A consulta da última transação aprovada responde mesmo sem nenhuma, com o código e o id vazios.
  bool get hasTransaction => (transactionCode?.isNotEmpty ?? false) && (transactionId?.isNotEmpty ?? false);
}
