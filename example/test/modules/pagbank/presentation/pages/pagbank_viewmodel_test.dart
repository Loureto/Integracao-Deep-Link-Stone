import 'dart:async';

import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';
import 'package:example/presentation/mocks/mocks.dart';
import 'package:example/presentation/presentation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_pagbank_service.dart';

void main() {
  late FakePagBankService service;
  late PagBankViewModel viewModel;

  setUp(() {
    service = FakePagBankService();
    viewModel = PagBankViewModel(service);
  });

  tearDown(() => viewModel.onDispose());

  final declined = PagBankFailure.fromTransaction(
    const PagBankTransaction({'result': -1, 'errorCode': 'R 51', 'message': 'SALDO INSUFICIENTE'}),
  );

  Future<void> receive(PagBankEvent event) async {
    service.eventsController.add(event);
    await Future<void>.delayed(Duration.zero);
  }

  test('pagamento aprovado exibe a transação e a guarda para o estorno', () async {
    await viewModel.sendPayment(PagBankPaymentsMock.all.first.request);

    expect((service.calls.single.$2 as PagBankPaymentModel).type, PagBankPaymentType.debit);
    expect(viewModel.state.status, PagBankStatus.success);
    expect(viewModel.state.message, 'Pagamento aprovado.');
    expect(viewModel.state.transaction?.transactionCode, 'TC1');
    expect(viewModel.state.voidRequest?.transactionId, 'TID1');
    expect(viewModel.state.voidRequest?.printReceipt, isTrue);
  });

  test('pagamento negado exibe a mensagem do terminal e mantém o último pagamento aprovado', () async {
    await viewModel.sendPayment(PagBankPaymentsMock.all.first.request);
    service.transactionResult = left(declined);

    await viewModel.sendPayment(PagBankPaymentsMock.all.first.request);

    expect(viewModel.state.status, PagBankStatus.error);
    expect(viewModel.state.message, 'SALDO INSUFICIENTE');
    expect(viewModel.state.transaction?.errorCode, 'R 51');
    expect(viewModel.state.lastPayment?.transactionCode, 'TC1');
  });

  test('exibe as mensagens do terminal durante a operação e mascara a senha', () async {
    service.pending = Completer();

    final payment = viewModel.sendPayment(PagBankPaymentsMock.all.first.request);
    expect(viewModel.state.message, 'Processando o pagamento no terminal...');

    await receive(const PagBankEvent(code: 0, message: 'APROXIME, INSIRA OU PASSE O CARTAO'));
    expect(viewModel.state.message, 'APROXIME, INSIRA OU PASSE O CARTAO');

    await receive(const PagBankEvent(code: PagBankEvent.noPasswordCode));
    await receive(const PagBankEvent(code: PagBankEvent.digitPasswordCode));
    await receive(const PagBankEvent(code: PagBankEvent.digitPasswordCode));
    expect(viewModel.state.message, 'Digite a senha\n**');

    service.pending!.complete(right(approvedPagBankTransaction));
    await payment;

    await receive(const PagBankEvent(code: 0, message: 'RETIRE O CARTAO'));
    expect(viewModel.state.message, 'Pagamento aprovado.', reason: 'eventos fora de operação são ignorados');
  });

  test('abort só chama o terminal com uma operação em andamento', () async {
    await viewModel.abort();
    expect(service.calls, isEmpty);

    service.pending = Completer();
    final payment = viewModel.sendPayment(PagBankPaymentsMock.all.first.request);
    await viewModel.abort();

    expect(service.calls.map((call) => call.$1), ['doPayment', 'abort']);

    service.pending!.complete(
      left(PagBankFailure.fromTransaction(const PagBankTransaction({'result': -1028}))),
    );
    await payment;
    expect(viewModel.state.status, PagBankStatus.error);
  });

  test('estorna o último pagamento aprovado e o tira do estado', () async {
    await viewModel.voidLastPayment();
    expect(service.calls, isEmpty, reason: 'sem pagamento aprovado não há o que estornar');

    await viewModel.sendPayment(PagBankPaymentsMock.all.first.request);
    await viewModel.voidLastPayment();

    final request = service.calls.last.$2 as PagBankVoidModel;
    expect(request.transactionCode, 'TC1');
    expect(request.voidType, PagBankVoidType.payment);
    expect(viewModel.state.message, 'Pagamento estornado.');
    expect(viewModel.state.voidRequest, isNull);
  });

  test('a última transação aprovada consultada pode ser estornada', () async {
    await viewModel.loadLastApprovedTransaction();

    expect(viewModel.state.message, 'Última transação aprovada carregada.');
    expect(viewModel.state.voidRequest?.transactionCode, 'TC1');
  });

  test('reimpressão exibe o resultado do terminal', () async {
    await viewModel.reprintCustomerReceipt();
    expect(viewModel.state.message, 'Via do cliente reimpressa.');

    service.unitResult = left(PagBankFailure.fromPrint(code: 'P05', message: 'SEM PAPEL'));
    await viewModel.reprintEstablishmentReceipt();

    expect(viewModel.state.status, PagBankStatus.error);
    expect(viewModel.state.message, 'SEM PAPEL');
  });
}
