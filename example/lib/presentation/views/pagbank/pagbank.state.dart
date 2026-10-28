import 'package:core/core.dart';

enum PagBankStatus { idle, success, loading, error }

extension PagBankStatusExtension on PagBankStatus {
  bool get isIdle => this == PagBankStatus.idle;
  bool get isLoading => this == PagBankStatus.loading;
  bool get isSuccess => this == PagBankStatus.success;
  bool get isError => this == PagBankStatus.error;
}

class PagBankState extends ViewModelState {
  final String message;
  final PagBankStatus status;

  /// Transação da última operação, aprovada ou não.
  final PagBankTransaction? transaction;

  /// Último pagamento aprovado, que pode ser estornado.
  final PagBankTransaction? lastPayment;

  const PagBankState({
    this.message = '',
    this.status = PagBankStatus.idle,
    this.transaction,
    this.lastPayment,
  });

  factory PagBankState.initialState() => PagBankState();

  /// Estorno do último pagamento aprovado, com a via do cliente, ou nulo quando não há o que estornar.
  PagBankVoidModel? get voidRequest {
    final payment = lastPayment;
    if (payment == null) return null;

    return PagBankVoidModel.fromTransaction(payment, printReceipt: true);
  }

  PagBankState copyWith({
    String? message,
    PagBankStatus? status,
    PagBankTransaction? transaction,
    PagBankTransaction? lastPayment,
  }) {
    return PagBankState(
      message: message ?? this.message,
      status: status ?? this.status,
      transaction: transaction ?? this.transaction,
      lastPayment: lastPayment ?? this.lastPayment,
    );
  }
}
