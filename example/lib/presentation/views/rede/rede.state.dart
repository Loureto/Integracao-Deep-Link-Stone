import 'package:core/core.dart';

/// Situação da tela. O nome evita colidir com o `RedeStatus` do plugin `flutter_rede_sdk`.
enum RedePageStatus { idle, success, loading, error }

extension RedePageStatusExtension on RedePageStatus {
  bool get isIdle => this == RedePageStatus.idle;
  bool get isLoading => this == RedePageStatus.loading;
  bool get isSuccess => this == RedePageStatus.success;
  bool get isError => this == RedePageStatus.error;
}

/// Pagamentos de teste, um para cada método de pagamento do [IRedePaymentService].
enum RedePaymentType { credit, debit, pix }

class RedeState extends ViewModelState {
  final String message;
  final RedePageStatus status;

  /// Transação da última operação aprovada.
  final RedeTransactionResult? transaction;

  /// Último pagamento aprovado, que pode ser estornado pelo NSU.
  final RedeTransactionResult? lastPayment;

  const RedeState({
    this.message = '',
    this.status = RedePageStatus.idle,
    this.transaction,
    this.lastPayment,
  });

  factory RedeState.initialState() => RedeState();
}
