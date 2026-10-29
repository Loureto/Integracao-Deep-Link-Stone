import 'dart:async';

import 'package:dependencies/dependencies.dart';
import 'package:flutter/services.dart';

import '../../data/data.dart';
import '../../domain/domain.dart';

class PagBankPaymentService implements IPagBankPaymentService {
  static const _doPayment = 'doPayment';
  static const _voidPayment = 'voidPayment';
  static const _abort = 'abort';
  static const _getLastApprovedTransaction = 'getLastApprovedTransaction';
  static const _reprintCustomerReceipt = 'reprintCustomerReceipt';
  static const _reprintEstablishmentReceipt = 'reprintEstablishmentReceipt';
  static const _printImage = 'printImage';
  static const _onEvent = 'onPagBankEvent';

  /// `PlugPag.RET_OK`.
  static const _ok = 0;

  final MethodChannel _channel;
  final _events = StreamController<PagBankEvent>.broadcast();

  PagBankPaymentService(this._channel) {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  @override
  Stream<PagBankEvent> get events => _events.stream;

  @override
  Future<Either<PagBankFailure, PagBankTransaction>> sendPayment(PagBankPaymentModel data) async {
    if (!data.isAmountValid) return left(PagBankFailure.invalidAmount());
    if (!data.isInstallmentsValid) return left(PagBankFailure.invalidInstallments());
    if (!data.isUserReferenceValid) return left(PagBankFailure.invalidUserReference());

    return _transaction(_doPayment, PagBankPaymentModel.toMap(data));
  }

  @override
  Future<Either<PagBankFailure, PagBankTransaction>> voidPayment(PagBankVoidModel data) async {
    if (!data.isValid) return left(PagBankFailure.invalidVoid());

    return _transaction(_voidPayment, PagBankVoidModel.toMap(data));
  }

  @override
  Future<Either<PagBankFailure, Unit>> abort() async {
    final result = await _invoke(_abort);

    return result.flatMap<Unit>((code) => code == _ok ? right(unit) : left(PagBankFailure.notAborted()));
  }

  @override
  Future<Either<PagBankFailure, PagBankTransaction>> getLastApprovedTransaction() async {
    final result = await _transaction(_getLastApprovedTransaction);

    return result.flatMap<PagBankTransaction>(
      (transaction) => transaction.hasTransaction ? right(transaction) : left(PagBankFailure.noTransaction()),
    );
  }

  @override
  Future<Either<PagBankFailure, Unit>> reprintCustomerReceipt() => _print(_reprintCustomerReceipt);

  @override
  Future<Either<PagBankFailure, Unit>> reprintEstablishmentReceipt() => _print(_reprintEstablishmentReceipt);

  @override
  Future<Either<PagBankFailure, Unit>> printImage(PagBankPrintModel data) async {
    if (!data.isValid) return left(PagBankFailure.invalidPrint());

    return _print(_printImage, PagBankPrintModel.toMap(data));
  }

  /// Só `result` 0 é aprovada: as outras viram falha com a própria transação.
  Future<Either<PagBankFailure, PagBankTransaction>> _transaction(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    final result = await _invoke(method, arguments);

    return result.flatMap<PagBankTransaction>((data) {
      final transaction = PagBankTransaction.fromMap(data);
      if (transaction == null) return left(PagBankFailure.invalidResponse());

      return transaction.isApproved ? right(transaction) : left(PagBankFailure.fromTransaction(transaction));
    });
  }

  Future<Either<PagBankFailure, Unit>> _print(String method, [Map<String, dynamic>? arguments]) async {
    final result = await _invoke(method, arguments);

    return result.flatMap<Unit>((data) {
      if (data is! Map) return left(PagBankFailure.invalidResponse());
      if (data['result'] == _ok) return right(unit);

      return left(
        PagBankFailure.fromPrint(code: _string(data['errorCode']), message: _string(data['message'])),
      );
    });
  }

  static String? _string(Object? value) => value is String ? value : null;

  Future<Either<PagBankFailure, Object?>> _invoke(String method, [Map<String, dynamic>? arguments]) async {
    try {
      return right(await _channel.invokeMethod<Object?>(method, arguments));
    } on PlatformException catch (e) {
      return left(PagBankFailure.fromPlatform(code: e.code, message: e.message));
    } on MissingPluginException {
      return left(PagBankFailure.notSupported());
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != _onEvent) throw MissingPluginException();

    final event = PagBankEvent.fromMap(call.arguments);
    if (event != null) _events.add(event);
  }
}
