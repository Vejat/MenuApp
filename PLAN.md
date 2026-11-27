# MenuApp · Plan de implementación

La especificación aprobada está en [SPEC.md](SPEC.md). Las decisiones de implementación están en [DESIGN.md](DESIGN.md).

| Orden | Entrega | Verificación |
| --- | --- | --- |
| 1 | Flutter Web para clientes, app móvil Flutter para el restaurante, API y migraciones. Acceso por rol, mesas, visitas y QR fijo. | Dos celulares que escanean el mismo QR comparten la cuenta activa. Al cerrarla vencen esas sesiones y el mismo QR abre otra visita. |
| 2 | Administración móvil de productos y disponibilidad, carta web y carrito. | La API reserva la edición de productos al encargado. Editar cantidades y quitar platos actualiza el total. Un cambio de precio o disponibilidad exige revisar el carrito. |
| 3 | Pedidos agrupados por mesa y eventos en tiempo real. | El panel agrupa los pedidos de cada mesa y permite abrirlos y actualizarlos por separado. El cliente ve los cambios de estado. Reintentar después de un corte crea un único pedido. |
| 4 | Administración y aplicación de descuentos. | Cubrir código inválido, vencimiento, código de un día, pedidos adicionales y descuento del 100 %. Verificar el redondeo. |
| 5 | Resumen PDF, llamada al mesero y solicitud de pago. | El PDF coincide con el panel. Una doble pulsación crea una sola alerta. Elegir un método envía la solicitud de pago al panel. |
| 6 | Confirmación de pago, revisión y cierre automático. | El saldo pendiente sigue visible. Confirmar el pago tras la entrega cierra la visita y libera la mesa para su próximo escaneo. |
| 7 | Piloto con navegador móvil del cliente y app móvil del restaurante. | Recorrer QR → pedido → entrega → boleta → cierre y verificar la administración desde el celular. Registrar pedidos por QR, tiempo de toma e intervenciones del personal en turnos comparables. |
