# Progreso y citas de los libros

El Kindle usa la zona `Atlantic/Canary`, con sus cambios de horario estacionales.
El reloj interno se conserva en UTC: corregir la zona no retrasa las marcas de
tiempo del progreso, las citas ni las estadísticas.

KOReader envía a Biblioteca el porcentaje, la página y el capítulo actual cuando
el índice del libro lo proporciona, además de los subrayados
de texto con su nota, capítulo, fecha y página o posición. No copia el archivo del
libro. Cuando el progreso vigente alcanza el 1 %, un libro pendiente pasa
automáticamente a «En curso», tanto con Todo abierto como con el agente en
segundo plano. No completa libros automáticamente ni cambia los ya completados.
Los envíos antiguos o repetidos no alteran el estado. La página
de un EPUB depende del tamaño de letra si no contiene un mapa de páginas de la
edición; la posición interna también se conserva.

En Todo, un libro completado tiene un progreso efectivo del 100 %, tanto en
Recientes como en su portada y ficha, incluidos los ya completados anteriormente.
El porcentaje y la posición recibidos del Kindle se conservan como datos de la
lectura: una sincronización posterior no reduce el progreso efectivo mientras
el libro siga completado. Al devolverlo a «En curso» se recupera ese avance.
Completar un libro no inventa sesiones ni aumenta sus estadísticas de lectura.
Cuando el documento contiene ese mapa se activa su numeración en KOReader y se
envían a Todo las mismas etiquetas para el avance y las citas, sin convertir el
porcentaje en páginas ni mezclar el total de otra edición. Los mapas sintéticos
por cantidad de caracteres no se presentan como páginas editoriales. Calibre
puede conservar un mapa, pero el número de páginas de su ficha no lo sustituye.
Los libros sin mapa mantienen sus pantallas identificadas como tales.

### Cotejo de páginas del Kindle actual (27/10/2026)

Se han contrastado los nueve títulos de «Mis libros», sus siete EPUB y dos MOBI,
además de los originales conservados. El motor instalado abre los nueve y solo
detecta un mapa de la edición en **El portal de los dioses ferales**, con etiquetas
de 1 a 669. La pantalla 140 abarca las páginas 86 y 87 de ese mapa. KOReader y
Todo muestran la última etiqueta visible, 87, manteniendo el 13 % recibido.
No se sustituye este total por las 592 páginas de otra ficha editorial.

No contienen mapa de páginas **Eisenhorn Omnibus**, **Hábitos atómicos**,
**Comerás flores**, **La Ilíada**, **Las galletas**, **Frankenstein**,
**La Odisea** y **El verano en que mi madre tuvo los ojos verdes**. Tampoco hay
archivos APNX en el dispositivo. Su numeración impresa necesita una fuente que
relacione los saltos de página de esa edición con el texto; Calibre no puede
reconstruirla a partir del total de páginas de la ficha. No se han modificado los
archivos de los libros para inventar esa relación.
La activación se ha comprobado de nuevo tras reiniciar KOReader: se conservan
el ajuste, la posición interna, el porcentaje y el dato 87/669. El agente del PC
ha confirmado el mismo dato en Todo. Las 16 copias de archivos de libros y sus
originales coinciden por SHA-256 con las anteriores al cambio; se han retirado
la caché y los temporales del cotejo del Kindle.

