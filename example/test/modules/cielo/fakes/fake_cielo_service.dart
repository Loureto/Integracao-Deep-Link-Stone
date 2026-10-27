import 'dart:async';

import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';

class FakeCieloService implements ICieloPaymentService {
  final responsesController = StreamController<CieloResponse>.broadcast();

  /// Ação e modelo enviados em cada operação aberta.
  final requests = <(CieloAction, Object?)>[];
  Either<CieloFailure, Unit> result = right(unit);

  @override
  Stream<CieloResponse> get responses => responsesController.stream;

  Future<Either<CieloFailure, Unit>> _open(CieloAction action, [Object? data]) async {
    requests.add((action, data));
    return result;
  }

  @override
  Future<Either<CieloFailure, Unit>> sendPayment(CieloPaymentModel data) => _open(CieloAction.payment, data);

  @override
  Future<Either<CieloFailure, Unit>> cancelPayment(CieloCancelModel data) {
    return _open(CieloAction.paymentReversal, data);
  }

  @override
  Future<Either<CieloFailure, Unit>> printText(CieloPrintModel data) => _open(CieloAction.print, data);

  @override
  Future<Either<CieloFailure, Unit>> listOrders([CieloOrderListModel data = const CieloOrderListModel()]) {
    return _open(CieloAction.orders, data);
  }

  @override
  Future<Either<CieloFailure, Unit>> findOrder(CieloOrderQueryModel data) => _open(CieloAction.order, data);

  @override
  Future<Either<CieloFailure, Unit>> listEnabledProducts() => _open(CieloAction.enabledProducts);

  @override
  Future<Either<CieloFailure, Unit>> listEstablishments() => _open(CieloAction.establishments);

  @override
  Future<Either<CieloFailure, Unit>> getTerminalInfo() => _open(CieloAction.terminalInfo);
}
