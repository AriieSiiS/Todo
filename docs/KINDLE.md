# Todo en KOReader

La extensión `kindle/todo.koplugin` muestra Hoy y una agenda de siete días en
KOReader. El dispositivo actual es el Kindle básico KT6 (2024), con firmware
5.17.1.0.4, SpiderCat y KOReader instalado mediante KPM.

## Mantenimiento del Kindle actual

La fuente del complemento está en `kindle/todo.koplugin`; se mantienen sus pruebas,
las herramientas de actualización y la recuperación del arranque y del inicio
original. Se conservan las credenciales, el emparejamiento SSH, los ajustes, la
agenda y las marcas del dispositivo. Se han retirado el ZIP, la guía y el perfil
de traslado porque el Kindle definitivo ya está en uso.

## Conexión en segundo plano

La [sincronización de lectura](KINDLE_LECTURA.md) añade el porcentaje y las citas
de KOReader a las fichas de Biblioteca, con cola sin conexión y vínculo por libro.

El Kindle utiliza el agente HTTPS local de Todo, en el puerto 47832. Su perfil
solo permite consultar `/v1/kindle/agenda` y el catálogo mínimo `/v1/kindle/books`,
enviar marcas a `/v1/kindle/completions` y lecturas a `/v1/kindle/reading`;
no permite descargar Ropa ni utilizar herramientas
arbitrarias. Los perfiles Android anteriores conservan sus permisos de lectura.
El certificado del PC se copia por USB y se comprueba antes de enviar la
credencial. No se utilizan Supabase, servicios públicos ni redirecciones HTTP.

El firewall permite únicamente TCP 47832 y el descubrimiento mDNS por UDP 5353,
en redes privadas y desde la subred local. Si Windows deniega este ajuste por
falta de permisos, ejecutar una vez `limitar_red_todo.ps1` desde PowerShell como
administrador en el directorio de instalación. El script crea reglas limitadas
y desactiva las reglas antiguas del mismo ejecutable; no modifica otros
programas. La copia USB no acredita que ese ajuste administrativo se haya hecho.

Con la ventana abierta, las operaciones llegan al puente local y las ejecuta
`TodoWorkspace`. Al cerrar Todo se guardan los cambios y termina la interfaz.
El agente ligero continúa atendiendo al Kindle sin cargar Flutter cuando está
activada «Conexión Kindle con Todo cerrado». El inicio de sesión solo arranca
el agente; no abre Todo oculto ni conserva su icono en la bandeja.

La agenda, las marcas de tareas, el progreso y las citas comparten la misma
lógica entre la app y el agente. Un bloqueo exclusivo protege el escritor:
la app lo adquiere antes de cargar los datos y el agente solo modifica el
snapshot si la app ya lo ha liberado. Cada operación vuelve a leer el estado
actual y conserva los demás apartados y los recibos de idempotencia. Una
transición en curso devuelve un error reintentable, sin confirmar un guardado
que no haya terminado. Las lecturas no reescriben el snapshot.
El archivo `todo_state.json.lock` también coordina las escrituras del MCP local.
La compilación corrige además la liberación tardía del compositor del WebView,
que provocaba un fallo nativo al salir. La corrección se aplica a una copia de
compilación y no modifica la caché compartida de dependencias.

## Contrato de agenda y marcas

`GET /v1/kindle/agenda?start_date=AAAA-MM-DD` devuelve siete días. Sin fecha,
empieza en el día lógico actual. Incluye fecha lógica, hora del servidor,
desfase horario, ajustes de día, tareas y subtareas, con una versión por familia
y fecha. Reutiliza el orden y las reglas de fechas de Todo.

`POST /v1/kindle/completions` envía un grupo con `request_id`, `root_task_id`,
`occurrence_date`, `expected_version` y `task_ids`. Una familia de tareas y una
fecha forman un grupo: todas sus versiones se comprueban antes de modificar
nada. El resultado y el recibo se guardan juntos. Reintentar exige exactamente
el mismo identificador y cuerpo, incluso después de perder la respuesta.

