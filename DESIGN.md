# MenuApp · Diseño técnico del MVP

## Arquitectura

- Flutter Web para carta, carrito y consumo del cliente. App móvil Flutter para el panel del personal y la administración del encargado. Ambas usan la misma API. Separar la interfaz del acceso a datos para probar los flujos y facilitar una futura versión de escritorio del panel.
- API HTTPS para lecturas y acciones. PostgreSQL guarda el estado. Un canal SSE por sesión del cliente o por panel notifica cambios confirmados. Al reconectar, la aplicación vuelve a consultar el estado vigente.
- El servidor calcula importes, comprueba permisos y valida transiciones. Flutter muestra una estimación inmediata del carrito y usa la cotización del servidor para confirmar.

Si se incorpora el acceso con Google para el restaurante, la opción evaluada es Firebase Authentication con Cloud Firestore. El cambio requiere un proyecto Firebase y una migración de datos y permisos. El cliente seguirá entrando por QR.

## Modelo de datos

| Entidad | Datos e invariantes |
| --- | --- |
| Mesa y visita | Identificador de mesa, apertura, estado y cierre. Una visita activa por mesa. |
| Sesión de cliente | Credencial revocable ligada a una visita. El QR contiene un token aleatorio por visita, canjeable por una sesión. El personal abre la visita y presenta el QR a los comensales. |
| Producto | Nombre, precio vigente, disponibilidad y estado. |
| Pedido y líneas | Visita, estado, hora e identificador de reintento. Cada línea guarda nombre, cantidad y precio confirmados. |
| Código y descuento aplicado | Código único, porcentaje, vigencia y estado. La visita conserva el código y porcentaje validados al primer uso. |
| Llamada al mesero | Visita, hora y atención. Una llamada pendiente por visita. |
| Solicitud de boleta y pago | Visita, método, total solicitado y registro de confirmación con importe, hora y responsable. La marca de revisión es independiente del estado de cobro. |

## Reglas y operaciones

- **Acceso:** la carta puede verse desde el QR. Para pedir o consultar consumo se exige una sesión de la visita. Los dispositivos que escanean el mismo QR comparten el consumo de esa visita. Al cerrar, se invalidan el QR y sus sesiones. La app móvil habilita las pantallas según el rol. La API verifica permisos en cada acción. El personal opera mesas, pedidos, llamadas y cobros. El encargado tiene esos permisos y además gestiona productos y códigos.
- **Cotizar y confirmar:** devolver líneas, cambios de disponibilidad y totales. Confirmar solo si coinciden con lo aceptado por el cliente. Si cambió la cotización, pedir revisión. Un reintento con la misma clave y contenido devuelve el pedido original. Una clave reutilizada con otro contenido se rechaza.
- **Descuento:** calcular sobre el consumo confirmado más el carrito en la vista previa y sobre el consumo confirmado en el resumen. Usar pesos enteros y redondear el descuento una vez sobre el subtotal de la visita al peso más cercano. Interpretar las fechas de vigencia en `America/Santiago`, con el día final incluido.
- **Cobro:** visita abierta → boleta solicitada → pagada → cerrada. Mientras la boleta está solicitada se bloquean los pedidos adicionales. El personal puede devolver la visita a abierta para agregar pedidos y solicitar la boleta de nuevo. Un total de $0 requiere que el personal confirme el saldo cero para cerrar. Descargar el resumen genera un PDF identificado como resumen de consumo.
- **Concurrencia:** confirmar pedidos, solicitar boleta, confirmar pago y cerrar validan el estado dentro de una transacción que bloquea la fila de la visita. Así, el importe a cobrar incluye los pedidos confirmados antes de solicitar la boleta. La alerta y los cambios de estado se publican después de guardar los datos.
