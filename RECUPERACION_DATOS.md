# Recuperación completa de los datos de Todo

Esta guía permite recuperar tareas, biblioteca, propósitos, ropa, recetas,
hogar, gastos, conocimiento y todos sus archivos. El código de la aplicación no
forma parte de estas copias.

## Rutas canónicas

- Datos activos: `C:\Users\aries\Documents\Todo`
- Copias completas: `C:\Users\aries\Documents\Todo Backups`
- Copia verificada del 1 de septiembre de 2026:
  `C:\Users\aries\Documents\Todo Backups\Todo-completo-20260901-213007`

Una copia válida contiene `backup_manifest.json`, `runtime\todo_state.json` y
las carpetas de recursos. Restaurar únicamente el JSON no recupera las imágenes,
documentos ni la base de conocimiento.

## Restaurar

1. Cierra Todo y mantenlo cerrado durante toda la operación.
2. Desde la raíz del repositorio ejecuta:

```powershell
.\tooling\restore_todo_backup.ps1 `
  -BackupDirectory 'C:\Users\aries\Documents\Todo Backups\Todo-completo-20260901-213007'
```

El script valida todos los tamaños y hashes SHA-256 antes de tocar los datos,
crea una copia preventiva del estado actual, restaura snapshot y recursos, y
verifica de nuevo cada archivo restaurado. El resultado correcto termina con:

```text
"status": "restaurado_y_verificado"
```

También devuelve `safetyBackup`, que es la ruta desde la que se puede deshacer
la operación. Si aparece un error, no se debe improvisar ni abrir la app: hay que
conservar el mensaje y la copia preventiva.

Para comprobar una copia sin restaurarla se puede añadir `-ValidateOnly`.

## Crear otra copia completa

Con la app cerrada:

```powershell
.\tooling\backup_todo_data_full.ps1
```

El script crea `Todo-completo-AAAAMMDD-HHMMSS` con un manifiesto verificable.
Las copias que contienen solamente `todo_state.json` no sustituyen a una copia
completa.

## Instrucción para un chat nuevo

La petición «recupera los datos de la copia de seguridad» significa: leer esta
guía, usar la copia completa indicada o la más reciente, mantener la app cerrada,
ejecutar `tooling\restore_todo_backup.ps1` y comunicar `restoredFrom`,
`safetyBackup`, `restoredFiles` y el estado final. No se debe editar manualmente
el snapshot ni copiar carpetas a mano.
