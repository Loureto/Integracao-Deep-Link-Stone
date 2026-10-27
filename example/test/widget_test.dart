import 'package:dependencies/dependencies.dart';
import 'package:example/app_binding.dart';
import 'package:example/app_widget.dart';
import 'package:example/presentation/presentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => GetIt.instance.reset());

  testWidgets('abre na escolha da integração e navega para Cielo e Stone', (tester) async {
    AppBinding.binds(GetIt.instance);

    await tester.pumpWidget(const AppWidget());
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);

    await tester.tap(find.text('Cielo Smart'));
    await tester.pumpAndSettle();
    expect(find.byType(CieloPage), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stone'));
    await tester.pumpAndSettle();
    expect(find.byType(StonePage), findsOneWidget);
  });
}
