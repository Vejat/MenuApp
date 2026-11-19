import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'restaurant.dart';
import 'api.dart';
import 'checkout.dart';
import 'night_theme.dart';
import 'orders.dart';
import 'products.dart';

void main() => runApp(const MenuApp());

class MenuApp extends StatelessWidget {
  const MenuApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MenuApp',
    theme: nightTheme(),
    debugShowCheckedModeBanner: false,
    home: kIsWeb
        ? GuestPage(token: Uri.base.queryParameters['visita'])
        : const RestaurantPage(),
  );
}

class GuestPage extends StatefulWidget {
  const GuestPage({super.key, required this.token});

  final String? token;

  @override
  State<GuestPage> createState() => _GuestPageState();
}

class _GuestPageState extends State<GuestPage> {
  final api = Api();
  Future<Map<String, dynamic>>? visit;

  @override
  void initState() {
    super.initState();
    if (widget.token != null) visit = connect();
  }

  Future<Map<String, dynamic>> connect() async {
    final result = await api.request(
      '/guest/session',
      body: {'qrToken': widget.token},
    );
    api.session = result['session'] as String;
    final results = await Future.wait([
      api.request('/guest/visit'),
      api.request('/guest/catalog'),
    ]);
    return {...results[0], ...results[1]};
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: visit,
    builder: (context, snapshot) {
      final data = snapshot.data;
      if (data != null && !snapshot.hasError) {
        return GuestCatalog(
          label: data['label'] as String,
          initialProducts: (data['products'] as List).cast<Product>(),
          initialSummary: data['summary'] as Map<String, dynamic>? ?? const {},
          api: api,
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('MenuApp')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Builder(
              builder: (context) {
                if (widget.token == null) {
                  return const Text('Escanea el QR de tu mesa para comenzar.');
                }
                if (snapshot.hasError) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(apiMessage(snapshot.error)),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => setState(() => visit = connect()),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  );
                }
                return const CircularProgressIndicator();
              },
            ),
          ),
        ),
      );
    },
  );
}

class GuestCatalog extends StatefulWidget {
  const GuestCatalog({
    super.key,
    required this.label,
    required this.initialProducts,
    required this.initialSummary,
    required this.api,
  });

  final String label;
  final List<Product> initialProducts;
  final Map<String, dynamic> initialSummary;
  final Api api;

  @override
  State<GuestCatalog> createState() => _GuestCatalogState();
}

class _GuestCatalogState extends State<GuestCatalog> {
  late List<Product> products = widget.initialProducts;
  late Map<String, dynamic> summary = widget.initialSummary;
  final discountInput = TextEditingController();
  String selectedCode = '';
  int selectedPercent = 0;
  final cart = <int, int>{};
  int tab = 0;
  bool get reviewing => tab == 3;
  bool loading = false;
  String? notice;
  Map<String, dynamic>? pendingOrder;

  String get savedCode => summary['code'] as String? ?? '';
  String get code => savedCode.isEmpty ? selectedCode : savedCode;
  int get percent =>
      savedCode.isEmpty ? selectedPercent : summary['percent'] as int;
  bool get canOrder => (summary['status'] ?? 'open') == 'open';

  @override
  void dispose() {
    discountInput.dispose();
    super.dispose();
  }

