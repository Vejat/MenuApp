# MenuApp · Especificación del MVP

Estado: aprobada. Ver [diseño técnico](DESIGN.md) y [plan de implementación](PLAN.md).

## Objetivo

Permitir que los clientes consulten la carta y pidan desde su mesa. El piloto medirá cuánto trabajo de toma de pedidos se puede ahorrar manteniendo la atención al cliente.

## MVP propuesto

- **Cliente:** escanea el QR de su mesa y abre la carta en el navegador con Flutter Web, sin instalar una app ni crear una cuenta. Puede pedir, consultar el estado, llamar al mesero y solicitar la boleta.
- **Personal:** inicia sesión en la app móvil Flutter. Abre visitas y presenta el QR, recibe pedidos y actualiza sus estados, atiende llamadas, gestiona solicitudes de boleta y confirma pagos antes de cerrar mesas. Cada pedido muestra mesa, productos, cantidades y hora.
- **Encargado (admin):** usa la misma app móvil con permisos de administración. Puede realizar las tareas del personal y gestionar productos, precios, disponibilidad y códigos de descuento. El primer piloto cubre un restaurante.

La versión de escritorio para el personal queda para una etapa posterior.

Flujo del pedido: recibido → en preparación → listo → entregado. La suscripción se evaluará después del piloto.

## Carrito y descuentos

- El carrito muestra los platos seleccionados, cantidades, precios unitarios, subtotales y total. El cliente puede cambiar cantidades o quitar platos y ver el total actualizado al instante antes de confirmar.
- El encargado puede crear y activar códigos con un porcentaje de descuento mayor a 0 y hasta 100 %, y un periodo de vigencia que puede cubrir un solo día.
- El cliente ingresa el código en el carrito y ve el importe del descuento. Se admite un código por visita, aplicado al subtotal del consumo de la visita, incluidos los pedidos adicionales. Al confirmar un pedido con el código, se guarda el porcentaje validado para esa visita.

## Resumen de consumo, asistencia y cobro

- **Resumen de consumo:** el cliente puede consultar y descargar un respaldo de los pedidos de su visita, con cantidades, precios unitarios, subtotales, descuento aplicado y total a pagar, para cotejarlo con la boleta oficial del restaurante.
- **Llamar al mesero:** el cliente puede pedir ayuda durante su visita. El panel recibe una alerta por mesa que permanece visible hasta que el personal la atiende. Solo puede haber una llamada pendiente por mesa.
- **Pedir la boleta:** el cliente elige transferencia, efectivo o tarjeta. El panel muestra la solicitud con la mesa, el total y el método elegido. El restaurante cobra con su sistema habitual y el personal confirma el pago recibido.
- **Control de mesas:** el panel distingue las mesas con consumo pendiente, con boleta solicitada y pagadas. El personal solo puede cerrar una mesa tras confirmar el pago. Si encuentra desocupada una mesa pendiente, puede marcarla para revisión sin borrar el saldo.

## Criterios de aceptación

- Al escanear el QR se muestra la carta y se identifica la mesa asociada.
- Si un producto se agota o cambia de precio antes de confirmar, el cliente ve el cambio y puede revisar el pedido. El pedido guarda los precios confirmados.
- Al editar el carrito se recalculan los subtotales, el descuento y el total sin recargar. El cliente puede revisar todos los platos antes de confirmar.
- El servidor valida el código al ingresarlo y al confirmar su primer uso. Si el código es inválido, está inactivo o queda fuera de vigencia, el cliente recibe un aviso y puede revisar el total antes de confirmar sin descuento.
- El resumen del cliente y la solicitud de boleta del personal muestran el mismo subtotal, descuento y total a pagar, calculados sobre los pedidos confirmados.
- El pedido aparece en el panel sin recargar. Los cambios de estado también llegan al cliente sin recargar.
- Si falla la conexión durante el envío, se puede reintentar sin duplicar el pedido. La confirmación aparece cuando el servidor registra el pedido.
- El panel exige autenticación. Cada cliente solo puede consultar los pedidos de su propia sesión.
- Después de iniciar sesión, el personal y el encargado llegan a Inicio. Al reabrir la app se conserva la sesión hasta que el usuario pulsa «Cerrar sesión». Inicio ofrece acceso a Mesas y, para el encargado, a Administrar platos.
- El resumen incluye todos los pedidos confirmados de la sesión, utiliza los precios guardados en cada pedido y se puede descargar antes de cerrar la visita.
- La llamada al mesero aparece sin recargar. Si el cliente vuelve a pulsar mientras está pendiente, sigue viendo la misma solicitud. Al atenderla, el panel deja de mostrarla como pendiente.
- Solicitar la boleta con cualquiera de los tres métodos actualiza el panel sin recargar y mantiene el saldo pendiente. Solo el personal autenticado puede confirmar el pago y cerrar la mesa. Marcarla para revisión mantiene visible el saldo pendiente.

## Piloto

Comparar turnos similares antes y después del piloto. Medir el porcentaje de pedidos hechos por QR, el tiempo de toma del pedido y las intervenciones del personal. Mantener el pedido asistido para quienes lo necesiten y usar los resultados para decidir la dotación.
