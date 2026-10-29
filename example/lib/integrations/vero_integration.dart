import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';
import 'package:flutter/services.dart';

import '../presentation/presentation.dart';
import 'acquirer_integration.dart';

class VeroIntegration extends AcquirerIntegration {
  const VeroIntegration();

  static const String _home = '/vero';

  @override
  String get initialLocation => _home;

  @override
  void binds(GetIt i) {
    i.registerLazySingleton<IPdfImageConverter>(() => const PdfImageConverter());
    i.registerLazySingleton<INativePrinterService>(
      () => NativePrinterService(const MethodChannel('acquirers_sdk'), i.get<IPdfImageConverter>()),
    );
    i.registerLazySingleton<IVeroPaymentService>(
      () => VeroPaymentService(const MethodChannel('vero_flutter'), i.get<INativePrinterService>()),
    );
    i.registerFactory<VeroViewModel>(
      () => VeroViewModel(i.get<IVeroPaymentService>(), i.get<INativePrinterService>()),
    );
  }

  @override
  List<RouteBase> routes() {
    return [
      GoRoute(
        path: _home,
        builder: (_, _) => VeroPage(),
      ),
    ];
  }
}
