import 'dart:async';

import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';

const approvedPagBankTransaction = PagBankTransaction({
  'result': 0,
  'errorCode': '0000',
  'transactionCode': 'TC1',
  'transactionId': 'TID1',
  'amount': '100',
  'paymentType': 'DEBIT',
  'voidType': 'PAYMENT',
  'cardBrand': 'MASTERCARD',
  'nsu': '123456',
  'autoCode': 'A1B2C3',
});

class FakePagBankService implements IPagBankPaymentService {
  final eventsController = StreamController<PagBankEvent>.broadcast();

  /// Método e modelo de cada operação, na ordem em que foram chamadas.
  final calls = <(String, Object?)>[];
  Either<PagBankFailure, PagBankTransaction> transactionResult = right(approvedPagBankTransaction);
  Either<PagBankFailure, Unit> unitResult = right(unit);

  /// Quando definido, as operações com transação só terminam quando ele completar, como no terminal.
  Completer<Either<PagBankFailure, PagBankTransaction>>? pending;

  @override
  Stream<PagBankEvent> get events => eventsController.stream;

  Future<Either<PagBankFailure, PagBankTransaction>> _transaction(String method, [Object? data]) async {
    calls.add((method, data));
    return pending?.future ?? transactionResult;
  }

  Future<Either<PagBankFailure, Unit>> _unit(String method) async {
    calls.add((method, null));
    return unitResult;
  }

  @override
  Future<Either<PagBankFailure, PagBankTransaction>> sendPayment(PagBankPaymentModel data) {
    return _transaction('doPayment', data);
  }

  @override
  Future<Either<PagBankFailure, PagBankTransaction>> voidPayment(PagBankVoidModel data) {
    return _transaction('voidPayment', data);
  }

  @override
  Future<Either<PagBankFailure, Unit>> abort() => _unit('abort');

  @override
  Future<Either<PagBankFailure, PagBankTransaction>> getLastApprovedTransaction() {
    return _transaction('getLastApprovedTransaction');
  }

  @override
  Future<Either<PagBankFailure, Unit>> reprintCustomerReceipt() => _unit('reprintCustomerReceipt');

  @override
  Future<Either<PagBankFailure, Unit>> reprintEstablishmentReceipt() => _unit('reprintEstablishmentReceipt');
}
