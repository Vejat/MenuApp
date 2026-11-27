import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'restaurant.dart';
import 'api.dart';
import 'checkout.dart';
import 'guest_ready_feedback.dart';
import 'night_theme.dart';
import 'orders.dart';
import 'products.dart';

void main() => runApp(const MenuApp());

class MenuApp extends StatelessWidget {
  const MenuApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MenuApp',
    theme: appTheme(Brightness.light),
    darkTheme: appTheme(Brightness.dark),
    themeMode: ThemeMode.system,
    debugShowCheckedModeBanner: false,
    home: kIsWeb
        ? Uri.base.queryParameters['personal'] == '1'
            ? const RestaurantPage()
            : GuestPage(
                token: Uri.base.queryParameters['visita'],
                tableToken: Uri.base.queryParameters['mesa'],
              )
        : const RestaurantPage(),
  );
}

class GuestPage extends StatefulWidget {
  const GuestPage({super.key, required this.token, this.tableToken});

  final String? token;
  final String? tableToken;

  @override
  State<GuestPage> createState() => _GuestPageState();
}

class _GuestPageState extends State<GuestPage> {
  final api = Api();
  Future<Map<String, dynamic>>? visit;

  @override
  void initState() {
    super.initState();
    if (widget.token != null || widget.tableToken != null) visit = connect();
  }

