import 'package:core/core.dart';

enum StoneStatus { idle, success, loading, error }

extension StoneStatusExtension on StoneStatus {
  bool get isIdle => this == StoneStatus.idle;
  bool get isLoading => this == StoneStatus.loading;
  bool get isSuccess => this == StoneStatus.success;
  bool get isError => this == StoneStatus.error;
}

class StoneState extends ViewModelState {
  final String message;
  final StoneStatus status;
  final StonePaymentResponse? response;

  const StoneState({
    this.message = '',
    this.status = StoneStatus.idle,
    this.response,
  });

  factory StoneState.initialState() => StoneState();

  StoneState copyWith({
    String? message,
    StoneStatus? status,
    StonePaymentResponse? response,
  }) {
    return StoneState(
      message: message ?? this.message,
      status: status ?? this.status,
      response: response ?? this.response,
    );
  }
}
