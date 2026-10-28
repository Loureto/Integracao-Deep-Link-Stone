import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';

import 'integrations/integrations.dart';

class AppModule {
  const AppModule._();

  /// Registra o [environment] do build e as dependências da [integration] do flavor.
  static void binds(GetIt i, Environment environment, AcquirerIntegration integration) {
    i.registerSingleton<Environment>(environment);
    integration.binds(i);
  }

  /// Retorna o [GoRouter] com as rotas da [integration], aberto na rota inicial dela.
  static GoRouter router(AcquirerIntegration integration) {
    return GoRouter(
      initialLocation: integration.initialLocation,
      debugLogDiagnostics: true,
      routes: integration.routes(),
    );
  }
}
