import 'package:dependencies/dependencies.dart';
import 'package:example/presentation/presentation.dart';

abstract final class AppRouting {
  static const String home = '/';

  static final GoRouter router = GoRouter(
    initialLocation: home,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(path: home, builder: (context, state) => const CieloPage()),
    ],
  );
}
