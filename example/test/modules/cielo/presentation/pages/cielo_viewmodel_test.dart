import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';
import 'package:example/presentation/mocks/mocks.dart';
import 'package:example/presentation/presentation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/cielo_responses.dart';
import '../../fakes/fake_cielo_service.dart';

void main() {
  late FakeCieloService service;
  late CieloViewModel viewModel;

  setUp(() {
    service = FakeCieloService();
    viewModel = CieloViewModel(service);
  });

  tearDown(() => viewModel.onDispose());

  Future<void> receive(CieloAction action, Object? data) async {
    service.responsesController.add(cieloResponse(action, data));
    await Future<void>.delayed(Duration.zero);
  }

  test('aguarda o retorno depois de abrir o app da Cielo', () async {
    await viewModel.sendPayment(CieloPaymentsMock.all.first.request);

    expect(service.requests.single.$1, CieloAction.payment);
    expect(viewModel.state.status, CieloStatus.loading);
    expect(viewModel.state.message, 'Aguardando o retorno do app da Cielo...');
  });

  test('exibe a falha quando o app da Cielo não abre', () async {
    service.result = left(CieloFailure.missingCredentials());

    await viewModel.sendPayment(CieloPaymentsMock.all.first.request);

    expect(viewModel.state.status, CieloStatus.error);
    expect(viewModel.state.message, CieloFailure.missingCredentials().message);
  });

  test('pagamento aprovado libera o cancelamento, que some depois de concluído', () async {
    await viewModel.sendPayment(CieloPaymentsMock.all.first.request);
    await receive(CieloAction.payment, paidCieloOrder);

    expect(viewModel.state.status, CieloStatus.success);
    expect(viewModel.state.message, 'Pagamento aprovado.');

    await viewModel.cancelLastPayment();

    final cancel = service.requests.last.$2 as CieloCancelModel;
    expect(CieloCancelModel.toMap(cancel), {
      'id': 'pedido-1',
      'cieloCode': '910792',
      'authCode': '142941',
      'value': 3620,
    });

    await receive(CieloAction.paymentReversal, cancelledCieloOrder);

    expect(viewModel.state.message, 'Pagamento cancelado.');
    expect(viewModel.state.cancelRequest, isNull);
  });

  test('erro da Cielo exibe o motivo e mantém o último pedido', () async {
    await receive(CieloAction.payment, paidCieloOrder);
    await viewModel.sendPayment(CieloPaymentsMock.all.first.request);
    await receive(CieloAction.payment, {'code': 1, 'reason': 'CANCELADO PELO USUÁRIO'});

    expect(viewModel.state.status, CieloStatus.error);
    expect(viewModel.state.message, 'CANCELADO PELO USUÁRIO');
    expect(viewModel.state.lastOrder?.id, 'pedido-1');
  });

  test('consulta o último pedido pelo id', () async {
    await receive(CieloAction.payment, paidCieloOrder);

    await viewModel.findLastOrder();

    final query = service.requests.single.$2 as CieloOrderQueryModel;
    expect(query.orderId, 'pedido-1');
  });

  test('sem pedido, cancelar e consultar não abrem o app da Cielo', () async {
    await viewModel.cancelLastPayment();
    await viewModel.findLastOrder();

    expect(service.requests, isEmpty);
  });

  test('impressão e consultas abrem a ação correspondente', () async {
    await viewModel.printText(CieloPrintsMock.all.first.request);
    await viewModel.listOrders();
    await viewModel.listEnabledProducts();
    await viewModel.listEstablishments();
    await viewModel.getTerminalInfo();

    expect(service.requests.map((request) => request.$1), [
      CieloAction.print,
      CieloAction.orders,
      CieloAction.enabledProducts,
      CieloAction.establishments,
      CieloAction.terminalInfo,
    ]);
  });

  test('reset volta ao estado inicial e mantém o último pedido', () async {
    await receive(CieloAction.payment, paidCieloOrder);
    await viewModel.sendPayment(CieloPaymentsMock.all.first.request);

    viewModel.reset();

    expect(viewModel.state.status, CieloStatus.idle);
    expect(viewModel.state.response, isNull);
    expect(viewModel.state.cancelRequest, isNotNull);
  });
}
