import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_module.dart';
import 'app_widget.dart';
import 'integrations/integrations.dart';

// O flavor do Android (--flavor) chega aqui em appFlavor. Como estas condições são constantes de
// compilação (como kReleaseMode), o build de cada flavor descarta as integrações das outras adquirentes,
// e o APK leva só a da sua: o PagBank não homologa app com referência a outras adquirentes.
const _isStone = appFlavor == 'stone';
const _isCielo = appFlavor == 'cielo';
const _isPagBank = appFlavor == 'pagbank';
const _isVero = appFlavor == 'vero';
const _isRede = appFlavor == 'rede';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final environment = EnvironmentLocal.instance;
  final integration = _flavorIntegration(environment);

  AppModule.binds(GetIt.instance, environment, integration);

  runApp(AppWidget(router: AppModule.router(integration)));
}

/// A integração do flavor do build. Sem ela (sem --flavor ou num flavor ainda sem integração no Dart) ou com
/// o env de outro flavor, o app abre na home de ajuda da [HelpIntegration].
AcquirerIntegration _flavorIntegration(Environment environment) {
  // Quem escolhe a integração é o --flavor, com o qual o Android também foi montado. O FLAVOR_TYPE só
  // confirma que o arquivo do --dart-define-from-file é do mesmo flavor: o de outra adquirente traria as
  // credenciais dela para este build.
  if (environment.flavorType != appFlavor) return HelpIntegration();
  if (_isStone) return StoneIntegration();
  if (_isCielo) return CieloIntegration();
  if (_isPagBank) return PagBankIntegration();
  if (_isVero) return VeroIntegration();
  if (_isRede) return RedeIntegration();

  return HelpIntegration();
}
