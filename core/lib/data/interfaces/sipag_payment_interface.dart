import 'package:dependencies/dependencies.dart';

import '../../domain/domain.dart';

/// Pagamentos da Sipag, no DX8000, na X990 e no P2. Os nomes são os do `SiPagPayment` do flutter_acquirers_sdk,
/// para a migração para este core não mudar o contrato. O resultado chega quando o app da adquirente termina a
/// operação.
abstract class ISiPagPaymentService {
  /// Resultado da operação que o app não chegou a receber, porque caiu enquanto o app da adquirente estava na
  /// frente. Sem operação interrompida, responde `LAST_OPERATION_NOT_FOUND`, que pode ser ignorado.
  Future<Either<SiPagFailure, SiPagTransactionResult>> getLastOperation();

  /// Crédito à vista no valor [amount], em reais.
  Future<Either<SiPagFailure, SiPagTransactionResult>> creditCardPayment(double amount);

  /// Débito no valor [amount], em reais.
  Future<Either<SiPagFailure, SiPagTransactionResult>> debitCardPayment(double amount);

  /// Pix no valor [amount], em reais.
  Future<Either<SiPagFailure, SiPagTransactionResult>> pixPayment(double amount);

  /// Estorno do pagamento identificado pelo [nsu]. O [type] 1 estorna um Pix, e os outros, um cartão, como no
  /// `FlutterAcquirersSdk.refund`; acima de 1, não há estorno.
  Future<Either<SiPagFailure, SiPagTransactionResult>> refundPayment(int type, String nsu);
}