Las marcas solo se crean desde Hoy. Sin conexión, la agenda y la cola se
guardan atómicamente en el Kindle y se indica «Pendiente de enviar». Se pueden
cancelar las marcas que aún no se hayan enviado. Al cambiar de día sin una
agenda actualizada, se bloquean nuevas marcas y se conservan las anteriores.
Las rutinas pendientes conservan siempre su fecha original. Una ocurrencia ya
completada se considera resuelta. Los cambios de versión, omisiones, archivos o
borrados requieren revisión; nunca se fuerza una sobrescritura. La revisión
permite descartar la marca o volver a confirmar con la versión recién leída.

El reloj se actualiza cada minuto y la agenda cada cinco minutos mientras el
panel esté abierto. Al suspender se cancelan los temporizadores; al despertar se
actualiza. No se evita la suspensión ni se mantiene el Wi-Fi encendido.

Las peticiones HTTPS se ejecutan en un proceso auxiliar de KOReader. Un toque
interrumpe la espera y se atiende con normalidad: abrir KOReader o «Mis libros»
no depende de que el PC responda. Cerrar el panel o suspender cancela la petición
pendiente. La agenda y la cola solo las guarda el proceso principal. Si una marca
pudo llegar al PC antes de interrumpirse, se conserva su cuerpo sellado y se
reintenta con el mismo identificador; cancelar la espera no descarta la marca.

## Todo como salvapantallas

Con KOReader abierto, al pulsar el botón de encendido para dejar el Kindle en
reposo se muestra una vista fija de Hoy, aunque se estuviera leyendo o
consultando otra semana. Incluye fecha, batería, tareas, marcas pendientes y
la hora de la última descarga. Las subtareas aparecen directamente debajo de
su tarea, con sangría y su estado de completado. Las prioridades se conservan
en Todo, pero no se muestran en el Kindle, tampoco en los detalles.
La sangría desplaza también la casilla de cada subtarea, tanto en el panel
interactivo como en el salvapantallas, y aumenta para sus descendientes.

La cabecera en reposo centra Todo y la fecha, con la batería a la derecha,
sin mostrar un reloj que pueda confundirse con la hora actual. La lista utiliza la altura disponible y ajusta
el tamaño y la separación de las filas al contenido. El pie queda al borde
inferior y muestra únicamente la actualización y las marcas pendientes cuando
las haya. Se retira el mensaje explicativo de reposo. Si hay más tareas y
subtareas de las que caben, se indica cuántas quedan. Los datos permanecen
congelados durante el reposo; «Actualizado…» identifica la hora de su descarga.

La vista interactiva conserva el reloj y la jerarquía de subtareas; permite
marcarlas desde Hoy sin abrir sus detalles. Las listas largas se paginan y una
subtarea que continúa en otra página conserva la referencia a su tarea principal.
Los controles inferiores permanecen junto al borde inferior.

## Pantalla inicial

### Arranque del Kindle y recuperación

El arranque automático abre KOReader y después Hoy de Todo. KOReader utiliza
`--framework_stop` para detener la interfaz de Amazon durante la sesión; conserva
los servicios del sistema necesarios para la energía y la conexión. «Mis libros»,
las portadas, los accesos a Todo y el salvapantallas conservan su funcionamiento.

Una tarea independiente de Upstart espera a que arranque la interfaz nativa y deja
30 segundos para conectar el USB o desactivar el inicio. Solo intenta abrir
KOReader una vez por arranque; no lo relanza al salir ni si falla. La instalación
no sustituye el firmware ni los trabajos originales de Amazon.

