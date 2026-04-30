# AGENTS

Guia corta para que cualquier chat o agente entienda este proyecto sin reexplorarlo entero.

## Objetivo del repo

App personal de tareas hecha con Flutter, priorizando `Windows` como plataforma principal. Web y Android siguen soportadas, pero las decisiones de persistencia local, validacion manual y experiencia de escritorio se revisan primero en Windows.

La app tiene:

- estado local persistente en `runtime/todo_state.json`
- sincronizacion opcional con Supabase
- servidor MCP local para operar el mismo snapshot desde agentes
- arquitectura por capas con estado de aplicacion en Riverpod

## Lectura minima recomendada

1. `README.md`
2. `lib/app/todo_app.dart`
3. `lib/application/state/todo_workspace.dart`
4. `lib/application/providers/todo_providers.dart`
5. `lib/presentation/shell/app_shell.dart`
6. `mcp_server/README.md` si la tarea toca automatizacion o agentes externos

## Mapa rapido

### App

- `lib/main.dart`: arranque y `ProviderScope` raiz
- `lib/app/todo_app.dart`: carga `TodoWorkspace`, aplica tema y monta el shell
- `lib/app/app_launch_intent.dart`: argumentos de arranque para abrir secciones o editores
- `lib/app/todo_theme.dart`: tema visual

### Application

- `lib/application/state/todo_workspace.dart`: estado de aplicacion y operaciones del producto
- `lib/application/providers/todo_providers.dart`: providers Riverpod

`TodoWorkspace` es la fuente de verdad de runtime. Maneja tareas, proyectos, categorias, notas, calendario, ajustes, notificaciones, persistencia y sincronizacion.

### Domain

- `lib/domain/entities/`: entidades y value objects
- `lib/domain/snapshots/`: contrato JSON compartido con local, Supabase y MCP
- `lib/domain/repositories/`: contratos de persistencia, nube, calendario y notificaciones
- `lib/domain/models.dart`: barrel publico de dominio

### Data e integraciones

- `lib/data/local_store.dart`: contrato de store local
- `lib/data/local_store_file_backed.dart`: store principal para Windows/IO
- `lib/data/local_store_shared_prefs.dart`: store para web
- `lib/data/repositories/`: adaptadores hacia repositorios de dominio
- `lib/services/`: integraciones de plataforma, Supabase, calendario, notificaciones y scheduler

### Presentation

- `lib/presentation/shell/app_shell.dart`: archivo raiz con parts del shell
- `lib/presentation/shell/shell_chrome.dart`: shell, sidebar, navegacion y reproductor
- `lib/presentation/shell/today_page.dart`: vista Hoy
- `lib/presentation/shell/projects_page.dart`: vista Proyectos
- `lib/presentation/shell/categories_page.dart`: vista Categorias
- `lib/presentation/shell/calendar_page.dart`: vista Calendario
- `lib/presentation/shell/completed_page.dart`: vista Completadas
- `lib/presentation/shell/settings_page.dart`: vista Ajustes
- `lib/presentation/shell/shared_widgets.dart`: widgets compartidos del shell
- `lib/presentation/shared/editors.dart`: API publica de editores
- `lib/presentation/shared/*_editor.dart`: editores por entidad
- `lib/presentation/shared/editor_pickers.dart`: pickers de fecha, hora, recordatorio, color e icono

## Atajos para abrir una vista exacta

Secciones:

- `--section=today`
- `--section=projects`
- `--section=categories`
- `--section=calendar`
- `--section=completed`
- `--section=settings`

Editores:

- `--new-task`
- `--new-project`
- `--new-category`

Windows primero:

```text
flutter run -d windows -- --section=today
flutter run -d windows -- --section=calendar
flutter run -d windows -- --new-task
```

## Fuente de verdad segun tarea

UI o flujo visual:

- `lib/presentation/shell/*_page.dart`
- `lib/presentation/shared/*_editor.dart`
- `lib/app/todo_theme.dart`

Logica de producto:

- `lib/application/state/todo_workspace.dart`
- `lib/domain/entities/`
- `lib/domain/snapshots/`

Persistencia, Supabase o calendario:

- `lib/data/repositories/`
- `lib/data/local_store_file_backed.dart`
- `lib/services/`
- `runtime/todo_state.json`

MCP:

- `mcp_server/README.md`
- `mcp_server/server.py`
- `mcp_server/start_mcp.ps1`

## Validacion recomendada

Para cambios generales:

```text
flutter analyze
flutter test
flutter build windows --debug
```

Para cambios visuales importantes, arrancar Windows con la seccion exacta que se haya tocado.
