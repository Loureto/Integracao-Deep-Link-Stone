import 'dart:async';
import 'dart:convert';

import 'package:dependencies/dependencies.dart';
import 'package:flutter/services.dart';

import '../../data/data.dart';
import '../../domain/domain.dart';

class CieloPaymentService implements ICieloPaymentService {
  static const _sendDeeplink = 'sendCieloDeeplink';
  static const _onResponse = 'onCieloResponse';

  final MethodChannel _channel;
  final Environment _environment;
  final _responses = StreamController<CieloResponse>.broadcast();

  CieloPaymentService(this._channel, this._environment) {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  @override
  Stream<CieloResponse> get responses => _responses.stream;

  @override
  Future<Either<CieloFailure, Unit>> sendPayment(CieloPaymentModel data) async {
    if (!data.isValueValid) return left(CieloFailure.invalidValue());
    if (!data.isInstallmentsValid) return left(CieloFailure.invalidInstallments());

    return _send(CieloAction.payment, CieloPaymentModel.toMap(data));
  }

  @override
  Future<Either<CieloFailure, Unit>> cancelPayment(CieloCancelModel data) async {
    if (!data.isValid) return left(CieloFailure.invalidCancel());

    return _send(CieloAction.paymentReversal, CieloCancelModel.toMap(data));
  }

  @override
  Future<Either<CieloFailure, Unit>> printText(CieloPrintModel data) async {
    if (!data.isValid) return left(CieloFailure.invalidPrint());

    return _send(CieloAction.print, CieloPrintModel.toMap(data));
  }

  @override
  Future<Either<CieloFailure, Unit>> listOrders([
    CieloOrderListModel data = const CieloOrderListModel(),
  ]) async {
    if (!data.isValid) return left(CieloFailure.invalidOrderList());

    return _send(CieloAction.orders, CieloOrderListModel.toMap(data));
  }

  @override
  Future<Either<CieloFailure, Unit>> findOrder(CieloOrderQueryModel data) async {
    if (!data.isValid) return left(CieloFailure.invalidOrderQuery());

    return _send(CieloAction.order, CieloOrderQueryModel.toMap(data));
  }

  @override
  Future<Either<CieloFailure, Unit>> listEnabledProducts() => _send(CieloAction.enabledProducts, {});

  @override
  Future<Either<CieloFailure, Unit>> listEstablishments() => _send(CieloAction.establishments, {});

  @override
  Future<Either<CieloFailure, Unit>> getTerminalInfo() => _send(CieloAction.terminalInfo, null);

  /// Envia [request] em JSON, com as credenciais quando a ação exige. Nulo abre a ação sem `request`.
  Future<Either<CieloFailure, Unit>> _send(CieloAction action, Map<String, dynamic>? request) async {
    if (action.requiresCredentials && !_hasCredentials) return left(CieloFailure.missingCredentials());

    final body = request == null
        ? null
        : {
            if (action.requiresCredentials) ...{
              'clientID': _environment.cieloClientID,
              'accessToken': _environment.cieloAccessToken,
            },
            ...request,
          };

    try {
      final opened = await _channel.invokeMethod<bool>(_sendDeeplink, {
        'action': action.value,
        'request': body == null ? null : jsonEncode(body),
      });
      if (opened ?? false) return right(unit);

      return left(CieloFailure.notStarted());
    } on PlatformException catch (e) {
      return left(CieloFailure.fromPlatform(code: e.code, message: e.message));
    } on MissingPluginException {
      return left(CieloFailure.notSupported());
    }
  }

  bool get _hasCredentials =>
      _environment.cieloClientID.isNotEmpty && _environment.cieloAccessToken.isNotEmpty;

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != _onResponse) throw MissingPluginException();

    final response = CieloResponse.fromMap(Map<String, String?>.from(call.arguments as Map));
    if (response != null) _responses.add(response);
  }
}
