import '../models/models.dart';

class CieloFailure {
  final String code;
  final String message;

  const CieloFailure._({this.code = '', this.message = ''});

  factory CieloFailure.notStarted() {
    return const CieloFailure._(
      code: 'NOT_STARTED',
      message: 'O app da Cielo não foi aberto.',
    );
  }

  factory CieloFailure.notSupported() {
    return const CieloFailure._(
      code: 'NOT_SUPPORTED',
      message: 'Integração Cielo indisponível nesta plataforma.',
    );
  }

  factory CieloFailure.missingCredentials() {
    return const CieloFailure._(
      code: 'MISSING_CREDENTIALS',
      message: 'Credenciais da Cielo ausentes: informe CLIENT_ID e ACCESS_TOKEN com --dart-define-from-file.',
    );
  }

  factory CieloFailure.invalidValue() {
    return const CieloFailure._(
      code: 'INVALID_VALUE',
      message: 'Informe ao menos um item, com quantidade maior que zero, e um valor total maior que zero.',
    );
  }

  factory CieloFailure.invalidInstallments() {
    return const CieloFailure._(
      code: 'INVALID_INSTALLMENTS',
      message: 'O número de parcelas não pode ser negativo.',
    );
  }

  factory CieloFailure.invalidCancel() {
    return const CieloFailure._(
      code: 'INVALID_CANCEL',
      message: 'Informe o pedido, o NSU (cieloCode), o código de autorização e o valor a cancelar.',
    );
  }

  factory CieloFailure.invalidPrint() {
    return const CieloFailure._(
      code: 'INVALID_PRINT',
      message: 'Informe o texto a imprimir e, se usar estilos, um estilo para cada texto.',
    );
  }

  factory CieloFailure.invalidOrderQuery() {
    return const CieloFailure._(
      code: 'INVALID_ORDER_QUERY',
      message:
          'Informe o id do pedido e, para buscar pelo pagamento, o valor, o NSU e o código de autorização.',
    );
  }

  factory CieloFailure.invalidOrderList() {
    return const CieloFailure._(
      code: 'INVALID_ORDER_LIST',
      message:
          'A página começa em 0 e a quantidade de pedidos por página deve estar entre 1 '
          'e ${CieloOrderListModel.maxPageSize}.',
    );
  }

  factory CieloFailure.fromPlatform({
    required String code,
    String? message,
  }) {
    return CieloFailure._(code: code, message: message ?? 'Não foi possível abrir o app da Cielo.');
  }

  factory CieloFailure.fromResponse(CieloResponse response) {
    if (response.data == null) {
      return const CieloFailure._(
        code: 'INVALID_RESPONSE',
        message: 'O app da Cielo respondeu sem dados válidos.',
      );
    }

    return CieloFailure._(
      code: response.code?.toString() ?? '',
      message: response.message ?? 'A Cielo não concluiu a operação.',
    );
  }
}
