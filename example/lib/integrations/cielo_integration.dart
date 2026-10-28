import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';
import 'package:flutter/services.dart';

import '../presentation/presentation.dart';
import 'acquirer_integration.dart';

class CieloIntegration extends AcquirerIntegration {
  const CieloIntegration();

  static const String _home = '/cielo';

  @override
  String get initialLocation => _home;

  @override
  void binds(GetIt i) {
    i.registerLazySingleton<ICieloPaymentService>(
      () => CieloPaymentService(const MethodChannel('cieloDeeplinkChannel'), i.get<Environment>()),
    );
    i.registerFactory<CieloViewModel>(() => CieloViewModel(i.get<ICieloPaymentService>()));
  }

  @override
  List<RouteBase> routes() {
    return [
      GoRoute(
        path: _home,
        builder: (_, _) => CieloPage(),
      ),
    ];
  }
}
