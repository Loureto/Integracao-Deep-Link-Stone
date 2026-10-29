import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';

import 'rede.state.dart';

class RedeViewModel extends ViewModel<RedeState> {
  final IRedePaymentService _service;

  RedeViewModel(this._service) : super(RedeState.initialState());

  /// Pagamento pelo app da Rede. Diferente da Vero, nenhum comprovante sai depois, como no centralizer.
  Future<void> pay(RedePaymentType type, double amount) async {
    _start('Processando o pagamento no app da Rede...');

    final result = await switch (type) {
      RedePaymentType.credit => _service.creditCardPayment(amount),
      RedePaymentType.debit => _service.debitCardPayment(amount),
      RedePaymentType.pix => _service.pixPayment(amount),
    };

    result.match(
      _fail,
      (transaction) => emit(
        RedeState(
          status: RedePageStatus.success,
          message: 'Pagamento aprovado.',
          transaction: transaction,
          lastPayment: transaction,
        ),
      ),
    );
  }

  /// Estorna o último pagamento aprovado pelo NSU. Estornado, ele sai do estado: não há mais o que estornar.
  Future<void> refundLastPayment() async {
    final payment = state.lastPayment;
    if (payment == null) return;

    _start('Estornando o último pagamento...');

    final result = await _service.refundPayment(payment.nsu);

    result.match(
      _fail,
      (transaction) => emit(
        RedeState(status: RedePageStatus.success, message: 'Pagamento estornado.', transaction: transaction),
      ),
    );
  }

  /// Converte a primeira página da NFC-e em imagem e a imprime pela impressora da Rede.
  Future<void> printNfc(String pdfBase64) {
    return _print('Imprimindo a NFC-e...', () => _service.printNfc(pdfBase64), 'NFC-e impressa.');
  }

  Future<void> printTxt(String text) {
    return _print('Imprimindo o texto...', () => _service.printTxt(text), 'Texto impresso.');
  }

  Future<void> testPrint() {
    return _print('Imprimindo o teste...', _service.testPrint, 'Impressão de teste concluída.');
  }

  Future<void> _print(
    String loading,
    Future<Either<RedeFailure, Unit>> Function() print,
    String success,
  ) async {
    _start(loading);

    final result = await print();

    result.match(
      _fail,
      (_) =>
          emit(RedeState(status: RedePageStatus.success, message: success, lastPayment: state.lastPayment)),
    );
  }

  void _start(String message) {
    emit(RedeState(status: RedePageStatus.loading, message: message, lastPayment: state.lastPayment));
  }

  void _fail(RedeFailure failure) {
    emit(RedeState(status: RedePageStatus.error, message: failure.message, lastPayment: state.lastPayment));
  }
}
