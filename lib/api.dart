import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.status, this.message);

  final int status;
  final String message;
}

String apiMessage(Object? error) => error is ApiException
    ? error.message
    : 'No se pudo conectar con el servicio.';

class Api {
  static const base = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:3000',
  );

  String? session;

  Uri _endpoint(String path) =>
      base.isEmpty ? Uri.base.resolve(path) : Uri.parse('$base$path');

  Stream<Map<String, dynamic>> watchOrders(String path) async* {
    while (session != null) {
      final client = http.Client();
      try {
        final request = http.Request('GET', _endpoint('$path/events'))
          ..headers['Authorization'] = 'Bearer $session';
        final response = await client
            .send(request)
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 401) {
          yield* Stream.error(
            const ApiException(401, 'La sesión ya no está disponible.'),
          );
          return;
        }
        if (response.statusCode != 200) {
          throw const ApiException(503, 'Pedidos no disponibles.');
        }
        await for (final line
            in response.stream
                .transform(utf8.decoder)
                .transform(const LineSplitter())
                .timeout(const Duration(seconds: 25))) {
          if (line == 'data: orders') yield await this.request(path);
        }
      } catch (error) {
        yield* Stream.error(error);
        if (error is ApiException && error.status == 401) return;
      } finally {
        client.close();
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = _endpoint(path);
    final headers = {
      if (session != null) 'Authorization': 'Bearer $session',
      if (body != null) 'Content-Type': 'application/json',
    };
    final response =
        await (body == null
                ? http.get(uri, headers: headers)
                : http.post(uri, headers: headers, body: jsonEncode(body)))
            .timeout(const Duration(seconds: 10));
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw ApiException(response.statusCode, result['error'] as String);
    }
    return result;
  }
}
