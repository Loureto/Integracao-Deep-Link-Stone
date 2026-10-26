import 'package:dependencies/dependencies.dart';

/// Dependency manager, which registers and provides the app dependencies.
///
/// It wraps [GetIt], so the rest of the code does not depend on the
/// injection package directly.
abstract final class DM {
  static final GetIt _getIt = GetIt.instance;

  /// Registers [factory], which creates a new [T] on every [get].
  ///
  /// The [DM] does not keep these instances, so the caller must dispose them.
  static void registerFactory<T extends Object>(T Function() factory) {
    _getIt.registerFactory<T>(factory);
  }

  /// Registers [factory], which creates a single [T] on the first [get].
  ///
  /// The instance is kept until [dispose] is called, and a new one is created
  /// on the next [get].
  static void registerLazySingleton<T extends Object>(T Function() factory) {
    _getIt.registerLazySingleton<T>(factory);
  }

  /// Returns the registered [T].
  static T get<T extends Object>() => _getIt.get<T>();

  /// Disposes the [T] kept by the [DM], calling [Disposable.onDispose] if it
  /// implements [Disposable].
  ///
  /// Returns `true` if [T] is a lazy singleton, which is disposed and created
  /// again on the next [get]. Returns `false` if the [DM] does not keep the
  /// instance (factories or unregistered types), so the caller must dispose it.
  static bool dispose<T extends Object>() {
    final registration = _getIt.findFirstObjectRegistration<T>();
    if (registration?.registrationType != ObjectRegistrationType.lazy) {
      return false;
    }
    _getIt.resetLazySingleton<T>();
    return true;
  }
}
