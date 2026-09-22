# AGENTS

Guía corta para que cualquier chat o agente entienda este proyecto sin reexplorarlo entero.

## Supabase desactivado temporalmente

Supabase no está funcionando y debe ignorarse hasta que el usuario indique lo
contrario. Los datos locales son la única fuente de verdad: no se debe intentar
conectar, sincronizar, diagnosticar ni validar nada contra Supabase, ni bloquear
una tarea por su estado. Esta regla prevalece sobre cualquier flujo general o
skill que normalmente obligue a comprobar Supabase.

## Regla de idioma

Todo texto visible de la app y de la documentación propia del proyecto debe estar en castellano correcto, con tildes, `ñ` y signos adecuados. Antes de entregar cambios de UI hay que buscar y corregir textos sin acentos como `Categoria`, `Mas`, `rapido` o `sesion`, además de cualquier mojibake. No se deben introducir textos en inglés salvo nombres técnicos inevitables, marcas, APIs, claves internas o comandos no visibles.

A partir de ahora, todo cambio nuevo en este proyecto debe escribirse en castellano: textos visibles, mensajes de error propios, documentación, comentarios nuevos y nombres descriptivos de datos de ejemplo. Si un término técnico queda en inglés por convención del framework, debe estar justificado por ser identificador, API o nombre de herramienta.

## Objetivo del repo

App personal de tareas hecha con Flutter, priorizando `Windows` como plataforma principal. Las decisiones de persistencia local, validación manual y experiencia de escritorio se revisan primero en Windows.

La app tiene:

- estado local persistente en `runtime/todo_state.json`
- sincronización opcional con Supabase
- servidor MCP local para operar el mismo snapshot desde agentes
- arquitectura por capas con estado de aplicación en Riverpod

## Lectura mínima recomendada

1. `README.md`
2. `lib/app/todo_app.dart`
3. `lib/application/state/todo_workspace.dart`
4. `lib/application/providers/todo_providers.dart`
5. `lib/presentation/shell/app_shell.dart`
6. `mcp_server/README.md` si la tarea toca automatización o agentes externos

## Mapa rápido

### App

- `lib/main.dart`: arranque y `ProviderScope` raíz
- `lib/app/todo_app.dart`: carga `TodoWorkspace`, aplica tema y monta el shell
- `lib/app/app_launch_intent.dart`: argumentos de arranque para abrir secciones o editores
- `lib/app/todo_theme.dart`: tema visual

### Application

- `lib/application/state/todo_workspace.dart`: estado de aplicación y operaciones del producto
- `lib/application/providers/todo_providers.dart`: providers Riverpod

`TodoWorkspace` es la fuente de verdad de runtime. Maneja tareas, proyectos, categorías, notas, calendario, ajustes, notificaciones, persistencia y sincronización.

### Domain

- `lib/domain/entities/`: entidades y value objects
- `lib/domain/snapshots/`: contrato JSON compartido con local, Supabase y MCP
- `lib/domain/repositories/`: contratos de persistencia, nube, calendario y notificaciones
- `lib/domain/models.dart`: barrel público de dominio

### Data e integraciones

- `lib/data/local_store.dart`: contrato de store local
- `lib/data/local_store_file_backed.dart`: store principal para Windows/IO
- `lib/data/repositories/`: adaptadores hacia repositorios de dominio
- `lib/services/`: integraciones de plataforma, Supabase, calendario, notificaciones y scheduler

### Presentation

- `lib/presentation/shell/app_shell.dart`: archivo raiz con parts del shell
- `lib/presentation/shell/shell_chrome.dart`: shell, sidebar, navegación y reproductor
- `lib/presentation/shell/today_page.dart`: vista Hoy
- `lib/presentation/shell/projects_page.dart`: vista Proyectos
- `lib/presentation/shell/categories_page.dart`: vista Categorías
- `lib/presentation/shell/calendar_page.dart`: vista Calendario
- `lib/presentation/shell/wardrobe_page.dart`: armario, conjuntos,
  planificación, lavandería, maletas, estadísticas e importaciones de Ropa
- `lib/presentation/shell/household_page.dart`: inventario visual de Hogar,
  fichas técnicas, manuales, facturas y garantías
- `lib/presentation/shell/plants_page.dart`: catálogo de Plantas, fichas de
  cuidados, seguridad felina y rutinas enlazadas con tareas
