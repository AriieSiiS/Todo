# Seguimiento gratuito de Compras

El motor es changedetection.io, instalado en un entorno Python aislado de
Windows. No necesita Keepa, Supabase, claves de IA, Docker ni WSL. Su API y el
adaptador de Todo escuchan únicamente en `127.0.0.1`, con claves locales. No se
exponen puertos a la red ni se contrata el servicio alojado.

Amazon se carga con el Edge instalado, en segundo plano y con un perfil propio
sin tus cookies ni tu cuenta. Playwright conecta ese navegador al motor; no se
descarga otro navegador ni se activan extensiones de evasión. Los puertos se
eligen dinámicamente para evitar los rangos reservados de Windows.

## Funcionamiento

- En la ficha de Compras, «Seguir precio» activa revisiones cada 24 horas.
- «Revisar ahora» solicita una comprobación; no ejecuta un modelo de lenguaje.
- Se muestra el precio observado, fecha, historial y último error de lectura.
- Una ficha puede reunir varias opciones con nombre y enlace propio. Cada
  enlace tiene su monitor, base e historial independientes; la tarjeta sigue
  siendo única. Activar, pausar o revisar actúa sobre todas sus opciones. Los
  avisos identifican la opción y abren su ficha de compra. Quitar una opción
  pausa su monitor sin borrar su historial.
- Un cambio válido produce un aviso de Windows y queda registrado en Compras.
  La primera lectura establece la base, sin inventar una bajada respecto al
  precio de referencia manual. Un precio objetivo añade contexto al aviso.
  Se respeta «Notificaciones» de los ajustes generales: si están desactivadas,
  el historial y los avisos internos se guardan sin enviar un aviso de Windows.
- Pausar conserva el historial. Comprar, archivar o eliminar un producto pausa
  su monitor. Cambiar de enlace reinicia la base de comparación del nuevo enlace.
- El servicio continúa aunque Todo esté cerrado, mientras Windows tenga una
  sesión iniciada y el PC esté encendido. No despierta un equipo apagado.

La tarea de Windows inicia el supervisor al entrar en la sesión y lo reinicia
ante fallos. changedetection.io programa las revisiones; no se crea una
automatización de Codex ni se gastan tokens durante el seguimiento.

## Datos y seguridad

`Documents/Todo/shopping/price_tracking` contiene el historial SQLite y el
almacén de changedetection.io. Entra en las copias completas existentes de
Compras. El adaptador solo **lee** `runtime/todo_state.json` para reconciliar
productos; nunca lo sobrescribe. La app sigue siendo la única propietaria de
sus fichas. La instalación Python y las credenciales locales están bajo
`%LOCALAPPDATA%/Todo/price_tracker`; no se incluyen en el snapshot ni se muestran
en los registros.

Las peticiones de la app requieren un token y no se habilita CORS. Solo se
aceptan enlaces HTTPS de fichas concretas de Amazon España con ASIN. Una búsqueda,
tuit o imagen no basta: primero hay que indicar la ficha exacta. Los filtros
extraen el precio principal, no los productos recomendados ni el precio tachado.

## Límites

El precio es el visible para el navegador del servicio, en euros, sin sesión
Amazon. No suma envío ni aplica cupones, Prime, descuentos personales o pagos
fraccionados. Se exige un único precio inequívoco. Ante un bloqueo, ausencia de
precio o lectura ambigua se guarda el error y se conserva el último precio
válido. No se resuelven ni eluden CAPTCHAs, ni se usan proxies de pago.

Una revisión diaria puede perder una oferta entre revisiones. El histórico
empieza al activar el monitor: no recupera el histórico de Keepa. Los avisos
dependen de los permisos y del modo de concentración de Windows.

## Instalación y comprobaciones

`tooling/price_tracker/install.ps1` instala el motor y registra la tarea del
usuario, sin permisos de administrador ni modificar el Python global. Los
registros y el estado del servicio permiten verificar el arranque sin abrir
la app instalada. Las pruebas del adaptador usan un motor simulado y un
servidor HTTP local; nunca envían avisos ni escriben datos personales.

Fuentes del motor:

- <https://github.com/dgtlmoon/changedetection.io>
- <https://changedetection.io/docs/api_v1/>
- <https://github.com/dgtlmoon/changedetection.io/wiki/Microsoft-Windows>

El soporte de Amazon debe verificarse con una lectura real: instalar el motor
o superar pruebas simuladas no demuestra que Amazon permita leer un producto.

## Copias del histórico

Antes de copiar o restaurar manualmente `shopping/price_tracking`, detener el
servicio con `tooling/price_tracker/stop.ps1 -RuntimeDirectory` y la ruta de su
instalación local. Así no se copia una base SQLite mientras se está escribiendo.
Después se puede iniciar de nuevo la tarea `\Todo\SeguimientoCompras`. Pausar
un producto no detiene el servicio completo. Las copias creadas con el servicio
activo no garantizan una captura consistente de su histórico.
