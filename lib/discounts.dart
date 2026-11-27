import 'package:flutter/material.dart';

import 'api.dart';
import 'night_theme.dart';

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
      label: const Text('Nuevo código'),
    ),
    body: ScreenColumn(
      child: FutureBuilder(
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
                    leading: const Icon(Icons.local_offer_outlined),
                    title: Text(
                      "${discount['code']} · ${discount['percent']} %",
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(_dateRange(discount as Map<String, dynamic>)),
                          _discountState(context, discount),
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => edit(discount),
                  ),
                ),
            ],
          );
        },
      ),
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

  Widget dateField(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextField(
      controller: controller,
      enabled: !busy,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_today_outlined),
      ),
      onTap: () async {
        final current = DateTime.tryParse(controller.text) ?? DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: current,
          firstDate: DateTime(2024),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          controller.text = picked.toIso8601String().substring(0, 10);
        }
      },
    ),
  );

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
          decoration: const InputDecoration(
            labelText: 'Código',
            helperText: 'Usa letras, números o guiones (máx. 24).',
          ),
        ),
        TextField(
          controller: percent,
          enabled: !busy,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Descuento (%)'),
        ),
        dateField(starts, 'Válido desde'),
        dateField(ends, 'Hasta'),
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

const _months = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

String _shortDate(String iso) {
  final date = DateTime.tryParse(iso);
  return date == null ? iso : '${date.day} ${_months[date.month - 1]}';
}

String _dateRange(Map<String, dynamic> discount) {
  final starts = discount['startsOn'] as String;
  final ends = discount['endsOn'] as String;
  return starts == ends
      ? _shortDate(starts)
      : '${_shortDate(starts)} – ${_shortDate(ends)}';
}

Widget _discountState(BuildContext context, Map<String, dynamic> discount) {
  final colors = Theme.of(context).colorScheme;
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final (label, color) = (discount['endsOn'] as String).compareTo(today) < 0
      ? ('Vencido', colors.error)
      : discount['active'] == true
      ? ('Activo', colors.success)
      : ('Inactivo', colors.onSurfaceVariant);
  return StatusLabel(label, color: color);
}
