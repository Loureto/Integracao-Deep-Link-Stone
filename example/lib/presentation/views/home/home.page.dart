import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/widgets.dart';

/// Página de ajuda: o app abre nela quando o build não abre nenhuma integração (ver `main.dart`). Mostra
/// o flavor e o env do build e o que corrigir.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final envFlavor = DM.get<Environment>().flavorType;
    final hasFlavor = appFlavor != null;
    final envMatchesFlavor = envFlavor == appFlavor;

    return Scaffold(
      appBar: AppBar(
        title: CustomText.medium('Payment Integrations'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade500,
      ),
      // Sem nomes de adquirentes: esta página entra no APK de todos os flavors.
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CustomText.medium('Nenhuma integração disponível neste build.', color: Colors.black),
          const SizedBox(height: 16),
          CustomText.small('Flavor do build (--flavor): ${appFlavor ?? 'nenhum'}', color: Colors.black),
          CustomText.small(
            'Flavor do env (FLAVOR_TYPE): ${envFlavor.isEmpty ? 'nenhum' : envFlavor}',
            color: Colors.black,
          ),
          const SizedBox(height: 16),
          if (!hasFlavor)
            CustomText.small(
              'O app rodou sem --flavor. Cada adquirente é um flavor do Android, declarado em '
              'android/app/build.gradle.kts, com o env dela em assets/env/.',
              color: Colors.black,
            )
          else if (!envMatchesFlavor)
            CustomText.small(
              'O env do --dart-define-from-file não é do flavor do build: rode com o env da mesma adquirente.',
              color: Colors.black,
            )
          else
            CustomText.small(
              'O flavor "$appFlavor" ainda não tem integração no Dart: crie a dele em lib/integrations/ '
              'e escolha-a pelo flavor em lib/main.dart.',
              color: Colors.black,
            ),
          if (!hasFlavor || !envMatchesFlavor) ...[
            const SizedBox(height: 8),
            CustomText.small(
              'fvm flutter run --flavor <adquirente> --dart-define-from-file=../assets/env/<adquirente>_env.json',
              color: Colors.black,
            ),
          ],
        ],
      ),
    );
  }
}
