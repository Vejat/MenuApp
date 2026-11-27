import 'dart:js_util' as js;

Future<bool> subscribe(String token) async {
  final promise = js.callMethod<Object?>(js.globalThis, 'menuAppEnablePush', [token]);
  return await js.promiseToFuture<bool>(promise);
}
