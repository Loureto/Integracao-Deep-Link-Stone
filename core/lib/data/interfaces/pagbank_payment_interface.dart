import 'package:dependencies/dependencies.dart';

import '../../domain/domain.dart';

/// Integração com os terminais Smart do PagBank pelo PlugPagServiceWrapper. O resultado volta na própria
/// chamada, que só completa quando a operação termina no terminal, e uma operação espera a anterior.
abstract class IPagBankPaymentService {
  /// Mensagens do terminal durante pagamento e estorno, para orientar o cliente.
  Stream<PagBankEvent> get events;

  /// Transação aprovada, ou a falha com a transação negada ou cancelada.
  Future<Either<PagBankFailure, PagBankTransaction>> sendPayment(PagBankPaymentModel data);

  /// Estorno de uma transação aprovada. O terminal pede o cartão de novo.
  Future<Either<PagBankFailure, PagBankTransaction>> voidPayment(PagBankVoidModel data);

  /// Interrompe o pagamento ou o estorno em andamento, que então termina com a própria falha.
  Future<Either<PagBankFailure, Unit>> abort();

  /// Última transação aprovada no terminal, que recupera uma venda quando o app cai no meio dela.
  Future<Either<PagBankFailure, PagBankTransaction>> getLastApprovedTransaction();

  /// Via do cliente da última transação.
  Future<Either<PagBankFailure, Unit>> reprintCustomerReceipt();

  /// Via do estabelecimento da última transação.
  Future<Either<PagBankFailure, Unit>> reprintEstablishmentReceipt();
}
