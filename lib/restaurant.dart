import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'api.dart';
import 'discounts.dart';
import 'night_theme.dart';
import 'orders.dart';
import 'order_alerts.dart';
import 'payment_history.dart';
import 'products.dart';

class RestaurantPage extends StatefulWidget {
  const RestaurantPage({super.key});

  @override
  State<RestaurantPage> createState() => _RestaurantPageState();
}

class _RestaurantPageState extends State<RestaurantPage> {
  static const storage = FlutterSecureStorage();
  static const sessionKey = 'restaurant_session_${Api.base}';
  final api = Api();
  final orderAlerts = OrderAlerts();
  final username = TextEditingController();
  final password = TextEditingController();
  List<Map<String, dynamic>> tables = [];
  String? role;
  String? error;
  bool busy = false;
  bool restoring = true;
  bool showTables = false;
  StreamSubscription<Map<String, dynamic>>? tablesSubscription;

  @override
  void initState() {
    super.initState();
    orderAlerts.onOpen(() => unawaited(openNotification()));
    restore();
  }

  Future<void> restore() async {
    await run(() async {
      api.session = await storage.read(key: sessionKey);
      if (api.session != null) await refresh();
    });
    if (mounted) setState(() => restoring = false);
  }

  @override
  void dispose() {
    unawaited(tablesSubscription?.cancel());
    orderAlerts.onOpen(null);
    orderAlerts.stop();
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (failure) {
      if (failure is ApiException && failure.status == 401) {
        await clearSession();
      }
      error = apiMessage(failure);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> refresh() async {
    final result = await api.request('/staff/tables');
    tables = (result['tables'] as List).cast<Map<String, dynamic>>();
    role = result['role'] as String;
    if (mounted) {
      orderAlerts.start(api);
      unawaited(openNotification());
    }
  }

  Future<void> openNotification() async {
    final session = api.session;
    if (role == null || session == null) return;
    final alert = await orderAlerts.takeOpenedAlert();
    if (!mounted || api.session != session || alert == null) return;
    final id = alert['id'];
    final type = alert['type'];
    final valid = switch (type) {
      'new_order' || 'waiter_called' => int.tryParse(id ?? '') != null,
      'bill_requested' ||
      'payment_confirmed' => RegExp(r'^[a-f0-9-]{36}$').hasMatch(id ?? ''),
      _ => false,
    };
    if (!valid || id == null || type == null) return;
    Navigator.of(context)
      ..popUntil((route) => route.isFirst)
      ..push<void>(
        MaterialPageRoute(
          builder: (_) => AlertDetailPage(api: api, type: type, id: id),
        ),
      );
  }

  Future<void> login() async {
    final result = await api.request(
      '/staff/login',
      body: {'username': username.text, 'password': password.text},
    );
    if (!mounted) return;
    final token = result['session'] as String;
    await storage.write(key: sessionKey, value: token);
    api.session = token;
    if (!mounted) return;
    TextInput.finishAutofillContext();
    password.clear();
    await refresh();
  }

  Future<void> logout() async {
    await api.request('/staff/logout', body: {});
    await clearSession();
  }

  Future<void> clearSession() async {
    stopTables();
    orderAlerts.stop();
    api.session = null;
    role = null;
    tables = [];
    showTables = false;
    await storage.delete(key: sessionKey);
  }

  void showQr(String label, String url, {bool fixed = false}) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                QrImageView(
                  data: url,
                  size: 248,
                  padding: const EdgeInsets.all(20),
                  backgroundColor: Colors.white,
                  semanticsLabel: 'Código QR de $label',
                ),
                const SizedBox(height: 12),
                Text(
                  fixed
                      ? 'Este QR se imprime una vez y se deja en la mesa.'
                      : 'Escanea el QR para abrir la carta.',
                ),
                if (fixed)
                  TextButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: url));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enlace copiado.')),
                        );
                      }
                    },
                    child: const Text('Copiar enlace'),
                  ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void startTables() {
    setState(() => showTables = true);
    unawaited(run(refresh));
    tablesSubscription = api.watchOrders('/staff/tables').listen((data) {
      if (mounted && showTables) {
        setState(
          () => tables = (data['tables'] as List).cast<Map<String, dynamic>>(),
        );
      }
    }, onError: (Object _) {});
  }

  int get billCount =>
      tables.where((table) => table['status'] == 'bill_requested').length;

  void stopTables() {
    unawaited(tablesSubscription?.cancel());
    tablesSubscription = null;
  }

  Widget tableTile(Map<String, dynamic> table) {
    final id = table['id'] as int;
    final label = table['label'] as String;
    final fixedUrl = table['tableQrUrl'] as String?;
    final url = fixedUrl ?? table['qrUrl'] as String?;
    final status = table['status'] as String?;
    final colors = Theme.of(context).colorScheme;
    final (state, accent) = switch (status) {
      'open' => ('Ocupada', colors.occupied),
      'bill_requested' => ('Pide la cuenta', colors.warning),
      'paid' => ('Pagada', colors.success),
      _ => ('Libre', colors.onSurfaceVariant),
    };
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.table_restaurant_outlined),
            title: Text(label),
            subtitle: Align(
              alignment: Alignment.centerLeft,
              child: StatusLabel(state, color: accent),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Wrap(
              spacing: 8,
              children: [
                if (url == null)
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => run(() async {
                            final result = await api.request(
                              '/staff/tables/$id/open',
                              body: {},
                            );
                            await refresh();
                            if (mounted) {
                              showQr(label, result['qrUrl'] as String);
                            }
                          }),
                    child: const Text('Abrir mesa'),
                  )
                else
                  FilledButton.tonal(
                    onPressed: busy
                        ? null
                        : () => showQr(label, url, fixed: fixedUrl != null),
                    child: const Text('Ver QR'),
                  ),
                if (status != null)
                  TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) =>
                            OrdersPage(api: api, staff: true, table: label),
                      ),
                    ),
                    child: const Text('Ver pedidos'),
                  ),
                if (status == 'paid')
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => run(() async {
                            await api.request(
                              '/staff/tables/$id/close',
                              body: {'visitId': table['visitId']},
                            );
                            await refresh();
                          }),
                    child: const Text('Cerrar mesa'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: role != null && showTables
          ? BackButton(
              onPressed: () {
                stopTables();
                setState(() => showTables = false);
              },
            )
          : null,
      title: Text(
        role == null
            ? 'MenuApp Restaurante'
            : (showTables ? 'Mesas' : 'Inicio'),
      ),
      actions: [
        if (role != null) ...[
          IconButton(
            tooltip: 'Actualizar',
            onPressed: busy ? null : () => run(refresh),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: busy ? null : () => run(logout),
            icon: const Icon(Icons.logout),
          ),
        ],
      ],
    ),
    body: SafeArea(
      child: ScreenColumn(
        width: role == null ? 440 : 600,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (role != null && showTables) ...[
              SectionHeading(
                '${tables.where((table) => table['status'] != null).length} ocupadas de ${tables.length}',
              ),
              ...tables.map(tableTile),
            ] else if (role != null) ...[
              const SectionHeading('Servicio'),
              Card(
                child: ListTile(
                  leading: const _TileIcon(Icons.table_restaurant_outlined),
                  title: const Text('Mesas'),
                  subtitle: Text(
                    '${tables.where((table) => table['status'] != null).length} ocupadas de ${tables.length}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: busy ? null : startTables,
                ),
              ),
              Card(
                color: billCount > 0
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                child: ListTile(
                  leading: const _TileIcon(
                    Icons.account_balance_wallet_outlined,
                  ),
                  title: const Text('Cuentas'),
                  subtitle: Text(
                    billCount == 0
                        ? 'Ninguna mesa pide la cuenta'
                        : billCount == 1
                        ? '1 mesa pide la cuenta'
                        : '$billCount mesas piden la cuenta',
                  ),
                  trailing: billCount > 0
                      ? Badge(label: Text('$billCount'))
                      : const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) =>
                          OrdersPage(api: api, staff: true, account: true),
                    ),
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const _TileIcon(Icons.receipt_long_outlined),
                  title: const Text('Pedidos'),
                  subtitle: const Text('Preparar, entregar y atender llamados'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => OrdersPage(api: api, staff: true),
                    ),
                  ),
                ),
              ),
              if (role == 'admin') ...[
                const SizedBox(height: 14),
                const SectionHeading('Administración'),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.history),
                    title: const Text('Historial de boletas'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => PaymentHistoryPage(api: api),
                      ),
                    ),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const _TileIcon(Icons.restaurant_menu),
                    title: const Text('Platos'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: busy
                        ? null
                        : () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => ProductsPage(api: api),
                            ),
                          ),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const _TileIcon(Icons.local_offer_outlined),
                    title: const Text('Códigos de descuento'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: busy
                        ? null
                        : () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => DiscountsPage(api: api),
                            ),
                          ),
                  ),
                ),
              ],
            ] else if (!restoring && api.session != null) ...[
              FilledButton(
                onPressed: busy ? null : () => run(refresh),
                child: const Text('Reintentar conexión'),
              ),
              TextButton(
                onPressed: busy ? null : () => run(logout),
                child: const Text('Cerrar sesión'),
              ),
            ] else if (!restoring) ...[
              const SectionHeading('Acceso del personal'),
              AutofillGroup(
                child: Column(
                  children: [
                    TextField(
                      enabled: !busy,
                      controller: username,
                      decoration: const InputDecoration(labelText: 'Usuario'),
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      enabled: !busy,
                      controller: password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                      ),
                      onSubmitted: (_) {
                        if (!busy) run(login);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy ? null : () => run(login),
                child: const Text('Iniciar sesión'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _TileIcon extends StatelessWidget {
  const _TileIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colors.brightness == Brightness.dark
            ? colors.secondaryContainer
            : colors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: colors.onPrimaryContainer, size: 22),
    );
  }
}