En el cotejo adicional de Eisenhorn se ha identificado el EPUB de Minotauro,
ISBN 9788445004357, y se han revisado sus documentos internos en busca de marcas
de página omitidas. No contiene etiquetas de página ni un mapa recuperable.
La [ficha editorial de la edición](https://www.planetadelibros.com/libro-warhammer-eisenhorn-omnibus/231275?soporte=242988)
indica 1088 páginas, pero ese total no proporciona los límites del texto en cada
página. La búsqueda no ha localizado un mapa completo compatible. El PDF de
muestra enlazado por la editorial devolvía HTTP 404 el 27/10/2026; tampoco se ha
encontrado un PDF de Eisenhorn en Calibre, Documentos ni Descargas del PC.
Para construir el mapa completo falta una referencia paginada de la misma
edición. Un fragmento solo permitiría mapear ese fragmento: no se debe instalar
como si cubriera todo el ómnibus ni extrapolar sus saltos al resto del libro.

El usuario ha aceptado una estimación para Eisenhorn. Se usa el mapa sintético
de caracteres de KOReader, calibrado tomando como referencia las 1088 páginas
de la ficha editorial. Es estable al cambiar la letra y no depende del número
de pantallas. Solo se activa en ese documento. La barra lo identifica con «≈»
y Todo muestra «Página», también en las citas, sin añadir «estimada», según la
preferencia del usuario. La unidad interna distingue la estimación del mapa de
la edición impresa. El porcentaje, la posición interna y el historial
de estadísticas se conservan con sus respectivas unidades originales.
En el Kindle actual la calibración usa 1992 caracteres por página y produce
1088 páginas. Se ha verificado la página 6 en el lector y en el estado confirmado
de Todo, así como la conservación del ajuste al reiniciar KOReader. El archivo
EPUB no se modifica. Las dos citas guardadas en Todo se conservan; las que envía
el documento actual reciben la unidad de su mapa sintético.

Todo distingue las pantallas de EPUB/MOBI de las páginas de documentos con
paginación fija. Nunca divide una pantalla del Kindle entre el total editorial
ni presenta ese número como una página impresa. El porcentaje recibido es la
referencia del avance. Los registros anteriores sin unidad explícita muestran
«Posición en KOReader» hasta que el lector vuelva a identificarlos.

El progreso manual se expresa en páginas de la edición y tiene su propio total.
Editar el total editorial no modifica la posición sincronizada. Las estadísticas
usan las páginas del mapa seleccionado, también para el ritmo. El récord de libro más largo solo usa
las páginas editoriales conocidas, sin sustituirlas por pantallas del Kindle.
El complemento añade `page_unit` (`screen`, `page` o `estimated_page`) al progreso y a cada cita;
Todo conserva la unidad con cada fuente de estadísticas. Al exportar un historial
nativo de pantallas, el complemento sitúa sus intervalos en el diseño actual
con el mismo reescalado de KOReader y cuenta las páginas del mapa que abarcan.
Reúne las partes de una misma página dentro de cada hora y conserva íntegros los
segundos. Los registros antiguos de otro tamaño de letra se reconstruyen por
posición relativa; no existe una posición interna exacta para cada lectura antigua.
La base nativa no se modifica. El siguiente envío reemplaza los contadores de la
misma fuente, sin duplicar el historial ni crear otra identidad.

Los pendientes presentes en el Kindle usan los mapas de la edición cuando los
incluyen. Si faltan, se prepara la misma paginación fija por caracteres aceptada
para Eisenhorn: 336 páginas para Hábitos atómicos, 744 para La mascarada del
carnicero y 544 para Proyecto Hail Mary. Son referencias para una estimación, no
saltos impresos recuperados. El ojo de la novia frenopática conserva su mapa
incluido de 971 páginas, aunque la ficha de otra edición indique 832. El progreso,
las citas y los contadores usan el mismo mapa; Todo muestra «Páginas leídas».

Referencias de los totales de calibración:
[Hábitos atómicos, Diana](https://www.planetadelibros.com/libro-habitos-atomicos/310441),
[La mascarada del carnicero, Nova](https://www.penguinrandomhouse.com/books/853245/la-mascarada-del-carnicero--the-butchers-masquerade-by-matt-dinniman/) y
[Proyecto Hail Mary, Nova](https://www.penguinrandomhouse.com/books/864412/proyecto-hail-mary-edicion-deluxe--project-hail-mary-by-andy-weir/).
No se han encontrado mapas compatibles para los tres archivos que carecen de
ellos. Estos totales son la referencia de la estimación y no identifican sus
posiciones como saltos impresos recuperados.

El 30/10/2026 se verificaron los seis libros que siguen en «Mis libros», incluidos
los cinco pendientes. Se conservaron los mapas de Carl 4 (669) y Carl 6 (971), y
se prepararon los cuatro mapas fijos restantes. Carl 4 se recontó inicialmente
de 421 pantallas a 251 páginas, conservando sus 14 537 segundos. La sincronización
reemplaza esa fuente; el estado, el porcentaje, las posiciones y las citas no se
reinician. Las fichas sin historial ya muestran «Páginas leídas» con valor cero.

## Estadísticas de lectura

Dentro de un libro, la barra muestra por defecto el porcentaje total, sin
la etiqueta «Libro». El toque sigue alternando páginas y tiempos; el porcentaje
no ocupa un paso separado del carrusel. El tiempo del capítulo conserva su
etiqueta para distinguirlo del tiempo restante del libro.
El carrusel incluye además un paso sin texto, que conserva únicamente la barra
del libro completo. El siguiente toque recupera el primer indicador. Este paso
no altera el interruptor del porcentaje y se conserva al reiniciar KOReader.
«Mostrar porcentaje del libro», en Ajustes → Barra de estado de KOReader,
permite ocultarlo y guarda la elección para los demás libros y reinicios.
Se ha comprobado en el Kindle el ciclo páginas → tiempo del libro → tiempo del
capítulo → páginas, conservando el mismo porcentaje y la posición de lectura.
Solo cambia `footer.lua`; sus copias de mantenimiento en Windows se actualizan
por hash, sin recompilar Flutter porque no cambia su código.

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

Si el progreso y los tiempos dejan de llegar, comprobar el envío persistente del
Kindle y la respuesta de `/v1/kindle/reading` antes de reiniciar o borrar datos.
Un HTTP 404 con «La operación Kindle no existe» indica un agente HTTPS antiguo;
actualizar únicamente el agente permite reintentar el mismo envío y conservar el
historial. La instalación de Windows debe compilar también el agente, aunque la
compilación Flutter ya exista, para no reinstalar un ejecutable antiguo.

El agente debe seguir sirviendo HTTPS si falla temporalmente la publicación de
su estado o el anuncio de red. Serializa las publicaciones del estado y registra
el último error operativo en `runtime_error.json`, sin incluir cuerpos de lectura
ni credenciales. Un archivo `status.json` antiguo no demuestra que siga activo:
hay que verificar el puerto y una petición real. El puerto es exclusivo de una
instancia; un segundo arranque termina sin sustituir la que ya está escuchando.
La tarea de Windows conserva el inicio de sesión y añade una comprobación de
arranque cada minuto, con instancias simultáneas bloqueadas y recuperación al
volver de la suspensión. Así no depende de abrir Ajustes ni de que sobreviva un
proceso iniciado manualmente. No se cambia la suspensión del Kindle.

El 02/11/2026 se encontró el agente detenido, con estado informativo del 31/10 y
resultado 255 en la tarea. No había registro del error exacto que lo cerró.
Se reprodujo y corrigió una excepción no tratada al publicar el estado, se
verificó la exclusión de instancias simultáneas y se probó la recuperación real
de Windows tras detener el proceso. Después, el Kindle obtuvo HTTP 200 con su
certificado fijado y confirmó toda la cola: Carl 4 al 98 % (651), Carl 5 al 10 %
(81) y Carl 6 en la página 4, conservando tiempos, páginas y citas.
El 30/10/2026 se comprobó ese fallo contra el servicio instalado: devolvía 404
con el agente del 23/10. Tras compilar, instalar y verificar el agente vigente,
el mismo envío obtuvo 200 y confirmación de guardado de la app. El Kindle reintentó
su cola y confirmó el dato más reciente: 41 %, página 274 y 14 121 segundos
acumulados, sin envíos pendientes. No se borró ni reinició el historial.

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

La pestaña «Citas» permite borrar cada cita desde su tarjeta, con confirmación.
Se retira de Todo y se guarda su identificador en `deletedQuoteIds` dentro de
la lectura del libro. Los envíos posteriores del Kindle, la edición del progreso
y la unión de fichas conservan esa decisión y no vuelven a importar esa cita.
El subrayado original del Kindle se conserva; esta acción no modifica el archivo
del libro ni sus anotaciones en KOReader. Los estados anteriores sin ese campo
siguen cargándose con la lista de borradas vacía.

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

En Biblioteca → Libros, el botón «Citas» junto a las estadísticas reúne las citas
de todos los libros, incluidos los pendientes, en curso y completados de cualquier
año. Muestra el texto completo y su nota, con el libro, autor, página y capítulo
disponibles; permite buscar por esos datos, editar, borrar con confirmación y
copiar cada cita con las mismas acciones de la ficha. Las notas personales se
distinguen en cursiva en ambas vistas. Esta vista consulta
las mismas citas de las fichas individuales y se actualiza con ellas, sin crear
otra copia ni modificar el progreso.

La instalación en el Kindle actual se ha verificado con su base nativa y un
envío real confirmado por el agente residente. Después se han retirado también
los tiempos de esa comprobación: la base del Kindle y las fuentes guardadas en
Todo quedan a cero. Las posiciones, las citas y los ajustes de los documentos
coinciden con los anteriores. La suspensión automática sigue habilitada.

## Cotejo de las bibliotecas

Antes de enviar libros desde Calibre, normalizar la ficha y los metadatos
incrustados del EPUB: título sin sufijos de tienda, autor en orden de lectura,
serie y número separados del título, idioma y datos de su edición real. Mantener
el orden invertido solo en el campo interno de ordenación por autor. No traducir
el título ni cambiar el idioma de una edición inglesa como Project Hail Mary.
Usar las herramientas de Calibre con un único escritor y comprobar que texto,
índice y mapas de páginas se conservan tras incrustar los metadatos.

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
