import 'dart:async';

import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';

class FakeStonePaymentService implements IStonePaymentService {
  final responsesController = StreamController<StonePaymentResponse>.broadcast();
  final requests = <StonePaymentModel>[];
  Either<StonePaymentFailure, Unit> result = right(unit);

  @override
  Stream<StonePaymentResponse> get responses => responsesController.stream;

  @override
  Future<Either<StonePaymentFailure, Unit>> sendPayment(StonePaymentModel data) async {
    requests.add(data);
    return result;
  }
}
