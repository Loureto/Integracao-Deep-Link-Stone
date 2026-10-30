import 'package:dependencies/dependencies.dart';
import 'package:flutter/services.dart';

import '../../data/data.dart';
import '../../domain/domain.dart';

/// [ISiPagPaymentService] pelo canal `sipag_sdk`, com os métodos do plugin `flutter_sipag_sdk` do
/// flutter_acquirers_sdk. O Android escolhe o SDK pelo modelo do terminal e responde quando o app da adquirente
/// devolve o resultado.
///
/// Nada é impresso depois do pagamento. O `SiPagPayment` do centralizer imprimia os comprovantes só quando o
/// modelo continha "x990", em minúsculas, e a X990 se identifica como "X990": na prática, nunca imprimia.
///
/// O `LAST_OPERATION_NOT_FOUND` da [getLastOperation] vem do Android, que guarda a marca de operação pendente; no
/// plugin, ela ficava no Dart.
class SiPagPaymentService implements ISiPagPaymentService {
  static const _getLastOperation = 'get_last_operation';
  static const _payCredit = 'pay_credit';
  static const _payDebit = 'pay_debit';
  static const _payPix = 'pay_pix';
  static const _refund = 'refund';
  static const _refundPix = 'refund_pix';

  /// Estorno de Pix no `FlutterAcquirersSdk.refund`. Acima dele, o centralizer não tem estorno.
  static const _pixRefundType = 1;

  final MethodChannel _channel;

  const SiPagPaymentService(this._channel);

  @override
  Future<Either<SiPagFailure, SiPagTransactionResult>> getLastOperation() => _call(_getLastOperation, {});

  @override
  Future<Either<SiPagFailure, SiPagTransactionResult>> creditCardPayment(double amount) =>
      _pay(_payCredit, amount);

  @override
  Future<Either<SiPagFailure, SiPagTransactionResult>> debitCardPayment(double amount) =>
      _pay(_payDebit, amount);

  @override
  Future<Either<SiPagFailure, SiPagTransactionResult>> pixPayment(double amount) => _pay(_payPix, amount);

  /// O NSU é conferido antes do [type], na ordem da fachada e do roteador do centralizer.
  @override
  Future<Either<SiPagFailure, SiPagTransactionResult>> refundPayment(int type, String nsu) async {
    if (nsu.trim().isEmpty) return left(SiPagFailure.nsuNotInformed());
    if (type > _pixRefundType) return left(SiPagFailure.invalidRefundType());

    return _call(type == _pixRefundType ? _refundPix : _refund, {'nsu': nsu});
  }

  /// O Android recebe o valor em reais, com duas casas e vírgula ("10,00"), como no plugin.
  Future<Either<SiPagFailure, SiPagTransactionResult>> _pay(String method, double amount) {
    return _call(method, {'amount': amount.toStringAsFixed(2).replaceAll('.', ',')});
  }

  Future<Either<SiPagFailure, SiPagTransactionResult>> _call(
    String method,
    Map<String, Object> arguments,
  ) async {
    final Map<dynamic, dynamic>? response;
    try {
      response = await _channel.invokeMethod<Map<dynamic, dynamic>>(method, arguments);
    } on PlatformException catch (e) {
      return left(SiPagFailure(code: e.code, message: e.message ?? e.stacktrace ?? e.toString()));
    } on MissingPluginException {
      return left(SiPagFailure.notImplemented(method));
    }
    if (response == null) return left(SiPagFailure.unknown());

    return right(SiPagTransactionResult.fromMap(response));
  }
}
