import 'dart:typed_data';

import 'package:dependencies/dependencies.dart';

import '../../domain/domain.dart';

/// Pagamentos e impressão da Rede. Os nomes são os do `RedeIntegration` do flutter_acquirers_sdk, para a
/// migração para este core não mudar o contrato. O resultado do pagamento chega quando o app da Rede termina a
/// operação.
abstract class IRedePaymentService {
  /// Crédito à vista no valor [amount], em reais.
  Future<Either<RedeFailure, RedeTransactionResult>> creditCardPayment(double amount);

  /// Débito no valor [amount], em reais.
  Future<Either<RedeFailure, RedeTransactionResult>> debitCardPayment(double amount);

  /// Pix no valor [amount], em reais.
  Future<Either<RedeFailure, RedeTransactionResult>> pixPayment(double amount);

  /// Estorno do pagamento identificado pelo [nsu].
  Future<Either<RedeFailure, RedeTransactionResult>> refundPayment(String nsu);

  /// Imprime o [text] pela impressora do SDK da Rede.
  Future<Either<RedeFailure, Unit>> printTxt(String text);

  /// Converte a primeira página da NFC-e em [nfcBase64] numa imagem e a imprime com [printReceipt].
  Future<Either<RedeFailure, Unit>> printNfc(String nfcBase64);

  /// Impressão de teste, com o texto "Impressao teste".
  Future<Either<RedeFailure, Unit>> testPrint();

  /// Imprime a imagem PNG [bitmap], com 1 cm de papel em branco no fim.
  Future<Either<RedeFailure, Unit>> printReceipt({required Uint8List bitmap});
}
