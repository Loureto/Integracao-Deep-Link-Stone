import 'dart:async';

import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';
import 'package:example/presentation/mocks/mocks.dart';
import 'package:example/presentation/presentation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_native_printer_service.dart';
import '../../fakes/fake_vero_payment_service.dart';

void main() {
  late FakeVeroPaymentService payments;
  late FakeNativePrinterService printer;
  late VeroViewModel viewModel;

  setUp(() {
    payments = FakeVeroPaymentService();
    printer = FakeNativePrinterService();
    viewModel = VeroViewModel(payments, printer);
  });

  tearDown(() => viewModel.onDispose());

  test('cada tipo de pagamento chama o método do serviço e mostra o aprovado', () async {
    for (final (type, method) in [
      (VeroPaymentType.credit, 'creditCardPayment'),
      (VeroPaymentType.debit, 'debitCardPayment'),
      (VeroPaymentType.pix, 'pixPayment'),
      (VeroPaymentType.wallet, 'acquirerPayment'),
    ]) {
      await viewModel.pay(type, 1.5);

      expect(payments.calls.last, (method, 1.5), reason: '$type');
      expect(viewModel.state.status, VeroPageStatus.success);
      expect(viewModel.state.message, 'Pagamento aprovado.');
      expect(viewModel.state.transaction?.authorization, 'A1');
      expect(viewModel.state.lastPayment?.nsu, '123');
    }
  });

  test('fica processando até o app da Vero responder', () async {
    payments.pending = Completer<void>();

    final paying = viewModel.pay(VeroPaymentType.credit, 1);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.state.status, VeroPageStatus.loading);
    expect(viewModel.state.message, 'Processando o pagamento no app da Vero...');

    payments.pending!.complete();
    await paying;

    expect(viewModel.state.status, VeroPageStatus.success);
  });

  test('mostra a falha do app da Vero', () async {
    payments.result = left(
      const VeroFailure(code: 'ERRO_DESCONHECIDO', message: 'Operação cancelada pelo usuário!'),
    );

    await viewModel.pay(VeroPaymentType.debit, 1);

    expect(viewModel.state.status, VeroPageStatus.error);
    expect(viewModel.state.message, 'Operação cancelada pelo usuário!');
    expect(viewModel.state.lastPayment, isNull);
  });

  test('estorna o último pagamento pelo NSU e deixa de oferecer o estorno', () async {
    await viewModel.pay(VeroPaymentType.credit, 1);

    await viewModel.refundLastPayment();

    expect(payments.calls.last, ('refundPayment', '123'));
    expect(viewModel.state.status, VeroPageStatus.success);
    expect(viewModel.state.message, 'Pagamento estornado.');
    expect(viewModel.state.lastPayment, isNull);
  });

  test('sem pagamento aprovado o estorno não chama o serviço', () async {
    await viewModel.refundLastPayment();

    expect(payments.calls, isEmpty);
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
    expect(viewModel.state.status, VeroPageStatus.success);
  });

  test('a falha da impressão aparece e o último pagamento continua estornável', () async {
    await viewModel.pay(VeroPaymentType.credit, 1);
    printer.result = left(
      const NativePrinterFailure(code: 'ERRO_SEM_PAPEL', message: 'Impressora sem papel, verifique!'),
    );

    await viewModel.testPrint();

    expect(viewModel.state.status, VeroPageStatus.error);
    expect(viewModel.state.message, 'Impressora sem papel, verifique!');
    expect(viewModel.state.lastPayment?.nsu, '123');
  });
}