«Volver al sistema Kindle», en Más herramientas de KOReader, guarda los ajustes,
desactiva el siguiente inicio automático y cierra KOReader para recuperar la
interfaz original. La recuperación puede tardar alrededor de un minuto mientras
arrancan sus servicios. El lanzador espera y abre el inicio de Amazon,
para no dejar visible la última imagen del libro. «Inicio automático de KOReader»
permite habilitarlo otra vez.
También se puede omitir el arranque creando un archivo o carpeta llamado
`DESACTIVAR_INICIO_TODO` en la raíz USB del Kindle. Retirarlo vuelve a permitir el
inicio automático. Al conectar el USB durante la espera se conserva el sistema
original para poder transferir archivos y recuperar la instalación.

Los programas de arranque viven en `/mnt/us/system/todo-koreader` y el único trabajo
nuevo del sistema es `/etc/upstart/todo-koreader.conf`. El lanzador de KPM se
respalda antes de adaptarlo. Salir de KOReader recupera la interfaz de Amazon;
el sistema de lectura no se elimina. La limpieza comercial anterior queda
separada del arranque y no se necesita para usar Todo o leer sin esa interfaz.

La primera instalación por SSH se ejecuta con
`python tooling/install_kindle_boot.py --host DIRECCIÓN_IP`. Exige la clave y el
servidor ya emparejados, KOReader cerrado, el firmware comprobado y ausencia de
otro trabajo con el mismo nombre. Guarda una copia verificada en
`%LOCALAPPDATA%\Todo\kindle_backups`, comprueba los hashes transferidos e instalados
y devuelve la raíz del sistema a solo lectura. `python tooling/test_kindle_boot.py`
comprueba el arranque y la recuperación con servicios simulados.

Al arrancar KOReader se abre automáticamente Hoy de Todo, mostrando primero la
agenda guardada y actualizándola si hay conexión. «Mis libros» abre directamente
una biblioteca de KOReader con portadas pequeñas, título, autor y el progreso
registrado por KOReader, sin recorrer las carpetas. Si Todo se ha abierto sobre
un libro, también aparece «Seguir leyendo» para recuperar esa lectura. Abrir
otro libro durante esa sesión no vuelve a superponer Todo.
El botón «KOReader», cuando no hay un libro abierto, permite acceder también al
explorador y a sus menús habituales.

En el explorador, el icono de la casa abre «Mis libros» en vez de la carpeta
«Inicio». El botón «Todo», arriba a la derecha del explorador y de la biblioteca,
recupera las tareas. En el explorador, mantenerlo pulsado conserva el menú de
añadir y seleccionar archivos. El menú superior de lectura incluye también un
acceso directo a Todo con el icono de una marca de verificación. Los accesos se
añaden desde el complemento; no se modifican los archivos internos de KOReader.

La biblioteca reúne los archivos de libros de `documents` y sus subcarpetas en
la colección «Mis libros», sin moverlos ni modificar su contenido. Excluye los
diccionarios y los archivos auxiliares. Al abrirla incorpora libros nuevos y
conserva las demás colecciones. La primera apertura configura la lista con
portadas y siete filas por página; después respeta los ajustes elegidos en
KOReader. Cerrar la biblioteca vuelve a Todo; tocar un libro abre su lectura.

El porcentaje corresponde a la lectura en KOReader. Las posiciones guardadas
por el lector de Amazon no se importan automáticamente. Un libro sin progreso
en KOReader conserva ese estado; no se inventa un porcentaje.

El idioma general de KOReader se configura en español, además de los textos
propios de Todo. La biblioteca, los menús y los mensajes de progreso utilizan
las traducciones incluidas en KOReader. Cambiar el idioma requiere reiniciar
KOReader y conserva los libros, sus posiciones y Todo como pantalla inicial.

La opción «Todo al iniciar», en Más herramientas, permite recuperar el inicio
habitual de KOReader; el cambio se aplica al siguiente arranque. Esta función
pertenece al complemento y no modifica los archivos internos de KOReader.

