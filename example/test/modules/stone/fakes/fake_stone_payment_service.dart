import 'dart:async';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';

class FakeStonePaymentService implements IStonePaymentService {
  final responsesController = StreamController<StonePaymentResponse>.broadcast();
  final requests = <StonePaymentModel>[];
  Either<StonePaymentFailure, Unit> result = right(unit);

  /// NFC-es recebidas em [printNfc], na ordem.
  final nfcs = <String>[];
  Either<StonePaymentFailure, Unit> printResult = right(unit);

  /// Quando definido, a impressão só termina ao completá-lo, como o app de impressão demorando a responder.
  Completer<void>? printing;

  @override
  Stream<StonePaymentResponse> get responses => responsesController.stream;

  @override
  Future<Either<StonePaymentFailure, Unit>> sendPayment(StonePaymentModel data) async {
    requests.add(data);
    return result;
  }

  @override
  Future<Either<StonePaymentFailure, Unit>> printNfc(String nfcBase64) async {
    nfcs.add(nfcBase64);
    await printing?.future;
    return printResult;
  }

  @override
  Future<Either<StonePaymentFailure, Unit>> printReceipt({required Uint8List bitmap}) async => printResult;
}
