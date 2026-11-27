import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_app/api.dart';
import 'package:menu_app/checkout.dart';
import 'package:menu_app/order_alerts.dart';
import 'package:menu_app/orders.dart';

class _OrderFeed extends Api {
  final controller = StreamController<Map<String, dynamic>>();
  final alerts = StreamController<Map<String, dynamic>>();

  @override
  Stream<Map<String, dynamic>> watchOrders(String path) => controller.stream;

  @override
  Stream<Map<String, dynamic>> watchAlerts() => alerts.stream;

  void emit(List<Map<String, dynamic>> orders) {
    controller.add({'orders': orders});
  }
}

class _PaymentApi extends Api {
  final requests = <(String, Map<String, dynamic>?)>[];

  @override
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    requests.add((path, body));
    return {};
  }
}

Map<String, dynamic> _order(int id, [String status = 'received']) => {
  'id': id,
  'table': 'Mesa 1',
  'createdAt': '2026-11-21T21:00:00Z',
  'status': status,
  'total': 4900,
  'lines': [
    {'name': 'Plato de prueba', 'price': 4900, 'quantity': 1},
  ],
};

void main() {
  testWidgets('Elegir el método solicita el pago en la mesa', (tester) async {
    final api = _PaymentApi();
    final visit = <String, dynamic>{
      'status': 'open',
      'orderCount': 1,
      'total': 4900,
      'subtotal': 4900,
      'percent': 0,
    };
    Widget page() => MaterialApp(
      home: Scaffold(
        body: VisitCheckout(api: api, visit: visit, staff: false),
      ),
    );
    await tester.pumpWidget(page());
    await tester.tap(find.widgetWithText(FilledButton, 'Pagar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tarjeta'));
    await tester.pumpAndSettle();
    expect(api.requests, hasLength(1));
    expect(api.requests.single.$1, '/guest/bill');
    expect(api.requests.single.$2, {'method': 'card'});
    visit.addAll({'status': 'bill_requested', 'method': 'card'});
    await tester.pumpWidget(page());
    expect(find.text('El personal va a tu mesa'), findsOneWidget);
    expect(find.text('Tarjeta'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Pagar'), findsNothing);
  });

  testWidgets('El aviso abre la ficha del pedido indicado', (tester) async {
    final api = _OrderFeed();
    await tester.pumpWidget(
      MaterialApp(
        home: AlertDetailPage(
          api: api,
          type: 'order_ready',
          id: '2',
          staff: false,
        ),
      ),
    );
    api.emit([_order(1), _order(2, 'ready')]);
    await tester.pumpAndSettle();
    expect(find.text('Pedido #2'), findsOneWidget);
    expect(find.text('Pedido #1'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Marcar entregado'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(api.controller.close());
    unawaited(api.alerts.close());
  });

  testWidgets('Android recibe solo los eventos del personal', (tester) async {
    const channel = MethodChannel('menuapp/orders');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final notified = <Object?>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'show') notified.add(call.arguments);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final api = _OrderFeed()..session = 'staff-test';
    final alerts = OrderAlerts()..start(api);
    await tester.pump();
    final events = [
      {'type': 'new_order', 'id': 1, 'table': 'Mesa 1'},
      {'type': 'order_ready', 'id': 1, 'table': 'Mesa 1'},
      {'type': 'bill_requested', 'id': 'visit', 'table': 'Mesa 1'},
      {'type': 'payment_confirmed', 'id': 'visit', 'table': 'Mesa 1'},
      {'type': 'waiter_called', 'id': 2, 'table': 'Mesa 1'},
    ];
    events.forEach(api.alerts.add);
    await tester.pump();
    expect(notified, events.where((event) => event['type'] != 'order_ready'));
    alerts.stop();
    unawaited(api.alerts.close());
    unawaited(api.controller.close());
  });

  testWidgets(
    'La lista resume y la ficha conserva las líneas y el estado en vivo',
    (tester) async {
      final api = _OrderFeed();
      await tester.pumpWidget(
        MaterialApp(home: OrdersPage(api: api, staff: true)),
      );
      api.emit([_order(1)]);
      await tester.pumpAndSettle();
      expect(find.text('Mesa 1'), findsOneWidget);
      expect(find.text('Pedido #1'), findsNothing);
      await tester.tap(find.text('Mesa 1'));
      await tester.pumpAndSettle();
      expect(find.text('Pedido #1'), findsOneWidget);
      expect(find.text('1 × Plato de prueba'), findsNothing);
      await tester.tap(find.byTooltip('Ver detalle del pedido 1'));
      await tester.pumpAndSettle();
      expect(find.text('1 × Plato de prueba'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Empezar preparación'),
        findsOneWidget,
      );
      api.emit([_order(1, 'preparing')]);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Marcar listo'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(api.alerts.close());
      unawaited(api.controller.close());
    },
  );
}
