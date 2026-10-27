import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';
import 'package:example/presentation/mocks/mocks.dart';
import 'package:example/presentation/presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/cielo_responses.dart';
import '../../fakes/fake_cielo_service.dart';

void main() {
  late FakeCieloService service;

  setUp(() {
    service = FakeCieloService();
    GetIt.instance.registerFactory<CieloViewModel>(() => CieloViewModel(service));
  });

  tearDown(() => GetIt.instance.reset());

  testWidgets('envia o pagamento fake escolhido, exibe o retorno e libera o cancelamento', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CieloPage()));

    for (final payment in CieloPaymentsMock.all) {
      expect(find.text(payment.label), findsOneWidget);
    }
    final cancelButton = find.widgetWithText(FilledButton, 'Cancelar o último pagamento');
    expect(tester.widget<FilledButton>(cancelButton).onPressed, isNull);

    await tester.tap(find.text('Débito à vista • R\$ 1,00'));
    await tester.pumpAndSettle();

    final request = service.requests.single.$2 as CieloPaymentModel;
    expect(request.value, 100);
    expect(request.paymentCode, CieloPaymentCode.debitoAvista);
    expect(find.text('Aguardando o retorno do app da Cielo...'), findsOneWidget);

    service.responsesController.add(cieloResponse(CieloAction.payment, paidCieloOrder));
    await tester.pumpAndSettle();

    expect(find.text('Pagamento aprovado.'), findsOneWidget);
    expect(find.text('Pedido: pedido-1'), findsOneWidget);

    // O resumo do pedido aumenta o card e empurra o botão para fora da tela.
    await tester.scrollUntilVisible(cancelButton, 100);
    expect(tester.widget<FilledButton>(cancelButton).onPressed, isNotNull);
  });
}
