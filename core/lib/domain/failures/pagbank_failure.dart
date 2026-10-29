import '../models/models.dart';

class PagBankFailure {
  final String code;
  final String message;

  /// Transação negada, cancelada ou com erro, quando o terminal a devolveu.
  final PagBankTransaction? transaction;

  const PagBankFailure._({this.code = '', this.message = '', this.transaction});

  factory PagBankFailure.notSupported() {
    return const PagBankFailure._(
      code: 'NOT_SUPPORTED',
      message: 'Integração PagBank indisponível nesta plataforma.',
    );
  }

  factory PagBankFailure.invalidAmount() {
    return const PagBankFailure._(
      code: 'INVALID_AMOUNT',
      message: 'O valor deve ser maior que zero e de no máximo ${PagBankPaymentModel.maxAmount} centavos.',
    );
  }

  factory PagBankFailure.invalidInstallments() {
    return const PagBankFailure._(
      code: 'INVALID_INSTALLMENTS',
      message: 'À vista usa 1 parcela, e o parcelado, 2 ou mais.',
    );
  }

  factory PagBankFailure.invalidUserReference() {
    return const PagBankFailure._(
      code: 'INVALID_USER_REFERENCE',
      message: 'O código da venda aceita até 10 letras sem acento e números.',
    );
  }

  factory PagBankFailure.invalidVoid() {
    return const PagBankFailure._(
      code: 'INVALID_VOID',
      message: 'Informe o código e o id da transação a estornar.',
    );
  }

  factory PagBankFailure.invalidPrint() {
    return const PagBankFailure._(
      code: 'INVALID_PRINT',
      message: 'Informe a imagem a imprimir e um avanço de no mínimo ${PagBankPrintModel.minSteps} linhas.',
    );
  }

  factory PagBankFailure.noTransaction() {
    return const PagBankFailure._(
      code: 'NO_TRANSACTION',
      message: 'O terminal não tem transação aprovada.',
    );
  }

  factory PagBankFailure.notAborted() {
    return const PagBankFailure._(
      code: 'NOT_ABORTED',
      message: 'O terminal não confirmou o cancelamento da operação.',
    );
  }

  factory PagBankFailure.invalidResponse() {
    return const PagBankFailure._(
      code: 'INVALID_RESPONSE',
      message: 'O terminal respondeu sem dados válidos.',
    );
  }

  factory PagBankFailure.fromPlatform({
    required String code,
    String? message,
  }) {
    return PagBankFailure._(
      code: code,
      message: message ?? 'Não foi possível concluir a operação no terminal.',
    );
  }

  factory PagBankFailure.fromTransaction(PagBankTransaction transaction) {
    return PagBankFailure._(
      code: transaction.errorCode ?? '',
      message: transaction.message ?? 'Operação não aprovada no terminal.',
      transaction: transaction,
    );
  }

  /// Falha de uma reimpressão ou da impressão livre.
  factory PagBankFailure.fromPrint({String? code, String? message}) {
    return PagBankFailure._(
      code: code ?? '',
      message: message ?? 'Não foi possível imprimir no terminal.',
    );
  }
}
