# AGENTS

## Lecciones

- Cuando se añadan textos al ejecutable nativo de Windows, compilar sus fuentes en UTF-8 y comprobar las tildes en el binario instalado.
- Cuando se unifiquen las fichas de Biblioteca, fijar la misma altura de cabecera para todas y colocar saga y orden a la derecha del título; mantener los datos en una columna ajustada al alto disponible sin scroll. En lectura, integrar «Información» y «Citas» en la cabecera, omitir «Libro», colocar el porcentaje en la esquina de las portadas y mostrar página, total y capítulo al pasar el cursor, sin fechas ni posiciones técnicas en las citas.
- Cuando se cotejen o trasladen libros del Kindle, normalizar metadatos y enlazar las fichas existentes, incluidas las completadas, antes de crear otras; comprobar la apertura real de los formatos ofrecidos y preparar EPUB para AZW3/KF8.
- Cuando se ajuste la ficha de lectura, mostrar el progreso editable en «Información» y aprovechar la altura de «Citas» con varias citas y edición individual; paginar solo las que no quepan, sin scroll ni títulos o contadores redundantes.
- Cuando se ajuste la barra de lectura del Kindle, usar todo el ancho entre márgenes con un trazo continuo sin marcas de capítulos y el dato debajo; sincronizar la escala con «Libro» o «Capítulo», conservar el formato de tiempo elegido y comprobar el carrusel mediante capturas y su persistencia, sin hora, batería ni páginas restantes.
- Cuando se termine una instalación del Kindle, retirar los instaladores, marcadores informativos, volcados de diagnóstico y sus carpetas auxiliares; comprobar la limpieza sin borrar libros ni componentes activos.
- Cuando se use un selector dentro de una fila de Biblioteca, ajustar el control al contenido y anclar su menú justo debajo; mantener la tipografía del valor de la fila.
- Cuando se revise el índice de un ómnibus, distinguir las obras, sus capítulos y sus epígrafes, y contrastar las entradas con los encabezados del texto antes de afirmar que está completo.
- Cuando se cambie una función del Kindle, mantener su fuente y pruebas en `kindle/` y verificar la actualización en el Kindle definitivo; conservar sus credenciales, libros, progreso y citas. No preparar paquetes ni perfiles de traslado salvo petición nueva del usuario.
- Cuando se revise una pantalla congelada en KOReader, comprobar primero si el lector sigue vivo y revisar su error; probar los accesos a Todo desde lectura y explorador con las API de cierre propias de cada menú. Verificar también el refresco físico y los controles posteriores, porque el framebuffer no valida la tinta electrónica; mantener cancelables las consultas de red y probar con el PC inaccesible.
- Cuando se facilite el acceso a los libros del Kindle, hacer que la casa y el botón de explorador dentro de un libro abran «Mis libros», ofrecer un botón visible para volver a Todo, configurar KOReader en español y conservar Todo como inicio predeterminado; al abrir un libro, mostrar un aviso breve sin rutas de archivos.
- Cuando se ajuste la vista del Kindle, mostrar las subtareas con sus casillas desplazadas a la derecha según su nivel, aprovechar la altura útil y equilibrar la cabecera; ocultar prioridades, el reloj durante el reposo y los mensajes explicativos de reposo.
- Cuando se agrupen elementos en carpetas, ofrecer desagrupar y volver a agrupar desde la interfaz, y conservar esa elección al reiniciar.
- Cuando se amplíe la conexión de ChatGPT, reutilizar las herramientas del MCP local existente y añadir solo la adaptación necesaria del transporte y las escrituras de Todo abierto.
- Cuando se añadan tarjetas de Compras en Windows, ofrecer las acciones de edición y eliminación también mediante clic derecho, con confirmación antes de eliminar.
- Cuando el usuario pida consultar tareas en ChatGPT, devolver solo los títulos y abrir paneles únicamente si los solicita expresamente.
- Cuando se complete la ficha de un libro o una película en Biblioteca, añadir también el enlace verificado a Goodreads o Letterboxd, y no adivinarlo si hay dudas.
- Cuando se vaya a hacer un cambio grande de datos, guardar antes el snapshot con
  `tooling\guardar_antes_de_cambio.ps1` y no dejar copias sueltas en `runtime`.
  Las copias completas conservan solo las 2 últimas y se duplican en el disco E.
