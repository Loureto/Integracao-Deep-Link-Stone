import 'dart:async';

import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';

/// Transação aprovada que o serviço fake devolve por padrão.
final approvedTransaction = SiPagTransactionResult.fromMap({
  'NSU_SITEF': '123',
  'AUTHORIZATION': 'A1',
  'FLAG': 'VISA',
  'AMOUNT': 1.0,
});

class FakeSiPagPaymentService implements ISiPagPaymentService {
  /// Chamadas recebidas, com o valor, o NSU e o type do estorno, na ordem.
  final calls = <(String, Object?)>[];
  Either<SiPagFailure, SiPagTransactionResult> result = right(approvedTransaction);

  /// Quando definido, a operação só termina ao completá-lo, como o app da adquirente demorando a responder.
  Completer<void>? pending;

  Future<Either<SiPagFailure, SiPagTransactionResult>> _record(String method, Object? argument) async {
    calls.add((method, argument));
    await pending?.future;
    return result;
  }

  @override
  Future<Either<SiPagFailure, SiPagTransactionResult>> getLastOperation() =>
      _record('getLastOperation', null);

  @override
  Future<Either<SiPagFailure, SiPagTransactionResult>> creditCardPayment(double amount) =>
      _record('creditCardPayment', amount);

  @override
  Future<Either<SiPagFailure, SiPagTransactionResult>> debitCardPayment(double amount) =>
      _record('debitCardPayment', amount);

  @override
  Future<Either<SiPagFailure, SiPagTransactionResult>> pixPayment(double amount) =>
      _record('pixPayment', amount);

  @override
  Future<Either<SiPagFailure, SiPagTransactionResult>> refundPayment(int type, String nsu) =>
      _record('refundPayment', (type, nsu));
}
