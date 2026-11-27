import 'package:flutter/material.dart';

import 'api.dart';
import 'checkout.dart';
import 'night_theme.dart';
import 'orders.dart';
import 'products.dart';

class PaymentHistoryPage extends StatefulWidget {
  const PaymentHistoryPage({super.key, required this.api});

  final Api api;

  @override
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  final payments = <Map<String, dynamic>>[];
  String? next;
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final suffix = next == null ? '' : '?before=$next';
      final page = await widget.api.request('/admin/payment-history$suffix');
      if (!mounted) return;
      setState(() {
        payments.addAll(
          (page['payments'] as List).cast<Map<String, dynamic>>(),
        );
        next = page['next'] as String?;
        loading = false;
      });
    } catch (failure) {
      if (mounted) {
        setState(() {
          error = apiMessage(failure);
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dates = MaterialLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de boletas')),
      body: ScreenColumn(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final payment in payments)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(payment['label'] as String),
                  subtitle: Text(
                    '${dates.formatShortDate(DateTime.parse(payment['paidAt'] as String).toLocal())} · '
                    '${paymentMethods[payment['method']] ?? 'Método sin registrar'}',
                  ),
                  trailing: Text(
                    clp((payment['total'] as num).toInt()),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => AlertDetailPage(
                        api: widget.api,
                        type: 'payment_confirmed',
                        id: payment['id'] as String,
                      ),
                    ),
                  ),
                ),
              ),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (error != null || next != null) ...[
              if (error != null) Text(error!),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    loading = true;
                    error = null;
                  });
                  load();
                },
                child: Text(
                  error == null ? 'Ver cobros anteriores' : 'Reintentar',
                ),
              ),
            ] else if (payments.isEmpty)
              const Text('Todavía no hay cobros registrados.'),
          ],
        ),
      ),
    );
  }
}
