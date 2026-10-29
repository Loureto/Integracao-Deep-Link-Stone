import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';
import 'package:example/app_module.dart';
import 'package:example/app_widget.dart';
import 'package:example/integrations/integrations.dart';
import 'package:example/presentation/presentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => GetIt.instance.reset());

  /// Monta o app como o `main.dart` faz, com o env do [flavorType] e a [integration] escolhida.
  Future<void> pumpApp(WidgetTester tester, String flavorType, AcquirerIntegration integration) async {
    final environment = Environment(flavorType: flavorType, cieloClientID: '', cieloAccessToken: '');
    AppModule.binds(GetIt.instance, environment, integration);

    await tester.pumpWidget(AppWidget(router: AppModule.router(integration)));
    await tester.pumpAndSettle();
  }

  testWidgets('flavor stone: abre direto na tela da Stone', (tester) async {
    await pumpApp(tester, 'stone', const StoneIntegration());

    expect(find.byType(StonePage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
  });

  testWidgets('flavor cielo: abre direto na tela da Cielo', (tester) async {
    await pumpApp(tester, 'cielo', const CieloIntegration());

    expect(find.byType(CieloPage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
  });

  testWidgets('flavor pagbank: abre direto na tela do PagBank', (tester) async {
    await pumpApp(tester, 'pagbank', const PagBankIntegration());

    expect(find.byType(PagBankPage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
  });

  testWidgets('flavor vero: abre direto na tela da Vero', (tester) async {
    await pumpApp(tester, 'vero', const VeroIntegration());

    expect(find.byType(VeroPage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
  });

  testWidgets('flavor rede: abre direto na tela da Rede', (tester) async {
    await pumpApp(tester, 'rede', const RedeIntegration());

    expect(find.byType(RedePage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
  });

  testWidgets('sem --flavor, a home de ajuda mostra o flavor e o env do build e como rodar', (tester) async {
    await pumpApp(tester, 'cielo', const HelpIntegration());

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Nenhuma integração disponível neste build.'), findsOneWidget);
    expect(find.text('Flavor do build (--flavor): nenhum'), findsOneWidget);
    expect(find.text('Flavor do env (FLAVOR_TYPE): cielo'), findsOneWidget);
    expect(find.textContaining('fvm flutter run --flavor <adquirente>'), findsOneWidget);
  });
}
