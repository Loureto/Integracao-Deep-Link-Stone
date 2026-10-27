import 'package:core/core.dart';

enum CieloStatus { idle, success, loading, error }

extension CieloStatusExtension on CieloStatus {
  bool get isIdle => this == CieloStatus.idle;
  bool get isLoading => this == CieloStatus.loading;
  bool get isSuccess => this == CieloStatus.success;
  bool get isError => this == CieloStatus.error;
}

class CieloState extends ViewModelState {
  final String message;
  final CieloStatus status;
  final CieloResponse? response;

  /// Último pedido devolvido pela Cielo, usado para cancelar e consultar o pagamento.
  final CieloOrder? lastOrder;

  const CieloState({
    this.message = '',
    this.status = CieloStatus.idle,
    this.response,
    this.lastOrder,
  });

  factory CieloState.initialState() => CieloState();

  /// Cancelamento do último pagamento ainda não cancelado, ou nulo quando não há o que cancelar.
  CieloCancelModel? get cancelRequest {
    final order = lastOrder;
    final payment = order?.cancelablePayment;
    if (order == null || payment == null) return null;

    return CieloCancelModel.fromPayment(order, payment);
  }

  CieloState copyWith({
    String? message,
    CieloStatus? status,
    CieloResponse? response,
    CieloOrder? lastOrder,
  }) {
    return CieloState(
      message: message ?? this.message,
      status: status ?? this.status,
      response: response ?? this.response,
      lastOrder: lastOrder ?? this.lastOrder,
    );
  }
}
