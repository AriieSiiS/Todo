# Prompt para Codex — App personal de tareas, casa, vida personal y autocuidado

Quiero que implementes una aplicación personal de gestión de tareas, casa, vida personal y autocuidado.

## Importante
No necesito que decidas arquitectura a alto nivel porque eso ya está resuelto. No quiero que reabras debates de stack, arquitectura, librerías o estructura general. Quiero que te centres en implementar el producto y el modelo interno de la aplicación según estas reglas.

## Identidad de la app

La app debe sentirse como:

> una app para mantener mi casa y mi vida personal bajo control sin agobiarme

El núcleo visible de la app son las tareas, pero esas tareas pueden venir de:
- tareas manuales
- tareas recurrentes
- proyectos
- eventos/calendario
- capturas rápidas / notas convertibles en tareas

Es decir: las tareas son la capa principal que ve el usuario, pero internamente pueden tener distintas fuentes y comportamientos.

---

## Filosofía del producto

La app debe optimizar:
- claridad
- control
- baja fricción
- flexibilidad
- sostenibilidad
- capacidad de reorganización
- uso personal intensivo
- integración futura con IA mediante MCP

No quiero una app rígida.
Quiero una app muy maleable, donde casi todo se pueda crear, mover, editar, reclasificar y reorganizar.

---

## Requisito muy importante: preparación para MCP / agente externo

La aplicación debe quedar preparada para ser controlada por un agente externo mediante MCP o un sistema equivalente.

Esto es crítico.

Quiero poder conectar en el futuro ChatGPT u otra IA a esta aplicación y decirle cosas como:
- créame estas tareas
- reorganízame la semana
- mueve esto al viernes
- convierte estas notas en tareas
- crea un proyecto
- asigna categorías
- cambia prioridades
- crea tareas recurrentes
- lee el calendario
- organiza el día
- etc.

Por tanto, la app debe estar modelada pensando en que un agente externo pueda hacer prácticamente todas las operaciones importantes.

### Requisitos MCP / agente externo

Diseña la aplicación de forma que sea fácil exponer operaciones como:
- crear tarea
- editar tarea
- borrar tarea
- completar tarea
- reabrir tarea
- crear subtarea
- mover tarea de día
- cambiar prioridad
- cambiar orden manual
- cambiar categoría
- cambiar proyecto
- crear proyecto
- editar proyecto
- cerrar/completar proyecto
- crear nota
- convertir nota en tarea
- convertir nota en proyecto
- listar tareas de hoy
- listar tareas de una semana
- listar tareas por categoría
- listar proyectos
- leer calendario interno
- importar/exportar datos
- gestionar recurrencias
- reorganizar semana
- reorganizar día

No hace falta implementar ahora el MCP real si aún no toca, pero sí debes dejar:
1. el modelo interno preparado,
2. las operaciones bien separadas,
3. las acciones claramente definidas,
4. y la app estructurada de forma que luego sea sencillo exponer esas capacidades a un agente externo.

Quiero que el diseño del dominio y de las acciones piense desde el principio:
> esto lo va a usar un humano, pero también lo va a operar una IA

No quiero confirmaciones innecesarias porque la app es de uso personal.

---

## Navegación principal

La app debe tener estas secciones principales:
- Hoy
- Proyectos
- Categorías
- Calendario
- Completadas
- Ajustes

No quiero una sección separada de Rutinas.
Las rutinas son un comportamiento de las tareas, no una sección independiente.

---

## Pantalla principal: Hoy

La vista principal al abrir la app debe ser la lista de tareas de hoy.

### Reglas de la vista Hoy
- lista simple
- no agrupada por defecto
- subtareas visibles anidadas debajo de la tarea principal
- categorías visibles de un vistazo
- colores visibles de un vistazo
- la lista debe poder reordenarse manualmente
- también debe permitir ordenar por distintos criterios si el usuario quiere:
  - categoría
  - hora
  - proyecto
  - prioridad
  - etc.

### Subtareas
Quiero subtareas reales, no solo texto interno.

Visualmente:
- tarea principal arriba
- subtareas debajo, con indentación/anidación
- deben poder plegarse/ocultarse
- pero también deben ser visibles rápidamente desde fuera

---

## Lógica del día real

Esto es muy importante.

La app no debe asumir que el día acaba a las 00:00.

El usuario debe poder configurar:
- a qué hora termina su día real
- y a qué hora empieza el siguiente día visible

