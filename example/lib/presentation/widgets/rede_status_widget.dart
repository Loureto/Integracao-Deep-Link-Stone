import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../views/views.dart';

class RedeStatusCard extends StatelessWidget {
  final RedePageStatus status;
  final String message;
  final RedeTransactionResult? transaction;

  const RedeStatusCard({
    super.key,
    required this.status,
    required this.message,
    this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      RedePageStatus.idle => (Icons.info_outline, Colors.grey),
      RedePageStatus.loading => (Icons.hourglass_top, Colors.blue),
      RedePageStatus.success => (Icons.check_circle, Colors.green),
      RedePageStatus.error => (Icons.error, Colors.red),
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
              // O valor vem do recibo da Rede, em reais.
              Text('Valor: ${transaction.amount}'),
            ],
          ],
        ),
      ),
    );
  }
}
