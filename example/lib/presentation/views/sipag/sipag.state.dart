import 'package:core/core.dart';

/// Situação da tela.
enum SipagPageStatus { idle, success, loading, error }

extension SipagPageStatusExtension on SipagPageStatus {
  bool get isIdle => this == SipagPageStatus.idle;
  bool get isLoading => this == SipagPageStatus.loading;
  bool get isSuccess => this == SipagPageStatus.success;
  bool get isError => this == SipagPageStatus.error;
}

/// Pagamentos de teste, um para cada método de pagamento do [ISiPagPaymentService].
enum SipagPaymentType { credit, debit, pix }

class SipagState extends ViewModelState {
  final String message;
  final SipagPageStatus status;

  /// Transação da última operação aprovada ou recuperada.
  final SiPagTransactionResult? transaction;

  /// Último pagamento aprovado, que pode ser estornado pelo NSU.
  final SiPagTransactionResult? lastPayment;

  /// Tipo do [lastPayment]: o estorno de Pix usa outro type.
  final SipagPaymentType? lastPaymentType;

  const SipagState({
    this.message = '',
    this.status = SipagPageStatus.idle,
    this.transaction,
    this.lastPayment,
    this.lastPaymentType,
  });

  factory SipagState.initialState() => SipagState();
}
