import 'dart:async';

import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';
import 'package:example/presentation/mocks/mocks.dart';
import 'package:example/presentation/presentation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_rede_payment_service.dart';

void main() {
  late FakeRedePaymentService service;
  late RedeViewModel viewModel;

  setUp(() {
    service = FakeRedePaymentService();
    viewModel = RedeViewModel(service);
  });

  tearDown(() => viewModel.onDispose());

  test('cada tipo de pagamento chama o método do serviço e mostra o aprovado', () async {
    for (final (type, method) in [
      (RedePaymentType.credit, 'creditCardPayment'),
      (RedePaymentType.debit, 'debitCardPayment'),
      (RedePaymentType.pix, 'pixPayment'),
    ]) {
      await viewModel.pay(type, 1.5);

      expect(service.calls.last, (method, 1.5), reason: '$type');
      expect(viewModel.state.status, RedePageStatus.success);
      expect(viewModel.state.message, 'Pagamento aprovado.');
      expect(viewModel.state.transaction?.authorization, 'A1');
      expect(viewModel.state.lastPayment?.nsu, '123');
    }
  });

  test('fica processando até o app da Rede responder', () async {
    service.pending = Completer<void>();

    final paying = viewModel.pay(RedePaymentType.credit, 1);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.state.status, RedePageStatus.loading);
    expect(viewModel.state.message, 'Processando o pagamento no app da Rede...');

    service.pending!.complete();
    await paying;

    expect(viewModel.state.status, RedePageStatus.success);
  });

  test('mostra a falha do app da Rede', () async {
    service.result = left(const RedeFailure(code: 'OPERATION_CANCELED', message: 'Operação cancelada!'));

    await viewModel.pay(RedePaymentType.debit, 1);

    expect(viewModel.state.status, RedePageStatus.error);
    expect(viewModel.state.message, 'Operação cancelada!');
    expect(viewModel.state.lastPayment, isNull);
  });

  test('estorna o último pagamento pelo NSU e deixa de oferecer o estorno', () async {
    await viewModel.pay(RedePaymentType.credit, 1);

    await viewModel.refundLastPayment();

    expect(service.calls.last, ('refundPayment', '123'));
    expect(viewModel.state.status, RedePageStatus.success);
    expect(viewModel.state.message, 'Pagamento estornado.');
    expect(viewModel.state.lastPayment, isNull);
  });

  test('sem pagamento aprovado o estorno não chama o serviço', () async {
    await viewModel.refundLastPayment();

    expect(service.calls, isEmpty);
  });

  test('as impressões chamam a impressora da Rede e mostram o resultado', () async {
    await viewModel.printNfc(NfceMock.pdf);
    expect(service.calls.last, ('printNfc', NfceMock.pdf));
    expect(viewModel.state.message, 'NFC-e impressa.');

    await viewModel.printTxt(NfceMock.text);
    expect(service.calls.last, ('printTxt', NfceMock.text));
    expect(viewModel.state.message, 'Texto impresso.');

    await viewModel.testPrint();
    expect(service.calls.last, ('testPrint', null));
    expect(viewModel.state.message, 'Impressão de teste concluída.');
    expect(viewModel.state.status, RedePageStatus.success);
  });

  test('a falha da impressão aparece e o último pagamento continua estornável', () async {
    await viewModel.pay(RedePaymentType.credit, 1);
    service.printResult = left(
      const RedeFailure(code: 'ERRO_SEM_PAPEL', message: 'Impressora sem papel, verifique!'),
    );

    await viewModel.testPrint();

    expect(viewModel.state.status, RedePageStatus.error);
    expect(viewModel.state.message, 'Impressora sem papel, verifique!');
    expect(viewModel.state.lastPayment?.nsu, '123');
  });
}
