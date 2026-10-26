# Progreso y citas de los libros

KOReader envía a Biblioteca el porcentaje, la página y el capítulo actual cuando
el índice del libro lo proporciona, además de los subrayados
de texto con su nota, capítulo, fecha y página o posición. No copia el archivo del
libro ni cambia su estado de pendiente, en curso o completado en Todo. La página
de un EPUB depende del tamaño de letra; la posición interna también se conserva.

## Estadísticas de lectura

Las fichas de los libros integran una tercera pestaña «Estadísticas», con tiempo
leído, páginas registradas, días de lectura, ritmo y actividad. Biblioteca ofrece
«Tu año de lectura» desde su cabecera: selector de año, tiempo, días, páginas,
libros terminados, actividad mensual y libros con más tiempo de lectura. Se usan
los colores, la tipografía y las dimensiones de las fichas actuales.

El Kindle envía las estadísticas junto al progreso usando el mismo transporte,
la cola persistente y la confirmación de TodoWorkspace. Cada fuente conserva una
identidad propia del historial y el identificador de libro de KOReader. Los
contadores acumulados sustituyen la versión anterior de esa fuente; no se suman
otra vez al reintentar. La identidad del historial se guarda en
`settings/todo/statistics.json`; los datos originales permanecen en la base nativa
`settings/statistics.sqlite3` del Kindle actual.
Las listas de periodos se codifican como listas JSON también cuando están vacías,
incluido el primer envío después de empezar las estadísticas desde cero.

Se conservan bloques horarios en UTC para sumar los tiempos en el día y año local,
incluidos los cambios de año. Las páginas dependen de la paginación de KOReader y
pueden incluir relecturas. No se inventan estadísticas para los libros antiguos
que solo tienen fecha de finalización. El estado y la valoración siguen siendo
independientes de la lectura automática.

El usuario ha confirmado que toda la actividad registrada antes de esta función
era de pruebas y autoriza empezar los tiempos desde cero. Se guarda antes una
copia verificable de la base de estadísticas y se eliminan exclusivamente esos
registros, incluidas las versiones técnicas repetidas; se conservan archivos,
posiciones, vínculos, citas y anotaciones. La comprobación final no añade tiempos
de prueba al historial nuevo.

El vínculo usa la huella del documento de KOReader. La primera vez se busca una
única ficha con el mismo título y autor. Si falta o hay dudas, en el menú de
KOReader se elige «Vincular libro con Todo» y la ficha correspondiente de
Biblioteca. No se crean fichas incompletas ni se mezclan libros por su nombre de
archivo. Un documento ya vinculado conserva su ficha aunque se renombre.
El complemento recalcula la huella del archivo al cargar sus ajustes y la valida
de nuevo antes de la primera captura. Así un cambio entre libros no hereda el
checksum de la lectura anterior ni envía sus citas a otra ficha.

El Kindle guarda los cambios antes de transmitirlos. Captura al cambiar de
página, subrayar, cerrar un libro y entrar en reposo. Durante la lectura espera
unos segundos de inactividad antes de sincronizar; al despertar o recuperar la
red reintenta. Al dormir intenta enviar durante un segundo como máximo; si no
alcanza a recibir la confirmación, conserva el envío hasta la siguiente conexión.
También se puede usar «Sincronizar lectura con Todo» en el menú.

Cada lote tiene un identificador y un cuerpo inmutables hasta recibir confirmación
de guardado de TodoWorkspace. Las citas se envían en lotes pequeños y se deduplican
por documento y posición. Las ediciones de notas se actualizan; borrar un
subrayado en KOReader no elimina la copia que ya llegó a Todo. Los envíos antiguos
no retroceden el progreso de una lectura más reciente; volver voluntariamente a
una página anterior sí actualiza el porcentaje. Los relojes deben estar en hora.

Biblioteca muestra el porcentaje en una insignia en la esquina superior derecha
de la portada, junto a la valoración y sin solapar el menú de acciones.
La ficha integra «Información», «Citas» y «Estadísticas» en la cabecera, junto al
título y la saga, sin repetir la etiqueta «Libro». La portada de la ficha también
muestra el porcentaje en una esquina, sin panel de progreso adicional.
Al pasar el cursor sobre el porcentaje se muestra la página actual con el total
de esa paginación, por ejemplo «Página 36 de 1300», y el capítulo cuando está
disponible. Los datos antiguos sin capítulo siguen siendo compatibles; se recibe
en una nueva sincronización desde el complemento actualizado.
La pestaña «Citas» reúne los pasajes recibidos en tarjetas de lectura, con su página,
capítulo y nota cuando existen. No se muestran fechas ni posiciones técnicas.
Los datos de sincronización se conservan internamente. Las citas se conservan al reiniciar Todo, en las copias
completas de Todo. El complemento se mantiene en `kindle/todo.koplugin` y se
actualiza en el Kindle actual conservando sus credenciales y su cola.
Esta integración informa a Todo: no mueve la
posición de lectura de otro lector ni descarga libros desde Todo.

La instalación en el Kindle actual se ha verificado con su base nativa y un
envío real confirmado por el agente residente. Después se han retirado también
los tiempos de esa comprobación: la base del Kindle y las fuentes guardadas en
Todo quedan a cero. Las posiciones, las citas y los ajustes de los documentos
coinciden con los anteriores. La suspensión automática sigue habilitada.

## Cotejo de las bibliotecas

Al incorporar los libros de un Kindle se contrastan antes sus títulos, autores,
ediciones y vínculos con las fichas existentes, incluidas las ya completadas.
Un EPUB y un MOBI de la misma obra se enlazan con una sola ficha; no se crea otra
por su formato o por un sufijo editorial. Los libros nuevos reciben los metadatos,
portada y enlace de Goodreads verificados. La presencia de un archivo no implica
que esté leído: se respeta el estado existente y los nuevos sin lectura registrada
quedan pendientes.

Las correcciones de título y autor se trasladan a Calibre y a los metadatos del
archivo, conservando el texto, índice, posición y anotaciones. Si cambia la huella
del documento se enlaza con la misma ficha y se conservan sus citas. Las escrituras
de lectura se realizan mediante TodoWorkspace; la creación de fichas por MCP se
efectúa con Todo cerrado para evitar dos escritores.
