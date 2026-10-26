# Registro de instalación del Kindle actual

La instalación y el traslado ya han terminado. Este documento conserva el
diagnóstico de la puesta en marcha; el mantenimiento vigente se describe en
`KINDLE.md` y la sincronización en `KINDLE_LECTURA.md`. Se han retirado el paquete
de traslado, su generador, el perfil reutilizable y las descargas de preparación.
La configuración ya aplicada, los componentes activos y las copias de los datos
del usuario permanecen en sus ubicaciones de mantenimiento.

## Identificación del 25 de octubre de 2026

- Modelo: Kindle básico de 11.ª generación, edición de 2024; KT6 / Rossini.
- Identificador de modelo: `3L2`, confirmado con los datos del selector oficial.
- Firmware leído por USB: `5.17.1.0.4`.
- Conexión: MTP, sin letra de unidad de Windows.
- Estado inicial: sin jailbreak ni KOReader.
- Método recomendado por el selector oficial consultado: SpiderCat.

El archivo oficial `spidercat.azw3` se ha comprobado contra las dos copias
publicadas por KindleModding y se ha vuelto a leer desde `documents` después
de copiarlo. Su SHA-256 es
`3e2e39221cae9e44385d4069aa57a1d5e539b176f831f24e740b158daa72294b`.
Esta comprobación acredita la copia del archivo, no la ejecución del jailbreak.

No se traslada la identidad, la credencial de Todo ni las claves SSH del Kindle
de pruebas. El arranque incorpora una comprobación explícita de su firmware y
del hash nativo obtenido por SSH; la validación física sigue siendo necesaria.

## Estado comprobado

Se copiaron y comprobaron 11 archivos temporales propios. El espacio libre
previo al jailbreak fue de 85.938.176 bytes, dentro del margen de la guía oficial.
Tras abrir SpiderCat y reiniciar, `documents/JAILBROKEN.txt` confirma `jb.sh
v2.2.1` y `privesc_marker.txt` registra `uid=0 euid=0`. El propio jailbreak retiró
los archivos de relleno; se comprobó que la carpeta estaba vacía y se eliminó.

Los primeros intentos desde la biblioteca y desde `;log runme` fallaron. El
diagnóstico por SSH confirmó que faltaba todo `kindlehf/bin` de KMC, aunque
estaban sus bibliotecas y el trabajo de arranque. Se guardó la instalación previa
en `%LOCALAPPDATA%\Todo\kindle_nuevo\copias\kmc-antes.tar.gz` y se restauró
únicamente ese directorio desde la misma versión oficial `jb.sh v2.2.1`. No se
ejecutó la versión más reciente del instalador. KPM 0.2.2 y `su -c id` funcionan.
Las marcas de depuración y ejecución están presentes y los binarios nativos de
actualización están renombrados por el jailbreak.

El acceso SSH usa claves propias, autenticación por clave y comprobación estricta
del servidor. Su identidad se comparó con la clave leída directamente por USB.
Los archivos del PC están en `%LOCALAPPDATA%\Todo\kindle_ssh\definitivo`. El
repositorio no contiene claves ni la credencial de Todo.
En este dispositivo conectar el USB corta el acceso por Wi-Fi: para trabajar por
SSH hay que dejarlo desconectado, despierto y con Wi-Fi.

KPM ha instalado su paquete KOReader 2026.7.2; el lector se identifica como
v2026.07.1 en su registro. Se copiaron y verificaron los 16 archivos
propios del complemento, el perfil y su configuración. El perfil de revisión 2
está aplicado, KOReader está en español y Todo dispone de una credencial propia.
La consulta HTTPS está autenticada y ha descargado la agenda semanal; la pantalla
de Todo muestra las tareas y subtareas reales. «Mis libros» abre la colección con
los nueve libros legibles y sus portadas; el botón «Todo» permite regresar.

El arranque está instalado y sus seis archivos finales se comprobaron por hash.
Se ha abierto Todo mediante ese lanzador y se ha confirmado que `lab126_gui`,
`framework` y `kppmainapp` están detenidos y la raíz sigue en solo lectura. La
copia previa del instalador está en
`%LOCALAPPDATA%\Todo\kindle_backups\arranque-20261025-074001`.
La suspensión pasa a `screenSaver`, muestra Todo sin reloj y vuelve a despertar;
`preventScreenSaver` se mantiene en 0.

## Revisión de libros y sincronización

