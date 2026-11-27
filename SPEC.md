# MenuApp · Especificación del MVP

Estado: aprobada. Ver [diseño técnico](DESIGN.md) y [plan de implementación](PLAN.md).

## Objetivo

Permitir que los clientes consulten la carta y pidan desde su mesa. El piloto medirá cuánto trabajo de toma de pedidos se puede ahorrar manteniendo la atención al cliente.

## MVP propuesto

- **Cliente:** escanea el QR de su mesa y abre la carta en el navegador con Flutter Web, sin instalar una app ni crear una cuenta. Puede pedir, consultar el estado, llamar al mesero y solicitar el pago.
- **Personal:** inicia sesión en la app móvil Flutter. Consulta el QR fijo para imprimirlo una vez por mesa. Recibe pedidos agrupados por mesa, abre las fichas individuales y actualiza sus estados. Atiende llamadas, gestiona solicitudes de pago y confirma pagos. Al confirmar el pago de los pedidos entregados, la visita se cierra automáticamente.
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
- **Pagar:** el cliente pulsa «Pagar» y elige transferencia, efectivo o tarjeta. La elección envía la solicitud con la mesa, el total y el método. El personal cobra con el sistema habitual, entrega la boleta y confirma el pago recibido en MenuApp.
- **Control de mesas:** el panel distingue las mesas con consumo pendiente, con pago solicitado y pagadas. El personal solo puede cerrar una mesa tras confirmar el pago. Si encuentra desocupada una mesa pendiente, puede marcarla para revisión sin borrar el saldo.

## Criterios de aceptación

- El personal puede desplegar una cuenta y revisar cada pedido con sus productos, cantidades y precios guardados. El encargado puede consultar todos los pagos registrados desde Administración → Historial de boletas, con acceso al detalle después de cerrar y reutilizar la mesa. El historial conserva el registro de consumo y del pago.

- Con sesión y conexión activas, Android avisa al personal al recibir un pedido, solicitar el pago, confirmar el pago o recibir una llamada al mesero. Una llamada pendiente suena una sola vez. Al marcar un pedido listo, el aviso se muestra en la web de la sesión que lo hizo, incluso si hay otros clientes en la misma mesa. El estado sigue visible en Pedidos.
- Al confirmar el pedido, la web prepara el sonido del aviso. Cuando el pedido está listo y la página sigue visible, el aviso también suena y vibra según la compatibilidad y configuración del navegador.
- Al escanear el QR fijo se muestra la carta y se identifica la mesa asociada. Si está disponible se abre una visita. Otros celulares que escanean durante esa visita comparten la cuenta y cada uno conserva su carrito. Confirmar el pago cierra la visita, invalida sus sesiones y libera la mesa para que el mismo QR inicie otra visita.
- Si un producto se agota o cambia de precio antes de confirmar, el cliente ve el cambio y puede revisar el pedido. El pedido guarda los precios confirmados.
- Al editar el carrito se recalculan los subtotales, el descuento y el total sin recargar. El cliente puede revisar todos los platos antes de confirmar.
- El servidor valida el código al ingresarlo y al confirmar su primer uso. Si el código es inválido, está inactivo o queda fuera de vigencia, el cliente recibe un aviso y puede revisar el total antes de confirmar sin descuento.
- El resumen del cliente y la solicitud de pago del personal muestran el mismo subtotal, descuento y total a pagar, calculados sobre los pedidos confirmados.
- El pedido aparece en el panel sin recargar. Los cambios de estado también llegan al cliente sin recargar.
- Si falla la conexión durante el envío, se puede reintentar sin duplicar el pedido. La confirmación aparece cuando el servidor registra el pedido.
- El panel exige autenticación. Cada cliente solo puede consultar los pedidos de su propia sesión.
- Después de iniciar sesión, el personal y el encargado llegan a Inicio. Al reabrir la app se conserva la sesión hasta que el usuario pulsa «Cerrar sesión». Inicio ofrece acceso a Mesas y, para el encargado, a Administrar platos.
- El resumen incluye todos los pedidos confirmados de la sesión, utiliza los precios guardados en cada pedido y se puede descargar antes de cerrar la visita.
- La llamada al mesero aparece sin recargar. Si el cliente vuelve a pulsar mientras está pendiente, sigue viendo la misma solicitud. Al atenderla, el panel deja de mostrarla como pendiente.
- Después de elegir el método, Cuenta muestra «El personal va a tu mesa», conserva visible el método y explica que la boleta se entrega después del pago. Si el personal reabre la cuenta, vuelve a aparecer «Pagar».
- Solicitar el pago con cualquiera de los tres métodos actualiza el panel sin recargar y mantiene el saldo pendiente. Solo el personal autenticado puede confirmar el pago. La confirmación cierra la mesa automáticamente una vez entregados los pedidos. Marcarla para revisión mantiene visible el saldo pendiente.

## Piloto

Comparar turnos similares antes y después del piloto. Medir el porcentaje de pedidos hechos por QR, el tiempo de toma del pedido y las intervenciones del personal. Mantener el pedido asistido para quienes lo necesiten y usar los resultados para decidir la dotación.
