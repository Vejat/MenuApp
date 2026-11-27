import 'package:flutter/material.dart';

import 'api.dart';
import 'checkout.dart';
import 'night_theme.dart';
import 'products.dart';

const _steps = ['Recibido', 'En preparación', 'Listo', 'Entregado'];
const _stepIcons = [
  Icons.receipt_long_outlined,
  Icons.restaurant_outlined,
  Icons.room_service_outlined,
  Icons.task_alt,
];

int _orderStep(Object? status) => switch (status) {
  'received' => 0,
  'preparing' => 1,
  'ready' => 2,
  _ => 3,
};

Color _stepColor(ColorScheme colors, int step) => switch (step) {
  0 => colors.secondary,
  1 => colors.preparing,
  2 => colors.brightness == Brightness.dark ? colors.primary : colors.success,
  _ => colors.onSurfaceVariant,
};

String _orderTime(BuildContext context, Map<String, dynamic> order) {
  final time = DateTime.parse(order['createdAt'] as String).toLocal();
  return MaterialLocalizations.of(context)
      .formatTimeOfDay(TimeOfDay.fromDateTime(time));
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({
    super.key,
    required this.api,
    this.staff = false,
    this.account = false,
    this.embedded = false,
    this.table,
  });

  final Api api;
  final bool staff;
  final bool account;
  final bool embedded;
  final String? table;

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  late final path = widget.staff ? '/staff/orders' : '/guest/orders';
  late final updates = widget.api
      .watchOrders(path)
      .asBroadcastStream(onCancel: (subscription) => subscription.cancel());

  @override
  Widget build(BuildContext context) {
    final title = widget.account
        ? (widget.staff ? 'Cuentas' : 'Cuenta')
        : (widget.staff ? widget.table ?? 'Pedidos' : 'Pedidos');
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
        final orders = rows
            .cast<Map<String, dynamic>>()
            .where(
              (order) => widget.table == null || order['table'] == widget.table,
            )
            .toList();
        final visits = (snapshot.data?['visits'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
        final summary = snapshot.data?['summary'] as Map<String, dynamic>?;
        final visibleVisits = visits
            .where(
              (visit) =>
                  (widget.table == null || visit['label'] == widget.table) &&
                  (widget.account
                      ? visit['orderCount'] != 0 || visit['review'] == true
                      : visit['callId'] != null),
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
            if (widget.embedded) SectionHeading(title),
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
                    'Aquí verás tu cuenta después del primer pedido.',
                  ),
                ),
              ),
            for (final visit in visibleVisits)
              if (widget.account)
                accountCard(
                  context,
                  visit,
                  orders.where((order) => order['visitId'] == visit['id']),
                )
              else
                VisitCheckout(
                  key: ValueKey(visit['id']),
                  api: widget.api,
                  visit: visit,
                  staff: true,
                  alertsOnly: true,
                ),
            if (widget.staff && widget.account && visibleVisits.isEmpty)
              const Center(child: Text('Sin cuentas abiertas.')),
            if (orders.isEmpty && !widget.account)
              Center(
                child: Text(
                  widget.staff
                      ? 'Sin pedidos por ahora. Los nuevos aparecen aquí solos.'
                      : 'Aquí verás tus pedidos cuando envíes el primero.',
                  textAlign: TextAlign.center,
                ),
              ),
            if (widget.account && !widget.staff && orders.isNotEmpty)
              _ConsumptionDetails(orders: orders),
            if (!widget.account)
              if (widget.staff && widget.table == null)
                ...groupedOrders(orders)
              else
                for (final order in orders) orderCard(order),
          ],
        );
      },
    );
    return widget.embedded
        ? feed
        : Scaffold(
            appBar: AppBar(title: Text(title)),
            body: ScreenColumn(child: feed),
          );
  }

  Widget accountCard(
    BuildContext context,
    Map<String, dynamic> visit,
    Iterable<Map<String, dynamic>> orders,
  ) {
    final colors = Theme.of(context).colorScheme;
    final (label, color) = switch (visit['status']) {
      'bill_requested' => ('Pide la cuenta', colors.warning),
      'paid' => ('Pagada', colors.success),
      _ => ('Ocupada', colors.occupied),
    };
    final method = paymentMethods[visit['method']];
    return Card(
      key: PageStorageKey(visit['id']),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(child: Text(visit['label'] as String)),
            const SizedBox(width: 8),
            Text(
              clp((visit['total'] as num).toInt()),
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: colors.price, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 5,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusLabel(label, color: color),
              if (method != null) Text(method),
              if (visit['review'] == true)
                StatusLabel('Saldo por revisar', color: colors.error),
            ],
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
        children: [
          if (orders.isNotEmpty)
            _ConsumptionDetails(orders: orders, initiallyExpanded: true),
          VisitCheckout(
            api: widget.api,
            visit: visit,
            staff: true,
            showSummary: false,
          ),
        ],
      ),
    );
  }

  Iterable<Widget> groupedOrders(List<Map<String, dynamic>> orders) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final order in orders) {
      groups.putIfAbsent(order['table'] as String, () => []).add(order);
    }
    final sorted = groups.entries.toList();
    sorted.sort((a, b) {
      final aPending = a.value.any((order) => order['status'] != 'delivered');
      final bPending = b.value.any((order) => order['status'] != 'delivered');
      return aPending == bPending ? 0 : (aPending ? -1 : 1);
    });
    return sorted.map((group) {
      final count = group.value.length;
      final pending = group.value
          .where((order) => order['status'] != 'delivered')
          .length;
      return Card(
        key: ValueKey(group.key),
        child: ExpansionTile(
          maintainState: true,
          leading: const Icon(Icons.table_restaurant_outlined),
          title: Text(group.key),
          subtitle: Text(
            "${count == 1 ? '1 pedido' : '$count pedidos'} · $pending por entregar",
          ),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 12),
          children: group.value.map(orderCard).toList(),
        ),
      );
    });
  }

  Widget orderCard(Map<String, dynamic> order) {
    final id = order['id'] as int;
    final step = _orderStep(order['status']);
    final units = (order['lines'] as List).fold<int>(
      0,
      (total, line) => total + (line['quantity'] as int),
    );
    final theme = Theme.of(context);
    final accent = _stepColor(theme.colorScheme, step);
    return Card(
      key: ValueKey(id),
      child: ListTile(
        title: Text('Pedido #$id'),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_orderTime(context, order)} · $units ${units == 1 ? 'plato' : 'platos'} · ${clp((order['total'] as num).toInt())}',
              ),
              const SizedBox(height: 4),
              StatusLabel(_steps[step], color: accent),
              if (!widget.staff) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var index = 0; index < _steps.length; index++)
                      Expanded(
                        child: Container(
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: index <= step
                                ? accent
                                : theme.colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        trailing: IconButton(
          tooltip: 'Ver detalle del pedido $id',
          onPressed: () => openOrder(order),
          icon: const Icon(Icons.chevron_right),
        ),
        onTap: () => openOrder(order),
      ),
    );
  }

  void openOrder(Map<String, dynamic> order) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: .9,
      child: _OrderDetail(
        api: widget.api,
        updates: updates,
        initialOrder: order,
        staff: widget.staff,
      ),
    ),
  );
}

