# Plan de implementación

## Objetivo

Construir una app personal de tareas, casa, vida personal y autocuidado donde la capa visible principal sean las tareas, pero con un dominio preparado para notas, proyectos, recurrencias, calendario y control futuro por MCP.

## Fase 1 - Base del producto

- [x] Copiar el prompt maestro al proyecto raíz.
- [x] Fijar la dirección del producto sin reabrir decisiones de arquitectura.
- [x] Definir un modelo interno preparado para operaciones humanas y de agente externo.
- [x] Crear un controlador central con acciones separadas para tareas, notas, categorías, proyectos, recurrencias y ajustes.
- [x] Montar una app Flutter real con proyecto Windows listo para crecer.

## Fase 2 - Navegación principal

- [x] Crear las secciones `Hoy`, `Proyectos`, `Categorías`, `Calendario`, `Completadas` y `Ajustes`.
- [x] Dejar `Hoy` como vista principal.
- [x] Preparar una UI minimalista, clara y de baja fricción.

## Fase 3 - Operaciones del dominio preparadas para MCP

- [x] Crear tarea, editar tarea, borrar tarea, completar tarea y reabrir tarea.
- [x] Crear subtarea y plegado de subtareas.
- [x] Cambiar prioridad, proyecto, categoría y orden manual.
- [x] Crear proyecto, editar proyecto y cambiar estado.
- [x] Crear nota, convertir nota en tarea y convertir nota en proyecto.
- [x] Listar tareas de hoy, semana, por categoría y completadas.
- [x] Exportar datos en JSON.
- [x] Reorganizar día y semana desde acciones separadas.

## Fase 4 - Lógica del día real

- [x] Soportar fin de día configurable.
- [x] Soportar aparición configurable del siguiente día visible.
- [x] Hacer que la fecha lógica de trabajo no dependa solo de las 00:00.
- [x] Conectar la recurrencia básica con esa lógica.

## Fase 5 - Interfaz funcional inicial

- [x] Captura rápida de notas.
- [x] Lista principal de hoy con reordenación manual.
- [x] Vista de proyectos con estado y conteos.
- [x] Vista de categorías con activación y edición.
- [x] Vista de calendario semanal interna.
- [x] Vista de completadas separada.
- [x] Ajustes para día real y exportación.

## Fase 6 - Validación técnica

- [x] Dejar `flutter analyze` limpio.
- [x] Dejar test base pasando.
- [x] Lanzar la versión Windows para prueba manual.

## Siguiente iteración recomendada

- [x] Persistencia local automática para mantener el estado entre sesiones.
- [ ] Sustituir la persistencia ligera por SQLite/Drift si el volumen o complejidad crece.
- [ ] Formularios más completos para tareas recurrentes, checklist y materiales.
- [ ] Calendario editable con arrastrar y mover entre días.
- [ ] Integración real con Google Calendar.
- [ ] Notificaciones locales y push.
- [ ] Capa MCP real para exponer operaciones al agente externo.
- [ ] Sincronización entre dispositivos.
