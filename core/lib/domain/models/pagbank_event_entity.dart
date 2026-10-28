/// Mensagem do PlugPagService durante pagamento ou estorno, como "APROXIME, INSIRA OU PASSE O CARTÃO".
class PagBankEvent {
  /// Código do `PlugPagEventData`.
  final int code;
  final String? message;

  const PagBankEvent({required this.code, this.message});

  /// `EVENT_CODE_DIGIT_PASSWORD`: um dígito da senha foi digitado. Chega sem texto.
  static const digitPasswordCode = 16;

  /// `EVENT_CODE_NO_PASSWORD`: a senha está vazia, ainda não digitada ou apagada. Chega sem texto.
  static const noPasswordCode = 17;

  bool get isPasswordDigit => code == digitPasswordCode;

  bool get isNoPassword => code == noPasswordCode;

  /// Nulo quando o Android não enviou um código.
  static PagBankEvent? fromMap(Object? map) {
    if (map is! Map) return null;

    return switch (map['code']) {
      int code => PagBankEvent(
        code: code,
        message: map['message'] is String ? map['message'] as String : null,
      ),
      _ => null,
    };
  }
}