La revisión de lectura detectó seis AZW3/KF8 sin lector registrado en KOReader.
Los originales están intactos y sin cifrado. Se han identificado sus EPUB de
Calibre por el identificador de la edición y se han añadido, junto al Eisenhorn
con índice corregido, conservando todos los originales. La colección se ajusta
al registro real de lectores y prefiere EPUB a MOBI/AZW del mismo nombre base.
La carga y composición del texto de los nueve libros ha pasado en el motor del
propio Kindle; Eisenhorn devuelve 82 entradas de índice.

La prueba de recuperación abrió el inicio nativo, pero mostró un error al pedir
el antiguo URI `app://com.lab126.booklet.home`. El registro de Amazon indica
expresamente que el inicio KPP usa `app://com.lab126.KPPMainApp?view=KPP_HOME`.
El lanzador emplea ese URI después de esperar el servicio `kppmainapp`.
Antes de detener la interfaz se pide a `appmgrd` el cierre de su aplicación KPP;
de lo contrario el gestor puede conservar un aviso de salida anormal para la
próxima recuperación.
La comprobación final abrió el inicio original y permitió cerrar el aviso que
había quedado de las pruebas anteriores mediante el control nativo de toques.
El bloqueo temporal de toques se restauró al terminar. Se vuelve a dejar Todo
abierto y el inicio automático habilitado.

La prueba de citas al cambiar de un EPUB nuevo a otro detectó un checksum
heredado del libro anterior en KOReader. El complemento calcula la huella del
archivo actual en `DocSettingsLoad` y la valida en `ReaderReady` antes de capturar
la lectura. La cita de prueba quedó asociada temporalmente a «Comerás flores»;
se corrigió su lectura mediante `TodoWorkspace`, con la app cerrada y una
comprobación que rechazaba cambios ajenos a esa ficha y a los metadatos del
guardado. La consulta al puente de Todo confirma que conserva su página 1 de 225
y ninguna cita de Eisenhorn.

Eisenhorn sincroniza con la identidad correcta del EPUB: página 9 de 1912,
capítulo «Introducción», y una nueva cita subrayada desde la pantalla del Kindle.
La cita antigua también permanece en su ficha de Todo. El Kindle confirma el
guardado y no conserva ningún envío pendiente. La copia privada de documentos
está en `%LOCALAPPDATA%\Todo\kindle_nuevo\copias\documentos-antes-revision.tar.gz`;
las copias del estado de Todo previas a la corrección están en el mismo directorio.

Por petición del usuario se prioriza dejar el dispositivo utilizable antes de
agotar el uso de Codex. El reinicio completo ha terminado: el trabajo de arranque
ha abierto KOReader, el SSH normal vuelve a responder con la identidad emparejada
y los tres servicios de la interfaz nativa siguen detenidos. Se ha capturado el
salvapantallas de Todo con la agenda actualizada después de ese reinicio. Se han
probado la apertura de «Comerás flores», el índice y los subrayados de Eisenhorn,
la vuelta a la biblioteca y el guardado en Todo. La revisión física de la tinta
electrónica corresponde al usuario: una captura remota no prueba por sí sola su
refresco. Los originales del Kindle permanecen junto a las copias EPUB.

El mantenimiento ya debe usar el SSH normal de KOReader en el puerto 2222 y su
SFTP `/mnt/us/koreader/sftp-server`. Dirección comprobada: `192.168.1.55`; puede
cambiar por DHCP. Para Windows OpenSSH es necesario
`KexAlgorithms=curve25519-sha256`; no desactivar la comprobación del servidor.
El auxiliar `.codex_tmp/run_new_kindle_remote.py` utiliza la identidad del destino.
El SFTP temporal ya no se utiliza. Se retiraron `/mnt/us/todo-mantenimiento`,
`/mnt/us/system/todo-preparacion`, SpiderCat, el instalador fallido, la entrada de
emergencia ejecutada y los cinco volcados nativos de diagnóstico creados en esta
preparación. No se eliminaron libros del usuario, anotaciones ni código de la app.
El auxiliar puntual de reparación de datos se retiró después de comprobar el
resultado. Todo y el agente de red vuelven a ejecutarse en Windows, con una sola
instancia de cada uno y sin cambios en sus ejecutables.