## Vistas de «Mis libros»

«Mis libros» ofrece la lista con información y una segunda vista de portadas
grandes. El control de la esquina superior izquierda alterna entre «Portadas» y
«Lista»; se recuerda la última vista elegida. La vista de portadas ordena primero
el último libro leído y muestra el porcentaje sobre una esquina de cada portada,
sin barras, fechas ni información adicional. Los libros sin lectura registrada
aparecen después y muestran 0 %. Todo conserva su inicio predeterminado y el
acceso superior para volver a las tareas.

## Barra de lectura de KOReader

Dentro de los libros se conserva el carrusel de indicadores de la barra
inferior. Cada toque recorre la página actual/total, el porcentaje leído y los
tiempos restantes del libro y del capítulo. La hora actual, la batería y las
páginas restantes del capítulo y del libro quedan desactivadas en ese carrusel.

Cada indicador identifica su ámbito con «Libro» o «Capítulo». La barra representa
el libro cuando se muestran sus páginas, porcentaje o tiempo restante; representa
el capítulo al mostrar el tiempo que falta para terminarlo. Su longitud es fija
entre indicadores, para que cambiar el texto no parezca avanzar la lectura.
Si el libro no tiene capítulos identificables, el tiempo y la barra corresponden
al libro. Se utiliza la información y la estimación nativas de KOReader.

Los tiempos utilizan el formato nativo «Letras», con unidades de horas y
minutos, en lugar de la notación con dos puntos. Estos ajustes pertenecen a
KOReader: no cambian la cabecera de Todo ni el cálculo de sus estimaciones.

## Actualización al despertar

Al despertar se recupera la pantalla anterior y se intenta actualizar la
agenda de Hoy sin forzar el Wi-Fi. Sin conexión se conserva la agenda descargada
y la cola. No se programan despertares ni consultas periódicas durante el reposo.
La opción «Todo como salvapantallas», en Más herramientas, permite desactivarlo
y recuperar el salvapantallas habitual de KOReader. No se cambian sus ajustes
de imágenes, portadas o bloqueo.

Este comportamiento corresponde al reposo habitual del botón de encendido;
requiere que KOReader esté ejecutándose. No sustituye la pantalla del firmware
después de salir de KOReader o apagar completamente el dispositivo.

## Instalación y recuperación

### Promociones del inicio de Amazon

