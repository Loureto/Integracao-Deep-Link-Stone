import 'package:dependencies/dependencies.dart';

/// Erro da Sipag. Os campos são os do `SiPagError` do plugin `flutter_sipag_sdk`, para o `AcquirerError` do
/// flutter_acquirers_sdk lê-lo sem mudança.
class SiPagFailure extends Equatable {
  final String code, message;

  const SiPagFailure({required this.code, required this.message});

  /// Estorno sem NSU, com o código e a mensagem do `FlutterAcquirersSdk.refund`.
  factory SiPagFailure.nsuNotInformed() {
    return const SiPagFailure(
      code: 'nsu.not.informed',
      message: 'O campo: nsu não foi informado! Corrija-o e tente novamente!',
    );
  }

  /// Estorno com tipo maior que 1 (Pix), com o código e a mensagem do `PaymentService` do flutter_acquirers_sdk.
  factory SiPagFailure.invalidRefundType() {
    return const SiPagFailure(code: 'type.is.invalid', message: 'Função de estorno não encontrada!');
  }

  /// Canal sem o [method] nesta plataforma, com o código que o plugin pretendia devolver.
  factory SiPagFailure.notImplemented(String method) {
    return SiPagFailure(code: '$method.not.implemented', message: '$method() has not been implemented.');
  }

  /// Sucesso sem resposta do Android, como a fachada do flutter_acquirers_sdk trata hoje.
  factory SiPagFailure.unknown() {
    return const SiPagFailure(code: 'unknown.error', message: 'Erro desconhecido, tente novamente');
  }

  @override
  List<Object?> get props => [code, message];
}
