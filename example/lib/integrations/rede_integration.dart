import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';
import 'package:flutter/services.dart';

import '../presentation/presentation.dart';
import 'acquirer_integration.dart';

class RedeIntegration extends AcquirerIntegration {
  const RedeIntegration();

  static const String _home = '/rede';

  @override
  String get initialLocation => _home;

  @override
  void binds(GetIt i) {
    i.registerLazySingleton<IPdfImageConverter>(() => const PdfImageConverter());
    i.registerLazySingleton<IRedePaymentService>(
      () => RedePaymentService(const MethodChannel('rede_sdk'), i.get<IPdfImageConverter>()),
    );
    i.registerFactory<RedeViewModel>(() => RedeViewModel(i.get<IRedePaymentService>()));
  }

  @override
  List<RouteBase> routes() {
    return [
      GoRoute(
        path: _home,
        builder: (_, _) => RedePage(),
      ),
    ];
  }
}
