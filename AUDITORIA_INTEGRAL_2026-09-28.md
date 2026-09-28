# Auditoría integral de Todo · 28 de septiembre de 2026

## Alcance y punto de recuperación

El commit `1a35306` conserva el trabajo pendiente antes de esta intervención,
incluidos los modelos y recursos del gemelo 3D. Las trazas de Playwright se
mantienen en disco y ahora se excluyen de Git.

La revisión combina análisis estático de toda la aplicación Dart, búsqueda de
referencias y acciones vacías, revisión de rutas críticas y ejecución de las
pruebas de escritorio, móvil, MCP, conocimiento y agente LAN. Incluye la
compilación del JavaScript del gemelo y la compilación release de Windows.
No equivale a haber probado manualmente cada pantalla ni todos los dispositivos
físicos. Supabase queda expresamente fuera de la auditoría por `AGENTS.md`.

## Problemas corregidos

| Prioridad | Hallazgo | Resultado |
| --- | --- | --- |
| Alta | Las escrituras y la recuperación local podían disputar el mismo `.tmp`. | Se serializan las operaciones de cada `FileBackedLocalStore`. La prueba de 24 guardados simultáneos reproduce un error de acceso de Windows sin la cola y pasa con ella. Un fallo no bloquea la siguiente operación. |
| Alta | El cierre de la sesión de calendario dejaba `.tmp` y `.previous`, que podían restaurar una sesión antigua. | Se retiran también esos archivos al cerrar la sesión. Prueba de recuperación y cierre incluida. |
| Media | Cada consulta periódica de Ropa reconstruía todo el snapshot aunque el archivo no cambiase. | `loadIfChanged` compara el texto y solo decodifica los estados nuevos. Las lecturas normales siguen devolviendo objetos independientes. |
| Media | Cada petición parcial de audio o vídeo cargaba el recurso completo y copiaba el fragmento. | En Windows se transmite directamente el rango del archivo instalado. Se conserva la alternativa basada en recursos para otros entornos. |
| Media | Rangos HTTP enormes podían generar un error 500, y los audios con espacios fallaban por la codificación de la URL. | Validación de rangos con respuesta 416 y resolución de los segmentos decodificados de la ruta. Incluye pruebas de rangos abiertos, sufijos, archivo vacío y nombres con espacios. |
| Media | Un fallo de arranque dejaba la pantalla de carga indefinidamente. | Se muestra el fallo con un botón para reintentar. Se liberan los recursos del workspace si falla su inicialización. |
| Media | «Ver todos» en Biblioteca, Proyectos y Agenda no hacía nada. | Biblioteca y Agenda permiten ampliar y contraer sus listas; Proyectos abre todas las tareas del resumen y refleja sus actualizaciones. |
| Media | La fila de tareas de proyecto desbordaba con fechas largas. | La fecha se ajusta al espacio disponible. La prueba del nuevo diálogo detectó el problema y comprueba el resultado. |
| Media | Android podía iniciar dos sincronizaciones mientras esperaba la credencial. | El bloqueo se establece antes de la primera espera y se libera también si falla la lectura de la credencial. |
| Baja | Vistas antiguas y datos de demostración estaban ocultos al analizador con `ignore_for_file: unused_element`. | Se eliminaron más de 2.000 líneas de código sin referencias y las supresiones generales. El analizador vuelve a detectar nuevos elementos privados sin uso. |

La limpieza incluye `_LegacyTodayPage`, `_ReferenceProjectDetailPanel`,
`_buildLegacySettingsPage`, controles antiguos de Completadas, tarjetas y
helpers utilizados únicamente por esas vistas. No se retiraron entidades,
campos de snapshots ni las migraciones necesarias para leer datos existentes.

Las dos acciones vacías restantes en los botones de Recetas y el selector de
año de Biblioteca están dentro de `IgnorePointer`: el `PopupMenuButton` padre
gestiona la interacción real. No son enlaces rotos. Tampoco se eliminaron
plugins de plataforma por carecer de importaciones Dart directas; esa ausencia
no demuestra que sobren.

## Medición reproducible

Comando:

```text
flutter test test/benchmarks/local_store_benchmark.dart --no-pub
```

