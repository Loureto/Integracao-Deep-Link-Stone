import 'package:dependencies/dependencies.dart';

/// Erro da Vero. Classe e campos têm os nomes do `VeroError` do plugin `vero_flutter`, para o
/// `AcquirerError.fromVeroError` do flutter_acquirers_sdk lê-lo sem mudança.
class VeroFailure extends Equatable {
  final String code, message;

  const VeroFailure({required this.code, required this.message});

  /// Estorno sem NSU, com o código e a mensagem do `FlutterAcquirersSdk.refund`.
  factory VeroFailure.nsuNotInformed() {
    return const VeroFailure(
      code: 'nsu.not.informed',
      message: 'O campo: nsu não foi informado! Corrija-o e tente novamente!',
    );
  }

  /// Canal sem o [method] nesta plataforma, com o código que o plugin pretendia devolver.
  factory VeroFailure.notImplemented(String method) {
    return VeroFailure(code: '$method.not.implemented', message: '$method() has not been implemented.');
  }

  /// Sucesso sem resposta do app da Vero, como a fachada do flutter_acquirers_sdk trata hoje.
  factory VeroFailure.unknown() {
    return const VeroFailure(code: 'unknown.error', message: 'Erro desconhecido, tente novamente');
  }

  @override
  List<Object?> get props => [code, message];
}
