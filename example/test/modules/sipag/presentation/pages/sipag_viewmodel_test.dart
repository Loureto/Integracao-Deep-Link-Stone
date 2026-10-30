import 'dart:async';

import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';
import 'package:example/presentation/mocks/mocks.dart';
import 'package:example/presentation/presentation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../vero/fakes/fake_native_printer_service.dart';
import '../../fakes/fake_sipag_payment_service.dart';

void main() {
  late FakeSiPagPaymentService payments;
  late FakeNativePrinterService printer;
  late SipagViewModel viewModel;

  setUp(() {
    payments = FakeSiPagPaymentService();
    printer = FakeNativePrinterService();
    viewModel = SipagViewModel(payments, printer);
  });

  tearDown(() => viewModel.onDispose());

  test('cada tipo de pagamento chama o método do serviço e guarda o pagamento e o tipo', () async {
    for (final (type, method) in [
      (SipagPaymentType.credit, 'creditCardPayment'),
      (SipagPaymentType.debit, 'debitCardPayment'),
      (SipagPaymentType.pix, 'pixPayment'),
    ]) {
      await viewModel.pay(type, 1.5);

      expect(payments.calls.last, (method, 1.5), reason: '$type');
      expect(viewModel.state.status, SipagPageStatus.success);
      expect(viewModel.state.message, 'Pagamento aprovado.');
      expect(viewModel.state.transaction?.authorization, 'A1');
      expect(viewModel.state.lastPayment?.nsu, '123');
      expect(viewModel.state.lastPaymentType, type);
    }
  });

  test('fica processando até o app da adquirente responder', () async {
    payments.pending = Completer<void>();

    final paying = viewModel.pay(SipagPaymentType.credit, 1);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.state.status, SipagPageStatus.loading);
    expect(viewModel.state.message, 'Processando o pagamento no app da Sipag...');

    payments.pending!.complete();
    await paying;

    expect(viewModel.state.status, SipagPageStatus.success);
  });

  test('mostra a falha do app da adquirente', () async {
    payments.result = left(const SiPagFailure(code: 'LICENCA_INVALIDA', message: 'Licença expirada.'));

    await viewModel.pay(SipagPaymentType.debit, 1);

    expect(viewModel.state.status, SipagPageStatus.error);
    expect(viewModel.state.message, 'Licença expirada.');
    expect(viewModel.state.lastPayment, isNull);
  });

  test('estorna o último Pix com type 1 e o último cartão com type 0', () async {
    for (final (type, refundType) in [(SipagPaymentType.pix, 1), (SipagPaymentType.credit, 0)]) {
      await viewModel.pay(type, 1);

      await viewModel.refundLastPayment();

      expect(payments.calls.last, ('refundPayment', (refundType, '123')), reason: '$type');
      expect(viewModel.state.status, SipagPageStatus.success);
      expect(viewModel.state.message, 'Pagamento estornado.');
      expect(viewModel.state.lastPayment, isNull);
    }
  });

  test('sem pagamento aprovado o estorno não chama o serviço', () async {
    await viewModel.refundLastPayment();

    expect(payments.calls, isEmpty);
  });

  test('a última operação recuperada aparece com a transação', () async {
    await viewModel.getLastOperation();

    expect(payments.calls.single, ('getLastOperation', null));
    expect(viewModel.state.status, SipagPageStatus.success);
    expect(viewModel.state.message, 'Última operação recuperada.');
    expect(viewModel.state.transaction?.nsu, '123');
  });

  test('sem operação interrompida, a última operação mostra a mensagem como sucesso', () async {
    payments.result = left(
      const SiPagFailure(
        code: 'LAST_OPERATION_NOT_FOUND',
        message: 'Não foi encontrado nenhuma operação no histórico!',
      ),
    );

    await viewModel.getLastOperation();

    expect(viewModel.state.status, SipagPageStatus.success);
    expect(viewModel.state.message, 'Não foi encontrado nenhuma operação no histórico!');
  });

  test('outra falha da última operação aparece como erro', () async {
    payments.result = left(
      const SiPagFailure(
        code: 'FILE_DOES_NOT_EXIST',
        message: 'Não foi possível recuperar a última operação!',
      ),
    );

    await viewModel.getLastOperation();

    expect(viewModel.state.status, SipagPageStatus.error);
    expect(viewModel.state.message, 'Não foi possível recuperar a última operação!');
  });

  test('as impressões chamam o driver e mostram o resultado', () async {
    await viewModel.printNfc(NfceMock.pdf);
    expect(printer.calls.last, ('printNfc', NfceMock.pdf));
    expect(viewModel.state.message, 'NFC-e impressa.');

    await viewModel.printTxt(NfceMock.text);
    expect(printer.calls.last, ('printTxt', NfceMock.text));
    expect(viewModel.state.message, 'Texto impresso.');

    await viewModel.testPrint();
    expect(printer.calls.last, ('testPrint', null));
    expect(viewModel.state.message, 'Impressão de teste concluída.');
    expect(viewModel.state.status, SipagPageStatus.success);
  });

  test('a falha da impressão aparece e o último pagamento continua estornável', () async {
    await viewModel.pay(SipagPaymentType.pix, 1);
    printer.result = left(
      const NativePrinterFailure(code: 'ERRO_SEM_PAPEL', message: 'Impressora sem papel, verifique!'),
    );

    await viewModel.testPrint();

    expect(viewModel.state.status, SipagPageStatus.error);
    expect(viewModel.state.message, 'Impressora sem papel, verifique!');
    expect(viewModel.state.lastPayment?.nsu, '123');
    expect(viewModel.state.lastPaymentType, SipagPaymentType.pix);
  });
}
