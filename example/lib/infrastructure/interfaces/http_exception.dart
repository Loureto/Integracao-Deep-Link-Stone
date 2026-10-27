import 'package:dependencies/dependencies.dart';

/// Base das exceptions HTTP. [code] é o status da resposta ou, quando não há
/// resposta, um código como `TIMEOUT`. [reason] guarda a causa original, como
/// o corpo da resposta ou a exception do client.
abstract class IHttpException extends Equatable implements Exception {
  final String code;

  final String message;

  final dynamic reason;

  const IHttpException(
    this.code, {
    this.message = '',
    this.reason,
  });

  @override
  List<Object?> get props => [code, message, reason];
}

class BadRequestException extends IHttpException {
  const BadRequestException({String? message, super.reason})
    : super('400', message: message ?? 'Requisição inválida.');
}

class UnauthorizedException extends IHttpException {
  const UnauthorizedException({String? message, super.reason})
    : super('401', message: message ?? 'Não autorizado. Verifique as credenciais.');
}

class ForbiddenException extends IHttpException {
  const ForbiddenException({String? message, super.reason})
    : super('403', message: message ?? 'Acesso negado.');
}

class NotFoundException extends IHttpException {
  const NotFoundException({String? message, super.reason})
    : super('404', message: message ?? 'Recurso não encontrado.');
}

/// Qualquer status 5xx: [code] recebe o status da resposta.
class InternalServerErrorException extends IHttpException {
  const InternalServerErrorException({String code = '500', String? message, super.reason})
    : super(code, message: message ?? 'Erro no servidor. Tente novamente mais tarde.');
}

/// Sem resposta dentro do tempo limite. Não se chama `TimeoutException` para
/// não conflitar com a de `dart:async`.
class RequestTimeoutException extends IHttpException {
  const RequestTimeoutException({String? message, super.reason})
    : super('TIMEOUT', message: message ?? 'O servidor demorou para responder.');
}

class NoConnectionException extends IHttpException {
  const NoConnectionException({String? message, super.reason})
    : super('NO_CONNECTION', message: message ?? 'Sem conexão com a internet.');
}

/// Status sem exception própria, como `422`, ou erro inesperado do client.
class UnknownException extends IHttpException {
  const UnknownException({String code = 'UNKNOWN', String? message, super.reason})
    : super(code, message: message ?? 'Erro inesperado.');
}