La limpieza final incluye `JAILBROKEN.txt`, `privesc_marker.txt`, las cinco
carpetas auxiliares de esos marcadores y los volcados, la preparación del arranque
y sus tres copias de instalación anteriores. Se retira también el volcado
comprimido de `system/logbackup` generado durante esta preparación. Los registros
activos `crash.log` y `arranque.log` se vacían, sin retirar los archivos abiertos;
pueden volver a recibir mensajes al usar o reiniciar el lector. Se comprueban las
huellas de los libros, sus anotaciones y los componentes activos antes y después.
`version.log` se conserva porque identifica la versión instalada de KOReader.

## Conexión con Calibre por Wi-Fi

Se utiliza el complemento oficial de Calibre de KOReader y la opción de Calibre
«Conectar y compartir → Iniciar conexión con dispositivo inalámbrico». Ambos
dispositivos deben estar en la misma red y Calibre debe permanecer abierto.
La carpeta de recepción del Kindle es `/mnt/us/documents`; se prioriza EPUB para
que los libros enviados puedan abrirse con el lector instalado. En KOReader,
«Calibre → Conectar» establece la conexión y «Desconectar» la termina. La
suspensión también la interrumpe; al volver a usarla hay que conectar de nuevo.
La dirección del PC pertenece a la configuración privada de cada instalación;
no se incluyen contraseñas ni direcciones propias en las fuentes del repositorio.
No se envía la biblioteca completa automáticamente por establecer la conexión.
Calibre 8.4.0 está iniciado con el puerto fijo 9090 y la recepción habilitada al
abrir Calibre. La selección de carpeta se hizo desde la interfaz del Kindle;
EPUB es el formato predeterminado del complemento instalado. La prueba de acceso
TCP desde el Kindle funciona después de que el usuario haya aceptado el aviso
del Firewall de Windows. Se ha conectado mediante descubrimiento automático:
KOReader registra la conexión establecida y Calibre muestra «Conectado
Dispositivo inalámbrico: KOReader (KindleBasic5)», junto con «Enviar al dispositivo».
Esta comprobación valida la conexión; no se ha enviado ningún libro nuevo.

