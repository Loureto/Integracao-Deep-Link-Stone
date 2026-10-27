import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../views/views.dart';

class PaymentStatus extends StatelessWidget {
  final StoneStatus status;
  final String message;
  final StonePaymentResponse? response;

  const PaymentStatus({
    super.key,
    required this.status,
    required this.message,
    this.response,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      StoneStatus.idle => (Icons.info_outline, Colors.grey),
      StoneStatus.loading => (Icons.hourglass_top, Colors.blue),
      StoneStatus.success => (Icons.check_circle, Colors.green),
      StoneStatus.error => (Icons.error, Colors.red),
    };

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
                    message.isEmpty ? 'Escolha um pagamento de teste.' : message,
                  ),
                ),
              ],
            ),
            if (response != null) ...[
              const Divider(),
              for (final MapEntry(:key, :value) in response!.data.entries) Text('$key: ${value ?? ''}'),
            ],
          ],
        ),
      ),
    );
  }
}
