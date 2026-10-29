import 'dart:typed_data';

import 'package:dependencies/dependencies.dart';

import '../../domain/domain.dart';

/// Os nomes da impressão seguem o `StoneIntegration` e o stone_sdk do flutter_acquirers_sdk, para a migração
/// para este core não mudar o contrato.
abstract class IStonePaymentService {
  /// Retorno do app de Pagamento para cada pagamento aberto com [sendPayment].
  Stream<StonePaymentResponse> get responses;

  /// Sucesso indica que o app de Pagamento foi aberto, não que o pagamento foi
  /// aprovado: o resultado chega em [responses].
  Future<Either<StonePaymentFailure, Unit>> sendPayment(StonePaymentModel data);

  /// Converte a primeira página da NFC-e em [nfcBase64] numa imagem e a imprime com [printReceipt].
  Future<Either<StonePaymentFailure, Unit>> printNfc(String nfcBase64);

  /// Imprime a imagem PNG [bitmap] pelo deeplink de impressão da Stone. O resultado chega quando o app de
  /// impressão termina.
  Future<Either<StonePaymentFailure, Unit>> printReceipt({required Uint8List bitmap});
}
