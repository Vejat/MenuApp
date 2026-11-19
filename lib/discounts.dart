import 'package:flutter/material.dart';

import 'api.dart';

class DiscountsPage extends StatefulWidget {
  const DiscountsPage({super.key, required this.api});

  final Api api;

  @override
  State<DiscountsPage> createState() => _DiscountsPageState();
}

class _DiscountsPageState extends State<DiscountsPage> {
  late Future<Map<String, dynamic>> discounts = widget.api.request(
    '/admin/discounts',
  );

  void reload() =>
      setState(() => discounts = widget.api.request('/admin/discounts'));

  Future<void> edit([Map<String, dynamic>? discount]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => DiscountEditor(api: widget.api, discount: discount),
    );
    if (mounted && saved == true) reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Códigos de descuento')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => edit(),
      icon: const Icon(Icons.add),
      label: const Text('Agregar código'),
    ),
    body: FutureBuilder(
      future: discounts,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: reload,
              child: Text('${apiMessage(snapshot.error)} Reintentar'),
            ),
          );
        }
        final entries = snapshot.data?['discounts'] as List?;
        if (entries == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (entries.isEmpty) {
          return const Center(child: Text('Todavía no hay códigos.'));
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          children: [
            for (final discount in entries)
              Card(
                child: ListTile(
                  title: Text("${discount['code']} · ${discount['percent']}%"),
                  subtitle: Text(
                    "${discount['startsOn']} a ${discount['endsOn']} · ${discount['active'] == true ? 'Activado' : 'Desactivado'}",
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => edit(discount as Map<String, dynamic>),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class DiscountEditor extends StatefulWidget {
  const DiscountEditor({super.key, required this.api, this.discount});

  final Api api;
  final Map<String, dynamic>? discount;

  @override
  State<DiscountEditor> createState() => _DiscountEditorState();
}

class _DiscountEditorState extends State<DiscountEditor> {
  late final today = DateTime.now().toIso8601String().substring(0, 10);
  late final code = TextEditingController(
    text: widget.discount?['code'] as String?,
  );
  late final percent = TextEditingController(
    text: widget.discount?['percent']?.toString(),
  );
  late final starts = TextEditingController(
    text: widget.discount?['startsOn'] as String? ?? today,
  );
  late final ends = TextEditingController(
    text: widget.discount?['endsOn'] as String? ?? today,
  );
  late bool active = widget.discount?['active'] as bool? ?? true;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    code.dispose();
    percent.dispose();
    starts.dispose();
    ends.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.request(
        '/admin/discounts',
        body: {
          'code': code.text,
          'percent': int.tryParse(percent.text.trim()),
          'startsOn': starts.text.trim(),
          'endsOn': ends.text.trim(),
          'active': active,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (failure) {
      if (mounted) {
        setState(() {
          error = apiMessage(failure);
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.discount == null ? 'Nuevo código' : 'Editar código'),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: code,
          enabled: !busy && widget.discount == null,
          decoration: const InputDecoration(labelText: 'Código'),
        ),
        TextField(
          controller: percent,
          enabled: !busy,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Porcentaje'),
        ),
        TextField(
          controller: starts,
          enabled: !busy,
          decoration: const InputDecoration(labelText: 'Desde (AAAA-MM-DD)'),
        ),
        TextField(
          controller: ends,
          enabled: !busy,
          decoration: const InputDecoration(labelText: 'Hasta (AAAA-MM-DD)'),
        ),
        SwitchListTile(
          title: const Text('Activo'),
          value: active,
          onChanged: busy ? null : (value) => setState(() => active = value),
        ),
        if (error != null) Text(error!),
      ],
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: busy ? null : save, child: const Text('Guardar')),
    ],
  );
}
