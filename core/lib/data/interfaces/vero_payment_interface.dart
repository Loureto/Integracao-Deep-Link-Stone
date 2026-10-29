import 'package:dependencies/dependencies.dart';

import '../../domain/domain.dart';

/// Pagamentos pelo app da Vero. Os nomes são os do `VeroPayment` do flutter_acquirers_sdk, para a migração para
/// este core não mudar o contrato. O resultado chega quando o app da Vero termina a operação.
abstract class IVeroPaymentService {
  /// Crédito no valor [amount], em reais.
  Future<Either<VeroFailure, VeroTransactionResult>> creditCardPayment(double amount);

  /// Débito no valor [amount], em reais.
  Future<Either<VeroFailure, VeroTransactionResult>> debitCardPayment(double amount);

  /// Pix no valor [amount], em reais.
  Future<Either<VeroFailure, VeroTransactionResult>> pixPayment(double amount);

  /// Pagamento pela carteira Vero no valor [amount], em reais. A Vero o exige na homologação.
  Future<Either<VeroFailure, VeroTransactionResult>> acquirerPayment(double amount);

  /// Estorno do pagamento identificado pelo [nsu].
  Future<Either<VeroFailure, VeroTransactionResult>> refundPayment(String nsu);
}
