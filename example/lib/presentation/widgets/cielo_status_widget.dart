import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../views/views.dart';

class CieloStatusCard extends StatelessWidget {
  final CieloStatus status;
  final String message;
  final CieloResponse? response;

  const CieloStatusCard({
    super.key,
    required this.status,
    required this.message,
    this.response,
  });

  static const _json = JsonEncoder.withIndent('  ');

  static String _money(int cents) => 'R\$ ${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      CieloStatus.idle => (Icons.info_outline, Colors.grey),
      CieloStatus.loading => (Icons.hourglass_top, Colors.blue),
      CieloStatus.success => (Icons.check_circle, Colors.green),
      CieloStatus.error => (Icons.error, Colors.red),
    };
    final data = response?.data;
    final order = response?.order;

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
            if (order != null) ...[
              const Divider(),
              Text('Pedido: ${order.id}'),
              Text('Status: ${order.status ?? ''}'),
              for (final payment in order.payments)
                Text(
                  '${payment.isCancellation ? 'Cancelamento' : payment.productName ?? 'Pagamento'} • '
                  '${_money(payment.amount)} • NSU ${payment.cieloCode ?? ''} • Aut. ${payment.authCode ?? ''}',
                ),
            ],
            if (data != null)
              ExpansionTile(
                title: const Text('Retorno completo'),
                tilePadding: EdgeInsets.zero,
                children: [
                  SelectableText(
                    _json.convert(data),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
