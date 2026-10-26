import 'package:core/core.dart';

import '../../../domain/domain.dart';

class CieloState extends ViewModelState {
  final String message;
  final CieloStatus status;

  const CieloState({this.message = '', this.status = CieloStatus.idle});

  factory CieloState.initialState() => CieloState();

  CieloState copyWith({String? message, CieloStatus? status}) {
    return CieloState(
      message: message ?? this.message,
      status: status ?? this.status,
    );
  }
}
