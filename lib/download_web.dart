import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

void downloadSummary(String encoded) {
  final file = web.Blob(
    [base64Decode(encoded).toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final url = web.URL.createObjectURL(file);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = 'resumen-menuapp.pdf';
  web.document.body?.append(link);
  link.click();
  link.remove();
  Future<void>.delayed(
    const Duration(seconds: 5),
    () => web.URL.revokeObjectURL(url),
  );
}
