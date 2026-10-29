import 'package:dependencies/dependencies.dart';

/// Erro do driver genérico de impressão, com os códigos do `NativePrinter` do flutter_acquirers_sdk, como
/// `ERRO_SEM_PAPEL` e `ERRO_DESCONHECIDO`.
class NativePrinterFailure extends Equatable {
  final String code, message;

  const NativePrinterFailure({required this.code, required this.message});

  factory NativePrinterFailure.notSupported() {
    return const NativePrinterFailure(
      code: 'NOT_SUPPORTED',
      message: 'Driver de impressão indisponível nesta plataforma.',
    );
  }

  /// Bytes que não formam uma imagem, com o código e a mensagem que o driver nativo usa nesse caso.
  factory NativePrinterFailure.invalidImage() {
    return const NativePrinterFailure(code: 'ERRO_DESCONHECIDO', message: 'Erro na impressão');
  }

  @override
  List<Object?> get props => [code, message];
}