Referencia: [guía oficial de Calibre en KOReader](https://github.com/koreader/koreader/wiki/calibre).

## Regreso a Todo desde el menú superior

El bloqueo comunicado después de conectar Calibre dejó un error explícito:
el acceso superior a Todo llamaba a `onTapCloseMenu` en el menú del explorador,
que dispone de `onCloseFileManagerMenu`. KOReader terminó y el lanzador recuperó
la interfaz original; la última imagen del lector quedó detrás del aviso nativo.
El regreso a Todo y la recuperación del sistema deben usar el cierre propio de
cada contexto, conservando la espera de repintado antes de abrir las tareas.
Las pruebas del acceso deben cubrir tanto el explorador como un libro abierto,
sin añadir al explorador métodos exclusivos del lector en las simulaciones.
Se comprobó primero que esa prueba fallaba con el mismo error y después que
pasaban las pruebas Lua. Se instalaron únicamente `main.lua` y `navigation.lua`,
verificando su sintaxis en el Kindle y sus huellas. Después de recuperar el
lector, el icono superior abrió Todo desde el explorador y desde «Comerás flores»;
el proceso siguió vivo y la agenda se actualizó. La colección mantiene nueve
libros. Se restableció Calibre y se repitió el regreso a Todo con la conexión
activa; el panel respondió al cambio a Semana y la conexión siguió establecida.
Las pruebas Lua y las seis pruebas del paquete pasan. Esta comprobación remota
no sustituye la revisión física del refresco.
No se eliminan libros, datos ni módulos de KOReader; se sustituye la llamada
incorrecta por el cierre común que distingue lectura y explorador. El cambio
se conserva en el complemento instalado y no modificó la aplicación Windows.
Se retiran del PC los cuatro auxiliares puntuales de inspección, instalación y
verificación usados para esta corrección; no se han creado instaladores ni
volcados de diagnóstico nuevos en el almacenamiento del Kindle.

## Restauración de la barra de lectura

Al revisar la pérdida de los ajustes anteriores, el carrusel conservaba página,
porcentaje y tiempos, sin hora, batería ni páginas restantes. El formato de
duración estaba guardado como «Clásico». La revisión 3 del perfil restaura el
formato «Letras» y mantiene los indicadores solicitados. Esos ajustes permanecen
guardados en el Kindle actual, una vez retirado el perfil de traslado.

Se instaló únicamente el JSON del perfil, verificando su hash, y se reinició
KOReader desde su menú. Se comprobó el tiempo en letras dentro del libro y, tras
otro reinicio normal, la revisión 3 y todos los indicadores guardados. El formato
nativo muestra «8m» para ocho minutos y «7h 53m» para horas y minutos. El libro
conservó su posición; no se cambió el contenido ni se actualizaron componentes.
Pasan las pruebas Lua del complemento y las del paquete. Se retiran los
auxiliares puntuales y las capturas de esta comprobación; no se recompila Windows
porque solo se han actualizado las preferencias del Kindle y su documentación.

## Diseño y coherencia de la barra y sus indicadores

La revisión 5 sustituye la barra lateral corta por una barra continua sobre el
texto, que ocupa todo el ancho disponible entre los márgenes. El relleno oscuro
avanza sobre un fondo gris claro; se eliminan las marcas del índice que, en libros
con muchos capítulos, parecían puntos. Los datos siguen debajo, centrados y sin
cambiar el formato de las duraciones. Las vistas del libro comparten escala y
longitud; la del capítulo conserva su escala propia con esa misma longitud.

La restauración anterior no resolvía la mezcla entre la barra del capítulo y los
datos del libro. Además, su longitud variaba según el texto mostrado. La revisión
4 fija la longitud y comienza en las páginas del libro. El módulo `footer.lua`
conecta con la barra de `ReaderView`, añade «Libro» o «Capítulo» y selecciona la
escala correspondiente en cada actualización. Conserva los cálculos y el formato
de tiempo nativos; no cambia la posición ni el texto del libro.

La revisión 5 se comprobó con capturas reales de las cuatro vistas: la barra
ocupa 1036 de los 1072 píxeles de ancho, con 18 píxeles de margen a cada lado y sin
marcas intermedias. Páginas, porcentaje y tiempo del libro comparten exactamente
la barra; el tiempo del capítulo cambia solo el relleno. El texto de la página
permanece idéntico al recorrer el carrusel. Los ajustes instalados quedaron
verificados por SHA-256 en esa revisión. Al reservar una segunda línea para el dato,
KOReader recalcula la paginación del EPUB conservando su posición de lectura.
Las capturas de revisión están en `output/kindle/capturas-barras/`.

Se comprobaron las cuatro vistas en el Kindle: páginas, porcentaje y tiempo del
libro tienen barras idénticas en las capturas; el tiempo del capítulo muestra su
propia escala con la misma longitud. El texto de lectura permanece idéntico en
las cuatro capturas. Se reinició KOReader normalmente y se volvió a abrir el libro,
confirmando el indicador guardado, su etiqueta y la escala. Esta comprobación
del framebuffer no acredita por sí sola el refresco físico de la tinta electrónica.
Las pruebas Lua cubren también el libro sin capítulos y la conexión real con
`ReaderView`; pasan junto con las seis pruebas del paquete. Se retiran los
auxiliares de instalación, inspección y comparación y sus capturas. No se eliminan
módulos nativos ni datos del Kindle. No se compila Windows, cuyo código no cambia.

## Biblioteca cotejada y segunda vista de portadas

Se cotejaron nueve obras del Kindle con Todo y Calibre. Se conservaron las cinco
fichas existentes y se añadieron cuatro pendientes con portada, metadatos y
enlace verificado: «La Ilíada», «Las galletas», «Hábitos atómicos» y «El verano en
que mi madre tuvo los ojos verdes». La Biblioteca de Todo pasó de 28 a 32 libros.
El EPUB y el MOBI de Eisenhorn comparten ficha. También se mantiene el vínculo
histórico de Carl después de cambiar la huella de sus metadatos.

Calibre conserva sus identificadores y corrige el título de Carl a «El portal de
los dioses ferales» y el autor a «Matt Dinniman», incluyendo los metadatos de sus
formatos. «Las galletas» queda normalizado también. En el Kindle solo se modifica
el OPF de los dos EPUB afectados: se verificó que el resto de sus archivos internos
permanecía idéntico. Sus posiciones y anotaciones se conservan; Carl vuelve a abrir
en la página 58 de 1083, capítulo 2, con un 5,36 % de lectura. No se renombran sus
rutas ni se sustituyen los formatos originales de recuperación.

La cola del complemento recibió los vínculos inequívocos y envió las lecturas
mediante el agente HTTPS y TodoWorkspace. Todos los documentos quedaron
confirmados, sin lotes ni vínculos pendientes. Se contrastaron las nueve fichas
tanto con Todo abierto como con su snapshot guardado; sus estados y citas previas
permanecen intactos. Las altas por MCP se hicieron con Todo cerrado y después se
recuperó su instancia residente. La copia preventiva del snapshot está en la
carpeta de copias de Todo; las de los metadatos afectados se guardan en el directorio
privado de mantenimiento del PC.

`covergrid.lua` adapta el mosaico nativo para mostrar cuatro portadas grandes,
con porcentaje en la esquina y orden por el historial real de lectura. No usa
las fechas de acceso de los archivos. El porcentaje también es correcto mientras
se carga una portada nueva. «Lista» y «Portadas», arriba a la izquierda, alternan
las vistas; la pulsación larga conserva el menú de colección. Todo sigue siendo
el inicio y mantiene su acceso superior. Se comprobaron las tres páginas de la
cuadrícula, la alternancia, la apertura de libros, la vuelta a Todo y la selección
persistente después de reiniciar KOReader. Las capturas verifican el framebuffer;
no sustituyen la revisión física del refresco de tinta electrónica.

Pasaron las pruebas Lua y las seis pruebas del paquete usado entonces. Se retiraron
los auxiliares, capturas y archivos de preparación de este cotejo. No se compila
Windows porque su código no ha cambiado.

Fichas utilizadas: [La Ilíada](https://www.goodreads.com/book/show/16147035-la-il-ada),
[Las galletas](https://www.goodreads.com/book/show/247134755-las-galletas),
[Hábitos atómicos](https://www.goodreads.com/book/show/51277830-habitos-atomicos) y
[El verano en que mi madre tuvo los ojos verdes](https://www.goodreads.com/book/show/61099953-el-verano-en-que-mi-madre-tuvo-los-ojos-verdes).

## Limpieza del inicio original

El traslado había omitido la limpieza comercial porque solo estaba preparada
para el firmware del Kindle de pruebas. El destino requiere su propia copia
de 5.17.1.0.4. Se ocultan las doce plantillas promocionales y la rama del carrito
de su barra superior, conservando biblioteca, búsqueda y ajustes. El original
sigue intacto y se utiliza un montaje de la copia verificada. El lanzador aplica
la limpieza validada antes de recuperar Amazon al salir del lector, también
después de reiniciar el dispositivo. La desactivación sigue siendo independiente
del inicio de Todo.
La copia del destino se generó y verificó con SHA-256
`db7ceae850d1159c0ffdac4cc8c7e8113daa71c151acb3888dd676da9b7cf23f`:
13 funciones modificadas de 16 314 y ninguna cadena alterada. La receta del
Kindle anterior sigue generando exactamente su hash previo. Se salió del lector
normalmente, se abrió el inicio sin carrito ni filas promocionales y se comprobó
que Biblioteca respondía. Se cerró el aviso nativo que había quedado durante la
recuperación, se marcó esta copia como validada y se volvió a abrir KOReader.
La raíz permanece en solo lectura y no se ha sustituido su archivo original.
Pasan 47 pruebas de activación, restauración, arranque, compatibilidad y paquete.
No se repite un reinicio completo: la reaplicación se cubre mediante el lanzador
y sus pruebas; la comprobación de la tinta electrónica corresponde al usuario.
Se han retirado los diez auxiliares temporales del PC usados para esta adaptación;
en el Kindle solo quedan los tres archivos de la limpieza y su marca de validación.
No se eliminan módulos activos ni contenido de la biblioteca.

Comprobaciones locales finales: las pruebas Lua del complemento y 25 pruebas de
compatibilidad, arranque y paquete superadas; la corrección puntual mediante
`TodoWorkspace` también se ejecutó y verificó con Flutter. El ZIP utilizado en
esa instalación quedó verificado y se ha eliminado al cerrar el traslado.
No se recompiló la app Windows entonces porque no se había
modificado su código en este tramo; la revisión visual de esa app queda al usuario.

Fuentes: [selector oficial](https://kindlemodding.org/jailbreak-wizard.html),
[SpiderCat](https://kindlemodding.org/jailbreaking/SpiderCat/),
[protección de actualizaciones](https://kindlemodding.org/jailbreaking/prevent-auto-update/)
y [pasos posteriores](https://kindlemodding.org/jailbreaking/whats-next/).
