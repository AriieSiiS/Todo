# Revisión visual de los temas

Se revisan las secciones y pestañas que están visibles en la instalación actual
de Windows, sus fichas y los diálogos de uso habitual. La comprobación incluye
texto, iconos, fondos, selecciones, menús, formularios y desbordamientos.

La revisión solicitada el 30 de octubre de 2026 incluye capturas de la app real
en modo oscuro y comprobaciones del modo claro en los componentes corregidos.
Se conserva la configuración de visibilidad existente y se evitan cambios en
tareas, libros, compras, domótica y demás contenido durante la inspección.

Las referencias se toman a pantalla completa, con la app maximizada a
2048 × 1104. Se combinan capturas de Windows y renders completos de las mismas
vistas con las fuentes instaladas y una copia en memoria de los datos actuales,
incluidos sus menús y diálogos. El recorrido reproducible está en
`test/capturas/vistas_actuales_captura_test.dart`.

Las capturas y el registro de vistas inspeccionadas se guardan como resultados
locales de la revisión. Las correcciones se validan con pruebas centradas en los
problemas encontrados y con una nueva inspección de las pantallas afectadas.

En Hoy se retira la línea «Rutinas en pausa». Su acción se conserva como un
icono de la cabecera con descripción al pasar el cursor. La columna auxiliar
debe conservar un tamaño de texto legible y permitir desplazarse cuando sus
paneles no quepan en la altura disponible.

La agenda vacía debe mostrar su estado informativo sin lanzar una excepción.
Los contadores de la semana, los textos de Notas y los controles auxiliares
deben mantener contraste suficiente sin depender de un fondo claro fijo.

El espacio documental de Biblioteca y el selector de hora comparten los colores
del tema activo, incluidos el contenido editable, el árbol, las fichas y los
valores seleccionados. La inspección abarca también esas vistas secundarias.

El calendario debe avanzar por fechas civiles al generar meses y semanas:
los cambios de hora no pueden repetir u omitir días ni desplazar sus columnas.

Resultado del recorrido del 30 de octubre: 136 capturas completas (68 por tema)
sin excepciones ni desbordamientos registrados. Incluye Hoy, Notas, Proyectos,
Categorías, Calendario, Biblioteca, Ropa, Hogar, Completadas y Ajustes, con sus
pestañas y formularios principales. El Gemelo 3D se comprueba por separado en
la app nativa de Windows, sin accionar dispositivos.

Validación: 334 pruebas de Flutter superadas y análisis de `lib` y `test` sin
incidencias. Se retiran la línea visible de rutinas en pausa, el escalado de la
columna auxiliar de Hoy y la conversión de lista que rompía la agenda vacía;
se sustituyen fondos y colores fijos incompatibles con el tema oscuro. No se
eliminan archivos del producto ni datos del usuario.

La compilación de Windows se instala y verifica por SHA-256: 226 archivos
comprobados, incluido `kernel_blob.bin`. Tras instalarla se vuelven a comprobar
el calendario corregido y Completadas en la app real.
