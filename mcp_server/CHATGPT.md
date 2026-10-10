# Todo como plugin privado de ChatGPT

El adaptador estándar `chatgpt_server.py` conecta el MCP local con ChatGPT por
Secure MCP Tunnel. Los datos permanecen en `Documents/Todo/runtime/todo_state.json`.
Supabase está desactivado: no se carga el `.env` antiguo ni se utilizan sus
credenciales. El transporte stdio usa mensajes JSON UTF-8 por líneas del SDK
oficial; el servidor anterior conserva su transporte con `Content-Length`.
Las consultas reutilizan los manejadores del MCP completo en `server.py` sobre
el estado local o en memoria. El adaptador añade búsqueda y paginación; las
escrituras de ChatGPT pasan por Todo abierto para no sobrescribir sus cambios.

## Funciones disponibles

- Consultar Hoy, buscar tareas, consultar una tarea, listar proyectos y categorías.
- Crear, editar, mover, completar y borrar tareas locales mediante Todo abierto.
- Consultar, crear, editar, archivar y borrar notas de Entrada.
- Buscar y consultar fichas de Ropa, conjuntos, usos, planes y maletas; Recetas y
  menús; Hogar; Compras; Biblioteca y sus objetivos. Estas colecciones son de lectura.
- Abrir el panel **Hoy en Todo** como MCP App, con entradas para la barra lateral
  y el panel de conversación. Permite actualizar, añadir y completar tareas.
- Probar las herramientas con un estado vacío en memoria, sin datos personales.
- Instalar el cliente oficial de túneles para Windows y comprobar su hash publicado.
- Arrancar un proceso supervisado con un túnel real y una referencia local a su clave.
- Generar el paquete del plugin cuando exista el identificador real de la conexión.

La conexión requiere un túnel activo, una clave de ejecución y el registro en
ChatGPT con la cuenta autenticada. El túnel local y el panel ya se han utilizado
desde ChatGPT. No se ha desplegado en Sites ni publicado en un directorio público.

## Respuestas de consulta

«Muéstrame las tareas de hoy» utiliza `get_today` y devuelve únicamente los títulos
en una lista de texto. No abre paneles, no añade explicaciones, prioridades,
resúmenes, propuestas ni casillas de seguimiento ajenas a Todo. Los detalles se
incluyen cuando el usuario los solicita.

`open_today_panel` abre **Hoy en Todo** solo ante una petición expresa de abrir
el panel. Ambas herramientas consultan las mismas tareas; únicamente la segunda
tiene un recurso visual asociado. Tras actualizar estas instrucciones, hay que
actualizar las herramientas de la conexión en ChatGPT y probar en un chat nuevo.

## Navegar por el contenido

`list_content_sections` muestra las colecciones disponibles y sus tamaños.
`browse_content` busca por palabras, estado y tipo, con páginas de hasta 100 fichas;
`get_content_item` consulta una ficha completa por su identificador. No abre vistas.
Las respuestas distinguen datos en memoria de la última copia guardada y omiten
rutas de archivos locales. No leen imágenes, manuales ni facturas: consultan los
datos registrados, enlaces, ingredientes, pasos, valoraciones y fechas disponibles.

Para «¿jugué a este juego?» se comprueba el estado y la fecha de Biblioteca; una
entrada pendiente en objetivos no demuestra que esté completado. Para «mi camisa
azul» se busca en Ropa y se consulta su ficha y, si hace falta, sus usos o conjuntos.
No se afirma que una ficha no existe sin revisar la búsqueda y sus páginas.

Las notas se consultan con `list_notes` y `get_note`. Las modificaciones requieren
`note_version` como `expected_version`, y las escrituras conservan `request_id`
para reintentos. Borrar una tarea incluye todas sus subtareas y limpia sus referencias;
el resultado indica los identificadores afectados. Borrar tareas o notas requiere
`confirm: true` tras una petición explícita de borrar. No se ofrecen borrados masivos.

## Preparar Python en Windows

```powershell
py -3 -m venv mcp_server/.venv-chatgpt
mcp_server/.venv-chatgpt/Scripts/python.exe -m pip install -r mcp_server/requirements-chatgpt.txt
```

El entorno está excluido de Git. Si el Python empaquetado de Codex no consigue
preparar `pip` con `ensurepip`, su `pip` puede instalar en el entorno ya creado:

```powershell
& "$env:USERPROFILE/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe" -m pip --python mcp_server/.venv-chatgpt/Scripts/python.exe install -r mcp_server/requirements-chatgpt.txt
```

