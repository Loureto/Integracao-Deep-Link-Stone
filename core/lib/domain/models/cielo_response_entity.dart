import 'dart:convert';

import '../enums/enums.dart';
import 'cielo_order_entity.dart';

/// Retorno do app da Cielo para uma ação do `lio://`.
class CieloResponse {
  final CieloAction action;

  /// `responsecode` da URI de retorno. A documentação usa 0 tanto em sucessos quanto em erros, então o
  /// resultado é decidido pelo conteúdo de [data].
  final String? responseCode;

  /// JSON do `response`: objeto, lista, ou nulo quando o retorno não trouxe dados válidos.
  final Object? data;

  const CieloResponse({required this.action, this.responseCode, this.data});

  static const _orderActions = {CieloAction.payment, CieloAction.paymentReversal, CieloAction.order};

  /// Nulo quando a ação do retorno não é conhecida.
  static CieloResponse? fromMap(Map<String, String?> map) {
    final action = CieloAction.fromValue(map['action']);
    if (action == null) return null;

    return CieloResponse(action: action, responseCode: map['responseCode'], data: _decode(map['response']));
  }

  static Object? _decode(String? json) {
    if (json == null) return null;

    try {
      return jsonDecode(json);
    } on FormatException {
      return null;
    }
  }

  Map<String, dynamic>? get _object => switch (data) {
    Map<String, dynamic> object => object,
    _ => null,
  };

  /// Código do erro: 1 cancelado pelo usuário, 2 erro genérico, 3 erro no pagamento e 4 erro de
  /// autenticação. A impressão também responde com `code`, e nela 0 indica sucesso.
  int? get code => switch (_object?['code']) {
    num code => code.toInt(),
    _ => null,
  };

  /// Motivo do erro (`reason`) ou, na impressão, a mensagem (`message`).
  String? get message => (_object?['reason'] ?? _object?['message'])?.toString();

  bool get isSuccess => data != null && (code ?? 0) == 0;

  /// Pedido devolvido pelo pagamento, pelo cancelamento ou pela consulta de pedido.
  CieloOrder? get order {
    final object = _object;
    if (!isSuccess || object == null || !_orderActions.contains(action)) return null;

    return CieloOrder.fromMap(object);
  }
}
