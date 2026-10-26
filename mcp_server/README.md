# Todo MCP Server

Este servidor MCP local permite que Codex u otras IAs compatibles lean y gestionen la app Todo sin tocar la interfaz.

## Plugin privado de ChatGPT

[CHATGPT.md](CHATGPT.md) describe el adaptador estándar para Secure MCP Tunnel.
Incluye consultas, un panel de Hoy y creación, edición, traslado y finalización
de tareas mediante Todo abierto. Las escrituras reales usan un puente local
autenticado, versiones y un registro persistente de reintentos. La conexión de
la cuenta aún requiere un túnel y una clave de ejecución reales. El servidor
y el arranque existentes se conservan.

Supabase está desactivado por las instrucciones actuales del proyecto. Las
secciones históricas sobre sincronización remota no deben ejecutarse mientras
esa regla siga vigente.

## Idea clave

Las consultas `get_steam_games` y `get_steam_achievements` del adaptador privado
usan la conexión configurada en «Ajustes → Steam» mediante Todo abierto.
No reciben ni devuelven la clave. Véase [la guía de Steam](../docs/STEAM.md).

No es un servidor en internet. Es un proceso local dentro del mismo repo.

Eso significa que cuando lleves este proyecto a otro PC:

1. copias o clonas el repo
2. levantas el servidor MCP desde `mcp_server`
3. conectas tu cliente MCP a ese script

## Cómo funciona ahora

- La app Flutter sigue guardando cache local en `Documents/Todo/runtime/todo_state.json`
- Si configuras Supabase, el MCP usa Supabase como fuente principal y mantiene ese archivo como espejo local
- Si no configuras Supabase, el MCP sigue funcionando en modo local

## Qué puede hacer

- leer el estado completo
- ver tareas de hoy
- listar tareas
- crear tareas
- actualizar tareas
- añadir varios avisos a una tarea y retirarlos de forma individual
- completar tareas
- mover tareas de día
- listar proyectos
- crear proyectos
- exportar e importar el estado JSON
- reiniciar a un estado vacio
- preparar lotes de prendas PNG para revisarlos en la sección Ropa
- gestionar prendas, conjuntos, usos, lavandería, planificación y maletas
- gestionar recetas, sus imágenes y su conversión en tareas de compra o cocina
- gestionar plantas, imágenes, seguridad felina y rutinas de cuidado enlazadas con tareas

Cada tarea admite varios avisos simultáneos. `set_task_reminder` añade uno sin
sustituir los anteriores; `clear_task_reminder` elimina el aviso indicado o
todos si solo recibe `task_id`. `create_task` y `update_task` aceptan la lista
completa mediante `reminder_minutes_before_values`.
Cada aviso acepta `reminder_delivery_mode: "normal" | "important"`. Volver a
configurar el mismo momento actualiza su modo de entrega; no crea un duplicado.

## Páginas de conocimiento

Las herramientas `get_knowledge_contract`, `list_knowledge_pages`,
`get_knowledge_page` y `search_knowledge` permiten inspeccionar el repositorio
local. Las operaciones de creación, edición, movimiento, papelera, recursos y
colecciones escriben directamente en `Documents/Todo/knowledge`.

Para generar árboles grandes se recomienda `apply_knowledge_manifest`. Requiere
un `operationId`, valida toda la estructura, comprueba las concesiones de
edición y aplica el lote en una única transacción SQLite. Repetir el mismo
`operationId` devuelve el resultado anterior sin duplicar contenido. Los
bloques con `manualOverride` o modificados desde su último `generationHash` se
conservan.

Las imágenes de bloques `image` y `knowledgeMedia` admiten tamaño, alineación y
recorte no destructivo. `get_knowledge_contract` devuelve los atributos
`knowledgeImageWidth`, `knowledgeImageAlignment`,
`knowledgeImageCropAspectRatio`, `knowledgeImageCropZoom`,
`knowledgeImageCropX` y `knowledgeImageCropY` para que Flutter y los manifiestos
de IA utilicen exactamente el mismo formato.

`export_knowledge_repository` crea una copia ZIP con JSON, Markdown y todos los
recursos. Este repositorio funciona aunque Supabase esté desactivado o no sea
accesible.

Los manifiestos también admiten `pageExternalKey`, `assetExternalKey` y
`collectionExternalKey`; el servidor resuelve referencias adelantadas antes de
confirmar la transacción. `import_knowledge_assets` importa recursos en lote.
`list_knowledge_progress`, `set_knowledge_progress` y
`replace_knowledge_progress` permiten consultar, cambiar o sustituir de forma
exacta todos los valores de una fuente. La sustitución por fuente conserva los
pasos manuales y permite que un guardado restaurado reduzca el progreso sin
dejar valores antiguos.