- Cuando un script guarde una credencial, validar su formato y distinguir el guardado local de la autenticación comprobada antes de comunicar éxito.

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

`TodoWorkspace` es la fuente de verdad de runtime con la interfaz abierta. Maneja tareas, proyectos, categorías, notas, calendario, ajustes, notificaciones, persistencia y sincronización. Al cerrarla, el agente ligero atiende al Kindle con la lógica compartida de `packages/todo_core/`; ambos adquieren `runtime/todo_state.json.lock` antes de cargar o modificar el estado para impedir escritores simultáneos.

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
- `lib/presentation/shell/journal_page.dart`: Diario (una entrada por día, ánimo,
  foto opcional y recuerdos de años anteriores)
- `lib/presentation/shell/trips_page.dart`: Viajes (itinerario, reservas,
  documentos PDF o enlaces y maleta enlazada con Ropa; se ven en el Calendario)
- `lib/presentation/shell/focus_page.dart`: Enfoque (temporizador ligado a
  tareas y resumen semanal del tiempo dedicado)
- `lib/presentation/shell/compact_view.dart`: modo mini de Hoy; lo activa el
  botón de la barra lateral o `--compact`
- `lib/presentation/shell/weekly_summary_dialog.dart`: resumen semanal, solo
  bajo demanda desde Completadas; la lógica está en
  `lib/application/state/todo_workspace_resumen.dart`
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
- `--section=journal`
- `--section=trips`
- `--section=focus`

Editores:

- `--new-task`
- `--new-project`
- `--new-category`
- `--quick-capture` (abre la nota rápida) y `--compact` (modo mini)

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

## Flujo rápido para añadir juegos, películas, series y libros a Biblioteca

Regla permanente: todo elemento que se añada a Biblioteca lleva metadatos y
portada, y todo en castellano salvo que el usuario indique lo contrario.

1. Buscar datos reales (TMDB con `?language=es-ES`, Netflix, IGDB, Open
   Library…): título en castellano si existe, título original, año, director o
   autor, género, duración, país, sinopsis y reparto. Si hay varias obras con
   el mismo nombre, elegir la más probable y decirlo. Si es una serie y no una
   película, usar `media_type: series`.
   Para libros y películas, localizar también su ficha: Goodreads para libros
   y Letterboxd para películas (las series y los juegos no llevan enlace).
2. Descargar la portada (p. ej. `https://image.tmdb.org/t/p/w500/<ruta>.jpg`) a
   `C:\Users\aries\Documents\Todo\library_covers\` y usar esa ruta absoluta en
   `cover_url`, igual que el resto de portadas.
3. Guardar antes una foto del snapshot con
   `tooling\guardar_antes_de_cambio.ps1 -Etiqueta <tarea>`.
4. Con `todo.exe` cerrado, llamar a `create_library_item_impl` de
   `mcp_server/herramientas/biblioteca.py` con `TODO_MCP_DISABLE_REMOTE=1`
   (Supabase está desactivado y, sin esa variable, el MCP intenta conectar y
   falla). Estado `pending` para pendientes; sinopsis y reparto van en `note`.
   Pasar también `external_url` con la ficha de Goodreads o Letterboxd.
5. Comprobar que `libraryItems` creció en uno y terminar, sin abrir la app.

Enlace a Goodreads o Letterboxd (campo `externalUrl` del elemento, `external_url`
en el MCP): es obligatorio al completar los metadatos de un libro o una película.
- Libros: `https://www.goodreads.com/book/show/<id>-<slug>`. Preferir la edición
  en castellano con más valoraciones; la búsqueda `goodreads.com/search?q=` responde
  por HTTP normal.
- Películas: `https://letterboxd.com/film/<slug>/`. Letterboxd bloquea `curl`; abrir
  `letterboxd.com/film/<slug>/` en el navegador integrado y comprobar título, año
  y director antes de guardar (`og:title`).
- Mangas: enlazar siempre el tomo 1 en Goodreads, aunque la serie tenga más tomos.
- Si hay duda razonable entre varias fichas, no adivinar: dejar el elemento sin
  enlace y preguntar al usuario.
- En la app se edita en el diálogo del elemento y se abre con el botón de la ficha
  de detalle.

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
`tooling\backup_todo_data_full.ps1` con la app cerrada. El script rota (2
últimas), duplica en `E:\Todo Backups externo` y se ejecuta solo cada domingo
a las 04:00. Detalles en `RECUPERACION_DATOS.md`.
