import 'dart:async';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';

import 'pagbank.state.dart';

class PagBankViewModel extends ViewModel<PagBankState> {
  final IPagBankPaymentService _service;
  final IPdfImageConverter _pdfImage;
  StreamSubscription<PagBankEvent>? _eventSubscription;

  PagBankViewModel(this._service, this._pdfImage) : super(PagBankState.initialState());

  static const _passwordHint = 'Digite a senha\n';

  @override
  void initViewModel() {
    super.initViewModel();
    _eventSubscription = _service.events.listen(_onEvent);
  }

  Future<void> sendPayment(PagBankPaymentModel request) async {
    _start('Processando o pagamento no terminal...');

    final result = await _service.sendPayment(request);

    result.match(
      _fail,
      (transaction) => emit(
        PagBankState(
          status: PagBankStatus.success,
          message: 'Pagamento aprovado.',
          transaction: transaction,
          lastPayment: transaction,
        ),
      ),
    );
  }

  /// Estorna o último pagamento aprovado. O terminal pede o cartão de novo.
  Future<void> voidLastPayment() async {
    final request = state.voidRequest;
    if (request == null) return;

    _start('Estornando o último pagamento no terminal...');

    final result = await _service.voidPayment(request);

    // Estornado, o pagamento sai do estado: não há mais o que estornar.
    result.match(
      _fail,
      (transaction) => emit(
        PagBankState(
          status: PagBankStatus.success,
          message: 'Pagamento estornado.',
          transaction: transaction,
        ),
      ),
    );
  }

  /// Carrega a última transação aprovada no terminal, que então pode ser estornada.
  Future<void> loadLastApprovedTransaction() async {
    _start('Consultando a última transação aprovada...');

    final result = await _service.getLastApprovedTransaction();

    result.match(
      _fail,
      (transaction) => emit(
        PagBankState(
          status: PagBankStatus.success,
          message: 'Última transação aprovada carregada.',
          transaction: transaction,
          lastPayment: transaction,
        ),
      ),
    );
  }

  Future<void> reprintCustomerReceipt() {
    return _print(
      'Reimprimindo a via do cliente...',
      _service.reprintCustomerReceipt,
      'Via do cliente reimpressa.',
    );
  }

  Future<void> reprintEstablishmentReceipt() {
    return _print(
      'Reimprimindo a via do estabelecimento...',
      _service.reprintEstablishmentReceipt,
      'Via do estabelecimento reimpressa.',
    );
  }

  /// Impressão livre de uma imagem PNG.
  Future<void> printImage(Uint8List image) {
    return _print(
      'Imprimindo a imagem...',
      () => _service.printImage(PagBankPrintModel(image: image)),
      'Imagem impressa.',
    );
  }

  /// Converte a primeira página da NFC-e em PNG e a imprime, como o PDV faz com a nota emitida.
  Future<void> printNfce(String pdfBase64) async {
    _start('Convertendo a NFC-e em imagem...');

    final image = await _pdfImage.firstPageToPng(pdfBase64);

    await image.match(
      (failure) async => emit(
        PagBankState(status: PagBankStatus.error, message: failure.message, lastPayment: state.lastPayment),
      ),
      (png) => _print(
        'Imprimindo a NFC-e...',
        () => _service.printImage(PagBankPrintModel(image: png)),
        'NFC-e impressa.',
      ),
    );
  }

  /// Interrompe o pagamento ou o estorno em andamento, que termina com a própria falha.
  Future<void> abort() async {
    if (!state.status.isLoading) return;

    final result = await _service.abort();

    result.match((failure) {
      if (state.status.isLoading) emit(state.copyWith(message: failure.message));
    }, (_) {});
  }

  Future<void> _print(
    String loading,
    Future<Either<PagBankFailure, Unit>> Function() print,
    String success,
  ) async {
    _start(loading);

    final result = await print();

    result.match(_fail, (_) => emit(state.copyWith(status: PagBankStatus.success, message: success)));
  }

  void _start(String message) {
    emit(PagBankState(status: PagBankStatus.loading, message: message, lastPayment: state.lastPayment));
  }

  void _fail(PagBankFailure failure) {
    emit(
      PagBankState(
        status: PagBankStatus.error,
        message: failure.message,
        transaction: failure.transaction,
        lastPayment: state.lastPayment,
      ),
    );
  }

  /// A senha chega um evento por dígito, sem texto: como no demo oficial, cada dígito vira um `*`.
  void _onEvent(PagBankEvent event) {
    if (!state.status.isLoading) return;

    final message = switch (event) {
      PagBankEvent(isNoPassword: true) => _passwordHint,
      PagBankEvent(isPasswordDigit: true) =>
        '${state.message.startsWith(_passwordHint) ? state.message : _passwordHint}*',
      PagBankEvent(:final message?) when message.isNotEmpty => message,
      _ => null,
    };
    if (message != null) emit(state.copyWith(message: message));
  }

  @override
  Future<void> onDispose() async {
    await _eventSubscription?.cancel();
    await super.onDispose();
  }
}
