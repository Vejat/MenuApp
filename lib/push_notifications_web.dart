import 'dart:js_interop';

@JS('menuAppEnablePush')
external JSPromise<JSBoolean> _menuAppEnablePush(JSString token);

Future<bool> subscribe(String token) async {
  return (await _menuAppEnablePush(token.toJS).toDart).toDart;
}
