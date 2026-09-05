# Auditoría de rendimiento y calidad

Fecha: 5 de septiembre de 2026.

## Alcance y respaldo

Commit previo a cualquier cambio: `ecdbc8b`. Conserva los 33 archivos que tenían
cambios pendientes. Se revisaron el arranque, los providers, el shell, las
consultas de tareas, el guardado local y la coordinación de persistencia.
Esta revisión no es un perfil completo de todas las pantallas e integraciones.

## Mejoras aplicadas

| Hallazgo | Cambio | Compatibilidad |
| --- | --- | --- |
| `MaterialApp` reconstruía el tema ante cualquier notificación del workspace. | Suscripción con `select` al modo visual. | El shell mantiene su propia suscripción al workspace; las pantallas siguen recibiendo actualizaciones. |
| Ordenar por categoría o proyecto buscaba linealmente el nombre en cada comparación. | Índice local de nombres por cada ordenación. | Se conserva la primera relación, la primera entidad con un ID duplicado y el valor `zzz` para relaciones ausentes. |
| El filtro diario calculaba la clave de recurrencia y la comparación con hoy por cada tarea. | Ambos valores se calculan una vez por consulta. | Se mantienen los filtros de estado, subtareas, recurrencias y tareas atrasadas. |

Para N tareas y M categorías o proyectos, la búsqueda de nombres durante la
ordenación pasa de un coste de hasta O(M × N log N) a O(M + N log N), con O(M)
de memoria temporal. No hay caché persistente que pueda quedar desactualizada
al editar nombres. Se retiraron los dos helpers privados de búsqueda que ya
no tenían consumidores. No se cambiaron contratos públicos, dependencias ni
formatos de datos.

La reducción de trabajo se deduce del código; no se ha medido una mejora en
milisegundos ni FPS con datos reales.

## Hallazgos para una siguiente intervención

- **Prioridad alta, riesgo por confirmar:** `_persist` tiene varios puntos de
  entrada y no serializa operaciones. Si un guardado dura más que el debounce
  de 250 ms, otro puede empezar mientras el anterior sigue pendiente. El store
  comparte nombres `.tmp` y `.previous`. Conviene reproducir esta concurrencia
  con un repositorio lento e introducir una cola con pruebas de fallos antes de
  modificar el contrato de persistencia o sincronización.
- **Prioridad media:** `FileBackedLocalStore` vuelve a decodificar y formatear
  el JSON al escribir, y guarda el snapshot tanto en preferencias como en
  archivo. Es trabajo adicional proporcional al tamaño del estado. Cualquier
  ajuste debe conservar la recuperación y migración existentes.
- **Prioridad media:** `AppShell` observa todo el workspace. La mejora del tema
  no elimina las reconstrucciones del shell. Separar suscripciones exige medir
  cada pantalla y comprobar que no pierde actualizaciones.
- **Prioridad media:** `TodoWorkspace` concentra cerca de 4.900 líneas y lógica
  de múltiples áreas. Extraer consultas puras y servicios por área facilitaría
  su mantenimiento, pero requiere una refactorización gradual y cobertura
  específica para las funciones en uso.

Estos puntos quedan documentados, sin cambios de comportamiento de riesgo en
esta intervención.

## Validación

- Estado previo: `flutter analyze`, sin incidencias; 88 pruebas aprobadas.
- Estado modificado: `flutter analyze --no-pub`, sin incidencias; 90 pruebas
  aprobadas con `flutter test --no-pub`.
- Dos pruebas nuevas verifican el orden por categoría y proyecto, relaciones
  ausentes, IDs duplicados, primera relación, exclusión de completadas y
  subtareas, cambios de nombre y conservación de la lista original.
- La suite existente incluye vistas principales, calendario, recurrencia,
  notificaciones y contratos de snapshots.
- La comprobación visual de la instalación corresponde al usuario según
  `AGENTS.md`; no se abrió la app instalada para probarla.
