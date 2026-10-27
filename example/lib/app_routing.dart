import 'package:dependencies/dependencies.dart';
import './presentation/presentation.dart';

class AppRouting {
  const AppRouting._();

  static const String home = '/';
  static const String stone = '/stone';
  static const String cielo = '/cielo';

  static final GoRouter router = GoRouter(
    initialLocation: home,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: home,
        builder: (context, state) => const HomePage(
          integrations: [
            (label: 'Stone', path: stone),
            (label: 'Cielo Smart', path: cielo),
          ],
        ),
      ),
      GoRoute(path: stone, builder: (context, state) => const StonePage()),
      GoRoute(path: cielo, builder: (context, state) => const CieloPage()),
    ],
  );
}
