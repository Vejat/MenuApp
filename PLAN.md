# MenuApp · Plan de implementación

La especificación aprobada está en [SPEC.md](SPEC.md). Las decisiones de implementación están en [DESIGN.md](DESIGN.md).

| Orden | Entrega | Verificación |
| --- | --- | --- |
| 1 | Flutter Web para clientes, app móvil Flutter para el restaurante, API y migraciones. Acceso por rol, mesas, visitas y QR. | El personal abre la visita desde el celular y el cliente accede por QR en el navegador. Dos visitas quedan aisladas. El QR de una visita cerrada deja de funcionar. |
| 2 | Administración móvil de productos y disponibilidad, carta web y carrito. | La API reserva la edición de productos al encargado. Editar cantidades y quitar platos actualiza el total. Un cambio de precio o disponibilidad exige revisar el carrito. |
| 3 | Pedidos y eventos en tiempo real. | El panel recibe el pedido y el cliente ve los cambios de estado. Reintentar después de un corte crea un único pedido. Reconectar recupera el estado actual. |
| 4 | Administración y aplicación de descuentos. | Cubrir código inválido, vencimiento, código de un día, pedidos adicionales y descuento del 100 %. Verificar el redondeo. |
| 5 | Resumen PDF, llamada al mesero y solicitud de boleta. | El PDF coincide con el panel. Una doble pulsación crea una sola alerta. Cada método de pago llega al panel. |
| 6 | Confirmación de pago, revisión y cierre. | Una mesa con saldo pendiente queda visible, incluso al marcarla para revisión. Si confirmar un pedido y pedir la boleta ocurren a la vez, el pedido se incorpora al cobro o se rechaza según el orden de confirmación. |
| 7 | Piloto con navegador móvil del cliente y app móvil del restaurante. | Recorrer QR → pedido → entrega → boleta → cierre y verificar la administración desde el celular. Registrar pedidos por QR, tiempo de toma e intervenciones del personal en turnos comparables. |