El ZIP de exportación usa el esquema 3 e incluye el progreso, pero nunca las
rutas ni los bytes de partidas guardadas. Se escribe de forma atómica en
`backups/conocimiento-actual.zip` y, tras verificarlo, sustituye cualquier copia
documental anterior. Las pruebas del contrato se ejecutan con
`python -m unittest tooling.test_knowledge_repository -v`.

## Ropa y Codex

La herramienta `get_wardrobe_import_contract` devuelve las categorías y valores
canónicos. Para una prenda, Codex llama a `import_wardrobe_item`: la imagen se
normaliza, se genera su miniatura y la ficha queda guardada directamente, sin
lote ni aprobación manual. `request_id` hace que un reintento no duplique la
prenda y la sincronización remota no bloquea el guardado local.

`set_wardrobe_item_image` sustituye la imagen y la miniatura de una ficha
existente mediante `item_id`, `source_file` y un `request_id` idempotente. La
operación conserva todos los metadatos y referencias de la prenda, guarda el
nuevo estado antes de retirar los recursos anteriores y responde con
`savedLocally: true` cuando el cambio local ha quedado confirmado.

El contrato de importación expone el preset `calzado-perfil`: lienzo RGBA de
`1200 × 1200`, una sola pieza en perfil lateral elevado, caja visible de
`1032 px` de ancho y relación horizontal entre `1,85:1` y `2,70:1`.

`stage_wardrobe_batch` se conserva únicamente cuando el usuario pide una
revisión previa. En ese caso usa `manifest.json`, copia el lote a
`Documents/Todo/wardrobe/imports` y deja la aprobación dentro de Todo.

## Inventario visual de Hogar

El MCP permite que Codex prepare una compra o un aparato sin dar acceso
permanente a la aplicación a servicios externos:

1. `create_household_item` crea la ficha con categoría, marca, modelo, serie,
   ubicación, compra y garantía.
2. `set_household_item_image` copia una imagen PNG de catálogo de al menos
   400 × 400 píxeles a `Documents/Todo/household`.
3. `set_household_item_document` guarda un PDF como `manual` o `invoice`; para
   el manual también admite la URL oficial de procedencia.
4. `list_household_items` permite verificar la ficha final.

Los archivos quedan bajo `household/images`, `household/thumbnails`,
`household/manuals` y `household/invoices`; el snapshot guarda únicamente sus
rutas relativas y metadatos.

### Gemelo 3D de la casa

`list_home_twin_rooms` consulta las habitaciones modeladas. Para añadir o
actualizar una, `import_home_twin_room` recibe `room_id`, `name`, `source_file`
(.glb), `floor`, `position` en metros (`x`, `y`, `z`), `rotation_degrees` y una
lista opcional de objetos. Cada objeto indica `id`, `name`, `node_name`, `kind`
y, si procede, `household_item_id`. El nodo debe existir en el GLB. Repetir una
importación idéntica no duplica la habitación.

El modelo usa glTF 2.0, metros, eje Y vertical y un origen local estable. Las
habitaciones se colocan en una escena común según su posición. El manifiesto y
los modelos se guardan en `Documents/Todo/household/twin`, incluido en la copia
completa. La pestaña «Gemelo 3D» de Hogar permite recargar la escena tras una
importación. La conexión con Home Assistant pertenece a la fase posterior.

## Plantas y cuidados automáticos

El MCP permite dar de alta y mantener plantas sin abrir la interfaz:

1. `get_plant_contract` devuelve el formato de ficha, rutinas y seguridad para
   gatos.
2. `create_plant` crea de forma idempotente la planta y una tarea recurrente
   independiente por cada rutina activa.
3. `set_plant_image` guarda un PNG de catálogo de al menos 400 × 400 píxeles en
   `Documents/Todo/plants`.
4. `list_plants`, `update_plant` y `delete_plant` permiten verificar, editar o
   retirar la ficha y sus tareas enlazadas.

Las rutinas pertenecen a una única categoría `Plantas`, reutilizada sin
distinguir mayúsculas. Las tareas nuevas no incluyen hora ni aviso; si el
usuario añade esos ajustes desde Todo, una edición posterior de la ficha los
conserva. `request_id` evita duplicados al reintentar creaciones o imágenes.

## Recetas y tareas

El recetario puede gestionarse sin abrir la interfaz:

1. `create_recipe` crea la ficha con tiempos, raciones, ingredientes y pasos.
2. `set_recipe_image` guarda un PNG de al menos 300 × 200 píxeles en
   `Documents/Todo/recipes`.
3. `create_recipe_task` acepta `shopping` para convertir ingredientes en
   subtareas de compra o `cooking` para convertir los pasos en subtareas. En
   compras, los condimentos se guardan sin la medida de la receta y las líneas
   compuestas como `sal y pimienta` generan productos independientes.
