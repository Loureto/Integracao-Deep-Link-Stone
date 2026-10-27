import 'dart:async';

import 'package:dependencies/dependencies.dart';
import 'package:flutter/services.dart';

import '../../data/data.dart';
import '../../domain/domain.dart';

class StonePaymentService implements IStonePaymentService {
  static const _sendDeeplink = 'sendStoneDeeplink';
  static const _onPaymentResponse = 'onStonePaymentResponse';

  final MethodChannel _channel;
  final _responses = StreamController<StonePaymentResponse>.broadcast();

  StonePaymentService(this._channel) {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  @override
  Stream<StonePaymentResponse> get responses => _responses.stream;

  @override
  Future<Either<StonePaymentFailure, Unit>> sendPayment(StonePaymentModel data) async {
    if (!data.isAmountValid) return left(StonePaymentFailure.invalidAmount());
    if (!data.isInstallmentCountValid) return left(StonePaymentFailure.invalidInstallmentCount());

    try {
      final opened = await _channel.invokeMethod<bool>(_sendDeeplink, StonePaymentModel.toMap(data));
      if (opened ?? false) return right(unit);

      return left(StonePaymentFailure.paymentNotStarted());
    } on PlatformException catch (e) {
      return left(StonePaymentFailure.fromPlatform(code: e.code, message: e.message));
    } on MissingPluginException {
      return left(StonePaymentFailure.notSupported());
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != _onPaymentResponse) throw MissingPluginException();

    final data = Map<String, String?>.from(call.arguments as Map);
    _responses.add(StonePaymentResponse(data));
  }
}
