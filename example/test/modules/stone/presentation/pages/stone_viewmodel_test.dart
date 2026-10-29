import 'dart:async';

import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';
import 'package:example/presentation/mocks/mocks.dart';
import 'package:example/presentation/presentation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_stone_payment_service.dart';

void main() {
  late FakeStonePaymentService service;
  late StoneViewModel viewModel;

  setUp(() {
    service = FakeStonePaymentService();
    viewModel = StoneViewModel(service);
  });

  tearDown(() => viewModel.onDispose());

  Future<void> receive(Map<String, String?> data) async {
    service.responsesController.add(StonePaymentResponse(data));
    await Future<void>.delayed(Duration.zero);
  }

  test('aguarda o retorno depois de abrir o app de pagamento', () async {
    await viewModel.sendPayment(StonePaymentsMock.all.first.request);

    expect(service.requests.single.transactionType, StoneTransactionType.debit);
    expect(viewModel.state.status, StoneStatus.loading);
    expect(viewModel.state.message, 'Aguardando o retorno do app de pagamento...');
  });

  test('exibe a falha quando o app de pagamento não abre', () async {
    service.result = left(
      StonePaymentFailure.fromPlatform(
        code: 'PAYMENT_APP_NOT_FOUND',
        message: 'Nenhum aplicativo disponível para processar o pagamento.',
      ),
    );

    await viewModel.sendPayment(const StonePaymentModel());

    expect(viewModel.state.status, StoneStatus.error);
    expect(viewModel.state.message, 'Nenhum aplicativo disponível para processar o pagamento.');
  });

  test('somente code 0 é tratado como pagamento aprovado', () async {
    await viewModel.sendPayment(const StonePaymentModel());

    await receive({'code': '0', 'atk': '37820073187607'});
    expect(viewModel.state.status, StoneStatus.success);
    expect(viewModel.state.response?.data['atk'], '37820073187607');

    await receive({'code': '-6', 'reason': '1016', 'message': 'Não autorizada'});
    expect(viewModel.state.status, StoneStatus.error);
    expect(viewModel.state.message, 'Não autorizada');

    await receive({'code': '2'});
    expect(viewModel.state.message, 'Pagamento não aprovado.');
  });

  test('reset volta ao estado inicial quando não há retorno', () async {
    await viewModel.sendPayment(const StonePaymentModel());

    viewModel.reset();

    expect(viewModel.state.status, StoneStatus.idle);
    expect(viewModel.state.response, isNull);
  });

  test('fica imprimindo até o app de impressão responder e então exibe o sucesso', () async {
    service.printing = Completer<void>();

    final printing = viewModel.printNfc(NfceHomologacaoMock.pdf);
    await Future<void>.delayed(Duration.zero);

    expect(service.nfcs.single, NfceHomologacaoMock.pdf);
    expect(viewModel.state.status, StoneStatus.loading);
    expect(viewModel.state.message, 'Imprimindo a NFC-e...');

    service.printing!.complete();
    await printing;

    expect(viewModel.state.status, StoneStatus.success);
    expect(viewModel.state.message, 'NFC-e impressa.');
  });

  test('exibe a falha da impressão', () async {
    service.printResult = left(
      StonePaymentFailure.fromPrinter(
        code: 'PRINTER_OUT_OF_PAPER',
        message: 'Impressora sem papel ou com a tampa de bobina aberta.',
      ),
    );

    await viewModel.printNfc(NfceMock.pdf);

    expect(viewModel.state.status, StoneStatus.error);
    expect(viewModel.state.message, 'Impressora sem papel ou com a tampa de bobina aberta.');
  });
}
