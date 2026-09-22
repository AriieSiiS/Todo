# Todo

Base de una app personal de tareas pensada para Windows.

## Mapa rápido para nuevos chats o agentes

Si un chat nuevo necesita orientarse sin volver a recorrer todo el repo, empieza por [AGENTS.md](</C:/Users/AlejandroAfonso/Documents/Todo/AGENTS.md>). Ahí está el mapa corto del proyecto, las rutas clave y los atajos para abrir cada vista directamente.

La app está migrada a una estructura por capas:

- `domain/`: entidades, snapshots JSON y contratos
- `application/`: estado principal `TodoWorkspace` y providers Riverpod
- `data/`: adaptadores de persistencia, Supabase, calendario y notificaciones
- `presentation/`: shell, vistas y editores

Windows es la plataforma prioritaria. La persistencia de escritorio usa archivo local en `runtime/todo_state.json`, y la validación principal recomendada es `flutter build windows --debug`.

## Estado actual

Este repositorio contiene:

- una app Flutter funcional con secciones de tareas, proyectos, calendario,
  biblioteca, ropa, hogar, recetas, gastos y ajustes
- modelo interno preparado para operaciones futuras por MCP o agente externo
- lógica de día real configurable
- persistencia local automática para Windows
- sincronización opcional con Supabase para compartir el mismo estado entre app, Windows y MCP
- documentación inicial de arranque, diseño y plan
- un módulo de Ropa para catálogo, conjuntos, planificación, lavandería,
  maletas, estadísticas e importaciones preparadas por Codex
- un inventario visual de Hogar para compras, aparatos, manuales, facturas,
  números de serie y garantías
- un catálogo de Plantas con cuidados, seguridad para gatos y rutinas
  recurrentes enlazadas con tareas
- un recetario visual con tiempos, raciones, ingredientes, pasos, favoritos,
  imágenes e importación desde JSON o páginas con datos schema.org

## Ropa

La sección `Ropa` es local y prioritaria para Windows. Los PNG se guardan en
`Documents/Todo/wardrobe`; el snapshot y Supabase conservan solamente sus
metadatos. La habilidad `skills/extract-clothing-to-todo` guía a Codex para convertir
una foto en una prenda transparente e insertarla directamente mediante el MCP
local. Los lotes revisables quedan para varias prendas o cuando se pidan
expresamente, sin claves de IA dentro de la aplicación.

## Hogar

La sección `Hogar` reúne las compras y aparatos en tarjetas visuales. Cada ficha
puede guardar marca, modelo, número de serie, ubicación, tienda, precio, fechas
de compra y garantía, notas, etiquetas, una imagen de catálogo, el manual
oficial y la factura. Los archivos viven en `Documents/Todo/household`; el
snapshot y Supabase conservan sus metadatos y rutas relativas.

Codex puede completar el flujo mediante el MCP local: crear la ficha con
`create_household_item`, asociar un PNG preparado o generado con
`set_household_item_image` y guardar el manual o la factura PDF con
`set_household_item_document`. Así la aplicación no necesita claves de IA ni
acceso permanente al correo o a la web.

## Plantas

La sección `Plantas` muestra cada ejemplar como una tarjeta visual con su
ubicación, seguridad para gatos y próximo cuidado. La ficha reúne información
botánica, condiciones de cultivo, fuentes verificables, notas y rutinas
editables. Las imágenes y miniaturas se guardan en `Documents/Todo/plants`.

Cada rutina activa crea o actualiza una tarea recurrente de día completo en la
categoría `Plantas`. La relación por identificadores evita duplicados y permite
conservar las horas, los avisos y el historial que el usuario haya añadido a la
tarea. Archivar o eliminar una planta hace lo mismo con sus tareas enlazadas.

## Recetas

La sección `Recetas` reutiliza el catálogo visual de Ropa y Hogar. Cada receta
guarda imagen, categoría, cocina, tiempos de preparación y cocción, raciones,
ingredientes, pasos, etiquetas y la fuente original. Las imágenes locales se
guardan en `Documents/Todo/recipes`; el snapshot local y Supabase conservan las
rutas relativas y todos los datos estructurados.

Se puede crear una receta manualmente, importar un JSON propio o leer una URL
que publique un objeto `Recipe` de schema.org. Desde la ficha, `Comprar
ingredientes` crea una tarea padre con un ingrediente por subtarea, mientras
que `Crear tarea de cocina` convierte los pasos en subtareas ordenadas.
Las cantidades se mantienen intactas en la ficha. Al generar la compra, los
condimentos y productos de despensa reconocidos se normalizan al producto
comprable (`½ cucharadita de comino` pasa a `Comino`); los ingredientes normales
conservan su cantidad y las líneas compuestas se separan y deduplican.

