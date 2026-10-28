import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../views/views.dart';

class PagBankStatusCard extends StatelessWidget {
  final PagBankStatus status;
  final String message;
  final PagBankTransaction? transaction;

  const PagBankStatusCard({
    super.key,
    required this.status,
    required this.message,
    this.transaction,
  });

  static String _money(int cents) => 'R\$ ${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      PagBankStatus.idle => (Icons.info_outline, Colors.grey),
      PagBankStatus.loading => (Icons.hourglass_top, Colors.blue),
      PagBankStatus.success => (Icons.check_circle, Colors.green),
      PagBankStatus.error => (Icons.error, Colors.red),
    };
    final transaction = this.transaction;
    final amount = transaction?.amount;

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
              Text('Transação: ${transaction.transactionCode ?? ''}'),
              Text('Id: ${transaction.transactionId ?? ''}'),
              if (amount != null) Text('Valor: ${_money(amount)}'),
              Text(
                '${transaction.cardBrand ?? ''} • NSU ${transaction.nsu ?? ''} • Aut. ${transaction.autoCode ?? ''}',
              ),
              Text('Código: ${transaction.errorCode ?? ''}'),
              ExpansionTile(
                title: const Text('Retorno completo'),
                tilePadding: EdgeInsets.zero,
                children: [
                  for (final MapEntry(:key, :value) in transaction.data.entries)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SelectableText('$key: ${value ?? ''}'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
