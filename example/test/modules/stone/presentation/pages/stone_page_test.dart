import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';
import 'package:example/presentation/mocks/mocks.dart';
import 'package:example/presentation/presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_stone_payment_service.dart';

void main() {
  late FakeStonePaymentService service;

  setUp(() {
    service = FakeStonePaymentService();
    GetIt.instance.registerFactory<StoneViewModel>(() => StoneViewModel(service));
  });

  tearDown(() => GetIt.instance.reset());

  testWidgets('envia o pagamento fake escolhido e exibe o retorno', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StonePage()));

    for (final payment in StonePaymentsMock.all) {
      expect(find.text(payment.label), findsOneWidget);
    }

    await tester.tap(find.text('Débito • R\$ 1,00'));
    await tester.pumpAndSettle();

    final request = service.requests.single;
    expect(request.amount, 100);
    expect(request.transactionType, StoneTransactionType.debit);
    expect(find.text('Aguardando o retorno do app de pagamento...'), findsOneWidget);

    service.responsesController.add(const StonePaymentResponse({'code': '0', 'brand': 'MASTERCARD'}));
    await tester.pumpAndSettle();

    expect(find.text('Pagamento aprovado.'), findsOneWidget);
    expect(find.text('brand: MASTERCARD'), findsOneWidget);
  });

  group('impressão de NFC-e', () {
    /// Tela alta o bastante para a lista inteira, com a impressão abaixo dos pagamentos.
    Future<void> pumpWholePage(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: StonePage()));
    }

    testWidgets('imprime a NFC-e de teste', (tester) async {
      await pumpWholePage(tester);

      await tester.tap(find.text('Imprimir a NFC-e de teste'));
      await tester.pumpAndSettle();

      expect(service.nfcs.single, NfceMock.pdf);
      expect(find.text('NFC-e impressa.'), findsOneWidget);
    });

    testWidgets('imprime a NFC-e de homologação, como o sistema a envia', (tester) async {
      await pumpWholePage(tester);

      await tester.tap(find.text('Imprimir a NFC-e de homologação'));
      await tester.pumpAndSettle();

      expect(service.nfcs.single, NfceHomologacaoMock.pdf);
      expect(find.text('NFC-e impressa.'), findsOneWidget);
    });
  });
}
