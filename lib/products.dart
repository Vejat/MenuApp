import 'package:flutter/material.dart';

import 'api.dart';
import 'night_theme.dart';

typedef Product = Map<String, dynamic>;

String clp(int amount) {
  final digits = amount.toString();
  return '\$${digits.replaceAllMapped(RegExp(r'(?<=\d)(?=(\d{3})+$)'), (_) => '.')}';
}

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key, required this.api});

  final Api api;

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  late Future<List<Product>> products = load();

  Future<List<Product>> load() async {
    final result = await widget.api.request('/admin/products');
    return (result['products'] as List).cast<Product>();
  }

  void reload() => setState(() => products = load());

  Future<void> edit([Product? product]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ProductEditor(api: widget.api, product: product),
    );
    if (saved == true && mounted) reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Platos')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => edit(),
      label: const Text('Agregar plato'),
      icon: const Icon(Icons.add),
    ),
    body: ScreenColumn(
      child: FutureBuilder(
        future: products,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: TextButton(
                onPressed: reload,
                child: Text('${apiMessage(snapshot.error)} Reintentar'),
              ),
            );
          }
          final list = snapshot.data;
          if (list == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (list.isEmpty) {
            return const Center(
              child: Text(
                'Aún no hay platos. Toca «Agregar plato» para crear el primero.',
                textAlign: TextAlign.center,
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            children: [
              for (final product in list)
                Card(
                  child: ListTile(
                    leading: Icon(
                      product['available'] == true
                          ? Icons.restaurant_menu
                          : Icons.visibility_off_outlined,
                    ),
                    title: Text(product['name'] as String),
                    subtitle: Text(
                      '${clp(product['price'] as int)} · ${product['available'] == true ? 'Disponible' : 'No disponible'}',
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => edit(product),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class ProductEditor extends StatefulWidget {
  const ProductEditor({super.key, required this.api, required this.product});

  final Api api;
  final Product? product;

  @override
  State<ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<ProductEditor> {
  late final name = TextEditingController(
    text: widget.product?['name'] as String?,
  );
  late final price = TextEditingController(
    text: widget.product?['price']?.toString(),
  );
  late bool available = widget.product?['available'] as bool? ?? true;
  bool saving = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    price.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      error = null;
    });
    final id = widget.product?['id'];
    try {
      await widget.api.request(
        id == null ? '/admin/products' : '/admin/products/$id',
        body: {
          'name': name.text,
          'price': int.tryParse(price.text.trim()),
          'available': available,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (failure) {
      if (mounted) {
        setState(() {
          error = apiMessage(failure);
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.product == null ? 'Agregar plato' : 'Editar plato'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Nombre'),
          enabled: !saving,
        ),
        TextField(
          controller: price,
          decoration: const InputDecoration(labelText: 'Precio en pesos'),
          keyboardType: TextInputType.number,
          enabled: !saving,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Disponible'),
          value: available,
          onChanged: saving
              ? null
              : (value) => setState(() => available = value),
        ),
        if (error != null) Text(error!),
      ],
    ),
    scrollable: true,
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: saving ? null : save,
        child: Text(saving ? 'Guardando…' : 'Guardar'),
      ),
    ],
  );
}