La limpieza del inicio nativo se basa en las funciones de presentación y del botón
de tienda de [KPP Patch](https://github.com/KindleModding/KPP_Patch). Oculta las filas
promocionales, incluida la de Kindle Unlimited, y el acceso a la tienda.
La preparación comprueba el archivo real del firmware y conserva una copia
verificada; los libros y la cuenta no forman parte del parche. Se comprueban
todas las funciones y cadenas para rechazar cambios ajenos a esa interfaz.
No se reescribe el almacenamiento compartido de cadenas: en este firmware altera
también textos utilizados por otras funciones. La rama que presenta el botón de
tienda devuelve un elemento vacío, conservando los demás botones de navegación.
Se desactiva la presentación de
las doce plantillas promocionales, conservando los constructores de los componentes
y la plantilla de la biblioteca propia.

El archivo original del sistema se conserva intacto. La copia modificada se
monta sobre él durante la sesión y se comprueba primero en el inicio nativo.
Cada copia tiene un nombre con su hash y no se sustituye mientras está montada.
La limpieza validada se aplica antes de recuperar la interfaz original al salir
de KOReader. Durante la lectura Amazon sigue detenido; no se inicia por aplicar
el montaje. Si falta la utilidad o falla, la recuperación conserva el inicio
original disponible y no impide salir del lector.
Para aplicarla manualmente se utiliza
`sh /mnt/us/system/todo-native-home/activar.sh`. Solo admite el original comprobado
de cada firmware compatible. Al reiniciar se desmonta la copia; la salida
posterior de KOReader vuelve a aplicar la limpieza validada para ese dispositivo.
Para retirarlo, ejecutar `sh /mnt/us/system/todo-native-home/desactivar.sh` por SSH.
Esto desactiva la reaplicación y recupera el original durante la sesión.
La limpieza se puede desactivar por separado del arranque de Todo.

`tooling/prepare_kindle_native_home.py` prepara la copia a partir del original
leído por SSH, con KPP Patch 0.2.0 y
su versión compatible de hbctool instalados en `.codex_tmp/kpp_env` (revisiones
`62d92fcded1b30d4a55f395db01a1c63c2620ecf` y
`8f9bd718445abc4d1068f9cf9702f79f090fc74b`, respectivamente). Solo admite
los SHA-256 inspeccionados de 5.19.2.0.1 y 5.17.1.0.4. Verifica todas las
funciones, conserva las cadenas y recalcula la firma SHA-1 del contenedor.
El argumento `--original` selecciona la copia leída del destino y `--salida` indica
dónde guardar su resultado. El informe y las copias se guardan bajo
`%LOCALAPPDATA%\Todo\kindle_backups`, separados por el hash del original.
Estos binarios privados se excluyen del control de versiones.

Para preparar otro destino compatible, leer su original por el SSH emparejado y
ejecutar, sustituyendo las rutas por las de esa copia:

```text
python tooling/prepare_kindle_native_home.py --original RUTA_ORIGINAL.hbc --salida RUTA_LIMPIA.hbc
```

Copiar por SFTP `activar.sh`, `desactivar.sh` y la copia limpia a
`/mnt/us/system/todo-native-home`. El nombre de esta última es
`inicio-PRIMEROS_12_CARACTERES_DEL_SHA256.hbc`, usando el hash del informe.
Con el original reconocido y sin la marca `desactivado`, ejecutar `activar.sh
prueba`. Comprobar que el inicio carga, desaparecen sus promociones y el carrito,
y funcionan biblioteca, búsqueda y ajustes. Solo después crear el archivo vacío
`validado` en ese directorio. El lanzador de `kindle/boot/launch.sh` aplica desde
entonces esa copia al recuperar la interfaz; el instalador de arranque admite
tanto el original como la copia limpia exacta del mismo firmware. Una copia de
otro firmware sigue siendo rechazada. Para recuperar el original se utiliza
`desactivar.sh`.

La comprobación de los controles de activación se ejecuta con
`python tooling/test_kindle_native_home.py`: valida firmware, copia corrupta,
desactivación, reintentos y recuperación ante un fallo de recarga, sin acceder al
Kindle.

Esta limpieza no es una cancelación de Kindle Unlimited ni cambia suscripciones.

## Instalación por USB y recuperación

Cerrar KOReader antes de conectar el Kindle como unidad USB. Ejecutar
`tooling/install_kindle.ps1 -KindleRoot F:\` con la letra real del dispositivo.
El instalador localiza KOReader, respalda la extensión anterior y verifica los
archivos copiados. Las actualizaciones conservan la agenda y la cola, que viven
fuera del directorio del complemento. No se debe borrar una cola pendiente.
Después de expulsar la unidad, abrir KOReader y elegir «Todo» en Herramientas
(icono de llave y destornillador) → Más herramientas. En la instalación
comprobada, ambos menús tienen dos páginas y Todo aparece en la segunda de
Más herramientas. Dentro del panel, «Actualizar» inicia la sincronización.

### Acceso remoto de mantenimiento

El acceso SSH es independiente de la sincronización de tareas. Se prepara con
`tooling/prepare_kindle_ssh.ps1 -KindleRoot F:\`, usando la letra real del Kindle.
El script aprovecha el servidor incluido en KOReader, genera una clave ECDSA
exclusiva en `%LOCALAPPDATA%\Todo\kindle_ssh`, copia solo su parte pública y
activa el arranque de SSH con autenticación por clave en el puerto 2222.
Conserva las demás preferencias y claves y respalda los archivos modificados
en ese directorio privado del PC. No se debe compartir la clave privada.

La preparación por USB no inicia un proceso dentro del Kindle. Mientras solo
exponga una unidad de almacenamiento, no acredita una conexión remota activa.
Después de expulsar el USB hay que abrir KOReader y conectar su Wi-Fi doméstico.
El arranque automático de SSH se aplica en esa apertura. Para desactivarlo,
usar la opción de arranque automático del servidor SSH en el menú Red de
KOReader y detener el servidor. Este acceso no modifica la suspensión habitual.
La clave de mantenimiento permite administrar el dispositivo; los permisos
limitados del perfil Todo siguen siendo una credencial diferente.

Revocar el perfil desde Ajustes corta su acceso al PC. Para retirar únicamente
la extensión, cerrar KOReader y quitar su directorio `todo.koplugin`; conservar
los datos locales hasta resolver las marcas pendientes.

## Validación

Probar con datos sintéticos la agenda, las recurrencias, las subtareas hermanas,
los reintentos después de reiniciar, los fallos de guardado, los conflictos y el
envío después del cambio de día. Comprobar certificados incorrectos, permisos,
revocación y regresión Android. Compilar Windows e instalar verificando hashes.
La navegación táctil, la suspensión y el Wi-Fi requieren además el Kindle físico;
no presentar la copia USB como prueba de funcionamiento del dispositivo.
La comprobación física de HTTPS debe utilizar el LuaSocket incluido en KOReader:
este configura el tiempo de espera antes de abrir el socket y exige una
confirmación correcta de ese paso. Las pruebas del adaptador reproducen también
esa secuencia, además del rechazo de certificados incorrectos.

Comandos de validación:

```text
flutter analyze --no-pub
flutter test --no-pub
cd lan_sync_agent
dart test
cd ..
python -m pip install --target .codex_tmp/kindle_python -r kindle/requirements-test.txt
python tooling/test_kindle.py
python tooling/test_kindle_installer.py
python tooling/test_kindle_ssh.py
python tooling/test_kindle_native_home.py
python tooling/test_kindle_boot.py
flutter build windows --release --no-pub
python tooling/test_kindle_windows.py
```

La última prueba utiliza la compilación local y un directorio temporal
con tareas sintéticas. Comprueba el guardado, la salida real y el relevo al agente sin abrir la app
instalada ni utilizar sus datos personales.

### Comprobación en el Kindle del 23 de octubre de 2026

Se comprobó el acceso SSH por clave en el puerto 2222 y la descarga HTTPS real
de los siete días desde el complemento instalado. El certificado correcto y la
credencial fueron aceptados; una huella distinta fue rechazada en el Kindle.
Esta prueba detectó y permitió corregir la confirmación del tiempo de espera
del adaptador LuaSocket. La corrección quedó cubierta por una prueba que fallaba
antes del cambio y se copió también al paquete instalado en Windows.

Una tarea temporal creada mediante `TodoWorkspace` se marcó mientras estaba
bloqueada únicamente la conexión al agente. La marca quedó guardada, sobrevivió
al reinicio de KOReader con el mismo identificador y fecha, y se confirmó al
restaurar la conexión. Después se retiró esa tarea mediante `TodoWorkspace` y
se verificó la cola vacía y la agenda habitual. Se probaron también los detalles,
la selección de días de Semana y los controles de completar deshabilitados allí.

El ciclo breve de reposo pasó de `active` a `screenSaver` y volvió a `active`,
recuperando el panel y actualizando la agenda al despertar. No se ha medido la
hibernación prolongada ni la autonomía. La revisión de la app instalada de
Windows sigue correspondiendo al usuario; aplicar las restricciones del firewall
requiere todavía ejecutar el script indicado con permisos de administrador.

La ampliación del salvapantallas se comprobó también ese día: durante el reposo
se capturó en el Kindle la vista fija de Hoy, tanto con el agente accesible como
con su conexión temporalmente bloqueada. Al despertar se recuperó el explorador
de KOReader y se descargó de nuevo la agenda sin abrir el panel sobre él. Se
retiró la regla de prueba y se verificaron la cola vacía y las copias idénticas
del complemento en el dispositivo y en los paquetes del PC. No se cambiaron los
ajustes del salvapantallas nativo ni se modificó código de Flutter.

El ajuste posterior de la interfaz retiró las prioridades y el aviso de reposo,
añadió las subtareas a ambas listas y repartió la cabecera entre reloj, nombre y
batería. Se verificaron en el Kindle el ajuste de las filas a la pantalla, la
vista semanal y la recuperación tras el reposo. Una captura del dispositivo en
estado `screenSaver` confirmó la cabecera centrada y las subtareas visibles en
la vista fija; al despertar se recuperó la pantalla anterior y se actualizó la
agenda. Las pruebas automatizadas
comprueban subtareas anidadas, el identificador que se marca y la navegación
hasta el último elemento de una familia de treinta subtareas. Se retiraron el
formato de prioridades y los auxiliares de fecha abreviada que quedaron sin uso;
no se eliminaron archivos. Los cambios de este ajuste corresponden al
complemento Lua y a su documentación, sin cambios en la aplicación Flutter.

El inicio automático se verificó después mediante un reinicio normal de
KOReader desde su menú: apareció Hoy sin abrir Todo manualmente y se descargó
la agenda. Las pruebas cubren también el arranque con datos guardados sin red,
la desactivación de «Todo al iniciar» y la apertura única por sesión, para que
cambiar de libro no interrumpa la lectura. Se respaldó la versión anterior y se
verificaron las copias del complemento en el Kindle y en los paquetes del PC.
Este cambio no elimina archivos ni requiere recompilar Flutter.

La biblioteca se comprobó en el dispositivo con sus cuatro archivos de libros:
se mostraron sus portadas, títulos y autores en una sola lista. Se abrió
«Circe» en su primera página, sin avanzar la lectura, y tras un reinicio normal
se verificó que Todo seguía siendo el inicio y que la biblioteca mostraba el
porcentaje guardado por KOReader. Las pruebas cubren la búsqueda en subcarpetas,
la exclusión de diccionarios, la conservación de otras colecciones y ajustes,
y la navegación entre Todo, biblioteca y lectura. Se sustituyó el acceso
ambiguo «Volver a leer» por «Mis libros» y los accesos de contexto; no se
eliminaron archivos ni se modificó el contenido de los libros.

Los accesos rápidos se comprobaron en el Kindle: la casa abrió «Mis libros» y
los botones «Todo» del explorador y la biblioteca recuperaron las tareas. Se
validó también el acceso superior desde lectura con el ordenador de menús real
de KOReader. El panel espera a que termine el repintado de lectura antes de
abrirse. Las pruebas cubren ese orden, la reconstrucción de la cabecera y las
acciones de selección de archivos. Se sustituyó la acción de la casa de esa
sesión y el cierre ambiguo de la biblioteca por accesos directos; no se borraron
archivos ni se modificaron los módulos internos de KOReader.

### Arranque del dispositivo comprobado el 24 de octubre de 2026

Un reinicio completo del Kindle abrió Hoy de Todo sin intervención. Se comprobó
el nuevo identificador de arranque, la descarga de la agenda y la detención de
`lab126_gui`, `framework` y `kppmainapp` durante la lectura. «Mis libros» conservó
los cuatro libros, sus portadas y el progreso. La marca de recuperación de la raíz
USB impidió el arranque automático en una prueba independiente.

«Volver al sistema Kindle» cerró el lector, guardó la desactivación del inicio
automático y recuperó el inicio original. Este firmware necesita más de veinte
segundos para volver a levantar sus servicios; el lanzador espera hasta sesenta
intentos y solicita el inicio cuando está disponible. Se confirmó su pantalla sin
abrirla manualmente. Después se habilitó otra vez el arranque y se abrió Todo
mediante el mismo lanzador de KPM.

Un ciclo breve de reposo mostró las tareas sin reloj y recuperó el panel al
despertar. La cola permaneció vacía. Se verificaron los seis archivos instalados
mediante SHA-256, la raíz en modo de solo lectura y `preventScreenSaver=0`.
No se ha medido la hibernación prolongada ni la autonomía. Se superaron las catorce
pruebas de arranque, las pruebas Lua de la extensión y las ocho de la utilidad
manual del inicio nativo. No se recompiló Flutter ni se actualizó Windows, porque
este cambio afecta únicamente al Kindle y a sus herramientas de instalación.

Se retiraron el antiguo lanzador de promociones `kindle/native-home/launch.sh`
y su auxiliar de pruebas `kindle/tests/native_home_activation_target.sh`.
El auxiliar de lanzamiento se trasladó de `kindle/tests/native_home_launch_target.sh`
a `kindle/tests/boot_reader_target.sh`, con las pruebas del nuevo arranque.
Se conservan la utilidad manual de promociones y las copias privadas de recuperación;
no se eliminaron libros ni datos de Todo.

### Respuesta al salir de Todo comprobada el 24 de octubre de 2026

Se reprodujo una espera de 6,07 segundos al tocar «KOReader» con las conexiones
al agente temporalmente bloqueadas. El lector conservaba su proceso: la petición
HTTPS síncrona impedía atender el toque. Las consultas pasan al proceso auxiliar
de `Trapper`; la cola y el guardado permanecen en el proceso principal. Interrumpir
una consulta conserva el panel existente para que reciba el mismo toque, sin
reconstruir sus controles durante la cancelación.

Tras actualizar y reiniciar KOReader desde su menú, la misma prueba mostró el
explorador en 0,13 segundos y «Mis libros» en 0,29 segundos. Son medidas hasta el
cambio del framebuffer, sin incluir el refresco físico de la tinta electrónica.
La comprobación posterior detectó que ese cambio interno no garantizaba mostrar
el destino en el panel físico: al cerrar Todo faltaba solicitar el refresco.
El botón inferior «KOReader», también «Seguir leyendo», debe cerrar Todo con
refresco completo del destino, además de cancelar la sincronización. Las pruebas
de cierre distinguen la imagen dibujada en memoria de la enviada a la pantalla.
La corrección solicita `full` al cerrar el panel. Tras instalarla y reiniciar
KOReader, se pulsó el botón inferior y se comprobó también la respuesta de la
casa hacia «Mis libros». El usuario confirmó después en el dispositivo físico
que «KOReader» cambia la pantalla y responde. Se verificó el archivo instalado
mediante SHA-256 y se superaron las pruebas Lua con el nuevo caso de refresco,
tanto para el explorador como para «Seguir leyendo». No se eliminaron archivos.
Se comprobó también la suspensión con una consulta pendiente, el despertar y la
descarga posterior. Se retiraron las reglas temporales, se conservó la cola vacía
y quedó activada la suspensión habitual.

Las pruebas Lua comprueban que la espera cede el control, que cancelar conserva
los controles y que cerrar o suspender interrumpe la petición. Una marca sellada
conserva su identificador, fecha y versión al cancelar y se retira únicamente al
recibir confirmación en el reintento. También se superaron las pruebas existentes
de biblioteca, navegación, cola, persistencia y certificado. Se respaldó la versión
anterior y se verificaron las copias del Kindle y de los dos paquetes del PC.
Este ajuste no elimina archivos ni modifica Flutter; no requiere recompilar el
ejecutable de Windows.
