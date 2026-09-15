---
name: extract-clothing-to-todo
description: Extraer una o varias prendas de fotografías personales en las que el usuario lleva un outfit, reconstruir cada una como imagen de catálogo sin fondo e insertarlas directamente en la sección Ropa de Todo. Usar cuando el usuario entregue fotos llevando ropa y pida añadir prendas a su armario; usar lotes únicamente cuando solicite revisión previa.
---

# Extraer ropa para Todo

Convertir la prenda visible en una imagen de catálogo fiel e incorporarla a Todo sin pedir al usuario que importe ni apruebe nada.

Trabajar como una línea de producción: **foto → render → aplicación**. Evitar
exploraciones, comprobaciones y artefactos que no cambien el resultado.

## Modelo de entrada y artefactos

- Suponer que las fotos de origen son fotografías opacas del usuario llevando un outfit, no imágenes de producto ni PNG transparentes.
- Usar las fotos únicamente como evidencia visual. No recortar a la persona ni guardar la fotografía original como imagen de la prenda.
- Distinguir siempre tres artefactos: las fotos de referencia, el render de catálogo sobre fondo plano y el PNG final transparente.
- Si el usuario ya ha aceptado un render de catálogo correcto, reutilizar exactamente ese archivo. No volver a generarlo porque aún tenga fondo.
- Si ese render ya tiene transparencia válida, importarlo directamente. Si conserva un fondo plano, eliminar solo ese fondo y continuar.

## Camino rápido

1. Identificar las prendas solicitadas y resolver sus metadatos. Consultar `get_wardrobe_import_contract` solo cuando exista una duda real sobre un valor canónico.
2. Buscar primero cualquier render de catálogo ya generado durante la tarea. Si el usuario lo considera correcto, conservar exactamente ese archivo y saltar la generación.
3. Cuando no exista un render válido, leer y seguir la habilidad `imagegen` y generar una sola imagen por prenda. Excluir persona, piel, pelo, móvil, percha, maniquí, escena y sombras.
4. Generar sobre un fondo croma completamente uniforme cuyo color no aparezca en la prenda. Elegirlo después de revisar colores, cuello, estampados, escudos y texto; no usar automáticamente verde o blanco.
5. Eliminar el croma localmente una sola vez para obtener PNG RGBA. La máscara debe eliminar únicamente el fondo conectado a los bordes, no píxeles interiores de la prenda que tengan un color parecido.
6. Realizar una única comprobación visual breve antes de importar. Cuello, mangas o perneras, silueta, colores, patrón, logotipos y texto deben coincidir y el fondo debe ser transparente. No encadenar comprobaciones técnicas que no puedan descubrir un defecto concreto.
7. Si la transparencia daña una parte de la prenda, repetir una sola vez la eliminación con un umbral más conservador usando el mismo render. No regenerar la prenda para corregir una máscara.
8. Llamar a `import_wardrobe_item` por cada prenda con su PNG exacto, todos sus metadatos y un `request_id` estable. Cuando responda `savedLocally: true`, confirmar el identificador y pasar a la siguiente prenda o terminar.

No crear una copia completa, carpeta de lote ni manifiesto durante una importación normal, aunque haya varias prendas. No pedir que el usuario pulse `Importar` o `Aprobar lote`. La operación directa es local e idempotente; la sincronización remota puede completarse después y no debe esperarse para dar la tarea por terminada.

No recontar el armario antes y después de cada inserción, no volver a abrir la app
y no comprobar repetidamente snapshot, miniatura, recursos y sincronización. La
revisión visual única y la respuesta atómica de importación son la validación del
camino normal. Ampliar las comprobaciones solo si la operación falla, devuelve un
resultado incoherente o el usuario informa de un defecto.

## Criterios de fidelidad

- Tratar el resultado como una reconstrucción limitada por la evidencia visible.
- Mantener separadas prendas parecidas cuando no esté demostrado que sean el mismo objeto.
- Omitir detalles inciertos antes que inventar bolsillos, cierres, logos, costuras o adornos.
- Mantener toda la prenda dentro del encuadre y no añadir márgenes artificiales: Todo normaliza automáticamente el tamaño visual.
- Rechazar cuerpo residual, capas fusionadas, recortes, fondo opaco, texto falso o halo croma.
- No aceptar que la retirada del fondo cambie o elimine cuello, puños, mangas, bajos, cordones, escudos, logotipos o texto.
- Una vez aceptado el render, no sustituirlo por otra generación ni importar un archivo intermedio distinto.

## Inserción sin desvíos

Usar `import_wardrobe_item` para una prenda individual. Si la herramienta no aparece en la sesión, comprobar primero que el MCP local de Todo está conectado o recargarlo. Si sigue sin estar disponible, ejecutar el fallback oficial [scripts/import_wardrobe_item.py](scripts/import_wardrobe_item.py), que llama a la misma operación atómica y acepta los valores múltiples repitiendo `--color`, `--season`, `--occasion` o `--tag`.

No sustituir este camino por el importador por lotes, la interfaz gráfica, la edición manual del snapshot ni scripts improvisados. La ausencia de la herramienta no es una razón para repetir la generación. Después de obtener una respuesta con `savedLocally: true`, confirmar el identificador y terminar.

## Varias prendas en una foto

Una sola foto es suficiente cuando todas las prendas solicitadas aparecen
completas, separadas entre sí, sin solaparse y con luz y detalle suficientes. Es
el formato más rápido porque evita gestionar varias referencias. Crear un render
independiente y una inserción directa independiente para cada prenda.

Pedir o aprovechar fotos separadas cuando una prenda esté tapada, doblada,
demasiado pequeña, solo muestre parte delantera insuficiente o contenga texto,
logotipos o detalles que no puedan leerse con seguridad.

## Revisión solicitada

Usar `stage_wardrobe_batch` únicamente cuando el usuario pida expresamente
revisar antes de guardar. En ese caso, preparar `manifest.json` según
[manifest.md](references/manifest.md) y comunicar el resultado del lote. La
aprobación seguirá correspondiendo al usuario.

## Renderizar un conjunto guardado

1. Consultar `list_wardrobe_outfits` y resolver sus prendas con `list_wardrobe_items`.
2. Usar fotografías personales como referencia de identidad y los PNG del armario como referencia de vestuario.
3. Con Imagegen, conservar cara, pelo, barba, gafas, tono de piel y proporciones; sustituir solo vestuario y escena.
4. Generar un retrato vertical de cuerpo entero sin móvil, espejo, texto ni prendas protagonistas ajenas al conjunto.
5. Comparar identidad y prendas, guardar el PNG final y llamar a `set_wardrobe_outfit_render`.