Dentro de `Recetas`, el selector superior separa las recetas individuales de
los `Menús semanales`. Cada menú enlaza sus siete recetas, conserva la lista de
compra agrupada y los precios aproximados, y puede generar una tarea de Compras
con un producto por subtarea sin duplicar las recetas del catálogo.
La compra parte con toda la semana marcada, pero admite seleccionar días o
momentos concretos (`Desayuno`, `Comida`, `Merienda` y `Cena`). Para una selección
parcial o una semana editada, la lista se recalcula desde los ingredientes de
las recetas elegidas; mientras el menú original no cambie, la semana completa
mantiene su compra consolidada y su presupuesto. El editor semanal permite
asignar, cambiar o quitar una receta en cualquiera de los 28 huecos del plan.

El MCP expone el mismo flujo mediante `create_recipe`, `update_recipe`,
`set_recipe_image`, `create_recipe_task`, `list_recipes` y `delete_recipe`.
Los menús semanales se consultan con `list_weekly_menus` y su lista completa se
convierte en tarea mediante `create_weekly_menu_task`.

## Alarmas importantes en Windows

Cada aviso de una tarea puede marcarse como `Importante`. Además del aviso de
Windows, Todo programa una tarea local bajo `\Todo\Alarmas` y, cuando llega la
hora, abre una ventana compacta siempre visible con sonido en bucle. La alarma
permite detener, posponer cinco minutos o abrir la tarea. Si la aplicación ya
estaba abierta, conserva y restaura su posición, tamaño y estado anteriores.

El estado recuperable de alarmas programadas, activas y pospuestas se guarda en
`Documents/Todo/runtime/important_alarm_state.json`, por lo que las copias
completas lo incluyen automáticamente. Este flujo es local y no depende de
Supabase. No puede avisar con el equipo apagado o sin una sesión de Windows,
pero `StartWhenAvailable` hace que los avisos perdidos reaparezcan al reanudar o
iniciar sesión.

## Supabase compartido

La sincronización nueva usa un snapshot único por cuenta. Eso encaja bien con una app de uso personal porque simplifica mucho la coherencia entre dispositivos y también deja el MCP hablando con la misma fuente de verdad.

Pasos base:

1. Crea un proyecto en Supabase.
2. Ejecuta el SQL de [supabase/001_todo_app_states.sql](</C:/Users/AlejandroAfonso/Documents/Todo/supabase/001_todo_app_states.sql>).
3. Arranca Flutter con:

```text
--dart-define=SUPABASE_URL=...
--dart-define=SUPABASE_PUBLISHABLE_KEY=...
--dart-define=SUPABASE_ALLOWED_EMAIL=tu-email@gmail.com
--dart-define=SUPABASE_REDIRECT_URL=...
```

También acepta directamente los nombres que suele mostrar Supabase al copiar variables:

```text
--dart-define=NEXT_PUBLIC_SUPABASE_URL=...
--dart-define=NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=...
```

Cuando la app tenga esa configuración, desde `Ajustes` podrás conectar la nube, seguir guardando en local como caché y sincronizar el mismo estado con Supabase.

Scripts útiles:

- Windows con Supabase ya preparado: [tooling/run_windows_supabase.ps1](</C:/Users/AlejandroAfonso/Documents/Todo/tooling/run_windows_supabase.ps1>)
- prueba MCP contra Supabase: [tooling/test_supabase_mcp_sync.py](</C:/Users/AlejandroAfonso/Documents/Todo/tooling/test_supabase_mcp_sync.py>)

Para completar el login real de la app, todavía hace falta tener Google activado en `Authentication > Providers > Google` dentro de Supabase y permitir el redirect URL local que vayas a usar.

### Android y sincronización por revisión

La versión Android usa el mismo snapshot de Supabase que Windows, pero con una capa de revisión para evitar sobrescrituras silenciosas entre dispositivos. Antes de usar la sincronización Android, aplica también [supabase/002_snapshot_revision_sync.sql](</C:/Users/AlejandroAfonso/Documents/Todo/supabase/002_snapshot_revision_sync.sql>).

Redirects recomendados en Supabase Auth:

- Windows: `http://localhost:3000/`
- Android: `todo://login-callback`

