# Todo MCP Server

Este servidor MCP local permite que Codex u otras IAs compatibles lean y gestionen la app Todo sin tocar la interfaz.

## Idea clave

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
- completar tareas
- mover tareas de día
- listar proyectos
- crear proyectos
- exportar e importar el estado JSON
- reiniciar a un estado vacio
- preparar lotes de prendas PNG para revisarlos en la sección Ropa
- gestionar prendas, conjuntos, usos, lavandería, planificación y maletas
- gestionar recetas, sus imágenes y su conversión en tareas de compra o cocina

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

La herramienta `get_wardrobe_import_contract` devuelve el formato vigente del
`manifest.json`. Codex debe crear una carpeta temporal con ese manifiesto y los
PNG transparentes finales y llamar a `stage_wardrobe_batch`. El MCP copia el
lote a `Documents/Todo/wardrobe/imports` y lo registra como pendiente.

La aprobación se realiza dentro de Todo. La app mueve los recursos aceptados a
`wardrobe/items`, genera miniaturas en `wardrobe/thumbnails` y conserva en el
snapshot únicamente rutas relativas y metadatos. Las fotografías originales no
se copian al armario.

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

Flutter también puede importar directamente archivos JSON y direcciones web
que publiquen una receta compatible con schema.org.

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
