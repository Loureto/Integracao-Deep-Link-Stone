import 'package:dependencies/dependencies.dart';
import 'package:flutter/material.dart';

import '../../widgets/widgets.dart';

/// Escolha da integração: cada terminal tem o app de pagamento de uma única adquirente.
class HomePage extends StatelessWidget {
  final List<({String label, String path})> integrations;

  const HomePage({super.key, required this.integrations});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: CustomText.medium('Payment Integrations'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade500,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final integration in integrations)
            FilledButton(
              onPressed: () => context.push(integration.path),
              child: CustomText.small(integration.label),
            ),
        ],
      ),
    );
  }
}
