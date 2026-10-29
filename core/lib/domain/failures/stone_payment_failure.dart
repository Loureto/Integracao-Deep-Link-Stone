import '../models/models.dart';

class StonePaymentFailure {
  final String code;
  final String message;

  /// Action code do autorizador Stone, como `1016`, enviado quando a transação é negada.
  final String? reason;

  const StonePaymentFailure._({this.code = '', this.message = '', this.reason});

  factory StonePaymentFailure.paymentNotStarted() {
    return const StonePaymentFailure._(
      code: 'PAYMENT_NOT_STARTED',
      message: 'O app de pagamento não foi aberto.',
    );
  }

  factory StonePaymentFailure.notSupported() {
    return const StonePaymentFailure._(
      code: 'NOT_SUPPORTED',
      message: 'Integração Stone indisponível nesta plataforma.',
    );
  }

  factory StonePaymentFailure.invalidAmount() {
    return const StonePaymentFailure._(
      code: 'INVALID_AMOUNT',
      message: 'O valor deve estar entre R\$ 0,00 e R\$ 9.999.999,99.',
    );
  }

  factory StonePaymentFailure.invalidInstallmentCount() {
    return const StonePaymentFailure._(
      code: 'INVALID_INSTALLMENT_COUNT',
      message:
          'A quantidade de parcelas deve estar entre ${StonePaymentModel.minInstallmentCount} '
          'e ${StonePaymentModel.maxInstallmentCount}.',
    );
  }

  factory StonePaymentFailure.fromPlatform({
    required String code,
    String? message,
  }) {
    return StonePaymentFailure._(code: code, message: message ?? 'Não foi possível iniciar o pagamento.');
  }

  /// Retorno do app de impressão, como `PRINTER_OUT_OF_PAPER`, com o código e a mensagem do stone_sdk.
  factory StonePaymentFailure.fromPrinter({required String code, String? message}) {
    return StonePaymentFailure._(code: code, message: message ?? 'Erro genérico da impressora.');
  }

  factory StonePaymentFailure.printerUnsupportedFormat() {
    return const StonePaymentFailure._(
      code: 'PRINTER_UNSUPPORTED_FORMAT',
      message: 'Algum formato enviado não corresponde ao padrão de texto, imagem ou texto customizado.',
    );
  }

  factory StonePaymentFailure.printerInvalidData() {
    return const StonePaymentFailure._(
      code: 'PRINTER_INVALID_DATA',
      message: 'Limite máximo do buffer foi ultrapassado.',
    );
  }

  factory StonePaymentFailure.fromResponse(StonePaymentResponse response) {
    return StonePaymentFailure._(
      code: response.code ?? '',
      message: response.message ?? 'Pagamento não aprovado.',
      reason: response.reason,
    );
  }
}
