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
}