Ejemplo:
- el día termina a las 5:00
- el siguiente día visible empieza a las 10:00

### Comportamiento esperado
- las tareas del día actual deben seguir considerándose del mismo día hasta la hora de fin configurada
- si una tarea diaria se completa de madrugada, no debe aparecer automáticamente la siguiente instancia solo porque haya pasado la medianoche
- la siguiente instancia debe aparecer cuando realmente toque según la lógica del siguiente día real y/o la regla de recurrencia

Esto es una pieza central del producto.

---

## Tareas

Las tareas son la entidad principal visible.

### Campos posibles de una tarea
No todos obligatorios, pero la entidad debe soportar al menos:
- título
- descripción
- categoría
- proyecto/s
- color heredado o contexto visual
- icono contextual si aplica
- fecha
- hora
- prioridad
- estado
- recurrencia
- subtareas
- checklist
- materiales / cosas necesarias
- fuente de origen (manual, nota convertida, proyecto, calendario, etc.) si internamente ayuda
- orden manual

### Campos obligatorios mínimos
- título
- y lo imprescindible para guardarla

No quiero formularios rígidos donde todo sea obligatorio.

### Descripción
Las tareas pueden tener descripción o no.
Algunas tareas deben poder tener descripción larga útil, por ejemplo:
- objetivo
- materiales
- pasos

pero no quiero obligarlo en todas.

---

## Completado de tareas

Cuando una tarea se completa:
- no quiero que simplemente desaparezca sin más
- debe ir a una vista separada de “Completadas”

### Completadas
Debe existir una sección/vista de completadas.
Las completadas no deben quedarse eternamente en la vista principal.
Su persistencia exacta puede resolverse después, pero:
- deben poder revisarse
- no deben ensuciar la pantalla principal

---

## Tareas recurrentes / reglas

Cualquier tarea puede ser recurrente, independientemente de:
- su categoría
- su proyecto
- su contexto

Ejemplos de recurrencia:
- diaria
- cada X días
- semanal
- anual
- etc.

Las rutinas no son una entidad aparte visible necesariamente, sino una propiedad/comportamiento de la tarea.

Ejemplos:
- hacer la cama diario
- cambiar toallas semanal
- cumpleaños anual

La siguiente instancia debe generarse:
- según su regla
- o según el siguiente día real, cuando corresponda

No quiero comportamiento tipo:
completas algo a las 2:30 y aparece instantáneamente la tarea del “día siguiente” solo porque ya pasaron las 00:00.

---

## Notas / capturas rápidas

Quiero una forma de captura rápida.

### Qué es una nota
Una nota no es un ecosistema paralelo complejo.
Es una captura rápida temporal.
Sirve como punto intermedio entre idea rápida y tarea/proyecto real.

### Qué puede pasar con una nota
- convertirse en tarea
- convertirse en proyecto
- archivarse o borrarse si hace falta

No quiero que las notas vivan eternamente sin gestionar.

### Regla importante
Cuando termine el día real, si hay notas sin procesar:
- la app debe avisar claramente
- debe empujar al usuario a gestionarlas

No hace falta poner fecha a la nota como entidad.
La fecha se pone cuando la conviertes en tarea o proyecto.

---

## Categorías

Las categorías son estructuras permanentes.

Ejemplos:
- baño
- cocina
- gimnasio
- compras
- calendario
- personal
- etc.

### Reglas de categorías
- el usuario puede crear categorías
- renombrarlas
- activar/desactivar
- asignar color
- asignar icono
- pueden contener tareas directamente
- deben tener interfaz propia

Las categorías existen para siempre o a muy largo plazo.
No son temporales como los proyectos.

---

## Proyectos

Los proyectos son agrupaciones temporales con principio y final.

Ejemplo:
- “arreglar armario del baño”

Esto pertenece a una o varias categorías permanentes, por ejemplo:
- baño
- casa

Pero el proyecto:
- empieza
- evoluciona
- y termina

### Reglas de proyectos
- entidad propia
- vista propia
- puede tener:
  - nombre
  - descripción
  - icono
  - color
  - estado
  - tareas
  - subtareas
  - tareas recurrentes también si hace falta
- sus tareas luego aparecen en “Hoy” cuando toque

### Estados de proyecto
Quiero soporte para estados como:
- activo
- pausado
- completado
- cancelado

### Importante
Una tarea puede:
- pertenecer a ningún proyecto
- pertenecer a un proyecto
- pertenecer a varios proyectos