  Future<Map<String, dynamic>> connect() async {
    final result = await api.request(
      '/guest/session',
      body: widget.tableToken == null
          ? {'qrToken': widget.token}
          : {'tableToken': widget.tableToken},
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
                if (widget.token == null && widget.tableToken == null) {
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

final _ctaStyle = FilledButton.styleFrom(
  minimumSize: const Size.fromHeight(52),
  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
  padding: const EdgeInsets.symmetric(horizontal: 20),
);

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
  String? discountError;
  Map<String, dynamic>? pendingOrder;

  String get savedCode => summary['code'] as String? ?? '';
  String get code => savedCode.isEmpty ? selectedCode : savedCode;
  int get percent =>
      savedCode.isEmpty ? selectedPercent : summary['percent'] as int;
  bool get canOrder => (summary['status'] ?? 'open') == 'open';

  StreamSubscription<Map<String, dynamic>>? _alerts;
  final _readyFeedback = GuestReadyFeedback();

  @override
  void initState() {
    super.initState();
    if (widget.api.session == null) return;
    _alerts = widget.api.watchGuestAlerts().listen((alert) {
      if (!mounted || alert['type'] != 'order_ready') return;
      final id = alert['id'] as int;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
          content: Text('Tu pedido #$id está listo. Te lo llevan a la mesa.'),
          action: SnackBarAction(
            label: 'Ver',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => AlertDetailPage(
                  api: widget.api,
                  type: 'order_ready',
                  id: '$id',
                  staff: false,
                ),
              ),
            ),
          ),
        ),
      );
      _readyFeedback.notify();
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    unawaited(_alerts?.cancel());
    _readyFeedback.dispose();
    discountInput.dispose();
    super.dispose();
  }

  Future<void> applyDiscount() async {
    if (loading || pendingOrder != null) return;
    final input = discountInput.text.trim();
    if (input.isEmpty) {
      setState(() => discountError = 'Escribe el código.');
      return;
    }
    setState(() {
      loading = true;
      discountError = null;
    });
    try {
      final response = await widget.api.request(
        '/guest/discount',
        body: {'code': input},
      );
      if (!mounted) return;
      setState(() {
        selectedCode = response['code'] as String;
        selectedPercent = response['percent'] as int;
        summary = response['summary'] as Map<String, dynamic>;
      });
    } catch (error) {
      if (mounted) setState(() => discountError = apiMessage(error));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void removeDiscount() => setState(() {
    selectedCode = '';
    selectedPercent = 0;
    discountInput.clear();
    discountError = null;
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
    _readyFeedback.enableAudio();
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
          await review();
        }
        if (mounted) setState(() => notice = error.message);
      } else {
        setState(
          () => notice = 'No sabemos si llegó tu pedido. Toca Reintentar: no se duplicará.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => notice = 'No sabemos si llegó tu pedido. Toca Reintentar: no se duplicará.',
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
      final current = result['summary'] as Map<String, dynamic>? ?? summary;
      final prices = {
        for (final product in updated) product['id']: product['price'],
      };
      setState(() {
        if (products.any(
          (product) =>
              cart.containsKey(product['id']) &&
              prices[product['id']] != product['price'],
        )) {
          notice = 'Un plato cambió de precio o se agotó. Revisa el carrito antes de enviar.';
        }
        cart.removeWhere((id, _) => !prices.containsKey(id));
        products = updated;
        summary = current;
      });
      if (savedCode.isEmpty && selectedCode.isNotEmpty && canOrder) {
        try {
          final quote = await widget.api.request(
            '/guest/discount',
            body: {'code': selectedCode},
          );
          if (!mounted) return;
          setState(() {
            selectedCode = quote['code'] as String;
            selectedPercent = quote['percent'] as int;
            summary = quote['summary'] as Map<String, dynamic>;
          });
        } on ApiException catch (error) {
          if (error.status != 409) rethrow;
          if (!mounted) return;
          setState(() {
            selectedCode = '';
            selectedPercent = 0;
            discountError = apiMessage(error);
          });
        }
      }
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
    final colors = Theme.of(context).colorScheme;
    final add =
        disabled ||
            quantity >= 99 ||
            (!cart.containsKey(id) && cart.length >= 50)
        ? null
        : () => change(id, 1);
    if (quantity == 0) {
      return IconButton.filledTonal(
        tooltip: 'Agregar',
        onPressed: add,
        icon: const Icon(Icons.add),
      );
    }
    final small = IconButton.styleFrom(
      minimumSize: const Size(36, 36),
      maximumSize: const Size(36, 36),
      padding: EdgeInsets.zero,
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.secondaryContainer,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.filled(
              style: small,
              tooltip: 'Quitar uno',
              onPressed: disabled ? null : () => change(id, -1),
              icon: const Icon(Icons.remove, size: 18),
            ),
            SizedBox(
              width: 32,
              child: Text(
                '$quantity',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton.filled(
              style: small,
              tooltip: 'Agregar uno',
              onPressed: add,
              icon: const Icon(Icons.add, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget catalogGrid(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final product in products)
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product['name'] as String,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          clp(product['price'] as int),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.price,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  quantityControls(product),
                ],
              ),
            ),
          ),
      ],
    );
  }

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
    final previousSubtotal = (summary['subtotal'] as num?)?.toInt() ?? 0;
    final visitSubtotal = previousSubtotal + total;
    final discount = (visitSubtotal * percent + 50) ~/ 100;
    final viewingOrders = tab == 1 || tab == 2;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.label,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          TextButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => GuestHelpDialog(api: widget.api),
            ),
            icon: const Icon(Icons.notifications_outlined),
            label: const Text('Mesero'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ScreenColumn(
        child: viewingOrders
            ? OrdersPage(api: widget.api, embedded: true, account: tab == 1)
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (loading) const LinearProgressIndicator(),
                  if (notice != null)
                    Card(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      child: ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: Text(notice!),
                      ),
                    ),
                  SectionHeading(
                    reviewing ? 'Carrito' : 'Carta',
                    description: reviewing
                        ? (count == 0
                              ? null
                              : count == 1
                              ? '1 plato'
                              : '$count platos')
                        : canOrder && products.isNotEmpty
                        ? 'Toca + para agregar. Revisas todo antes de enviar.'
                        : null,
                  ),
                  if (reviewing && !canOrder)
                    const Text(
                      'Ya pediste la cuenta. Para pedir algo más, avísale al personal.',
                    ),
                  if (visible.isEmpty)
                    Text(
                      reviewing
                          ? 'Tu carrito está vacío. Agrega platos desde la Carta.'
                          : 'La carta aún no tiene platos disponibles.',
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
                  if (reviewing && count > 0) ...[
                    const SizedBox(height: 8),
                    discountCard(context),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            amountRow(context, 'Este pedido', clp(total)),
                            if (percent > 0 && previousSubtotal > 0)
                              amountRow(
                                context,
                                'Pedidos anteriores',
                                clp(previousSubtotal),
                              ),
                            if (percent > 0)
                              amountRow(
                                context,
                                'Descuento ($percent %)',
                                '−${clp(discount)}',
                                accent: true,
                              ),
                            const Divider(height: 16),
                            amountRow(
                              context,
                              percent == 0
                                  ? 'Total de este pedido'
                                  : previousSubtotal == 0
                                  ? 'Total'
                                  : 'Total de la mesa',
                              clp(
                                percent == 0 ? total : visitSubtotal - discount,
                              ),
                              major: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (count > 0 && (reviewing || tab == 0))
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: reviewing
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FilledButton(
                              style: _ctaStyle,
                              onPressed: loading || !canOrder ? null : confirm,
                              child: Text(
                                pendingOrder == null
                                    ? 'Enviar pedido'
                                    : 'Reintentar',
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Llega a cocina y lo sigues en Pedidos.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        )
                      : FilledButton(
                          style: _ctaStyle,
                          onPressed: loading ? null : () => selectTab(3),
                          child: Row(
                            children: [
                              Expanded(child: Text('Ver carrito · $count')),
                              Text(clp(total)),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          NavigationBar(
            // Orden visible: Carta, Carrito, Pedidos, Cuenta.
            selectedIndex: const [0, 3, 2, 1][tab],
            onDestinationSelected: (index) =>
                selectTab(const [0, 3, 2, 1][index]),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.restaurant_menu),
                label: 'Carta',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: const Icon(Icons.shopping_bag_outlined),
                ),
                label: 'Carrito',
              ),
              const NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                label: 'Pedidos',
              ),
              const NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                label: 'Cuenta',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget discountCard(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final enabled = !loading && pendingOrder == null && canOrder;
    return Card(
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  code.isEmpty
                      ? Icons.local_offer_outlined
                      : Icons.check_circle_outline,
                  color: code.isEmpty ? colors.secondary : colors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    code.isEmpty ? '¿Tienes un descuento?' : 'Código aplicado',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (code.isEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: discountInput,
                      enabled: enabled,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.done,
                      onSubmitted: enabled ? (_) => applyDiscount() : null,
                      decoration: InputDecoration(
                        labelText: 'Código de descuento',
                        errorText: discountError,
                        errorMaxLines: 3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: enabled ? applyDiscount : null,
                    child: const Text('Aplicar'),
                  ),
                ],
              )
            else
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(
                    '$code · $percent %',
                    style: TextStyle(color: colors.primary),
                  ),
                  if (savedCode.isEmpty)
                    TextButton(
                      onPressed: enabled ? removeDiscount : null,
                      child: const Text('Quitar'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget amountRow(
    BuildContext context,
    String label,
    String value, {
    bool accent = false,
    bool major = false,
  }) {
    final theme = Theme.of(context);
    final color = accent
        ? theme.colorScheme.success
        : major
        ? theme.colorScheme.price
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: major ? theme.textTheme.titleMedium : null,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style:
                (major
                        ? theme.textTheme.headlineSmall
                        : theme.textTheme.titleSmall)
                    ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
