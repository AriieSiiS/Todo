# Estándar de catálogo para Calzado

Aplicar este contrato a cualquier prenda cuya categoría canónica sea `Calzado`.
El resultado debe seguir la composición de
[`calzado-perfil-guia.png`](../assets/calzado-perfil-guia.png); la guía controla
solo posición y orientación, nunca diseño, marca, colores ni materiales.

## Composición canónica

- Una sola pieza representativa del par, completa y vista desde un perfil
  lateral ligeramente elevado. La elevación debe dejar visibles la pala, los
  cordones y los logotipos demostrados por la referencia sin convertir la toma
  en una vista cenital.
- Puntera hacia la izquierda, talón hacia la derecha y suela prácticamente
  horizontal. En chanclas, mostrar una sola chancla con el mismo eje y una
  elevación suficiente para reconocer la tira y su marca.
- Fondo croma plano, sin suelo, sombras, reflejos, degradados ni elementos
  adicionales.
- PNG RGBA final de `1200 × 1200`, centrado, con una caja visible de `1032 px`
  de ancho, entre `380 y 560 px` de alto y relación entre `1,85:1` y `2,70:1`.

## Prompt canónico

```text
Use case: product-mockup
Asset type: imagen de catálogo para el armario digital de Todo
Input images: las fotografías o renders de la prenda son referencias de identidad; la guía neutra es referencia exclusiva de composición
Primary request: reconstruir fielmente una pieza representativa del par de calzado de las referencias
Composition/framing: una sola pieza completa en perfil lateral ligeramente elevado; puntera hacia la izquierda; talón hacia la derecha; suela prácticamente horizontal; copiar únicamente la disposición de la guía neutra
Scene/backdrop: fondo croma completamente uniforme cuyo color no aparezca en el calzado
Lighting/mood: iluminación de estudio suave y neutra, sin sombras proyectadas
Constraints: conservar forma, proporciones, materiales, desgaste solicitado, colores, patrón, logotipos y texto demostrado por las referencias; mantener la pieza entera dentro del encuadre
Avoid: segunda pieza, pareja, vista cenital, vista frontal, puntera hacia la derecha, eje vertical, suelo, escena, cuerpo, pies, percha, maniquí, sombras, reflejos, degradados, halo croma, texto o marca inventados
```

Añadir al prompt los rasgos concretos de la prenda y cualquier corrección pedida
por el usuario. Si el usuario ha solicitado que parezca nueva o limpia, eliminar
solo suciedad y desgaste, sin alterar el diseño.

## Preparación y validación

Después de generar el render, ejecutar:

```text
python scripts/prepare_catalog_png.py render.png final.png --preset calzado-perfil --chroma "#FF00FF"
```

Usar el croma real escogido. El script retira únicamente el fondo conectado a
los bordes, limpia transparencia residual, centra el contenido y valida la
relación horizontal. Si rechaza la orientación, hacer una sola regeneración
dirigida con el mismo material de referencia. No rotar el archivo, porque eso
giraría también logotipos, texto y detalles.

Para una ficha existente, usar `set_wardrobe_item_image` con `item_id`, el PNG
final y un `request_id` estable. Si la herramienta no está disponible, usar
[`set_wardrobe_item_image.py`](../scripts/set_wardrobe_item_image.py), que llama
a la misma operación atómica.
