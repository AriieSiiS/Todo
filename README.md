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

- una app Flutter funcional con secciones `Hoy`, `Proyectos`, `Categorías`, `Calendario`, `Completadas` y `Ajustes`
- modelo interno preparado para operaciones futuras por MCP o agente externo
- lógica de día real configurable
- persistencia local automática para Windows
- sincronización opcional con Supabase para compartir el mismo estado entre app, Windows y MCP
- documentación inicial de arranque, diseño y plan

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

## MCP local

La app ya trae una base para control externo por IA mediante un servidor MCP local en [mcp_server/README.md](</C:/Users/AlejandroAfonso/Documents/Todo/mcp_server/README.md>).

- La app mantiene caché local en `Documents/Todo/runtime/todo_state.json`
- El servidor MCP vive en [mcp_server/server.py](</C:/Users/AlejandroAfonso/Documents/Todo/mcp_server/server.py>)
- El arranque portable del repo está en [mcp_server/start_mcp.ps1](</C:/Users/AlejandroAfonso/Documents/Todo/mcp_server/start_mcp.ps1>) y [mcp_server/start_mcp.bat](</C:/Users/AlejandroAfonso/Documents/Todo/mcp_server/start_mcp.bat>)
- Hay una configuración de ejemplo para clientes en [mcp_server/client.example.json](</C:/Users/AlejandroAfonso/Documents/Todo/mcp_server/client.example.json>)
- Si quieres que el MCP use la misma nube que la app, copia [mcp_server/.env.example](</C:/Users/AlejandroAfonso/Documents/Todo/mcp_server/.env.example>) a `mcp_server/.env` y rellena sus valores
