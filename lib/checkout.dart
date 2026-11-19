import 'package:flutter/material.dart';

import 'api.dart';
import 'download.dart';
import 'products.dart';

const paymentMethods = {
  'transfer': 'Transferencia',
  'cash': 'Efectivo',
  'card': 'Tarjeta',
};

IconData _paymentIcon(String? method) => switch (method) {
  'transfer' => Icons.account_balance_outlined,
  'cash' => Icons.payments_outlined,
  'card' => Icons.credit_card,
  _ => Icons.account_balance_wallet_outlined,
};

class VisitCheckout extends StatefulWidget {
  const VisitCheckout({
    super.key,
    required this.api,
    required this.visit,
    required this.staff,
    this.alertsOnly = false,
  });

  final Api api;
  final Map<String, dynamic> visit;
  final bool staff;
  final bool alertsOnly;

  @override
  State<VisitCheckout> createState() => _VisitCheckoutState();
}

class _VisitCheckoutState extends State<VisitCheckout> {
  bool busy = false;

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiMessage(error))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> post(String path, [Map<String, dynamic> body = const {}]) async {
    await widget.api.request(path, body: body);
  }

  Future<void> chooseMethod() async {
    final method = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Método de pago'),
        children: [
          for (final item in paymentMethods.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, item.key),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(_paymentIcon(item.key)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(item.value)),
                    if (widget.visit['method'] == item.key)
                      const Icon(Icons.check_circle_outline),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    if (method != null && mounted) {
      await run(() => post('/guest/bill', {'method': method}));
    }
  }

  Future<void> pay(String path, int total, String method) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          total == 0 ? 'Confirmar saldo cero' : 'Confirmar pago recibido',
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.visit['label'] as String),
            Text(clp(total), style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(paymentMethods[method]!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await run(() => post(path, {'total': total, 'method': method}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visit = widget.visit;
    final path = "/staff/visits/${visit['id']}";
    final callId = visit['callId'];
    final method = visit['method'] as String?;
    final review = visit['review'] == true;
    final status = visit['status'];
    if (widget.alertsOnly) {
      return Card(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: ListTile(
          title: Text("${visit['label']} · Llamada pendiente"),
          subtitle: TextButton(
            onPressed: busy
                ? null
                : () => run(() => post('$path/attend', {'callId': callId})),
            child: const Text('Atender llamada'),
          ),
        ),
      );
    }
    final total = (visit['total'] as num).toInt();
    final hasOrders = (visit['orderCount'] as num) > 0;
    final heading = switch (status) {
      'bill_requested' => 'Boleta solicitada',
      'paid' => 'Pagada',
      _ => hasOrders ? 'Consumo pendiente' : 'Visita abierta',
    };
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = switch (status) {
      'bill_requested' => const Color(0xffffce8b),
      'paid' => const Color(0xffa6e6c0),
      _ => colors.secondary,
    };
    final primary = widget.staff
        ? switch ((status, method)) {
            ('bill_requested', final String value) => FilledButton(
              onPressed: busy ? null : () => pay('$path/pay', total, value),
              child: Text(
                total == 0 ? 'Confirmar saldo cero' : 'Confirmar pago',
              ),
            ),
            ('paid', _) => FilledButton(
              onPressed: busy
                  ? null
                  : () => run(
                      () => post("/staff/tables/${visit['tableId']}/close", {
                        'visitId': visit['id'],
                      }),
                    ),
              child: const Text('Cerrar mesa'),
            ),
            _ => null,
          }
        : hasOrders && status != 'paid'
        ? FilledButton(
            onPressed: busy ? null : chooseMethod,
            child: Text(
              status == 'bill_requested' ? 'Cambiar método' : 'Pedir boleta',
            ),
          )
        : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.staff ? visit['label'] as String : 'Resumen de consumo',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(
                  avatar: Icon(
                    status == 'paid'
                        ? Icons.task_alt
                        : Icons.receipt_long_outlined,
                    color: accent,
                    size: 18,
                  ),
                  label: Text(heading, style: TextStyle(color: accent)),
                  side: BorderSide(color: accent.withValues(alpha: .5)),
                  backgroundColor: Color.alphaBlend(
                    accent.withValues(alpha: .09),
                    colors.surface,
                  ),
                ),
                if (widget.staff && review)
                  const Chip(label: Text('En revisión')),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              status == 'paid' ? 'Total pagado' : 'Total a pagar',
              style: theme.textTheme.labelLarge,
            ),
            Text(
              clp(total),
              style: theme.textTheme.displaySmall?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            _AmountLine(
              label: 'Subtotal',
              amount: (visit['subtotal'] as num).toInt(),
            ),
            _AmountLine(
              label: "Descuento (${visit['percent']}%)",
              amount: (visit['discount'] as num).toInt(),
            ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                leading: Icon(_paymentIcon(method), color: colors.secondary),
                title: const Text('Método de pago'),
                subtitle: Text(
                  paymentMethods[method] ?? 'Por elegir',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
            if (callId != null)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('Llamada al mesero pendiente'),
              ),
            if (primary != null) ...[
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: primary),
            ],
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: widget.staff
                  ? [
                      if (callId != null)
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => run(
                                  () =>
                                      post('$path/attend', {'callId': callId}),
                                ),
                          child: const Text('Atender llamada'),
                        ),
                      if (status == 'bill_requested' && method != null)
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => run(() => post('$path/reopen')),
                          child: const Text('Reabrir cuenta'),
                        ),
                      if (status != 'paid' && (hasOrders || review))
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => run(
                                  () =>
                                      post('$path/review', {'review': !review}),
                                ),
                          child: Text(
                            review ? 'Quitar revisión' : 'Marcar para revisión',
                          ),
                        ),
                    ]
                  : [
                      if (hasOrders)
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => run(() async {
                                  final response = await widget.api.request(
                                    '/guest/summary/pdf',
                                  );
                                  downloadSummary(response['pdf'] as String);
                                }),
                          child: const Text('Descargar resumen PDF'),
                        ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountLine extends StatelessWidget {
  const _AmountLine({required this.label, required this.amount});

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(clp(amount)),
      ],
    ),
  );
}

class GuestHelpDialog extends StatefulWidget {
  const GuestHelpDialog({super.key, required this.api});

  final Api api;

  @override
  State<GuestHelpDialog> createState() => _GuestHelpDialogState();
}

class _GuestHelpDialogState extends State<GuestHelpDialog> {
  late final updates = widget.api.watchOrders('/guest/orders');
  bool sending = false;
  String? error;

  Future<void> call() async {
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await widget.api.request('/guest/call', body: {});
    } catch (failure) {
      if (mounted) setState(() => error = apiMessage(failure));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: updates,
    builder: (context, snapshot) {
      final summary = snapshot.data?['summary'] as Map<String, dynamic>?;
      final pending = summary?['callId'] != null;
      final paid = summary?['status'] == 'paid';
      final message =
          error ??
          (snapshot.hasError ? apiMessage(snapshot.error) : null) ??
          (pending
              ? 'Llamada al mesero pendiente.'
              : paid
              ? 'La cuenta ya está pagada.'
              : 'El personal recibirá una llamada de tu mesa.');
      return AlertDialog(
        title: const Text('Ayuda'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: summary == null || sending || pending || paid
                ? null
                : call,
            child: Text(sending ? 'Enviando…' : 'Llamar al mesero'),
          ),
        ],
      );
    },
  );
}
