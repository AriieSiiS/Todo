---
name: extract-clothing-to-todo
description: Extraer una prenda de fotografías personales, reconstruirla como imagen de catálogo sin fondo e insertarla directamente en la sección Ropa de Todo. Usar cuando el usuario entregue fotos de ropa y pida añadirla a su armario; usar lotes solo para varias prendas o cuando solicite revisión previa.
---

# Extraer ropa para Todo

Convertir la prenda visible en una imagen de catálogo fiel e incorporarla a Todo sin pedir al usuario que importe ni apruebe nada.

## Camino rápido para una prenda

1. Leer las fotos proporcionadas y resolver nombre, categoría, material, colores, temporadas, ocasiones y etiquetas. Consultar `get_wardrobe_import_contract` si hace falta confirmar los valores canónicos.
2. Leer y seguir la habilidad `imagegen`. Elegir una vista principal y, como máximo, una complementaria.
3. Generar una sola imagen con una única prenda completa, sin persona, piel, pelo, móvil, percha, maniquí, escena ni sombras. Usar un fondo croma plano y alejado de los colores de la prenda.
4. Eliminar el croma una sola vez con el helper local de Imagegen para obtener PNG RGBA transparente.
5. Hacer una comprobación visual breve: cuello, mangas o perneras, proporciones, colores, patrón, logotipos y texto legible. Corregir una sola vez si hay un defecto evidente o falla la transparencia; si vuelve a fallar, explicar el problema en vez de encadenar intentos.
6. Llamar a `import_wardrobe_item` con el PNG, los metadatos y un `request_id` estable. Confirmar el identificador devuelto y terminar.

No crear una copia completa, carpeta de lote ni manifiesto para una prenda individual. No pedir que el usuario pulse `Importar` o `Aprobar lote`. La operación directa es local e idempotente; la sincronización remota puede completarse después.

## Criterios de fidelidad

- Tratar el resultado como una reconstrucción limitada por la evidencia visible.
- Mantener separadas prendas parecidas cuando no esté demostrado que sean el mismo objeto.
- Omitir detalles inciertos antes que inventar bolsillos, cierres, logos, costuras o adornos.
- Mantener toda la prenda dentro del encuadre y no añadir márgenes artificiales: Todo normaliza automáticamente el tamaño visual.
- Rechazar cuerpo residual, capas fusionadas, recortes, fondo opaco, texto falso o halo croma.

## Varias prendas o revisión solicitada

Usar `stage_wardrobe_batch` únicamente cuando el usuario entregue varias prendas a la vez o pida expresamente revisar antes de guardar. En ese caso, preparar `manifest.json` según [manifest.md](references/manifest.md) y comunicar el resultado del lote. La aprobación seguirá correspondiendo al usuario.

## Renderizar un conjunto guardado

1. Consultar `list_wardrobe_outfits` y resolver sus prendas con `list_wardrobe_items`.
2. Usar fotografías personales como referencia de identidad y los PNG del armario como referencia de vestuario.
3. Con Imagegen, conservar cara, pelo, barba, gafas, tono de piel y proporciones; sustituir solo vestuario y escena.
4. Generar un retrato vertical de cuerpo entero sin móvil, espejo, texto ni prendas protagonistas ajenas al conjunto.
5. Comparar identidad y prendas, guardar el PNG final y llamar a `set_wardrobe_outfit_render`.
