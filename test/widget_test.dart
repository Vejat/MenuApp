import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:menu_app/api.dart';
import 'package:menu_app/main.dart';
import 'package:menu_app/restaurant.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  testWidgets('La web indica cómo acceder si falta el QR', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GuestPage(token: null)));
    expect(
      find.text('Escanea el QR de tu mesa para comenzar.'),
      findsOneWidget,
    );
  });

  testWidgets('La app del restaurante pide iniciar sesión', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: RestaurantPage()));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Abrir'), findsNothing);
  });

  testWidgets('Recupera la sesión al abrir y la borra al salir', (
    tester,
  ) async {
    const key = 'restaurant_session_${Api.base}';
    FlutterSecureStorage.setMockInitialValues({key: 'session-test'});
    var logout = false;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(const MaterialApp(home: RestaurantPage()));
        await tester.pumpAndSettle();
        expect(find.text('Inicio'), findsOneWidget);
        expect(find.text('Platos'), findsOneWidget);
        expect(find.text('Iniciar sesión'), findsNothing);
        await tester.tap(find.byTooltip('Cerrar sesión'));
        await tester.pumpAndSettle();
        expect(logout, isTrue);
        expect(find.text('Iniciar sesión'), findsOneWidget);
        expect(await const FlutterSecureStorage().read(key: key), isNull);
      },
      () => MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer session-test');
        if (request.url.path == '/staff/logout') {
          logout = true;
          return http.Response('{}', 200);
        }
        return http.Response('{"role":"admin","tables":[]}', 200);
      }),
    );
  });

  testWidgets('El personal abre el QR de una visita desde Mesas', (
    tester,
  ) async {
    const key = 'restaurant_session_${Api.base}';
    const url = 'https://menu.example/?visita=mesa1';
    FlutterSecureStorage.setMockInitialValues({key: 'session-test'});
    await http.runWithClient(
      () async {
        await tester.pumpWidget(const MaterialApp(home: RestaurantPage()));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mesas'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ver QR'));
        await tester.pumpAndSettle();

        final qr = tester.widget<QrImageView>(find.byType(QrImageView));
        expect(qr.semanticsLabel, 'Código QR de Mesa 1');
        expect(qr.eyeStyle.eyeShape, QrEyeShape.square);
        expect(qr.dataModuleStyle.dataModuleShape, QrDataModuleShape.square);
        expect(find.text('Escanea el QR para abrir la carta.'), findsOneWidget);
      },
      () => MockClient(
        (_) async => http.Response(
          '{"role":"staff","tables":[{"id":1,"label":"Mesa 1","status":"open","qrUrl":"$url"}]}',
          200,
        ),
      ),
    );
  });
}
