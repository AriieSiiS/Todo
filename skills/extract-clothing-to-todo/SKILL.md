---
name: extract-clothing-to-todo
description: Extraer prendas únicas de fotografías donde aparecen puestas, reconstruirlas como PNG transparentes con Imagegen, preparar lotes revisables y generar renders de conjuntos guardados en la sección Ropa de Todo mediante su MCP local. Usar cuando el usuario entregue fotos personales y pida crear o actualizar su armario, o visualizar un conjunto sobre sí mismo.
---

# Extraer ropa para Todo

Convertir fotografías personales en prendas de catálogo independientes y enviar únicamente resultados revisables a Todo. Tratar cada resultado como una reconstrucción limitada por la evidencia visible, no como una segmentación literal.

## Antes de empezar

1. Obtener la carpeta o los archivos de entrada y confirmar que pertenecen al usuario.
2. Crear todo el trabajo temporal fuera del repositorio y de `Documents/Todo/wardrobe`.
3. Leer y seguir la skill integrada `imagegen` antes de generar o editar imágenes.
4. Consultar `get_wardrobe_import_contract` en el MCP de Todo. Si no está disponible, leer [manifest.md](references/manifest.md) y preparar una carpeta importable manualmente.

No modificar las fotografías originales. No enviar ni conservar el volcado completo en Todo.

## Flujo

### 1. Inventariar

- Crear hojas de contacto de máximo 12 imágenes y revisar todas visualmente.
- Enumerar cada prenda deliberadamente llevada: parte superior, parte inferior, vestido, abrigo, calzado, calcetería, cinturón, corbata o sombrero.
- Consolidar duplicados solo cuando las fotografías demuestren que son el mismo objeto físico.
- Mantener separadas prendas genéricas parecidas cuando la identidad sea dudosa.
- Retener como `hold` cualquier fragmento cuyo tipo o construcción esencial no pueda recuperarse sin inventar.

### 2. Preparar referencias

- Elegir una vista principal y, como máximo, una complementaria por prenda.
- Recortar con aproximadamente 12 % de margen, conservando contexto suficiente para distinguir capas.
- No combinar referencias de prendas distintas.
- Registrar color, material, silueta, construcción, marcas legibles, incertidumbres y nombres de las fotos de origen.

### 3. Generar

- Generar exactamente una prenda por imagen, salvo pares establecidos como zapatos o calcetines.
- Reconstruir el objeto completo sin persona, piel, pelo, maniquí, percha, otras capas, escena, sombras ni texto inventado.
- Mantener la prenda completamente dentro del encuadre sobre un color croma uniforme y distante de sus colores.
- Preferir omitir detalles inciertos antes que inventar bolsillos, cierres, logos, costuras o adornos.
- Eliminar el croma con el helper de Imagegen y guardar PNG RGBA transparente.
- No compensar manualmente la escala añadiendo márgenes al PNG. Todo recorta el área transparente y normaliza automáticamente el tamaño visual según la categoría al aprobar la importación.

### 4. Verificar

- Comparar cada resultado con sus recortes fuente.
- Confirmar categoría, proporciones, color, material, aberturas, mangas o perneras, bajos, cierres, patrón y marcas legibles.
- Rechazar cuerpo residual, capas fusionadas, recortes, fondo opaco, texto falso o construcción inventada.
- Verificar PNG RGBA, esquinas transparentes, contenido no vacío, margen visible y ausencia de halo croma.
- Reintentar con un prompt corregido; después de dos fallos, reformularlo alrededor del fallo observado.

### 5. Preparar y enviar el lote

- Crear una carpeta temporal que contenga exclusivamente los PNG finales y `manifest.json`.
- Usar nombres de archivo simples, descriptivos y únicos.
- Completar el manifiesto versión 1 según [manifest.md](references/manifest.md).
- Invocar `stage_wardrobe_batch` con `source_directory` y, opcionalmente, `manifest_path`.
- Consultar `get_wardrobe_batch` y comunicar cuántas prendas quedaron válidas, con errores o como duplicados exactos.
- No aprobar el lote: la aprobación corresponde al usuario dentro de Todo.
- Si el MCP no está conectado, devolver la ruta absoluta de la carpeta para usar “Importar lote desde carpeta”.

## Contrato de entrega

- Entregar solo PNG finales y el manifiesto; mantener recortes, prompts, cromas y QA en temporal.
- No escribir directamente en `wardrobe/items` ni editar `todo_state.json`.
- No borrar temporales hasta confirmar que `stage_wardrobe_batch` aceptó el lote o que el usuario recibió la carpeta manual.
- Informar brevemente de fragmentos omitidos por falta de evidencia.

## Renderizar un conjunto guardado

Cuando el usuario pida visualizar un conjunto como una tarjeta editorial:

1. Consultar `list_wardrobe_outfits` y resolver todas sus prendas mediante `list_wardrobe_items`.
2. Usar una o dos fotografías personales como referencias de identidad y los PNG definitivos de las prendas como referencias de vestuario.
3. Seguir el modo `identity-preserve` de Imagegen: conservar cara, pelo, barba, gafas, tono de piel y proporciones; sustituir únicamente el vestuario y la escena.
4. Generar un retrato vertical de cuerpo entero, sin móvil, espejo, auriculares, mochila, texto ni marcas inventadas. No añadir prendas protagonistas que no estén en el conjunto; el calzado neutro solo puede completar un conjunto que no lo especifique.
5. Comparar el render con la identidad y con cada PNG de prenda. Rechazar cambios sustanciales de cara, silueta, color o gráfico.
6. Guardar el resultado final como PNG y llamar a `set_wardrobe_outfit_render` con `outfit_id` y `source_file`.
7. Confirmar que el conjunto muestra el nuevo render en Todo. La imagen puede reemplazarse manualmente desde el detalle del conjunto.
