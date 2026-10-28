import 'package:dependencies/dependencies.dart';
import 'package:flutter/material.dart';

class AppWidget extends StatelessWidget {
  final GoRouter router;

  const AppWidget({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Payment Integrations',
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue.shade500),
      ),
    );
  }
}
