import 'package:core/core.dart';

/// Situação da tela. O nome evita colidir com o `VeroStatus` do plugin `vero_flutter`.
enum VeroPageStatus { idle, success, loading, error }

extension VeroPageStatusExtension on VeroPageStatus {
  bool get isIdle => this == VeroPageStatus.idle;
  bool get isLoading => this == VeroPageStatus.loading;
  bool get isSuccess => this == VeroPageStatus.success;
  bool get isError => this == VeroPageStatus.error;
}

/// Pagamentos de teste, um para cada método de pagamento do [IVeroPaymentService].
enum VeroPaymentType { credit, debit, pix, wallet }

class VeroState extends ViewModelState {
  final String message;
  final VeroPageStatus status;

  /// Transação da última operação aprovada.
  final VeroTransactionResult? transaction;

  /// Último pagamento aprovado, que pode ser estornado pelo NSU.
  final VeroTransactionResult? lastPayment;

  const VeroState({
    this.message = '',
    this.status = VeroPageStatus.idle,
    this.transaction,
    this.lastPayment,
  });

  factory VeroState.initialState() => VeroState();
}
