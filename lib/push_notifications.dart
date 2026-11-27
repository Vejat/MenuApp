import 'package:flutter/material.dart';
import 'api.dart';
import 'push_notifications_stub.dart'
    if (dart.library.js_interop) 'push_notifications_web.dart' as platform;

Future<void> enablePush(BuildContext context, Api api) async {
  if (api.session == null) return;
  try {
    final ok = await platform.subscribe(api.session!);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok
        ? 'Notificaciones activadas en este dispositivo.'
        : 'En iPhone, agrega MenuApp a la pantalla de inicio y vuelve a abrirla desde el icono. Luego activa las notificaciones.')));
  } catch (_) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudieron activar las notificaciones. Revisa los permisos del navegador.')));
  }
}