  Future<void> applyDiscount() async {
    if (loading || pendingOrder != null) return;
    setState(() {
      loading = true;
      notice = null;
    });
    try {
      final response = await widget.api.request(
        '/guest/discount',
        body: {'code': discountInput.text.trim()},
      );
      if (!mounted) return;
      setState(() {
        selectedCode = response['code'] as String;
        selectedPercent = response['percent'] as int;
        summary = response['summary'] as Map<String, dynamic>;
      });
    } catch (error) {
      if (mounted) setState(() => notice = apiMessage(error));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void removeDiscount() => setState(() {
    selectedCode = '';
    selectedPercent = 0;
    discountInput.clear();
    notice = null;
  });

  void change(int id, int delta) {
    if (loading || pendingOrder != null) return;
    setState(() {
      final count = (cart[id] ?? 0) + delta;
      if (count <= 0) {
        cart.remove(id);
      } else if (count <= 99 && (cart.containsKey(id) || cart.length < 50)) {
        cart[id] = count;
      }
    });
  }

  void selectTab(int value) {
    if (loading || value == tab) return;
    if (value == 3 && pendingOrder == null) {
      review();
    } else {
      setState(() {
        tab = value;
        if (pendingOrder == null) notice = null;
      });
    }
  }

  Future<void> confirm() async {
    if (loading || cart.isEmpty || !canOrder) return;
    final random = Random.secure();
    pendingOrder ??= {
      'key': List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join(),
      'code': code,
      'percent': percent,
      'lines': [
        for (final product in products.where(
          (product) => cart.containsKey(product['id']),
        ))
          {
            'id': product['id'],
            'quantity': cart[product['id']],
            'price': product['price'],
          },
      ],
    };
    setState(() {
      loading = true;
      notice = null;
    });
    try {
      await widget.api.request('/guest/orders', body: pendingOrder);
      if (!mounted) return;
      setState(() {
        cart.clear();
        pendingOrder = null;
        tab = 2;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.status >= 400 && error.status < 500) {
        pendingOrder = null;
        if (error.status == 409) {
          if (selectedCode.isNotEmpty) removeDiscount();
          await review();
        }
        if (mounted) setState(() => notice = error.message);
      } else {
        setState(
          () => notice =
              'No pudimos confirmar el envío. Reintenta el mismo pedido.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => notice =
              'No pudimos confirmar el envío. Reintenta el mismo pedido.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> review() async {
    setState(() {
      tab = 3;
      loading = true;
      notice = null;
    });
    try {
      final result = await widget.api.request('/guest/catalog');
      if (!mounted) return;
      final updated = (result['products'] as List).cast<Product>();
      final prices = {
        for (final product in updated) product['id']: product['price'],
      };
      setState(() {
        if (products.any(
          (product) =>
              cart.containsKey(product['id']) &&
              prices[product['id']] != product['price'],
        )) {
          notice = 'Cambió el precio o la disponibilidad. Revisa el carrito actualizado.';
        }
        cart.removeWhere((id, _) => !prices.containsKey(id));
        products = updated;
        summary = result['summary'] as Map<String, dynamic>? ?? summary;
      });
    } catch (error) {
      if (mounted) setState(() => notice = apiMessage(error));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget quantityControls(Product product) {
    final id = product['id'] as int;
    final quantity = cart[id] ?? 0;
    final disabled = loading || pendingOrder != null;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (quantity > 0) ...[
          IconButton(
            tooltip: 'Quitar una unidad',
            onPressed: disabled ? null : () => change(id, -1),
            icon: const Icon(Icons.remove),
          ),
          Text('$quantity'),
        ],
        IconButton.filled(
          tooltip: 'Agregar una unidad',
          onPressed:
              disabled ||
                  quantity >= 99 ||
                  (!cart.containsKey(id) && cart.length >= 50)
              ? null
              : () => change(id, 1),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }

  Widget catalogGrid(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 350 ? 2 : 1;
      final compactWidth =
          (constraints.maxWidth - (columns - 1) * 12) / columns;
      final theme = Theme.of(context);
      return Wrap(
        spacing: 12,
        runSpacing: 2,
        children: [
          for (final (index, product) in products.indexed)
            SizedBox(
              width: index == 0 ? constraints.maxWidth : compactWidth,
              child: Card(
                color: index == 0 ? theme.colorScheme.secondaryContainer : null,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['name'] as String,
                        style: theme.textTheme.titleLarge,
                      ),
                      Text(
                        clp(product['price'] as int),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      quantityControls(product),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final visible = reviewing
        ? products.where((product) => cart.containsKey(product['id']))
        : products;
    final total = products.fold<int>(
      0,
      (sum, product) =>
          sum + (cart[product['id']] ?? 0) * (product['price'] as int),
    );
    final count = cart.values.fold<int>(0, (sum, quantity) => sum + quantity);
    final visitSubtotal = ((summary['subtotal'] as num?)?.toInt() ?? 0) + total;
    final discount = (visitSubtotal * percent + 50) ~/ 100;
    final viewingOrders = tab == 1 || tab == 2;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'MenuApp · ${widget.label}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => GuestHelpDialog(api: widget.api),
            ),
            child: const Text('Ayuda'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: viewingOrders
              ? OrdersPage(api: widget.api, embedded: true, account: tab == 1)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (loading) const LinearProgressIndicator(),
                    if (notice != null) Text(notice!),
                    Text(
                      reviewing ? 'Revisa tu pedido' : 'Carta',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    if (reviewing && !canOrder)
                      const Text(
                        'La cuenta está en proceso de cobro. Pide al personal que la reabra para agregar pedidos.',
                      ),
                    if (visible.isEmpty)
                      Text(
                        reviewing
                            ? 'El carrito está vacío.'
                            : 'Todavía no hay platos disponibles.',
                      ),
                    if (!reviewing && visible.isNotEmpty) catalogGrid(context),
                    if (reviewing)
                      for (final product in visible)
                        Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            title: Text(product['name'] as String),
                            subtitle: Text(
                              '${clp(product['price'] as int)} c/u · ${clp((product['price'] as int) * cart[product['id']]!)}',
                            ),
                            trailing: quantityControls(product),
                          ),
                        ),
                    if (reviewing && visible.isNotEmpty && savedCode.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: discountInput,
                                enabled: !loading && pendingOrder == null,
                                decoration: const InputDecoration(
                                  labelText: 'Código de descuento',
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: loading || pendingOrder != null
                                  ? null
                                  : applyDiscount,
                              child: const Text('Aplicar'),
                            ),
                          ],
                        ),
                      ),
                    if (reviewing && code.isNotEmpty)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('$code · $percent%'),
                        trailing: savedCode.isEmpty
                            ? TextButton(
                                onPressed: loading || pendingOrder != null
                                    ? null
                                    : removeDiscount,
                                child: const Text('Quitar código'),
                              )
                            : null,
                      ),
                  ],
                ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (reviewing || (tab == 0 && count > 0))
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: reviewing
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            percent > 0
                                ? 'Total previsto de la visita'
                                : 'Total del carrito',
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            clp(percent > 0 ? visitSubtotal - discount : total),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          if (percent > 0)
                            Text(
                              'Carrito: ${clp(total)} · Descuento: ${clp(discount)}',
                              textAlign: TextAlign.center,
                            ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: loading || count == 0 || !canOrder
                                ? null
                                : confirm,
                            child: Text(
                              pendingOrder == null
                                  ? 'Confirmar pedido'
                                  : 'Reintentar envío',
                            ),
                          ),
                        ],
                      )
                    : FilledButton(
                        onPressed: loading ? null : () => selectTab(3),
                        child: Text('Ver carrito ($count) · ${clp(total)}'),
                      ),
              ),
            ),
          NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: selectTab,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.restaurant_menu),
                label: 'Carta',
              ),
              const NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                label: 'Cuenta',
              ),
              const NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                label: 'Pedidos',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: const Icon(Icons.shopping_bag_outlined),
                ),
                label: 'Carrito',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
