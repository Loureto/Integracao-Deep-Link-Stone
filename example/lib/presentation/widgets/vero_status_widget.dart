import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../views/views.dart';

class VeroStatusCard extends StatelessWidget {
  final VeroPageStatus status;
  final String message;
  final VeroTransactionResult? transaction;

  const VeroStatusCard({
    super.key,
    required this.status,
    required this.message,
    this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      VeroPageStatus.idle => (Icons.info_outline, Colors.grey),
      VeroPageStatus.loading => (Icons.hourglass_top, Colors.blue),
      VeroPageStatus.success => (Icons.check_circle, Colors.green),
      VeroPageStatus.error => (Icons.error, Colors.red),
    };
    final transaction = this.transaction;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message.isEmpty ? 'Escolha uma operação de teste.' : message,
                  ),
                ),
              ],
            ),
            if (transaction != null) ...[
              const Divider(),
              Text('NSU: ${transaction.nsu}'),
              Text('Autorização: ${transaction.authorization}'),
              Text('Bandeira: ${transaction.flag}'),
              // O app da Vero manda o valor como texto; ele aparece como chegou.
              Text('Valor: ${transaction.value}'),
            ],
          ],
        ),
      ),
    );
  }
}
