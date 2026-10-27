import 'dart:async';

import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';

import 'cielo.state.dart';

class CieloViewModel extends ViewModel<CieloState> {
  final ICieloPaymentService _service;
  StreamSubscription<CieloResponse>? _responseSubscription;

  CieloViewModel(this._service) : super(CieloState.initialState());

  @override
  void initViewModel() {
    super.initViewModel();
    _responseSubscription = _service.responses.listen(_onResponse);
  }

  Future<void> sendPayment(CieloPaymentModel request) => _open(() => _service.sendPayment(request));

  Future<void> cancelLastPayment() async {
    final request = state.cancelRequest;
    if (request == null) return;

    await _open(() => _service.cancelPayment(request));
  }

  Future<void> findLastOrder() async {
    final order = state.lastOrder;
    if (order == null) return;

    await _open(() => _service.findOrder(CieloOrderQueryModel(orderId: order.id)));
  }

  Future<void> listOrders() => _open(() => _service.listOrders());

  Future<void> printText(CieloPrintModel request) => _open(() => _service.printText(request));

  Future<void> listEnabledProducts() => _open(_service.listEnabledProducts);

  Future<void> listEstablishments() => _open(_service.listEstablishments);

  Future<void> getTerminalInfo() => _open(_service.getTerminalInfo);

  /// Volta ao estado inicial, por exemplo quando o app da Cielo não responde, mantendo o último pedido.
  void reset() => emit(CieloState(lastOrder: state.lastOrder));

  Future<void> _open(Future<Either<CieloFailure, Unit>> Function() request) async {
    emit(
      CieloState(
        status: CieloStatus.loading,
        message: 'Abrindo o app da Cielo...',
        lastOrder: state.lastOrder,
      ),
    );

    final result = await request();

    result.match(
      (failure) => emit(
        CieloState(status: CieloStatus.error, message: failure.message, lastOrder: state.lastOrder),
      ),
      (_) {
        // O retorno pode ter chegado enquanto a abertura era confirmada.
        if (!state.status.isLoading) return;
        emit(
          state.copyWith(
            message: 'Aguardando o retorno do app da Cielo...',
          ),
        );
      },
    );
  }

  void _onResponse(CieloResponse response) {
    emit(
      CieloState(
        status: response.isSuccess ? CieloStatus.success : CieloStatus.error,
        message: response.isSuccess
            ? _successMessage(response.action)
            : CieloFailure.fromResponse(response).message,
        response: response,
        lastOrder: response.order ?? state.lastOrder,
      ),
    );
  }

  static String _successMessage(CieloAction action) {
    return switch (action) {
      CieloAction.payment => 'Pagamento aprovado.',
      CieloAction.paymentReversal => 'Pagamento cancelado.',
      CieloAction.print => 'Impressão concluída.',
      CieloAction.order => 'Pedido encontrado.',
      CieloAction.orders => 'Pedidos carregados.',
      CieloAction.enabledProducts => 'Produtos habilitados carregados.',
      CieloAction.establishments => 'Estabelecimentos carregados.',
      CieloAction.terminalInfo => 'Informações do terminal carregadas.',
    };
  }

  @override
  Future<void> onDispose() async {
    await _responseSubscription?.cancel();
    await super.onDispose();
  }
}
