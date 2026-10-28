import 'package:dependencies/dependencies.dart';

import '../presentation/presentation.dart';
import 'acquirer_integration.dart';

/// Build que não abre nenhuma integração de adquirente: rodou sem --flavor, com um flavor que ainda não
/// tem integração no Dart ou com o env de outro flavor. O app abre na home, que explica o que corrigir.
class HelpIntegration extends AcquirerIntegration {
  const HelpIntegration();

  static const String _home = '/';

  @override
  String get initialLocation => _home;

  /// A home de ajuda não usa serviços nem view models.
  @override
  void binds(GetIt i) {}

  @override
  List<RouteBase> routes() {
    return [
      GoRoute(
        path: _home,
        builder: (_, _) => const HomePage(),
      ),
    ];
  }
}