class _ConsumptionDetails extends StatelessWidget {
  const _ConsumptionDetails({
    required this.orders,
    this.initiallyExpanded = false,
  });

  final Iterable<Map<String, dynamic>> orders;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      title: const Text('Detalle del consumo'),
      subtitle: Text(
        orders.length == 1 ? '1 pedido' : '${orders.length} pedidos',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final order in orders) ...[
          const Divider(),
          Text(
            'Pedido #${order['id']} · ${clp((order['total'] as num).toInt())}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final line in order['lines'] as List)
            Text(
              "${line['quantity']} × ${line['name']} · ${clp((line['price'] as num).toInt())} c/u",
            ),
        ],
      ],
    ),
  );
}

class AlertDetailPage extends StatefulWidget {
  const AlertDetailPage({
    super.key,
    required this.api,
    required this.type,
    required this.id,
    this.staff = true,
  });

  final Api api;
  final String type;
  final String id;
  final bool staff;

  @override
  State<AlertDetailPage> createState() => _AlertDetailPageState();
}

class _AlertDetailPageState extends State<AlertDetailPage> {
  late final updates = widget.api
      .watchOrders(widget.staff ? '/staff/orders' : '/guest/orders')
      .asBroadcastStream(onCancel: (subscription) => subscription.cancel());
  late final payment = widget.api.request('/staff/visits/${widget.id}/payment');

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.type) {
      'new_order' || 'order_ready' => 'Detalle del pedido',
      'bill_requested' => 'Cuenta de la mesa',
      'waiter_called' => 'Llamada al mesero',
      _ => 'Pago confirmado',
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ScreenColumn(
        child: widget.type == 'payment_confirmed'
            ? FutureBuilder(future: payment, builder: buildPayment)
            : StreamBuilder(stream: updates, builder: buildActiveDetail),
      ),
    );
  }

  Widget buildActiveDetail(
    BuildContext context,
    AsyncSnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (snapshot.hasError) return message(apiMessage(snapshot.error));
    final data = snapshot.data;
    if (data == null) return const Center(child: CircularProgressIndicator());
    if (widget.type == 'new_order' || widget.type == 'order_ready') {
      final order = (data['orders'] as List)
          .cast<Map<String, dynamic>>()
          .where((order) => '${order['id']}' == widget.id)
          .firstOrNull;
      return order == null
          ? message('Este pedido ya no está disponible.')
          : _OrderDetail(
              api: widget.api,
              updates: updates,
              initialOrder: order,
              staff: widget.staff,
              modal: false,
            );
    }
    final waiter = widget.type == 'waiter_called';
    final visit = (data['visits'] as List)
        .cast<Map<String, dynamic>>()
        .where((visit) => '${visit[waiter ? 'callId' : 'id']}' == widget.id)
        .firstOrNull;
    if (visit == null) {
      return message(
        waiter
            ? 'Esta llamada ya fue atendida o la mesa se cerró.'
            : 'Esta cuenta ya se cerró.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!waiter)
          _ConsumptionDetails(
            initiallyExpanded: true,
            orders: (data['orders'] as List).cast<Map<String, dynamic>>().where(
              (order) => order['visitId'] == visit['id'],
            ),
          ),
        VisitCheckout(
          api: widget.api,
          visit: visit,
          staff: true,
          alertsOnly: waiter,
        ),
      ],
    );
  }

  Widget buildPayment(
    BuildContext context,
    AsyncSnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (snapshot.hasError) return message(apiMessage(snapshot.error));
    final result = snapshot.data?['payment'] as Map<String, dynamic>?;
    if (result == null) return const Center(child: CircularProgressIndicator());
    final orders = (snapshot.data?['orders'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final subtotal = orders.fold(
      0,
      (total, order) => total + (order['total'] as num).toInt(),
    );
    final total = (result['total'] as num).toInt();
    final theme = Theme.of(context);
    final date = DateTime.parse(result['paidAt'] as String).toLocal();
    final local = MaterialLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeading(
                  result['label'] as String,
                  description: 'Total pagado',
                ),
                Text(
                  clp(total),
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  paymentMethods[result['method']] ?? 'Método sin registrar',
                ),
                Text(
                  '${local.formatShortDate(date)} · ${local.formatTimeOfDay(TimeOfDay.fromDateTime(date))}',
                ),
                if (result['paidBy'] != null)
                  Text('Confirmado por ${result['paidBy']}'),
                if (subtotal > total) ...[
                  const SizedBox(height: 12),
                  Text('Subtotal ${clp(subtotal)}'),
                  Text(
                    'Descuento ${result['code'] ?? ''} (${result['percent']} %) · −${clp(subtotal - total)}',
                  ),
                ],
              ],
            ),
          ),
        ),
        if (orders.isNotEmpty)
          _ConsumptionDetails(orders: orders, initiallyExpanded: true),
      ],
    );
  }

  Widget message(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

class _OrderDetail extends StatefulWidget {
  const _OrderDetail({
    required this.api,
    required this.updates,
    required this.initialOrder,
    required this.staff,
    this.modal = true,
  });

  final Api api;
  final Stream<Map<String, dynamic>> updates;
  final Map<String, dynamic> initialOrder;
  final bool staff;
  final bool modal;

  @override
  State<_OrderDetail> createState() => _OrderDetailState();
}

class _OrderDetailState extends State<_OrderDetail> {
  bool updating = false;
  String? error;

  Future<void> advance(int id, String status) async {
    setState(() {
      updating = true;
      error = null;
    });
    try {
      await widget.api.request(
        '/staff/orders/$id/advance',
        body: {'status': status},
      );
    } catch (failure) {
      if (mounted) setState(() => error = apiMessage(failure));
    } finally {
      if (mounted) setState(() => updating = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: widget.updates,
    initialData: {
      'orders': [widget.initialOrder],
    },
    builder: (context, snapshot) {
      final id = widget.initialOrder['id'] as int;
      final orders = snapshot.data?['orders'] as List?;
      final ordersById = {
        for (final item in orders ?? const []) item['id']: item,
      };
      final order = ordersById[id] as Map<String, dynamic>?;
      if (order == null) {
        return Center(
          child: Text(
            snapshot.hasError
                ? apiMessage(snapshot.error)
                : 'Este pedido ya no está disponible.',
          ),
        );
      }
      final status = order['status'] as String;
      final step = _orderStep(status);
      final action = [
        'Empezar preparación',
        'Marcar listo',
        'Marcar entregado',
        null,
      ][step];
      final theme = Theme.of(context);
      return SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Pedido #$id',
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
                if (widget.modal)
                  IconButton(
                    tooltip: 'Cerrar detalle',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            Text("${order['table']} · ${_orderTime(context, order)}"),
            const SizedBox(height: 16),
            _OrderProgress(step: step),
            const Divider(height: 28),
            Text('Productos', style: theme.textTheme.titleLarge),
            for (final line in order['lines'] as List)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text("${line['quantity']} × ${line['name']}"),
                subtitle: Text('${clp((line['price'] as num).toInt())} c/u'),
                trailing: Text(
                  clp(
                    (line['price'] as num).toInt() * (line['quantity'] as int),
                  ),
                ),
              ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text('Total', style: theme.textTheme.titleLarge),
                ),
                Text(
                  clp((order['total'] as num).toInt()),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.price,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            if (error != null)
              Text(error!, style: TextStyle(color: theme.colorScheme.error)),
            if (widget.staff && action != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onPressed: updating ? null : () => advance(id, status),
                child: Text(updating ? 'Actualizando…' : action),
              ),
            ],
          ],
        ),
      );
    },
  );
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
    final accent = _stepColor(colors, step);
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
