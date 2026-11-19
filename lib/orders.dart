import 'package:flutter/material.dart';

import 'api.dart';
import 'checkout.dart';
import 'products.dart';

const _steps = ['Recibido', 'En preparación', 'Listo', 'Entregado'];
const _stepIcons = [
  Icons.receipt_long_outlined,
  Icons.restaurant_outlined,
  Icons.room_service_outlined,
  Icons.task_alt,
];

class OrdersPage extends StatefulWidget {
  const OrdersPage({
    super.key,
    required this.api,
    this.staff = false,
    this.account = false,
    this.embedded = false,
  });

  final Api api;
  final bool staff;
  final bool account;
  final bool embedded;

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  late final path = widget.staff ? '/staff/orders' : '/guest/orders';
  late final updates = widget.api.watchOrders(path);
  final updating = <int>{};

  Future<void> advance(int id, String status) async {
    setState(() => updating.add(id));
    try {
      await widget.api.request('$path/$id/advance', body: {'status': status});
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiMessage(error))));
      }
    } finally {
      if (mounted) setState(() => updating.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.account
        ? (widget.staff ? 'Cuentas' : 'Mi cuenta')
        : (widget.staff ? 'Pedidos' : 'Mis pedidos');
    final feed = StreamBuilder(
      stream: updates,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          return Center(
            child: Text(
              error is ApiException && error.status == 401
                  ? error.message
                  : 'Reconectando a los pedidos…',
            ),
          );
        }
        final rows = snapshot.data?['orders'] as List?;
        if (rows == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final orders = rows.cast<Map<String, dynamic>>();
        final visits = (snapshot.data?['visits'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
        final summary = snapshot.data?['summary'] as Map<String, dynamic>?;
        final visibleVisits = visits
            .where(
              (visit) => widget.account
                  ? visit['orderCount'] != 0 || visit['review'] == true
                  : visit['callId'] != null,
            )
            .toList();
        if (widget.account) {
          int priority(Object? status) => switch (status) {
            'bill_requested' => 0,
            'paid' => 2,
            _ => 1,
          };
          visibleVisits.sort((a, b) {
            final order = priority(a['status'])
                .compareTo(priority(b['status']));
            return order == 0
                ? (a['label'] as String).compareTo(b['label'] as String)
                : order;
          });
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.embedded) ...[
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
            ],
            if (widget.account && summary != null && summary['orderCount'] != 0)
              VisitCheckout(
                key: ValueKey(summary['id']),
                api: widget.api,
                visit: summary,
                staff: false,
              ),
            if (widget.account && !widget.staff && summary?['orderCount'] == 0)
              const Card(
                child: ListTile(
                  title: Text(
                    'Tu cuenta se habilita después del primer pedido.',
                  ),
                ),
              ),
            for (final visit in visibleVisits)
              VisitCheckout(
                key: ValueKey(visit['id']),
                api: widget.api,
                visit: visit,
                staff: true,
                alertsOnly: !widget.account,
              ),
            if (widget.staff && widget.account && visibleVisits.isEmpty)
              const Center(child: Text('Todavía no hay cuentas.')),
            if (orders.isEmpty && !widget.account)
              const Center(child: Text('Todavía no hay pedidos.')),
            if (widget.account && !widget.staff && orders.isNotEmpty)
              Card(
                child: ExpansionTile(
                  title: const Text('Detalle del consumo'),
                  subtitle: Text(
                    orders.length == 1
                        ? '1 pedido'
                        : '${orders.length} pedidos',
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final order in orders) ...[
                      const Divider(),
                      Text(
                        'Pedido #${order['id']}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      for (final line in order['lines'] as List)
                        Text(
                          "${line['quantity']} × ${line['name']} · ${clp((line['price'] as num).toInt())} c/u",
                        ),
                    ],
                  ],
                ),
              ),
            if (!widget.account)
              for (final order in orders) orderCard(order),
          ],
        );
      },
    );
    return widget.embedded
        ? feed
        : Scaffold(
            appBar: AppBar(title: Text(title)),
            body: feed,
          );
  }

  Widget orderCard(Map<String, dynamic> order) {
    final id = order['id'] as int;
    final status = order['status'] as String;
    final (step, action) = switch (status) {
      'received' => (0, 'Empezar preparación'),
      'preparing' => (1, 'Marcar listo'),
      'ready' => (2, 'Marcar entregado'),
      _ => (3, null),
    };
    final time = DateTime.parse(order['createdAt'] as String).toLocal();
    final timeLabel = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(time));
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      key: ValueKey(id),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  widget.staff
                      ? "${order['table']} · Pedido #$id"
                      : 'Pedido #$id',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  timeLabel,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _OrderProgress(step: step),
            const Divider(height: 24),
            for (final line in order['lines'] as List)
              Text("${line['quantity']} × ${line['name']}"),
            const SizedBox(height: 6),
            Text(
              'Total: ${clp((order['total'] as num).toInt())}',
              style: theme.textTheme.titleMedium,
            ),
            if (widget.staff && action != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: updating.contains(id)
                      ? null
                      : () => advance(id, status),
                  child: Text(updating.contains(id) ? 'Actualizando…' : action),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrderProgress extends StatelessWidget {
  const _OrderProgress({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    final accent = switch (step) {
      0 => colors.secondary,
      1 => const Color(0xffffce8b),
      2 => colors.primary,
      _ => const Color(0xffa6e6c0),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: duration,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              accent.withValues(alpha: .12),
              colors.surface,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: .55)),
          ),
          child: Semantics(
            liveRegion: true,
            child: Row(
              children: [
                Icon(_stepIcons[step], color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _steps[step],
                    style: theme.textTheme.titleLarge?.copyWith(color: accent),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ExcludeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < _steps.length; index++)
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: duration,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: index <= step ? accent : colors.outlineVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _steps[index],
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: index == step
                              ? accent
                              : colors.onSurfaceVariant,
                          fontWeight: index == step ? FontWeight.bold : null,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
