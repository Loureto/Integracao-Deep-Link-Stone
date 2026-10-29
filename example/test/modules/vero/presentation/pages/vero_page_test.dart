import 'package:dependencies/dependencies.dart';
import 'package:example/presentation/mocks/mocks.dart';
import 'package:example/presentation/presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_native_printer_service.dart';
import '../../fakes/fake_vero_payment_service.dart';

void main() {
  late FakeVeroPaymentService payments;
  late FakeNativePrinterService printer;

  setUp(() {
    payments = FakeVeroPaymentService();
    printer = FakeNativePrinterService();
    GetIt.instance.registerFactory<VeroViewModel>(() => VeroViewModel(payments, printer));
  });

  tearDown(() => GetIt.instance.reset());

  Finder button(String label) => find.widgetWithText(FilledButton, label);

  /// Tela alta o bastante para a lista inteira, com a impressão no fim.
  Future<void> pumpWholePage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: VeroPage()));
  }

  testWidgets('paga com o mock escolhido, mostra a transação e libera o estorno', (tester) async {
    await pumpWholePage(tester);

    for (final payment in VeroPaymentsMock.all) {
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
