import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';

import 'vero.state.dart';

class VeroViewModel extends ViewModel<VeroState> {
  final IVeroPaymentService _payments;
  final INativePrinterService _printer;

  VeroViewModel(this._payments, this._printer) : super(VeroState.initialState());

  /// Pagamento pelo app da Vero. O comprovante do cliente sai pelo driver genérico, chamado pelo core.
  Future<void> pay(VeroPaymentType type, double amount) async {
    _start('Processando o pagamento no app da Vero...');

    final result = await switch (type) {
      VeroPaymentType.credit => _payments.creditCardPayment(amount),
      VeroPaymentType.debit => _payments.debitCardPayment(amount),
      VeroPaymentType.pix => _payments.pixPayment(amount),
      VeroPaymentType.wallet => _payments.acquirerPayment(amount),
    };

    result.match(
      _fail,
      (transaction) => emit(
        VeroState(
          status: VeroPageStatus.success,
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

    final result = await _payments.refundPayment(payment.nsu);

    result.match(
      _fail,
      (transaction) => emit(
        VeroState(status: VeroPageStatus.success, message: 'Pagamento estornado.', transaction: transaction),
      ),
    );
  }

  /// Converte a primeira página da NFC-e em imagem e a imprime pelo driver genérico.
  Future<void> printNfc(String pdfBase64) {
    return _print('Imprimindo a NFC-e...', () => _printer.printNfc(pdfBase64), 'NFC-e impressa.');
  }

  Future<void> printTxt(String text) {
    return _print('Imprimindo o texto...', () => _printer.printTxt(text), 'Texto impresso.');
  }

  Future<void> testPrint() {
    return _print('Imprimindo o teste...', _printer.testPrint, 'Impressão de teste concluída.');
  }

  Future<void> _print(
    String loading,
    Future<Either<NativePrinterFailure, Unit>> Function() print,
    String success,
  ) async {
    _start(loading);

    final result = await print();

    result.match(
      (failure) => emit(
        VeroState(status: VeroPageStatus.error, message: failure.message, lastPayment: state.lastPayment),
      ),
      (_) =>
          emit(VeroState(status: VeroPageStatus.success, message: success, lastPayment: state.lastPayment)),
    );
  }

  void _start(String message) {
    emit(VeroState(status: VeroPageStatus.loading, message: message, lastPayment: state.lastPayment));
  }

  void _fail(VeroFailure failure) {
    emit(VeroState(status: VeroPageStatus.error, message: failure.message, lastPayment: state.lastPayment));
  }
}
