import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';
import 'package:example/presentation/mocks/mocks.dart';
import 'package:example/presentation/presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_pagbank_service.dart';
import '../../fakes/fake_pdf_image_converter.dart';

void main() {
  late FakePagBankService service;
  late FakePdfImageConverter converter;

  setUp(() {
    service = FakePagBankService();
    converter = FakePdfImageConverter();
    GetIt.instance.registerFactory<PagBankViewModel>(() => PagBankViewModel(service, converter));
  });

  tearDown(() => GetIt.instance.reset());

  Finder button(String label) => find.widgetWithText(FilledButton, label);

  /// Tela alta o bastante para a lista inteira. No fim dela fica a impressão livre: rolar até lá tira da árvore o
  /// cartão de status, no topo, e a lista, que só mede os itens construídos, para de rolar antes do último.
  Future<void> pumpWholePage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: PagBankPage()));
  }

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

  testWidgets('a impressão livre imprime a imagem de teste', (tester) async {
    await pumpWholePage(tester);

    await tester.tap(button('Imprimir a imagem de teste'));
    await tester.pumpAndSettle();

    expect((service.calls.single.$2 as PagBankPrintModel).image, PagBankPrintsMock.image);
    expect(find.text('Imagem impressa.'), findsOneWidget);
  });

  testWidgets('a impressão livre converte e imprime a NFC-e de teste', (tester) async {
    await pumpWholePage(tester);

    await tester.tap(button('Imprimir a NFC-e de teste'));
    await tester.pumpAndSettle();

    expect(converter.pdfs.single, NfceMock.pdf);
    expect((service.calls.single.$2 as PagBankPrintModel).image, convertedPng);
    expect(find.text('NFC-e impressa.'), findsOneWidget);
  });

  testWidgets('a impressão livre converte e imprime a NFC-e de homologação, como o sistema a envia', (
    tester,
  ) async {
    await pumpWholePage(tester);

    await tester.tap(button('Imprimir a NFC-e de homologação'));
    await tester.pumpAndSettle();

    expect(converter.pdfs.single, NfceHomologacaoMock.pdf);
    expect((service.calls.single.$2 as PagBankPrintModel).image, convertedPng);
    expect(find.text('NFC-e impressa.'), findsOneWidget);
  });
}
