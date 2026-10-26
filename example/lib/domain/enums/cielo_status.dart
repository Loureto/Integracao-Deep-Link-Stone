enum CieloStatus { idle, success, loading, error }

extension CieloStatusExtension on CieloStatus {
  bool get isIdle => this == CieloStatus.idle;
  bool get isLoading => this == CieloStatus.loading;
  bool get isSuccess => this == CieloStatus.success;
  bool get isError => this == CieloStatus.error;
}
