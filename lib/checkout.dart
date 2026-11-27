import 'package:flutter/material.dart';

import 'night_theme.dart';

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
    this.showSummary = true,
  });

  final Api api;
  final Map<String, dynamic> visit;
  final bool staff;
  final bool alertsOnly;
  final bool showSummary;

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
    final method = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Elige cómo pagar', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'El personal irá a tu mesa a cobrar.',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                for (final key in const ['card', 'cash', 'transfer'])
                  Card(
                    child: ListTile(
                      leading: Icon(_paymentIcon(key)),
                      title: Text(paymentMethods[key]!),
                      trailing: Icon(
                        widget.visit['method'] == key
                            ? Icons.check_circle_outline
                            : Icons.chevron_right,
                      ),
                      onTap: () => Navigator.pop(context, key),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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
          total == 0
              ? 'Confirmar saldo cero'
              : '¿Confirmar pago y cerrar la mesa?',
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _AmountLine(label: 'Mesa', text: widget.visit['label'] as String),
            _AmountLine(label: 'Método', text: paymentMethods[method]!),
            _AmountLine(label: 'Total', amount: total, major: true),
            const SizedBox(height: 12),
            const Text('La mesa queda libre para el próximo QR.'),
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
    final waitingForPayment = !widget.staff && status == 'bill_requested';
    if (widget.alertsOnly) {
      final warning = Theme.of(context).colorScheme.warning;
      return Card(
        color: Color.alphaBlend(
          warning.withValues(alpha: .14),
          Theme.of(context).colorScheme.surface,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${visit['label']} llama al mesero",
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: warning),
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: busy
                    ? null
                    : () => run(() => post('$path/attend', {'callId': callId})),
                icon: const Icon(Icons.check),
                label: const Text('Marcar atendida'),
              ),
            ],
          ),
        ),
      );
    }
    final total = (visit['total'] as num).toInt();
    final hasOrders = (visit['orderCount'] as num) > 0;
    final pendingDelivery = (visit['pendingDelivery'] as num? ?? 0) > 0;
    final heading = switch (status) {
      'bill_requested' => widget.staff ? 'Pide la cuenta' : 'Pago solicitado',
      'paid' => 'Pagada',
      _ => widget.staff ? 'Ocupada' : 'Por pagar',
    };
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = switch (status) {
      'bill_requested' => colors.warning,
      'paid' => colors.success,
      _ => colors.occupied,
    };
    final cta = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
    );
    final primary = widget.staff
        ? switch ((status, method)) {
            ('bill_requested', final String value) => FilledButton(
              style: cta,
              onPressed: busy || pendingDelivery
                  ? null
                  : () => pay('$path/pay', total, value),
              child: Text(
                total == 0 ? 'Confirmar saldo cero' : 'Confirmar pago',
              ),
            ),
            ('paid', _) => FilledButton(
              style: cta,
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
        : hasOrders && status == 'open'
        ? FilledButton(
            style: cta,
            onPressed: busy ? null : chooseMethod,
            child: const Text('Pagar'),
          )
        : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showSummary) ...[
              Text(
                widget.staff ? visit['label'] as String : 'Resumen de consumo',
                style: theme.textTheme.titleLarge,
              ),
              if (!waitingForPayment) ...[
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
                      Chip(
                        label: Text(
                          'Saldo por revisar',
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Text(
                status == 'paid' ? 'Total pagado' : 'Total a pagar',
                style: theme.textTheme.labelLarge,
              ),
              Text(
                clp(total),
                style: theme.textTheme.displaySmall?.copyWith(
                  color: colors.price,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 8),
            _AmountLine(
              label: 'Subtotal',
              amount: (visit['subtotal'] as num).toInt(),
            ),
            if ((visit['percent'] as num? ?? 0) > 0)
              _AmountLine(
                label: "Descuento (${visit['percent']} %)",
                amount: (visit['discount'] as num).toInt(),
              ),
            const SizedBox(height: 12),
            if (method != null && !waitingForPayment)
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
            if (waitingForPayment) ...[
              const SizedBox(height: 14),
              _PaymentOnTheWay(accent: accent, method: method),
            ],
            if (callId != null)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('Llamó al mesero'),
              ),
            if (primary != null) ...[
              const SizedBox(height: 14),
              if (widget.staff && status == 'bill_requested' && pendingDelivery)
                const Text(
                  'Marca los pedidos como entregados para confirmar el pago.',
                ),
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
                          child: const Text('Marcar atendida'),
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
                            review
                                ? 'Quitar marca'
                                : 'Marcar saldo por revisar',
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
                          child: const Text('Descargar resumen (PDF)'),
                        ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentOnTheWay extends StatelessWidget {
  const _PaymentOnTheWay({required this.accent, this.method});

  final Color accent;
  final String? method;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: .35)),
          color: Color.alphaBlend(
            accent.withValues(alpha: .10),
            colors.surface,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: .14),
              ),
              child: Icon(_paymentIcon(method), color: accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'El personal va a tu mesa',
                    style: theme.textTheme.titleMedium?.copyWith(color: accent),
                  ),
                  if (method != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      paymentMethods[method] ?? '',
                      style: theme.textTheme.titleSmall,
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    'Pagas en la mesa y recibes tu boleta.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountLine extends StatelessWidget {
  const _AmountLine({
    required this.label,
    this.amount,
    this.text,
    this.major = false,
  });

  final String label;
  final int? amount;
  final String? text;
  final bool major;

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
        Text(
          text ?? clp(amount!),
          style: major
              ? Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.price,
                  fontWeight: FontWeight.w800,
                )
              : null,
        ),
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
              ? 'El personal ya recibió tu llamado.'
              : paid
              ? 'La cuenta ya está pagada.'
              : 'Alguien del personal irá a tu mesa.');
      return AlertDialog(
        title: const Text('¿Llamar al mesero?'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: summary == null || sending || pending || paid
                ? null
                : call,
            child: Text(
              sending
                  ? 'Enviando…'
                  : pending
                  ? 'Llamado enviado'
                  : 'Llamar',
            ),
          ),
        ],
      );
    },
  );
}
