class PdfImageFailure {
  final String code;
  final String message;

  const PdfImageFailure._({required this.code, required this.message});

  factory PdfImageFailure.invalidBase64() {
    return const PdfImageFailure._(
      code: 'INVALID_BASE64',
      message: 'Informe o PDF em base64.',
    );
  }

  /// [message] é a mensagem do renderizador, quando ele a envia.
  factory PdfImageFailure.invalidPdf([String? message]) {
    return PdfImageFailure._(
      code: 'INVALID_PDF',
      message: message ?? 'Não foi possível abrir o PDF.',
    );
  }

  factory PdfImageFailure.renderFailed() {
    return const PdfImageFailure._(
      code: 'RENDER_FAILED',
      message: 'Não foi possível converter o PDF em imagem.',
    );
  }
}
