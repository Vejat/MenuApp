import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'api.dart';
import 'discounts.dart';
import 'orders.dart';
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
  final username = TextEditingController();
  final password = TextEditingController();
  List<Map<String, dynamic>> tables = [];
  String? role;
  String? error;
  bool busy = false;
  bool restoring = true;
  bool showTables = false;

  @override
  void initState() {
    super.initState();
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
    api.session = null;
    role = null;
    tables = [];
    showTables = false;
    await storage.delete(key: sessionKey);
  }

  void showQr(String label, String url) {
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
                const Text('Escanea el QR para abrir la carta.'),
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

  Widget tableTile(Map<String, dynamic> table) {
    final id = table['id'] as int;
    final label = table['label'] as String;
    final url = table['qrUrl'] as String?;
    final status = table['status'] as String?;
    return Card(
      child: ListTile(
        title: Text(label),
        subtitle: Text(switch (status) {
          'open' => 'Visita abierta',
          'bill_requested' => 'Boleta solicitada',
          'paid' => 'Pagada',
          _ => 'Disponible',
        }),
        trailing: Wrap(
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
                        if (mounted) showQr(label, result['qrUrl'] as String);
                      }),
                child: const Text('Abrir'),
              )
            else
              FilledButton.tonal(
                onPressed: busy ? null : () => showQr(label, url),
                child: const Text('Ver QR'),
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
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: role != null && showTables
          ? BackButton(onPressed: () => setState(() => showTables = false))
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
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (role != null && showTables)
                ...tables.map(tableTile)
              else if (role != null) ...[
                Text(
                  role == 'admin' ? 'Encargado' : 'Personal',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.table_restaurant_outlined),
                    title: const Text('Mesas'),
                    subtitle: Text(
                      'Visitas activas: ${tables.where((table) => table['status'] != null).length}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: busy
                        ? null
                        : () {
                            setState(() => showTables = true);
                            run(refresh);
                          },
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.account_balance_wallet_outlined),
                    title: const Text('Cuentas'),
                    trailing: const Icon(Icons.chevron_right),
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
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: const Text('Pedidos'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => OrdersPage(api: api, staff: true),
                      ),
                    ),
                  ),
                ),
                if (role == 'admin')
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.restaurant_menu),
                      title: const Text('Administrar platos'),
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
                if (role == 'admin')
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.local_offer_outlined),
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
    ),
  );
}
