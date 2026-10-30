import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';

import 'sipag.state.dart';

class SipagViewModel extends ViewModel<SipagState> {
  final ISiPagPaymentService _payments;
  final INativePrinterService _printer;

  SipagViewModel(this._payments, this._printer) : super(SipagState.initialState());

  /// Código da última operação quando nenhuma foi interrompida: não é erro, como o PDV Varejo trata.
  static const _lastOperationNotFound = 'LAST_OPERATION_NOT_FOUND';

  /// Pagamento pelo app da adquirente do terminal: o Sicoob no DX8000 e na X990, o da Ger7 no P2.
  Future<void> pay(SipagPaymentType type, double amount) async {
    _start('Processando o pagamento no app da Sipag...');

    final result = await switch (type) {
      SipagPaymentType.credit => _payments.creditCardPayment(amount),
      SipagPaymentType.debit => _payments.debitCardPayment(amount),
      SipagPaymentType.pix => _payments.pixPayment(amount),
    };

    result.match(
      _fail,
      (transaction) => emit(
        SipagState(
          status: SipagPageStatus.success,
          message: 'Pagamento aprovado.',
          transaction: transaction,
          lastPayment: transaction,
          lastPaymentType: type,
        ),
      ),
    );
  }

  /// Estorna o último pagamento aprovado pelo NSU, com o type 1 se ele foi Pix e 0 se foi cartão, como o PDV
  /// Varejo. Estornado, ele sai do estado: não há mais o que estornar.
  Future<void> refundLastPayment() async {
    final payment = state.lastPayment;
    if (payment == null) return;

    _start('Estornando o último pagamento...');

    final type = state.lastPaymentType == SipagPaymentType.pix ? 1 : 0;
    final result = await _payments.refundPayment(type, payment.nsu);

    result.match(
      _fail,
      (transaction) => emit(
        SipagState(
          status: SipagPageStatus.success,
          message: 'Pagamento estornado.',
          transaction: transaction,
        ),
      ),
    );
  }

  /// Busca o resultado de uma operação interrompida por uma queda do app, como o PDV faz ao abrir o dashboard.
  Future<void> getLastOperation() async {
    _start('Buscando a última operação...');

    final result = await _payments.getLastOperation();

    result.match(
      (failure) => failure.code == _lastOperationNotFound
          ? _keep(SipagPageStatus.success, failure.message)
          : _fail(failure),
      (transaction) => emit(
        SipagState(
          status: SipagPageStatus.success,
          message: 'Última operação recuperada.',
          transaction: transaction,
          lastPayment: state.lastPayment,
          lastPaymentType: state.lastPaymentType,
        ),
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
      (failure) => _keep(SipagPageStatus.error, failure.message),
      (_) => _keep(SipagPageStatus.success, success),
    );
  }

  void _start(String message) => _keep(SipagPageStatus.loading, message);

  void _fail(SiPagFailure failure) => _keep(SipagPageStatus.error, failure.message);

  /// Novo [status] e [message], com o último pagamento mantido para o estorno.
  void _keep(SipagPageStatus status, String message) {
    emit(
      SipagState(
        status: status,
        message: message,
        lastPayment: state.lastPayment,
        lastPaymentType: state.lastPaymentType,
      ),
    );
  }
}
