import 'package:dependencies/dependencies.dart';

/// Erro da Rede. Os campos são os do `RedeError` do plugin `flutter_rede_sdk`, para o `AcquirerError` do
/// flutter_acquirers_sdk lê-lo sem mudança.
class RedeFailure extends Equatable {
  final String code, message;

  const RedeFailure({required this.code, required this.message});

  /// Estorno sem NSU, com o código e a mensagem do `FlutterAcquirersSdk.refund`.
  factory RedeFailure.nsuNotInformed() {
    return const RedeFailure(
      code: 'nsu.not.informed',
      message: 'O campo: nsu não foi informado! Corrija-o e tente novamente!',
    );
  }

  /// Canal sem o [method] nesta plataforma, com o código que o plugin pretendia devolver.
  factory RedeFailure.notImplemented(String method) {
    return RedeFailure(code: '$method.not.implemented', message: '$method() has not been implemented.');
  }

  /// Sucesso sem resposta do Android, como a fachada do flutter_acquirers_sdk trata hoje.
  factory RedeFailure.unknown() {
    return const RedeFailure(code: 'unknown.error', message: 'Erro desconhecido, tente novamente');
  }

  /// Bytes que não formam imagem, com o código e a mensagem que o Android usa para a impressão que falha.
  factory RedeFailure.invalidImage() {
    return const RedeFailure(code: 'ERRO_DESCONHECIDO', message: 'Erro na impressão');
  }

  @override
  List<Object?> get props => [code, message];
}
