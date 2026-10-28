import 'package:dependencies/dependencies.dart';

/// Integração de uma adquirente com o app: a tela e as dependências dela. Cada flavor do Android
/// (stone, cielo, pagbank) monta o app só com a sua, escolhida no `main.dart`.
abstract class AcquirerIntegration {
  const AcquirerIntegration();

  /// Rota em que o app abre, uma das [routes].
  String get initialLocation;

  /// Registra o serviço da integração, que conversa com a `MainActivity` pelo canal dela, e o view model.
  void binds(GetIt i);

  /// Rotas das telas da integração.
  List<RouteBase> routes();
}
