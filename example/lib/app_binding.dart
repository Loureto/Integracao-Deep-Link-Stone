import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';
import 'package:flutter/services.dart';

import 'presentation/presentation.dart';

class AppBinding {
  const AppBinding._();

  static void binds(GetIt i) {
    _infra(i);
    _services(i);
    _viewModels(i);
  }

  static void _infra(GetIt i) {
    i.registerLazySingleton<Environment>(() => EnvironmentLocal.instance);
  }

  /// Cada integração tem o próprio canal com a `MainActivity`: no Dart, um canal aceita um único handler,
  /// e um serviço substituiria o handler que recebe os retornos do outro.
  static void _services(GetIt i) {
    i.registerLazySingleton<IStonePaymentService>(
      () => StonePaymentService(const MethodChannel('stoneDeeplinkChannel')),
    );
    i.registerLazySingleton<ICieloPaymentService>(
      () => CieloPaymentService(const MethodChannel('cieloDeeplinkChannel'), i.get<Environment>()),
    );
  }

  static void _viewModels(GetIt i) {
    i.registerFactory<StoneViewModel>(() => StoneViewModel(i.get<IStonePaymentService>()));
    i.registerFactory<CieloViewModel>(() => CieloViewModel(i.get<ICieloPaymentService>()));
  }
}