4. `list_recipes`, `update_recipe` y `delete_recipe` completan el ciclo de
   consulta y mantenimiento.

Los menús están separados de las recetas individuales en `weeklyMenus`.
`list_weekly_menus` devuelve su planificación, compra y recetas enlazadas;
`create_weekly_menu_task` crea una tarea de Compras con todos sus productos. Si
se envía `entry_ids`, recalcula la compra usando únicamente las comidas
seleccionadas; sin ese argumento utiliza la semana completa.

Diario, viajes y enfoque comparten el mismo snapshot (`journalEntries`,
`trips` y `focusSessions`). `save_journal_entry` crea o actualiza la única
entrada de un día; `create_trip` puede crear también la maleta en Ropa;
`add_trip_reservation` admite `flight`, `lodging`, `transport`, `activity` y
`other`. `generate_weekly_summary` devuelve el resumen de la semana pedida sin
guardar nada y `list_focus_sessions` suma los segundos de enfoque del periodo.

Flutter también puede importar directamente archivos JSON y direcciones web
que publiquen una receta compatible con schema.org.

## Compras deseadas en Hogar

`create_shopping_item` guarda productos que se quieren comprar en la pestaña
Compras, separados de los aparatos ya comprados. Recibe `name`, `category`,
`subcategory`, `source_url`, `retailer`, `reference_price`, `target_price`,
`priority`, `notes` y `research_notes`. Un agente identifica el producto desde
el enlace o la imagen que entregue el usuario y propone su clasificación.
`set_shopping_item_image` copia un PNG local a `Documents/Todo/shopping`; no se
comparten archivos borrables con el inventario. `list_shopping_items` filtra
por categoría y subcategoría; `update_shopping_item` permite vaciar precios
con `clear_reference_price` o `clear_target_price`. Los estados son `saved`,
`comparing` y `purchased`. `offers` admite hasta 25 opciones con `name` y
`source_url`, dentro de una única ficha. La app permite activar su seguimiento
diario con changedetection.io local, sin IA. Crear la ficha mediante MCP no
activa por sí solo los monitores; se configuran con la API local del servicio.

## Arranque rápido

Manual en PowerShell:

```powershell
.\mcp_server\start_mcp.ps1
```

O con doble clic / terminal clasica:

```bat
.\mcp_server\start_mcp.bat
```

## Modo Supabase compartido

Si quieres que el MCP vea lo mismo que la app web, Windows o Android:

1. Copia [mcp_server/.env.example](</C:/Users/AlejandroAfonso/Documents/Todo/mcp_server/.env.example>) a `mcp_server/.env`
2. Rellena:
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `SUPABASE_OWNER_EMAIL`
3. Asegurate de haber creado la tabla con [supabase/001_todo_app_states.sql](</C:/Users/AlejandroAfonso/Documents/Todo/supabase/001_todo_app_states.sql>)

Tambien te deje una plantilla casi lista para tu caso en [mcp_server/.env.setup.example](</C:/Users/AlejandroAfonso/Documents/Todo/mcp_server/.env.setup.example>).

En ese modo, el MCP usa el mismo snapshot compartido por tu cuenta personal.

## Configuracion para un cliente MCP

La forma portable recomendada es apuntar al script del repo:

```json
{
  "mcpServers": {
    "todo": {
      "command": "powershell",
      "args": [
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        "C:\\ruta\\a\\Todo\\mcp_server\\start_mcp.ps1"
      ]
    }
  }
}
```

Hay un ejemplo listo en [client.example.json](</C:/Users/AlejandroAfonso/Documents/Todo/mcp_server/client.example.json>).

Si quieres generar la configuración con la ruta real del repo actual:

```powershell
.\mcp_server\print_client_config.ps1
```

## Que necesita en otro PC

El script intenta encontrar Python en este orden:

1. runtime local de Codex si existe
2. `py -3`
3. `python`

Asi que normalmente basta con tener Python 3 instalado, o usarlo desde Codex.

## Escrituras coordinadas con la app

Leer el estado ya no lo reescribe. Al guardar, el servidor comprueba bajo un
bloqueo de archivo (`todo_state.json.lock`) que `todo_state.json` no haya
cambiado desde que lo leyó. Si la app guardó entretanto, la herramienta se
repite sobre el estado nuevo (hasta cinco intentos) en lugar de pisar el cambio.

## Estructura del servidor

`server.py` conserva el estado compartido, el acceso al archivo y el protocolo
MCP. Las herramientas están agrupadas por área en `herramientas/` (tareas,
notas, calendario, ajustes, gastos, biblioteca, ropa, compras, hogar, plantas,
recetas y las definiciones de las herramientas). Cada módulo usa el estado y los
ayudantes comunes mediante `server.`, de modo que las pruebas pueden sustituirlos.
