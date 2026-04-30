# Plan de implementacion

## Objetivo
Construir una app personal de tareas, casa, vida personal y autocuidado donde la capa visible principal sean las tareas, pero con un dominio preparado para notas, proyectos, recurrencias, calendario y control futuro por MCP.

## Fase 1 - Base del producto
- [x] Copiar el prompt maestro al proyecto raiz.
- [x] Fijar la direccion del producto sin reabrir decisiones de arquitectura.
- [x] Definir un modelo interno preparado para operaciones humanas y de agente externo.
- [x] Crear un controlador central con acciones separadas para tareas, notas, categorias, proyectos, recurrencias y ajustes.
- [x] Montar una app Flutter real con proyecto Windows, web y Android listo para crecer.

## Fase 2 - Navegacion principal
- [x] Crear las secciones `Hoy`, `Proyectos`, `Categorias`, `Calendario`, `Completadas` y `Ajustes`.
- [x] Dejar `Hoy` como vista principal.
- [x] Preparar una UI minimalista, clara y de baja friccion.

## Fase 3 - Operaciones del dominio preparadas para MCP
- [x] Crear tarea, editar tarea, borrar tarea, completar tarea y reabrir tarea.
- [x] Crear subtarea y plegado de subtareas.
- [x] Cambiar prioridad, proyecto, categoria y orden manual.
- [x] Crear proyecto, editar proyecto y cambiar estado.
- [x] Crear nota, convertir nota en tarea y convertir nota en proyecto.
- [x] Listar tareas de hoy, semana, por categoria y completadas.
- [x] Exportar datos en JSON.
- [x] Reorganizar dia y semana desde acciones separadas.

## Fase 4 - Logica del dia real
- [x] Soportar fin de dia configurable.
- [x] Soportar aparicion configurable del siguiente dia visible.
- [x] Hacer que la fecha logica de trabajo no dependa solo de las 00:00.
- [x] Conectar la recurrencia basica con esa logica.

## Fase 5 - Interfaz funcional inicial
- [x] Captura rapida de notas.
- [x] Lista principal de hoy con reordenacion manual.
- [x] Vista de proyectos con estado y conteos.
- [x] Vista de categorias con activacion y edicion.
- [x] Vista de calendario semanal interna.
- [x] Vista de completadas separada.
- [x] Ajustes para dia real y exportacion.

## Fase 6 - Validacion tecnica
- [x] Dejar `flutter analyze` limpio.
- [x] Dejar test base pasando.
- [x] Abrir la version web para prueba manual.
- [x] Lanzar la version Windows para prueba manual.

## Siguiente iteracion recomendada
- [x] Persistencia local automatica para mantener el estado entre sesiones.
- [ ] Sustituir la persistencia ligera por SQLite/Drift si el volumen o complejidad crece.
- [ ] Formularios mas completos para tareas recurrentes, checklist y materiales.
- [ ] Calendario editable con arrastrar y mover entre dias.
- [ ] Integracion real con Google Calendar.
- [ ] Notificaciones locales y push.
- [ ] Capa MCP real para exponer operaciones al agente externo.
- [ ] Sincronizacion entre dispositivos.
