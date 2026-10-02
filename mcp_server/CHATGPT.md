# Todo como plugin privado de ChatGPT

Esta primera fase prepara una conexión privada con el MCP local de Todo. Los
datos reales siguen en `Documents/Todo/runtime/todo_state.json`. El adaptador
usa el SDK oficial de Python, con mensajes JSON por líneas sobre `stdio`; el
servidor anterior y su transporte con `Content-Length` siguen disponibles para
los clientes existentes.

## Estado de la preparación

- El adaptador `chatgpt_server.py` permite consultar datos locales sin escribir
  el snapshot, ejecutar migraciones ni tocar las preferencias de Windows.
- Se exponen `get_today`, `list_tasks`, `get_task`, `list_projects` y
  `list_categories`, con esquemas y anotaciones de solo lectura.
- `--sandbox` añade `create_task`, `update_task`, `complete_task` y
  `move_task_to_day`. Usa un estado vacío en memoria que desaparece al cerrar
  el proceso. Nunca importa las tareas reales. Cada respuesta indica
  `mode: "sandbox"` y `persistent: false`.
- Las entradas se validan antes de ejecutar una operación. No se permiten
  herramientas de borrado, importación, exportación completa, archivos ni
  ajustes. Las respuestas solo contienen datos de las entidades consultadas.
- Supabase está desactivado en ambos modos. El adaptador también omite el
  archivo `.env` del servidor antiguo y sus credenciales.
- Las pruebas verifican el transporte mediante un cliente del SDK, el
  arranque por PowerShell, el castellano con tildes y la ausencia de escrituras
  en los archivos utilizados como snapshot y preferencias.

El adaptador **todavía no está conectado a una cuenta de ChatGPT**. No se ha
creado un túnel ni instalado un plugin, y no se ha desplegado nada en Sites.

## Preparar Python en Windows

Desde la raíz del repositorio, con una instalación normal de Python 3.10 o
posterior:

```powershell
py -3 -m venv mcp_server/.venv-chatgpt
mcp_server/.venv-chatgpt/Scripts/python.exe -m pip install -r mcp_server/requirements-chatgpt.txt
```

El entorno está excluido de Git. `requirements-chatgpt.txt` fija la versión
probada del SDK. Si el Python empaquetado de Codex no consigue instalar `pip`
mediante `ensurepip`, su `pip` puede preparar el entorno ya creado:

```powershell
& "$env:USERPROFILE/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe" -m pip --python mcp_server/.venv-chatgpt/Scripts/python.exe install -r mcp_server/requirements-chatgpt.txt
```

## Arrancar el adaptador

Lectura del snapshot activo:

```powershell
./mcp_server/start_chatgpt_mcp.ps1
```

Sesión de prueba, sin leer ni escribir datos personales:

```powershell
./mcp_server/start_chatgpt_mcp.ps1 -Sandbox
```

Un snapshot alternativo para consultas:

```powershell
./mcp_server/start_chatgpt_mcp.ps1 -StatePath 'C:/ruta/estado.json'
```

El proceso espera mensajes MCP de un cliente. No muestra una interfaz ni
mensajes de arranque en la salida estándar; esa salida pertenece al protocolo.
Un archivo ausente, vacío, mal formado o ilegible produce un error de consulta,
sin crear un estado nuevo ni reemplazar el archivo.

## Conectar con Secure MCP Tunnel

La documentación oficial permite conectar servidores privados mediante stdio
o HTTP sin abrir puertos entrantes. El cliente del túnel debe permanecer
encendido junto al servidor. Esta ruta sirve para conexiones privadas y
pruebas en modo desarrollador; no publica un plugin en el directorio público.

1. Comprobar el acceso a [túneles de Platform](https://platform.openai.com/settings/organization/tunnels)
   y al modo desarrollador de ChatGPT. Se necesitan permisos de lectura y
   gestión para crear el túnel, y de lectura y uso para ejecutarlo.
2. Crear el túnel y asociarlo a la organización y al espacio de ChatGPT que lo
   utilizarán. Usar su identificador real; no inventar uno.
3. Instalar el cliente oficial indicado en esa página y consultar
   `tunnel-client help quickstart`. Verificar su soporte de Windows antes de
   configurar el proceso persistente.
4. Proporcionar la clave del cliente mediante la configuración segura o el
   entorno local indicado por esa versión del cliente. No pegarla en chats,
   guardarla en este repositorio ni añadirla a los argumentos del servidor.
5. Inicializar un perfil stdio que lance
   `mcp_server/.venv-chatgpt/Scripts/python.exe -u mcp_server/chatgpt_server.py`
   con rutas absolutas. Se pueden usar las opciones `--mcp-command` y
   `--tunnel-id` del cliente. Usar `--sandbox` solo en el perfil de pruebas;
   el perfil de datos reales arranca sin esa opción.
6. Ejecutar `tunnel-client doctor --profile todo-local --explain` y después
   `tunnel-client run --profile todo-local`.
7. En ChatGPT, activar el modo desarrollador y crear la conexión desde Plugins,
   seleccionando «Tunnel» y el túnel correspondiente. Comprobar que se
   anuncian cinco herramientas de lectura, consultar Hoy y comparar una tarea
   por su identificador con Todo.

Los nombres de perfil son elecciones locales; el identificador del túnel y el
de la conexión del plugin deben venir de OpenAI. La disponibilidad y los
permisos de esta cuenta aún no se han comprobado. Las instrucciones específicas
del cliente instalado prevalecen sobre estos ejemplos.

Fuentes:

- [Secure MCP Tunnel](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels)
- [Conectar y probar un plugin](https://developers.openai.com/plugins/deploy/connect-chatgpt)
- [Construir un servidor MCP](https://developers.openai.com/plugins/build/mcp-server)
- [Extensiones de plugins](https://developers.openai.com/plugins/build/extensions)

## Validación local

```powershell
mcp_server/.venv-chatgpt/Scripts/python.exe -m unittest discover -s mcp_server -p test_chatgpt_server.py -v
```

Las pruebas usan archivos temporales y procesos locales. No crean conexiones
externas ni requieren credenciales de OpenAI.

## Fases siguientes

1. Conectar y probar la lectura con la cuenta real mediante el túnel.
2. Resolver la coordinación entre `TodoWorkspace`, el MCP y el agente LAN.
   Actualmente Todo mantiene estado en memoria y no aplica automáticamente
   todas las modificaciones externas de tareas. Un bloqueo exclusivo del MCP
   no coordina las escrituras de Flutter ni evita sobrescribir cambios.
   Las escrituras reales se habilitarán después de verificar actualizaciones
   simultáneas, errores, reintentos y recarga con la app abierta.
3. Añadir un panel de Hoy mediante MCP Apps y las extensiones de ChatGPT.
4. Empaquetar el plugin utilizando el identificador real de la conexión.
   No se incluye un manifiesto con identificadores ficticios.

Sites puede formar parte de una fase posterior de alojamiento. Un despliegue
remoto no tiene acceso directo a los archivos del PC: requiere un puente
autenticado o un diseño de sincronización. La fase actual mantiene los datos
locales y necesita que el PC y el cliente del túnel estén encendidos.

Esta preparación cambia herramientas de agente, no el ejecutable Flutter.
Cuando la coordinación requiera cambios en la app, se harán las comprobaciones
de Flutter y la actualización verificada de la instalación de Windows.