- `lib/presentation/shell/recipes_page.dart`: recetario visual, importación,
  tiempos, ingredientes, pasos y creación de tareas de compra o cocina
- `lib/presentation/shell/completed_page.dart`: vista Completadas
- `lib/presentation/shell/settings_page.dart`: vista Ajustes
- `lib/presentation/shell/shared_widgets.dart`: widgets compartidos del shell
- `lib/presentation/shared/editors.dart`: API pública de editores
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
- `--section=wardrobe`
- `--section=household`
- `--section=plants`
- `--section=recipes`

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

## Fuente de verdad según tarea

UI o flujo visual:

- `lib/presentation/shell/*_page.dart`
- `lib/presentation/shared/*_editor.dart`
- `lib/app/todo_theme.dart`

Lógica de producto:

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

## Flujo rápido para añadir ropa

Cuando el usuario entregue fotos y pida añadir ropa, hay que leer y seguir
`skills/extract-clothing-to-todo/SKILL.md`. El camino normal funciona como una
línea de producción: foto, un render por prenda, retirada local del fondo e
inserción directa en la aplicación.

- Si varias prendas se ven completas, separadas y con detalle suficiente en una
  misma foto, esa única foto sirve como referencia para todas. Cada prenda sigue
  teniendo su propio render y su propia inserción.
- No usar lotes, manifiestos, aprobaciones ni clics del usuario salvo que pida
  expresamente revisar antes de guardar.
- No crear copias completas por cada prenda. Las copias completas se reservan
  para una petición expresa, recuperación o una operación destructiva de datos.
- Hacer una sola comprobación visual breve del render final antes de insertarlo.
  Tras recibir `savedLocally: true`, confirmar el identificador y terminar: no
  recontar repetidamente el armario, esperar la sincronización, reabrir la app ni
  repetir verificaciones que no puedan descubrir un fallo concreto.
- Un render que el usuario haya aprobado se reutiliza tal cual; nunca se vuelve
  a generar solo para retirar el fondo o introducirlo en Todo.

## Flujo rápido para añadir plantas

Cuando el usuario pida añadir una planta a su colección, hay que leer y seguir
`skills/add-plant-to-todo/SKILL.md`. Se verifican por separado la especie, los
cuidados y la seguridad para gatos, se prepara una imagen si no se ha aportado
ninguna y se guarda la ficha con sus rutinas mediante el MCP local.

- No inferir la toxicidad por el nombre común ni por la familia botánica.
- Usar fuentes hortícolas y veterinarias fiables y guardar sus enlaces.
- Tras recibir `savedLocally: true`, confirmar el identificador y terminar sin
  abrir la app ni esperar a la sincronización remota.

## Validación recomendada

Para cambios generales:

```text
flutter analyze
flutter test
flutter build windows --debug
```

Para cambios visuales importantes, arrancar Windows con la sección exacta que se haya tocado.

## Actualización de la instalación de Windows

Siempre que se actualice la aplicación, también hay que compilar y actualizar la
instalación de Windows que usa el acceso de la barra de tareas. El ejecutable de
referencia está en:

```text
C:\Users\aries\AppData\Local\Programs\Todo\todo.exe
```

Antes de dar por terminada una actualización, hay que verificar técnicamente que
la instalación contiene la compilación nueva. Codex no debe abrir ni manejar la
app instalada para hacer la prueba visual o funcional: el usuario se encarga de
probarla después del despliegue.

## Copia y recuperación de datos

La guía canónica es `RECUPERACION_DATOS.md`. Cuando el usuario pida «recupera
los datos de la copia de seguridad» o algo equivalente, hay que seguirla
directamente, sin investigar otra vez las rutas ni restaurar solo el JSON.

- La fuente activa está en `C:\Users\aries\Documents\Todo`.
- Las copias completas están en `C:\Users\aries\Documents\Todo Backups`.
- Cerrar `todo.exe` y mantenerlo cerrado durante toda la operación.
- Usar `tooling\restore_todo_backup.ps1`: valida hashes, crea una copia
  preventiva, restaura snapshot y recursos, y vuelve a verificarlos.
- No omitir ropa, recetas, hogar, portadas ni conocimiento.
- Solo comunicar éxito si el script devuelve `restaurado_y_verificado`.

Para crear otra copia recuperable se usa
`tooling\backup_todo_data_full.ps1` con la app cerrada.
