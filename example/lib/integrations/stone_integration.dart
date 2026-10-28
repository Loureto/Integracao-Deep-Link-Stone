import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';
import 'package:flutter/services.dart';

import '../presentation/presentation.dart';
import 'acquirer_integration.dart';

class StoneIntegration extends AcquirerIntegration {
  const StoneIntegration();

  static const String _home = '/stone';

  @override
  String get initialLocation => _home;

  @override
  void binds(GetIt i) {
    i.registerLazySingleton<IStonePaymentService>(
      () => StonePaymentService(const MethodChannel('stoneDeeplinkChannel')),
    );
    i.registerFactory<StoneViewModel>(() => StoneViewModel(i.get<IStonePaymentService>()));
  }

  @override
  List<RouteBase> routes() {
    return [
      GoRoute(
        path: _home,
        builder: (_, _) => StonePage(),
      ),
    ];
  }
}
