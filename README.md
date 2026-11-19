# MenuApp

Flutter Web para clientes y Flutter móvil para el restaurante. La interfaz usa Carta nocturna. El cliente entra por QR y navega entre Carta, Cuenta, Pedidos y Carrito. Puede llamar al mesero desde Ayuda. El personal gestiona pedidos y llamadas desde Inicio → Pedidos, y cobros desde Inicio → Cuentas. El encargado también administra platos y descuentos desde Inicio.

## Desarrollo local

1. Crea una base PostgreSQL vacía. En PowerShell, configura `DATABASE_URL`, `ADMIN_PASSWORD` y `STAFF_PASSWORD`. Las contraseñas deben tener al menos 12 caracteres. Los usuarios iniciales son `admin` y `staff`.
2. Instala las dependencias y aplica el esquema.

   ```powershell
   npm.cmd --prefix api ci
   npm.cmd --prefix api run migrate
   flutter pub get
   ```

3. Para probar con celulares en la misma red, usa la IP local del PC en lugar de `192.168.1.10`. Ejecuta la API y la web en terminales independientes.

   ```powershell
   $env:PUBLIC_WEB_URL = 'http://192.168.1.10:8080'
   $env:API_HOST = '0.0.0.0'
   npm.cmd --prefix api start
   ```

   ```powershell
   flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 --dart-define=API_URL=http://192.168.1.10:3000
   ```

4. Ejecuta la app Android de depuración con `flutter run -d <dispositivo> --dart-define=API_URL=http://192.168.1.10:3000`. Inicia sesión, abre una mesa y escanea su QR con el navegador del cliente.

HTTP está previsto para desarrollo local. El restaurante cobra y emite la boleta con su sistema habitual. El personal confirma el pago en MenuApp antes de cerrar la mesa.

## Piloto sin el PC

Para seguir el despliegue y ver qué requiere tu intervención, abre [PILOTO.md](PILOTO.md).

El [Dockerfile](Dockerfile) compila Flutter Web y sirve la carta y la API en la misma dirección. [render.yaml](render.yaml) define un servicio Render y un PostgreSQL privado, ambos de pago. La API comprueba la base en `/healthz` y limita los intentos de ingreso. Mantener una instancia de la API mientras las notificaciones en tiempo real sean internas a ese proceso.

1. Conectar el repositorio privado a Render y revisar los cargos antes de aplicar el Blueprint. La migración crea el esquema y la cuenta `admin` con la contraseña inicial generada en Render. La cuenta compartida `staff` solo se crea cuando se configura `STAFF_PASSWORD`.
2. Crear una cuenta por persona con `node accounts.mjs create nombre staff` en el servicio. El comando muestra una contraseña inicial. `node accounts.mjs reset nombre` genera otra contraseña y reactiva la cuenta. `node accounts.mjs disable nombre` quita el acceso e invalida las sesiones. Compartir cada contraseña directamente con su titular.
3. Con la URL HTTPS publicada, compilar Android con `flutter build apk --debug --dart-define=API_URL=https://<host-del-piloto>`. Instalar ese APK de prueba en el teléfono del personal. La web usa la misma URL que la API y el servidor genera los QR con la dirección pública.
4. Cargar la carta y ensayar con el PC apagado. Confirmar pedido, recepción y cambios de estado, llamada al mesero, PDF, boleta, pago simulado y cierre. Contar los 14 días desde que el restaurante puede iniciar el servicio.
