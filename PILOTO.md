# MenuApp: publicación gratuita para pruebas

La configuración está preparada para alojar en Render, sin comprar dominio ni elegir recursos de pago. Render entrega una dirección HTTPS `*.onrender.com`. El sitio, la API y PostgreSQL quedan en el mismo despliegue. Los clientes usan los QR y el personal/administrador entra en la misma dirección con `?personal=1`.

## Límites del plan gratis

- La web/API se duerme tras 15 minutos sin visitas; la primera apertura puede tardar cerca de un minuto.
- PostgreSQL gratis tiene 1 GB, no incluye copias de seguridad y vence a los 30 días. Guarda solo datos de prueba y exporta lo que quieras conservar antes del vencimiento.
- Está pensado para probar, no para operar un restaurante de forma continua.

## Publicar

1. En Render, crea un **Blueprint** desde el repositorio GitHub `Vejat/MenuApp`, rama `main`, y revisa que los dos recursos indiquen plan **Free** antes de desplegar. El archivo `render.yaml` genera contraseñas iniciales para `admin` y `staff`; consúltalas en las variables de entorno del servicio y entrégalas directamente a sus titulares. No las pegues en el chat.
2. Pulsa **Deploy Blueprint**. Render construirá Flutter Web y Node; el servicio migrará PostgreSQL al arrancar y asignará la URL pública. La página de clientes queda en la raíz; el acceso web del personal queda en `https://<servicio>.onrender.com/?personal=1`.
3. Para cuentas individuales, ejecuta `node accounts.mjs create usuario staff` o `node accounts.mjs create usuario admin` con `DATABASE_URL` configurada desde una terminal segura. Para restablecer o revocar, usa `node accounts.mjs reset usuario` o `node accounts.mjs disable usuario`. No compartas la URL de conexión ni contraseñas públicamente.
4. En Android, compila el APK conectado a la misma API pública: `flutter build apk --debug --dart-define=API_URL=https://<servicio>.onrender.com`. Al instalarlo, el personal inicia sesión con las cuentas anteriores. La app móvil y la web operan sobre la misma base de datos remota; no se requiere que el computador del restaurante quede encendido.
5. Desde celulares distintos, ensaya QR, pedidos, cambios de estado, llamada al mesero, solicitud y confirmación de pago. Confirma que ambos paneles reflejen los mismos datos.

El código ya está listo para estos pasos, pero el servicio todavía no está publicado: Render debe tener acceso al repositorio y alguien con acceso a la cuenta debe iniciar el despliegue. No es necesario agregar tarjeta para crear los recursos gratuitos; confirma que el panel muestre **Free** antes de aceptar.
