import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';
import 'package:flutter/services.dart';

import '../presentation/presentation.dart';
import 'acquirer_integration.dart';

class PagBankIntegration extends AcquirerIntegration {
  const PagBankIntegration();

  static const String _home = '/pagbank';

  @override
  String get initialLocation => _home;

  @override
  void binds(GetIt i) {
    i.registerLazySingleton<IPagBankPaymentService>(
      () => PagBankPaymentService(const MethodChannel('pagbankChannel')),
    );
    i.registerLazySingleton<IPdfImageConverter>(() => const PdfImageConverter());
    i.registerFactory<PagBankViewModel>(
      () => PagBankViewModel(i.get<IPagBankPaymentService>(), i.get<IPdfImageConverter>()),
    );
  }

  @override
  List<RouteBase> routes() {
    return [
      GoRoute(
        path: _home,
        builder: (_, _) => PagBankPage(),
      ),
    ];
  }
}