APK privada:

```text
.\tooling\android_private_apk.ps1
```

Si existe `android/key.properties`, el build release usa esa keystore. Puedes partir de [android/key.properties.example](</C:/Users/AlejandroAfonso/Documents/Todo/android/key.properties.example>).

## MCP local

La app ya trae una base para control externo por IA mediante un servidor MCP local en [mcp_server/README.md](</C:/Users/AlejandroAfonso/Documents/Todo/mcp_server/README.md>).

- La app mantiene caché local en `Documents/Todo/runtime/todo_state.json`
- El servidor MCP vive en [mcp_server/server.py](</C:/Users/AlejandroAfonso/Documents/Todo/mcp_server/server.py>)
- El arranque portable del repo está en [mcp_server/start_mcp.ps1](</C:/Users/AlejandroAfonso/Documents/Todo/mcp_server/start_mcp.ps1>) y [mcp_server/start_mcp.bat](</C:/Users/AlejandroAfonso/Documents/Todo/mcp_server/start_mcp.bat>)
- Hay una configuración de ejemplo para clientes en [mcp_server/client.example.json](</C:/Users/AlejandroAfonso/Documents/Todo/mcp_server/client.example.json>)
- Si quieres que el MCP use la misma nube que la app, copia [mcp_server/.env.example](</C:/Users/AlejandroAfonso/Documents/Todo/mcp_server/.env.example>) a `mcp_server/.env` y rellena sus valores

## Páginas y conocimiento

Biblioteca incorpora un espacio documental local inspirado en páginas de
Notion y enlaces de Obsidian. Cada obra dispone de una raíz con subpáginas,
editor por bloques, multimedia, colecciones, pestañas persistentes, búsqueda
FTS5, enlaces entrantes, revisiones y papelera.

- La fuente de verdad está en `Documents/Todo/knowledge/knowledge.sqlite`.
- Los recursos deduplicados por SHA-256 están en
  `Documents/Todo/knowledge/assets`.
- Flutter y MCP comparten la base en modo WAL y coordinan las escrituras con
  concesiones locales.
- `apply_knowledge_manifest` permite que Codex aplique guías y árboles enteros
  de forma atómica e idempotente, respetando contenido manual.
- La exportación genera un ZIP con manifiesto JSON, Markdown y recursos.
- Supabase es solo un respaldo opcional por página y recurso. Para prepararlo,
  aplica [supabase/003_knowledge_workspace.sql](supabase/003_knowledge_workspace.sql).

### Wiki de The Binding of Isaac: Repentance+

La ficha de Isaac incluye una wiki interactiva en español con nombres oficiales
en inglés, ruta óptima marcable, fichas enlazadas, colecciones paginadas y
progreso compartido. El importador reproducible está en
`tooling/import_isaac_wiki.py` y siempre genera un ZIP recuperable antes de
aplicar el manifiesto. `tooling/audit_isaac_wiki.py` verifica conteos, enlaces,
recursos, fuentes, páginas huérfanas y las relaciones de pools.
`tooling/translate_isaac_dataset.py` mantiene una caché local de redacción
española y protege los nombres oficiales en inglés durante su generación.

El lector de `rep+persistentgamedata#.dat` es original y estrictamente de solo
lectura. Valida cabecera, checksum, secciones y longitudes; sincroniza únicamente
estados derivados y conserva el último estado válido ante una escritura
incompleta. Las rutas de Steam se guardan solo en SQLite local. Para respaldar
el progreso derivado en Supabase sobre una instalación existente, aplica
`supabase/004_knowledge_progress.sql`.

## Copias y recuperación de datos

La recuperación completa está documentada en
[RECUPERACION_DATOS.md](RECUPERACION_DATOS.md). Con la aplicación cerrada:

```powershell
.\tooling\backup_todo_data_full.ps1
.\tooling\restore_todo_backup.ps1 -BackupDirectory 'RUTA_DE_LA_COPIA_COMPLETA'
```

La restauración valida todos los hashes, crea primero una copia preventiva y
recupera el snapshot junto con imágenes, documentos, recetas, ropa, hogar,
portadas y conocimiento.

En Windows, `Ajustes > Copias de seguridad` muestra la última copia completa
verificada y permite crear otra. Para mantener coherente la base de Biblioteca,
la app guarda los cambios, se cierra durante la copia y vuelve a abrirse en
Ajustes cuando termina. Las copias se guardan en `Documents/Todo Backups`.