Con 10.000 tareas sintéticas, cinco rondas de calentamiento y 20 consultas
alternadas por variante en este equipo:

| Consulta | Tiempo total |
| --- | ---: |
| Lectura y reconstrucción completa | 1.161 ms |
| Lectura periódica sin cambios | 176 ms |

La reducción observada es del 84,8 % en esta operación concreta. La consulta
todavía lee el archivo y conserva su último texto; evita la decodificación y
la creación repetida de entidades. No es una medición de FPS ni de la rapidez
global de la aplicación, y los tiempos variarán entre equipos.

## Hallazgos pendientes, por prioridad

1. **Alta: coordinación de escrituras entre procesos.** La cola nueva protege
   una instancia de la aplicación, no coordina el MCP con Flutter. El MCP
   escribe el mismo snapshot en `mcp_server/server.py:write_local_state`, y
   `_mergeExternalWardrobeItems` solo incorpora cambios de Ropa. Debe diseñarse
   una revisión o bloqueo compartido y una fusión por entidad, incluidas las
   eliminaciones, antes de permitir escrituras concurrentes seguras de todas
   las áreas. No se ha reproducido pérdida de datos reales.
2. **Alta: visibilidad de fallos de guardado en segundo plano.** El callback
   de `_commit` espera `_persist` sin presentar un error recuperable al
   usuario. La serialización evita la colisión reproducida, pero no resuelve
   un disco lleno, permisos o errores de E/S. Falta un estado de guardado
   fallido, reintento y una prueba de cierre con cambios pendientes.
3. **Media: cancelación de operaciones móviles.** `disconnect` y `dispose`
   todavía necesitan coordinarse con una sincronización ya iniciada. La
   corrección aplicada evita solicitudes duplicadas, pero no define la
   cancelación al desconectar durante una respuesta lenta ni impide todas las
   notificaciones posteriores a `dispose`. Requiere pruebas de ese ciclo de
   vida antes de ampliar los cambios.
4. **Media: importaciones de imágenes.** Ropa, Hogar, Plantas y Recetas
   decodifican y redimensionan imágenes de forma síncrona. Con fotografías
   grandes pueden ocupar el hilo de interfaz. Conviene medir con imágenes
   representativas y trasladar el procesamiento a un isolate conservando los
   hashes, miniaturas y gestión de errores actuales.
5. **Media: tamaño y reconstrucciones de las vistas.** El workspace concentra
   más de 5.600 líneas y el shell observa todo su estado. Extraer consultas
   puras por área y separar suscripciones requiere una refactorización
   incremental. El visor 3D mantiene animaciones continuas; su consumo de GPU
   necesita una medición específica con WebView y el equipo real.

## Validación y entrega

- Antes de los cambios: 140 pruebas Flutter aprobadas y análisis sin errores.
- Después: `flutter analyze --no-pub`, sin incidencias; 166 pruebas Flutter
  aprobadas, incluidas 26 nuevas pruebas de regresión.
- MCP y gemelo Python: 22 pruebas aprobadas.
- Repositorio documental Python: 3 pruebas aprobadas.
- Agente LAN: análisis sin incidencias y 1 prueba aprobada.
- Medición de rendimiento: 1 prueba adicional, ejecutada por separado.
- `npm run build`: compilación del visor correcta; el bundle coincide con la
  fuente previa, sin cambios funcionales de JavaScript en esta intervención.
- `flutter build windows --release --no-pub`: compilación correcta. CMake
  emite un aviso de desarrollo CMP0175 del plugin de WebView; no impide la
  compilación y no se modificó código de terceros para silenciarlo.
- Instalación de Windows actualizada con `tooling/install_todo_windows.ps1`:
  **216 archivos verificados por SHA-256**.
- No se abrió la aplicación instalada para pruebas visuales, siguiendo
  `AGENTS.md`. No se realizó una prueba física de Android, luces, calendario
  externo o alarmas reales. Los cambios de Android están en el código; no se
  distribuyó un APK nuevo.

Las pruebas nuevas usan datos sintéticos y directorios temporales. Esta
auditoría no borra ni migra los datos personales activos.
