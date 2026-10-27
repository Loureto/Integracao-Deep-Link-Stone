import 'package:dependencies/dependencies.dart';

import '../../domain/domain.dart';

/// Integração com a Cielo Smart pelo deep link `lio://`. Em todos os métodos, o sucesso indica que o app da
/// Cielo foi aberto, não que a operação foi concluída: o resultado chega em [responses].
abstract class ICieloPaymentService {
  /// Retorno do app da Cielo para cada operação aberta pelos métodos abaixo.
  Stream<CieloResponse> get responses;

  Future<Either<CieloFailure, Unit>> sendPayment(CieloPaymentModel data);

  Future<Either<CieloFailure, Unit>> cancelPayment(CieloCancelModel data);

  Future<Either<CieloFailure, Unit>> printText(CieloPrintModel data);

  /// Pedidos abertos na Cielo Smart pelo app, em páginas de no máximo
  /// [CieloOrderListModel.maxPageSize].
  Future<Either<CieloFailure, Unit>> listOrders([CieloOrderListModel data = const CieloOrderListModel()]);

  Future<Either<CieloFailure, Unit>> findOrder(CieloOrderQueryModel data);

  /// Valores de `paymentCode` habilitados para o estabelecimento.
  Future<Either<CieloFailure, Unit>> listEnabledProducts();

  /// Estabelecimentos (ECs) disponíveis no terminal, para pagamentos MULTI-EC.
  Future<Either<CieloFailure, Unit>> listEstablishments();

  /// Bateria, modelo, número lógico, número de série e IMEI do terminal.
  Future<Either<CieloFailure, Unit>> getTerminalInfo();
}
