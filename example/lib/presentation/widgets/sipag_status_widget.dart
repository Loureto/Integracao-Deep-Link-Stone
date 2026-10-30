import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../views/views.dart';

class SipagStatusCard extends StatelessWidget {
  final SipagPageStatus status;
  final String message;
  final SiPagTransactionResult? transaction;

  const SipagStatusCard({
    super.key,
    required this.status,
    required this.message,
    this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      SipagPageStatus.idle => (Icons.info_outline, Colors.grey),
      SipagPageStatus.loading => (Icons.hourglass_top, Colors.blue),
      SipagPageStatus.success => (Icons.check_circle, Colors.green),
      SipagPageStatus.error => (Icons.error, Colors.red),
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
              // O valor chega em reais, já convertido dos centavos pelo Android.
              Text('Valor: ${transaction.amount}'),
            ],
          ],
        ),
      ),
    );
  }
}
