# MenuApp · Piloto de 14 días sin el PC

La versión para alojamiento está preparada y probada en Docker. Falta publicar la web y la API, crear la base de datos del piloto y apuntar el APK a la dirección pública.

**Estado actual:** el código está en el repositorio privado [Vejat/MenuApp](https://github.com/Vejat/MenuApp), en la rama `main`. Falta dar a Render acceso a ese repositorio y revisar el costo antes de activar los recursos.

## 1. Lo que te toca ahora

1. **GitHub: completado.** Si necesitas volver a iniciar sesión, abre **Terminal → Nueva terminal** en VS Code y ejecuta:

   ```powershell
   gh auth login --hostname github.com --git-protocol https --web
   ```

   Completa el inicio de sesión en el navegador. Yo puedo comprobar la conexión y crear el repositorio privado. [Guía de GitHub CLI](https://cli.github.com/manual/gh_auth_login)

2. **Conecta el repositorio a Render.** En Edge, abre el panel de Render y selecciona **New → Blueprint**. Si te pide conectar GitHub, autoriza el acceso solo a **Vejat/MenuApp**. Selecciona ese repositorio y deja abierta la pantalla que muestra los recursos del Blueprint. [Panel de Render](https://dashboard.render.com/)

3. **Avísame cuando veas los recursos del Blueprint.** Revisaremos el costo de la API y PostgreSQL antes de pulsar **Deploy Blueprint**. Contraseñas, tokens y códigos de verificación se quedan fuera del chat.

## 2. Lo que haré yo

1. **Completado.** Revisé y subí el código al repositorio privado. La base de pruebas del PC y las contraseñas locales quedaron fuera.
2. Prepararé el despliegue con [render.yaml](render.yaml) para que Render construya la web y la API, conecte un PostgreSQL privado y aplique la migración. Verificaré el precio del servicio y de la base para que apruebes el gasto antes de activarlos.
3. Una vez publicado, verificaré la dirección HTTPS, compilaré el APK para esa dirección e instalaré la actualización cuando el Moto esté conectado. Configuraré las cuentas individuales del personal y cargaré la carta cuando tengamos los datos del local.

## 3. Lo que podría volver a requerir tu intervención

- **Autorizar a Render a leer el repositorio privado.** Te indicaré su nombre una vez creado. Si GitHub pide acceso, selecciona solo el repositorio de MenuApp. [Conectar GitHub a Render](https://render.com/docs/git-provider)
- **Aprobar el costo.** El restaurante prueba gratis. Nosotros cubrimos los recursos contratados. Los 14 días del piloto son nuestro acuerdo con el local. Render sigue cobrando mientras mantengamos los recursos activos.
- **Presupuesto de referencia.** El Blueprint usa una instancia web de USD 7 al mes y PostgreSQL de USD 6 al mes con 1 GB de disco. Presupuesta hasta USD 0,30 mensuales para ese almacenamiento y revisa el importe en Render. Con 14 días de recursos activos, el costo base estimado es de unos USD 6,20, antes de impuestos o excedentes de uso. [Precios de Render](https://render.com/pricing)
- **Preparar el ensayo en el local.** Necesitaremos la carta, los precios, el número de mesas del piloto y los nombres de quienes tendrán acceso. Para la prueba final, conecta el Moto cuando instalemos el APK y luego apaga el PC. Desde otro celular, escanea un QR, haz un pedido, solicita la boleta y confirma un pago simulado desde el Moto.

El día 1 empieza cuando el local puede operar con sus propios datos y el flujo ya pasó el ensayo. Al día 14 revisamos el resultado y decidimos si mantener el servicio o coordinar su cierre.