## Modos de funcionamiento

Solo lectura del snapshot, sin escrituras, migraciones ni preferencias:

```powershell
./mcp_server/start_chatgpt_mcp.ps1
```

Lectura del estado en memoria y escritura mediante Todo abierto:

```powershell
./mcp_server/start_chatgpt_mcp.ps1 -Live
```

Prueba aislada en memoria, sin leer ni modificar la colección real:

```powershell
./mcp_server/start_chatgpt_mcp.ps1 -Sandbox
```

`-StatePath` permite seleccionar otro snapshot. Los modos `-Live` y `-Sandbox`
son excluyentes. El proceso espera a un cliente MCP; no imprime mensajes de
arranque en la salida estándar, que pertenece al protocolo.

## Cómo se guardan los cambios

La instalación de Todo inicia un puente HTTP en `127.0.0.1`, con un puerto
aleatorio y un token distinto por sesión. Su archivo de conexión está en
`runtime/agent_bridge_session.json`. Nunca se envía ese token a ChatGPT: el
adaptador stdio lo utiliza únicamente dentro del PC. El puente rechaza peticiones
sin token y peticiones que incluyan `Origin`, y no escucha en la LAN. Un bloqueo
de archivo impide que dos puentes publiquen la misma sesión.

El adaptador solicita operaciones a `TodoWorkspace`; **nunca escribe directamente
el snapshot real**. Cada operación se valida también en Flutter y se aplica sobre
su estado actual. El agente LAN continúa leyendo los archivos que guarda Todo.

Cada escritura necesita un `request_id` único. La tarea y el resultado se guardan
juntos en `agentOperationReceipts`, dentro del mismo snapshot. Un reintento con
el mismo identificador y argumentos devuelve el resultado original sin repetir
el cambio, incluso después de recargar. Reutilizarlo para otra operación se
rechaza. Se conservan hasta 10.000 operaciones; al alcanzar ese límite se
rechazan escrituras nuevas sin eliminar silenciosamente la protección anterior.

Para editar, mover o completar se requiere `expected_version`, obtenido del
`task_version` devuelto al consultar. La versión incluye la tarea, sus subtareas
y el día lógico. Una edición reciente o un cambio de día obliga a consultar de
nuevo. Completar una rutina marca la ocurrencia del día lógico; un reintento
nunca la vuelve a abrir.

Solo se devuelve `savedLocally: true` después de guardar. Si falla la persistencia,
el cambio queda en memoria con su identificador pendiente: el mismo reintento
vuelve a intentar guardarlo. Los errores del MCP indican `retryable`; el panel
conserva la petición cuando no está confirmado el resultado.

Si Todo está cerrado, las consultas usan el snapshot y las escrituras devuelven
un error. Hoy respeta el día lógico manual, las rutinas completadas o saltadas y
el orden guardado. El panel muestra que debe abrirse Todo para modificar tareas.

Las escrituras de este adaptador cubren título, descripción, fecha y hora,
prioridad, categorías y proyectos; la creación también admite recurrencia.
No permiten importar, exportar el estado completo, editar ajustes ni gestionar
archivos. Las tareas archivadas o enlazadas al calendario se modifican
desde Todo. Los campos no editados se conservan, incluidos materiales y avisos.
Las herramientas antiguas ajenas a este adaptador mantienen su funcionamiento;
no se convierten automáticamente en clientes del puente.

## Conectar el túnel

Esta conexión es privada y saliente. No requiere abrir puertos entrantes ni
publicar un servidor accesible sin autenticación. Necesita el PC y el cliente
del túnel encendidos; para escribir también debe estar abierta la app Todo.

