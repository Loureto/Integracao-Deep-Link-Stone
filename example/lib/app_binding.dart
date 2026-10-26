import 'package:dependencies/dependencies.dart';

abstract final class AppBinding {
  static void binds(GetIt i) {
    _infra(i);
    _dataSources(i);
    _repositories(i);
    _viewModels(i);
  }

  static void _infra(GetIt i) {}

  static void _dataSources(GetIt i) {}

  static void _repositories(GetIt i) {}

  static void _viewModels(GetIt i) {}
}
