# MenuApp · Piloto de 14 días sin el PC

La versión para alojamiento está preparada y probada en Docker. Falta publicar la web y la API, crear la base de datos del piloto y apuntar el APK a la dirección pública.

**Estado actual:** GitHub CLI ya está autenticado. El código se está preparando en Git local. Render está abierto en Edge. Queda autorizar la subida al repositorio privado y, cuando exista, dar a Render acceso a ese repositorio.

## 1. Lo que te toca ahora

1. **GitHub: completado.** Si necesitas volver a iniciar sesión, abre **Terminal → Nueva terminal** en VS Code y ejecuta:

   ```powershell
   gh auth login --hostname github.com --git-protocol https --web
   ```

   Completa el inicio de sesión en el navegador. Yo puedo comprobar la conexión y crear el repositorio privado. [Guía de GitHub CLI](https://cli.github.com/manual/gh_auth_login)

2. **Entra a Render** con la cuenta que será dueña del piloto. Si quieres que yo gestione el despliegue desde esta conversación, instala y conecta la integración de Render. [Panel de Render](https://dashboard.render.com/)

3. **Avísame cuando termines.** Puedes escribir «GitHub listo, Render listo. Autorizo subir MenuApp a un repositorio privado». Completa los inicios de sesión en el navegador. Contraseñas, tokens y códigos de verificación se quedan fuera del chat.

## 2. Lo que haré yo

1. Revisaré los archivos que se subirán, crearé el repositorio privado y subiré el código. La base de pruebas del PC y las contraseñas locales quedan fuera.
2. Prepararé el despliegue con [render.yaml](render.yaml) para que Render construya la web y la API, conecte un PostgreSQL privado y aplique la migración. Verificaré el precio del servicio y de la base para que apruebes el gasto antes de activarlos.
3. Una vez publicado, verificaré la dirección HTTPS, compilaré el APK para esa dirección e instalaré la actualización cuando el Moto esté conectado. Configuraré las cuentas individuales del personal y cargaré la carta cuando tengamos los datos del local.

## 3. Lo que podría volver a requerir tu intervención

- **Autorizar a Render a leer el repositorio privado.** Te indicaré su nombre una vez creado. Si GitHub pide acceso, selecciona solo el repositorio de MenuApp. [Conectar GitHub a Render](https://render.com/docs/git-provider)
- **Aprobar el costo.** El restaurante prueba gratis. Nosotros cubrimos los recursos contratados. Los 14 días del piloto son nuestro acuerdo con el local. Render sigue cobrando mientras mantengamos los recursos activos.
- **Preparar el ensayo en el local.** Necesitaremos la carta, los precios, el número de mesas del piloto y los nombres de quienes tendrán acceso. Para la prueba final, conecta el Moto cuando instalemos el APK y luego apaga el PC. Desde otro celular, escanea un QR, haz un pedido, solicita la boleta y confirma un pago simulado desde el Moto.

El día 1 empieza cuando el local puede operar con sus propios datos y el flujo ya pasó el ensayo. Al día 14 revisamos el resultado y decidimos si mantener el servicio o coordinar su cierre.
