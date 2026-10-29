import 'dart:async';

import 'package:core/core.dart';

import 'stone.state.dart';

class StoneViewModel extends ViewModel<StoneState> {
  final IStonePaymentService _service;
  StreamSubscription<StonePaymentResponse>? _responseSubscription;

  StoneViewModel(this._service) : super(StoneState.initialState());

  @override
  void initViewModel() {
    super.initViewModel();
    _responseSubscription = _service.responses.listen(_onResponse);
  }

  Future<void> sendPayment(StonePaymentModel request) async {
    emit(
      const StoneState(
        status: StoneStatus.loading,
        message: 'Abrindo o app de pagamento Stone...',
      ),
    );

    final result = await _service.sendPayment(request);

    result.match(
      (failure) => emit(
        StoneState(status: StoneStatus.error, message: failure.message),
      ),
      (_) {
        // O retorno pode ter chegado enquanto o envio era confirmado.
        if (!state.status.isLoading) return;
        emit(
          state.copyWith(
            message: 'Aguardando o retorno do app de pagamento...',
          ),
        );
      },
    );
  }

  /// Imprime a NFC-e pelo app de impressão da Stone. Diferente do pagamento, o resultado chega na própria chamada.
  Future<void> printNfc(String nfcBase64) async {
    emit(const StoneState(status: StoneStatus.loading, message: 'Imprimindo a NFC-e...'));

    final result = await _service.printNfc(nfcBase64);

    result.match(
      (failure) => emit(StoneState(status: StoneStatus.error, message: failure.message)),
      (_) => emit(const StoneState(status: StoneStatus.success, message: 'NFC-e impressa.')),
    );
  }

  /// Volta ao estado inicial, por exemplo quando o app Stone não responde.
  void reset() => emit(StoneState.initialState());

  void _onResponse(StonePaymentResponse response) {
    emit(
      StoneState(
        status: response.isApproved ? StoneStatus.success : StoneStatus.error,
        message: response.isApproved
            ? 'Pagamento aprovado.'
            : StonePaymentFailure.fromResponse(response).message,
        response: response,
      ),
    );
  }

  @override
  Future<void> onDispose() async {
    await _responseSubscription?.cancel();
    await super.onDispose();
  }
}
