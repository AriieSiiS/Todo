# Recuperación completa de los datos de Todo

Esta guía permite recuperar tareas, biblioteca, propósitos, ropa, recetas,
hogar, gastos, conocimiento y todos sus archivos. El código de la aplicación no
forma parte de estas copias.

## Rutas canónicas

- Datos activos: `C:\Users\aries\Documents\Todo`
- Copias completas: `C:\Users\aries\Documents\Todo Backups`
- Segunda ubicación en otro disco: `E:\Todo Backups externo`
- Fotos rápidas del snapshot antes de cambios grandes (las últimas 10):
  `C:\Users\aries\Documents\Todo Backups\_antes-de-cambios`
- Copias antiguas archivadas, sin rotación:
  `C:\Users\aries\Documents\Todo Backups\_archivo-historico`

## Cómo se gestionan las copias

- Solo hay un tipo de copia de recuperación: la completa y verificada
  `Todo-completo-AAAAMMDD-HHMMSS`.
- Se crea desde Ajustes, con `tooling\backup_todo_data_full.ps1` o sola cada
  domingo a las 04:00 (tarea programada `\Todo\CopiaSemanal`, que reintenta
  cada hora si Todo está abierto).
- El script para el seguimiento de precios mientras copia y lo vuelve a
  arrancar al terminar.
- Tras verificar la copia nueva se conservan solo las **2 últimas** en cada
  ubicación y se borran las anteriores y las incompletas.
- La copia nueva se duplica en `E:\Todo Backups externo` y se verifica allí. Si
  la unidad no está, se omite sin fallar.
- Antes de un cambio grande de datos se usa
  `tooling\guardar_antes_de_cambio.ps1 -Etiqueta <motivo>`, que guarda el
  snapshot en `_antes-de-cambios` y conserva las 10 últimas. No se crean más
  copias sueltas en `runtime`.
- La tarea semanal apunta al script de este repositorio; si se mueve la
  carpeta del proyecto, hay que volver a ejecutar
  `tooling\registrar_copia_semanal.ps1`.

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
