import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';
import 'package:example/presentation/mocks/mocks.dart';
import 'package:example/presentation/presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_pagbank_service.dart';

void main() {
  late FakePagBankService service;

  setUp(() {
    service = FakePagBankService();
    GetIt.instance.registerFactory<PagBankViewModel>(() => PagBankViewModel(service));
  });

  tearDown(() => GetIt.instance.reset());

  Finder button(String label) => find.widgetWithText(FilledButton, label);

  testWidgets('paga com o mock escolhido, exibe a transação e libera o estorno', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PagBankPage()));

    for (final payment in PagBankPaymentsMock.all.take(3)) {
      expect(find.text(payment.label), findsOneWidget);
    }
    expect(tester.widget<FilledButton>(button('Cancelar a operação em andamento')).onPressed, isNull);

    await tester.tap(find.text('Débito • R\$ 1,00'));
    await tester.pumpAndSettle();

    final request = service.calls.single.$2 as PagBankPaymentModel;
    expect(request.type, PagBankPaymentType.debit);
    expect(request.amount, 100);
    expect(find.text('Pagamento aprovado.'), findsOneWidget);
    expect(find.text('Transação: TC1'), findsOneWidget);
    expect(find.text('Valor: R\$ 1,00'), findsOneWidget);

    // O estorno fica abaixo dos pagamentos de teste, fora da tela.
    await tester.scrollUntilVisible(button('Estornar o último pagamento'), 100);
    expect(tester.widget<FilledButton>(button('Estornar o último pagamento')).onPressed, isNotNull);
  });

  testWidgets('sem pagamento aprovado, o estorno fica desabilitado', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PagBankPage()));

    await tester.scrollUntilVisible(button('Estornar o último pagamento'), 100);

    expect(tester.widget<FilledButton>(button('Estornar o último pagamento')).onPressed, isNull);
  });
}
