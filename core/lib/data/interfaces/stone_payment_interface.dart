import 'package:dependencies/dependencies.dart';

import '../../domain/domain.dart';

abstract class IStonePaymentService {
  /// Retorno do app de Pagamento para cada pagamento aberto com [sendPayment].
  Stream<StonePaymentResponse> get responses;

  /// Sucesso indica que o app de Pagamento foi aberto, não que o pagamento foi
  /// aprovado: o resultado chega em [responses].
  Future<Either<StonePaymentFailure, Unit>> sendPayment(StonePaymentModel data);
}
