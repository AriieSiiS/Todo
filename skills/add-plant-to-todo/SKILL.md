---
name: add-plant-to-todo
description: Investigar y añadir una planta a la sección Plantas de Todo con imagen, ficha botánica, seguridad para gatos, fuentes fiables y rutinas de cuidado enlazadas con tareas. Usar cuando el usuario pida añadir, registrar o incorporar una planta concreta a su colección de Todo.
---

# Añadir una planta a Todo

Crear una ficha completa, prudente y respaldada por fuentes. Trabajar como una
línea directa: **identificación → investigación → imagen → aplicación**.

## Camino normal

1. Identificar la especie con el nombre científico más preciso que permita la
   información disponible. Si una fotografía no basta para distinguir especies
   con cuidados o toxicidad diferentes, pedir el dato que falta antes de
   afirmar una identificación.
2. Consultar `get_plant_contract` para respetar los valores canónicos y el
   formato vigente.
3. Verificar los cuidados en una fuente hortícola fiable, priorizando RHS,
   jardines botánicos, universidades o servicios oficiales de extensión
   agraria. Adaptar las instrucciones a una vivienda, sin convertir rangos
   orientativos en certezas.
4. Verificar por separado la seguridad para gatos en ASPCA u otra fuente
   veterinaria reconocida. No deducir la toxicidad a partir de la familia, el
   nombre popular ni una ficha de cuidados. Si no hay evidencia suficiente,
   guardar `unknown` o `caution` y explicarlo.
5. Reutilizar la fotografía aportada por el usuario si muestra bien la planta.
   Si no hay imagen, leer y seguir la habilidad `imagegen` para crear una única
   imagen de catálogo botánicamente fiel, sin texto, marcas ni elementos que
   oculten hojas o tallos.
6. Preparar rutinas independientes, concretas y editables. Cada una debe tener
   un identificador estable, instrucciones accionables, primera fecha, tipo de
   recurrencia e intervalo. Usar `activeMonths` para cuidados estacionales. Las
   tareas se crean como día completo, sin hora ni aviso.
7. Llamar una sola vez a `create_plant` con toda la ficha, las fuentes, las
   rutinas y un `request_id` estable. Después, si hay imagen, llamar a
   `set_plant_image` con otro `request_id` estable.
8. Cuando la operación responda `savedLocally: true`, confirmar el identificador
   y terminar. Consultar `list_plants` solo si la respuesta es incoherente o si
   el usuario pide una verificación adicional.

## Calidad de la ficha

- Escribir en castellano correcto y mantener el nombre científico en cursiva
  solo cuando el formato de destino lo admita.
- Incluir luz, riego, humedad, temperatura, sustrato, abonado, poda,
  propagación, trasplante y problemas frecuentes cuando las fuentes permitan
  afirmarlos con seguridad.
- Explicar la seguridad felina con lenguaje claro. Incluso una planta no tóxica
  puede causar molestias gastrointestinales si se ingiere en cantidad.
- Guardar enlaces directos a las fuentes consultadas, con títulos descriptivos.
- Evitar calendarios rígidos para el riego: la tarea debe pedir comprobar el
  sustrato y regar solo cuando corresponda.
- No crear duplicados al reintentar. Conservar los mismos `request_id` e
  identificadores de rutina durante toda la operación.

No editar manualmente el snapshot, no abrir la aplicación para completar el
alta y no esperar a la sincronización remota después de una confirmación local.