1. Iniciar sesión en [túneles de Platform](https://platform.openai.com/settings/organization/tunnels).
   Crear el túnel y asociarlo a la organización y al espacio de ChatGPT adecuados.
   Crear requiere permisos Tunnels Read + Manage; ejecutarlo requiere Read + Use.
2. Instalar el cliente oficial para la arquitectura de Windows:

   ```powershell
   ./tooling/install_mcp_tunnel_client.ps1
   ```

   El instalador consulta la última publicación oficial y verifica SHA-256 antes
   de extraer. El binario queda en `mcp_server/.tunnel-client/`, excluido de Git.
3. Crear una clave **de ejecución**, con acceso al túnel; no utilizar una clave
   administrativa para el proceso persistente. Introducirla en un terminal local
   mediante entrada oculta:

   ```powershell
   ./mcp_server/save_chatgpt_runtime_key.ps1
   ```

   Se guarda en `%LOCALAPPDATA%/Todo/ChatGPT/runtime.key`, fuera del repositorio,
   con permisos exclusivos del usuario actual. No pegarla en chats ni incluirla
   en argumentos. El cliente oficial lee el archivo mediante una referencia
   `file:`; el archivo contiene la clave y debe mantenerse privado.
   El guardado aplica los permisos mediante las API de Windows, sin depender de
   la carga de `Microsoft.PowerShell.Security`. Si un intento fallido dejó un
   archivo vacío, se puede repetir; una clave ya guardada nunca se sobrescribe.
   Antes de guardar se comprueba el formato de la entrada. El mensaje de guardado
   no confirma la autenticación: esta solo se confirma al conectar el túnel.
4. Arrancar con el identificador real devuelto por Platform:

   ```powershell
   ./mcp_server/start_chatgpt_tunnel.ps1 -TunnelId $idRealDelTunel -RuntimeKeyFile "$env:LOCALAPPDATA/Todo/ChatGPT/runtime.key"
   ```

   El script utiliza `tunnel-client runtimes connect`, el alias `todo-local` y
   el servidor stdio con `--live`. Después muestra el estado JSON. Solo confirmar
   conexión cuando `process_running`, `healthy` y `ready` estén activos. Si falla,
   consultar `tunnel-client doctor --profile todo-local --explain` y los permisos
   de la cuenta. Los identificadores no se inventan ni se incluyen en Git.
5. Con el túnel activo, activar el modo desarrollador de ChatGPT y crear la
   conexión desde [Plugins](https://chatgpt.com/plugins), seleccionando **Tunnel**.
   Comprobar las herramientas registradas y el recurso `ui://todo/hoy.html`.
   Consultar Hoy y comparar una tarea real por su identificador con Todo.
6. Actualizar la conexión en ChatGPT después de cambiar herramientas o metadatos.

Las instrucciones concretas de la versión instalada del cliente prevalecen.
El cliente verificado durante la preparación fue `v0.0.15` para Windows amd64.
Cada cuenta debe disponer de los permisos indicados para configurar la conexión.

## Paquete del plugin

Después de registrar la conexión, copiar su identificador real del enlace de
ChatGPT (`plugin_asdk_app_…`) y ejecutar:

```powershell
mcp_server/.venv-chatgpt/Scripts/python.exe mcp_server/package_chatgpt_plugin.py --connection-id $idRealDeLaConexion
```

El ZIP en `output/chatgpt/todo-personal.zip` contiene `plugin.json`, `.app.json`
y un README. Usa el manifiesto portable y la referencia MCP registrada, sin
copiar tareas, credenciales, entorno Python ni recursos personales. La instalación
del paquete se realiza desde el flujo de plugins de la cuenta; generarlo no
confirma que esté instalado. No se genera un paquete con identificadores ficticios.

## Validación

```powershell
mcp_server/.venv-chatgpt/Scripts/python.exe -m unittest discover -s mcp_server -p 'test_chatgpt*.py' -v
flutter test --no-pub test/agent_bridge_test.dart
flutter analyze --no-pub
flutter test --no-pub
flutter build windows --debug --no-pub
```

Las pruebas usan archivos temporales: autenticación, consultas en memoria,
escrituras simultáneas, versiones antiguas, guardados fallidos, reintentos,
recarga, rutinas y traslado conservando la hora. Con el entorno Python instalado,
la prueba Flutter arranca un cliente del SDK y un servidor stdio reales contra
su puente temporal. No modifica datos personales ni requiere credenciales.

El panel se puede comprobar localmente con un host de prueba; eso no sustituye
la validación final dentro de ChatGPT. La actualización de Flutter requiere
instalar y verificar los hashes de Windows. La prueba visual de la aplicación
instalada corresponde al usuario.

## Fuentes

- [Secure MCP Tunnel](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels)
- [MCP y panel de ejemplo](https://developers.openai.com/plugins/build/app-quickstart)
- [Extensiones de plugins](https://developers.openai.com/plugins/build/extensions)
- [Conectar un plugin](https://developers.openai.com/plugins/deploy/connect-chatgpt)
- [Empaquetar un plugin](https://developers.openai.com/plugins/build/plugins)

Sites puede alojar una interfaz o un servidor remoto en una fase posterior.
Ese despliegue no accede directamente a los archivos del PC. Esta implementación
conserva la fuente local y usa el túnel privado para llegar hasta ella.