Y puede cambiar de proyecto sin perder información.

---

## Relación entre categorías y proyectos

No son lo mismo, pero sí se parecen.

Distinción clave:
- categoría = estructura permanente
- proyecto = agrupación temporal que termina

Ambos pueden tener:
- color
- icono
- tareas
- descripción
- estructura propia

Si una tarea pertenece a varias categorías/proyectos, no hace falta una “principal” compleja.
Puede valer con el orden en que estén asignadas o una lógica simple.

---

## Semana activa

Quiero una noción de semana activa, pero no una separación demasiado rígida entre:
- esta semana
- día concreto

Lo importante es que se pueda trabajar fácilmente con:
- tareas del día
- tareas de la semana
- reorganización manual

No quiero un backlog complejo separado.
Lo no clasificado puede vivir como:
- otros
- sin categoría
- o equivalente simple

No quiero una entidad especial llamada “foco actual”.

---

## Calendario

Quiero una sección de calendario.

### Ideal
Poder ver:
- el calendario de tareas de la app
- y si es posible, integrarlo con Google Calendar

### Si la integración completa no está lista
Al menos:
- la app debe poder conectarse fácilmente con Google Calendar en el futuro
- o exportar sus datos de forma muy fácil para que una IA o un sistema externo lo traduzca a Google Calendar

### Objetivo
Quiero poder:
- ver eventos
- usar calendario para planificación
- y potencialmente convertir o relacionar eventos con tareas

---

## Ajustes

En Ajustes debe existir soporte para cosas como:
- hora a la que termina el día real
- hora a la que empieza el siguiente día visible
- notificaciones
- categorías
- colores
- iconos
- conexión/calendario
- exportación
- importación si aplica

---

## Notificaciones y recordatorios

La app debe soportar recordatorios/notificaciones propios.

Ejemplos:
- a una hora concreta
- al empezar el día real
- al acercarse el final del día real
- para revisar notas sin procesar
- para tareas pendientes

---

## Creación de tareas

Quiero dos modos de creación:

### 1. Creación completa
Formulario completo desde el principio, con todos los campos disponibles.

### 2. Captura rápida
Poder crear algo rápido y dejarlo incompleto para rellenarlo después.

No quiero que la captura rápida desaparezca en un limbo.
Debe quedar clara y gestionable.

---

## Comportamiento de alto nivel por agente externo

La app debe estar pensada para que un agente externo pueda operar no solo a bajo nivel, sino también a alto nivel.

Ejemplos de operaciones de alto nivel:
- organízame la semana
- prioriza baño y cocina
- mueve lo no urgente
- conviérteme estas notas en tareas
- sácame tareas del calendario
- reorganiza el día
- reordena automáticamente estas tareas
- crea un proyecto y distribuye sus tareas

La app no debe impedir este tipo de control.
Debe estar preparada para ello.

---

## Exportación

Quiero exportación desde el principio en un formato especialmente fácil de leer por una IA.

Elige el formato que consideres más robusto para lectura por IA y manipulación externa.
Mi preferencia conceptual sería algo tipo:
- JSON estructurado

o equivalente muy claro.

Debe ser fácil exportar:
- tareas
- proyectos
- categorías
- calendario interno
- notas
- configuración relevante

---

## Decisiones UX importantes

- lista principal = Hoy
- lista simple
- subtareas anidadas
- reordenación manual
- colores visibles
- categorías visibles
- notas como captura temporal
- tareas completadas en vista separada
- categorías permanentes
- proyectos temporales
- reglas de recurrencia potentes
- soporte fuerte para control externo por agente/IA

---

## Qué quiero que hagas ahora

Implementa la app siguiendo esta especificación de producto.

Prioriza:
1. modelo correcto de entidades y relaciones
2. vista Hoy
3. creación/edición de tareas
4. categorías
5. proyectos
6. notas/captura rápida
7. lógica del día real
8. recurrencias
9. calendario
10. preparación clara para futura integración vía MCP/agente externo

No me vuelvas a discutir arquitectura.
No quiero un rediseño conceptual alternativo.
Quiero que construyas esta app según esta definición.

Si ves detalles menores que faltan, decide con criterio, pero sin traicionar estas reglas.

Y cuando termines cada parte importante, explícame:
- qué implementaste
- qué supusiste
- y qué puntos dejarías para la siguiente iteración
