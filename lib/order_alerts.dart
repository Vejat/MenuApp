import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'api.dart';

class OrderAlerts {
  static const _channel = MethodChannel('menuapp/orders');
  StreamSubscription<Map<String, dynamic>>? _subscription;
  String? _session;

  void onOpen(VoidCallback? callback) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _channel.setMethodCallHandler(
      callback == null
          ? null
          : (call) async {
              if (call.method == 'alertOpened') callback();
            },
    );
  }

  Future<Map<String, String>?> takeOpenedAlert() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      return await _channel.invokeMapMethod<String, String>('takeOpenedAlert');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  void start(Api api) {
    final session = api.session;
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        session == null ||
        _session != null) {
      return;
    }
    _session = session;
    unawaited(_listen(api, session));
  }

  Future<void> _listen(Api api, String session) async {
    final available = await _invoke('prepare');
    if (!available || _session != session || api.session != session) return;
    _subscription = api.watchAlerts().listen((alert) {
      if (_session == session &&
          api.session == session &&
          alert['type'] != 'order_ready') {
        unawaited(_invoke('show', alert));
      }
    }, onError: (Object _) {});
  }

  void stop() {
    _session = null;
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
      unawaited(_invoke('clear'));
    }
  }

  Future<bool> _invoke(String method, [Map<String, dynamic>? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
      return true;
    } on PlatformException catch (error) {
      debugPrint('No se pudo procesar una notificación: ${error.code}');
    } on MissingPluginException {
      // The channel is only implemented by the Android application.
    }
    return false;
  }
}
