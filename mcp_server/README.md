# Todo MCP Server

Este servidor MCP local permite que Codex u otras IAs compatibles lean y gestionen la app Todo sin tocar la interfaz.

## Idea clave

No es un servidor en internet. Es un proceso local dentro del mismo repo.

Eso significa que cuando lleves este proyecto a otro PC:

1. copias o clonas el repo
2. levantas el servidor MCP desde `mcp_server`
3. conectas tu cliente MCP a ese script

## Como funciona ahora

- La app Flutter sigue guardando cache local en `Documents/Todo/runtime/todo_state.json`
- Si configuras Supabase, el MCP usa Supabase como fuente principal y mantiene ese archivo como espejo local
- Si no configuras Supabase, el MCP sigue funcionando en modo local

## Que puede hacer

- leer el estado completo
- ver tareas de hoy
- listar tareas
- crear tareas
- actualizar tareas
- completar tareas
- mover tareas de dia
- listar proyectos
- crear proyectos
- exportar e importar el estado JSON
- reiniciar a un estado vacio

## Arranque rapido

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

Si quieres generar la configuracion con la ruta real del repo actual:

```powershell
.\mcp_server\print_client_config.ps1
```

## Que necesita en otro PC

El script intenta encontrar Python en este orden:

1. runtime local de Codex si existe
2. `py -3`
3. `python`

Asi que normalmente basta con tener Python 3 instalado, o usarlo desde Codex.
