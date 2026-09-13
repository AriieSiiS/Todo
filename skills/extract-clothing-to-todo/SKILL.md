---
name: extract-clothing-to-todo
description: Extraer una prenda de fotografías personales en las que el usuario lleva un outfit, reconstruirla como imagen de catálogo sin fondo e insertarla directamente en la sección Ropa de Todo. Usar cuando el usuario entregue fotos llevando ropa y pida añadir una prenda a su armario; usar lotes solo para varias prendas o cuando solicite revisión previa.
---

# Extraer ropa para Todo

Convertir la prenda visible en una imagen de catálogo fiel e incorporarla a Todo sin pedir al usuario que importe ni apruebe nada.

## Modelo de entrada y artefactos

- Suponer que las fotos de origen son fotografías opacas del usuario llevando un outfit, no imágenes de producto ni PNG transparentes.
- Usar las fotos únicamente como evidencia visual. No recortar a la persona ni guardar la fotografía original como imagen de la prenda.
- Distinguir siempre tres artefactos: las fotos de referencia, el render de catálogo sobre fondo plano y el PNG final transparente.
- Si el usuario ya ha aceptado un render de catálogo correcto, reutilizar exactamente ese archivo. No volver a generarlo porque aún tenga fondo.
- Si ese render ya tiene transparencia válida, importarlo directamente. Si conserva un fondo plano, eliminar solo ese fondo y continuar.

## Camino rápido para una prenda

1. Identificar en las fotos la prenda solicitada y resolver nombre, categoría, material, colores, temporadas, ocasiones y etiquetas. Consultar `get_wardrobe_import_contract` solo si hace falta confirmar valores canónicos.
2. Buscar primero un render de catálogo ya generado durante la tarea. Si es correcto, conservarlo y saltar la generación.
3. Cuando no exista un render válido, leer y seguir la habilidad `imagegen`, elegir una vista principal y, como máximo, una complementaria, y generar una sola imagen con una única prenda completa. Excluir persona, piel, pelo, móvil, percha, maniquí, escena y sombras.
4. Generar sobre un fondo croma completamente uniforme cuyo color no aparezca en la prenda. Elegirlo después de revisar colores, cuello, estampados, escudos y texto; no usar automáticamente verde o blanco.
5. Eliminar el croma localmente una sola vez para obtener PNG RGBA. La máscara debe eliminar únicamente el fondo conectado a los bordes, no píxeles interiores de la prenda que tengan un color parecido.
6. Comparar brevemente el render anterior y el PNG resultante. Cuello, mangas o perneras, silueta, colores, patrón, logotipos y texto deben permanecer iguales. La importación posterior solo puede recortar margen transparente y ajustar escala.
7. Si la transparencia daña una parte de la prenda, repetir una sola vez la eliminación con un umbral más conservador usando el mismo render. No regenerar la prenda para corregir una máscara.
8. Llamar a `import_wardrobe_item` con ese PNG exacto, todos los metadatos y un `request_id` estable. Confirmar el identificador devuelto y terminar.

No crear una copia completa, carpeta de lote ni manifiesto para una prenda individual. No pedir que el usuario pulse `Importar` o `Aprobar lote`. La operación directa es local e idempotente; la sincronización remota puede completarse después.

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

## Varias prendas o revisión solicitada

Usar `stage_wardrobe_batch` únicamente cuando el usuario entregue varias prendas a la vez o pida expresamente revisar antes de guardar. En ese caso, preparar `manifest.json` según [manifest.md](references/manifest.md) y comunicar el resultado del lote. La aprobación seguirá correspondiendo al usuario.

## Renderizar un conjunto guardado

1. Consultar `list_wardrobe_outfits` y resolver sus prendas con `list_wardrobe_items`.
2. Usar fotografías personales como referencia de identidad y los PNG del armario como referencia de vestuario.
3. Con Imagegen, conservar cara, pelo, barba, gafas, tono de piel y proporciones; sustituir solo vestuario y escena.
4. Generar un retrato vertical de cuerpo entero sin móvil, espejo, texto ni prendas protagonistas ajenas al conjunto.
5. Comparar identidad y prendas, guardar el PNG final y llamar a `set_wardrobe_outfit_render`.
