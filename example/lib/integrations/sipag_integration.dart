import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';
import 'package:flutter/services.dart';

import '../presentation/presentation.dart';
import 'acquirer_integration.dart';

class SipagIntegration extends AcquirerIntegration {
  const SipagIntegration();

  static const String _home = '/sipag';

  @override
  String get initialLocation => _home;

  @override
  void binds(GetIt i) {
    i.registerLazySingleton<IPdfImageConverter>(() => const PdfImageConverter());
    i.registerLazySingleton<INativePrinterService>(
      () => NativePrinterService(const MethodChannel('acquirers_sdk'), i.get<IPdfImageConverter>()),
    );
    i.registerLazySingleton<ISiPagPaymentService>(
      () => const SiPagPaymentService(MethodChannel('sipag_sdk')),
    );
    i.registerFactory<SipagViewModel>(
      () => SipagViewModel(i.get<ISiPagPaymentService>(), i.get<INativePrinterService>()),
    );
  }

  @override
  List<RouteBase> routes() {
    return [
      GoRoute(
        path: _home,
        builder: (_, _) => SipagPage(),
      ),
    ];
  }
}
