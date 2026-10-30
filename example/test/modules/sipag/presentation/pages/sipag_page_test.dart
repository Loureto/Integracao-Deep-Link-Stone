import 'dart:async';

import 'package:dependencies/dependencies.dart';
import 'package:example/presentation/mocks/mocks.dart';
import 'package:example/presentation/presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../vero/fakes/fake_native_printer_service.dart';
import '../../fakes/fake_sipag_payment_service.dart';

void main() {
  late FakeSiPagPaymentService payments;
  late FakeNativePrinterService printer;

  setUp(() {
    payments = FakeSiPagPaymentService();
    printer = FakeNativePrinterService();
    GetIt.instance.registerFactory<SipagViewModel>(() => SipagViewModel(payments, printer));
  });

  tearDown(() => GetIt.instance.reset());

  Finder button(String label) => find.widgetWithText(FilledButton, label);

  /// Tela alta o bastante para a lista inteira, com a impressão no fim.
  Future<void> pumpWholePage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: SipagPage()));
  }

  testWidgets('paga com o mock escolhido, mostra a transação e libera o estorno', (tester) async {
    await pumpWholePage(tester);

    for (final payment in SipagPaymentsMock.all) {
      expect(find.text(payment.label), findsOneWidget);
    }
    expect(tester.widget<FilledButton>(button('Estornar o último pagamento')).onPressed, isNull);

    await tester.tap(find.text('Crédito • R\$ 1,00'));
    await tester.pumpAndSettle();

    expect(payments.calls.single, ('creditCardPayment', 1.0));
    expect(find.text('Pagamento aprovado.'), findsOneWidget);
    expect(find.text('NSU: 123'), findsOneWidget);
    expect(tester.widget<FilledButton>(button('Estornar o último pagamento')).onPressed, isNotNull);
  });

  testWidgets('busca a última operação', (tester) async {
    await pumpWholePage(tester);

    await tester.tap(find.text('Buscar a última operação'));
    await tester.pumpAndSettle();

    expect(payments.calls.single, ('getLastOperation', null));
    expect(find.text('Última operação recuperada.'), findsOneWidget);
  });

  testWidgets('durante a operação, os botões ficam desabilitados', (tester) async {
    payments.pending = Completer<void>();
    await pumpWholePage(tester);

    await tester.tap(find.text('Pix • R\$ 1,00'));
    await tester.pump();

    for (final label in ['Crédito • R\$ 1,00', 'Buscar a última operação', 'Impressão de teste']) {
      expect(tester.widget<FilledButton>(button(label)).onPressed, isNull, reason: label);
    }

    payments.pending!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('as impressões usam as NFC-e e o texto de teste', (tester) async {
    await pumpWholePage(tester);

    for (final (label, call) in [
      ('Imprimir a NFC-e de teste', ('printNfc', NfceMock.pdf)),
      ('Imprimir a NFC-e de homologação', ('printNfc', NfceHomologacaoMock.pdf)),
      ('Imprimir o texto de teste', ('printTxt', NfceMock.text)),
      ('Impressão de teste', ('testPrint', null)),
    ]) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(printer.calls.last, call, reason: label);
    }
  });
}
