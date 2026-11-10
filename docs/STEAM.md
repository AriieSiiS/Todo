# Conexión con Steam

Todo consulta la biblioteca, las horas jugadas y los logros mediante la API
oficial de Steam. Las consultas son de lectura y se hacen desde el PC.

## Configuración

1. Copiar el enlace del perfil con formato
   `https://steamcommunity.com/profiles/7656119…/` o su SteamID de 17 cifras.
2. Crear una clave personal en <https://steamcommunity.com/dev/apikey>.
   Para el uso local, indicar `localhost` como dominio. No enviar la clave
   por chat ni incorporarla a archivos del repositorio.
3. En Steam, revisar «Editar perfil → Configuración de privacidad»: el perfil
   y los detalles de juegos deben ser accesibles para la API. Para consultar
   horas, desmarcar la opción que mantiene privado el tiempo de juego.
4. En Todo, abrir «Ajustes → Steam», introducir el perfil y la clave y pulsar
   «Guardar y comprobar». Solo se confirma la conexión después de recibir una
   respuesta válida de Steam; un perfil inaccesible no equivale a cero juegos.
5. En una ficha de juego de Biblioteca, pulsar el trofeo «Logros de Steam». Si el título
   coincide exactamente con un único juego de Steam, se muestra directamente.
   En otro caso, buscar y seleccionar el juego correcto. Se conserva el vínculo
   local para las siguientes consultas.

Si Steam permite consultar los logros de un juego pero no lo devuelve en
`GetOwnedGames`, se puede enlazar su AppID verificado con la ficha existente.
Todo comprueba el acceso a sus logros antes de guardar ese vínculo. El juego
enlazado aparece en la conexión con sus horas como «no disponibles»; no se
deducen su propiedad, licencia ni tiempo de juego a partir de los logros.

La clave y los vínculos se guardan con `flutter_secure_storage`, fuera del
snapshot, del repositorio y de las exportaciones. La conexión se configura en
cada PC. «Desconectar» elimina esta configuración y la caché en memoria.
No se importan juegos nuevos ni se cambia el estado, las notas o las valoraciones
de las fichas existentes. Los logros se consultan bajo demanda, con caché de diez
minutos y botón para actualizar. Los datos que Steam no devuelve se muestran como
desconocidos; un juego sin logros se distingue de una consulta fallida.
Al abrir el trofeo se consulta automáticamente la conexión. No hay consultas
periódicas en segundo plano.

En Biblioteca → Juegos, el icono «Actualizar logros de esta vista» actualiza los
juegos incluidos por el estado, año, búsqueda, universo y saga actuales. Conserva
la selección inicial mientras termina, evita consultas duplicadas al mismo juego
y resume los actualizados, los que necesitan enlace y los que fallaron. El botón
muestra actividad y no admite otra actualización simultánea.
Las portadas, el filtro de juegos al 100 % y «Recientes» reciben los cambios al
actualizar logros, también desde la ficha individual. En «Recientes» solo los
libros y juegos en curso muestran porcentaje: lectura para libros y logros para
juegos. Si los logros todavía no están disponibles, se muestra solo el estado.
Los juegos con todos los logros obtenidos muestran un borde plateado de 2 píxeles
y un halo azulado, con un reflejo diagonal de 1,8 segundos cada 6 segundos,
siguiendo el efecto de la web local Platino. El distintivo «100 %» se conserva.
El reflejo se detiene al desactivar las animaciones del sistema y no intercepta
clics ni menús de la portada. El efecto aparece y desaparece con los logros
actualizados, sin cambiar el estado del juego.
El título visible se obtiene de la biblioteca de Steam: el esquema de logros
puede devolver un nombre interno distinto. Los porcentajes globales se
normalizan tanto si Steam los envía como números como si los envía como texto.

## Guías personales

Cada consulta guarda los logros en
`Documents/Todo/steam_icons/<appid>/logros.json` y escribe junto a él
`logros.js`, con los mismos datos en `window.LOGROS_STEAM`. Una guía abierta
desde disco no puede leer el JSON, pero sí cargar ese script para retirar los
logros obtenidos. Los datos son los de la última actualización de logros en Todo.

## Limpiar la lista de deseados

«Ajustes → Steam → Limpiar lista de deseados» descarga la lista de deseados
(`IWishlistService/GetWishlist`) y los juegos del plan familiar
(`IFamilyGroupsService/GetSharedLibraryApps`, sin los propios ni los excluidos),
los cruza por AppID y quita los coincidentes con
`IWishlistService/RemoveFromWishlist`, uno a uno con un pequeño retardo y
siguiendo aunque alguno falle. Muestra los quitados con su enlace de la tienda,
los fallos aparte y un botón «Copiar lista», y guarda el mismo texto en
`Documents/Todo/steam/lista_deseados_plan_familiar_<fecha>.txt`.

La clave Web API no sirve aquí: Steam responde 401 al plan familiar y al
borrado. Hace falta el token de sesión `webapi_token` que muestra
<https://store.steampowered.com/pointssummary/ajaxgetasyncconfig> con la sesión
iniciada en el navegador. El diálogo lo pide cuando falta o ha caducado (dura
unas 24 horas), admite pegar la página completa, comprueba que pertenece al
perfil conectado y lo guarda cifrado con `flutter_secure_storage`. Un token
rechazado se avisa como tal; nunca se interpreta como «sin coincidencias».

## Consulta desde agentes

El adaptador MCP existente expone `get_steam_games` y
`get_steam_achievements` en modo real. Usa el puente autenticado de Todo abierto;
el agente recibe resultados y nunca la clave. La primera herramienta admite
`query`, `offset`, `limit` y `refresh`; la segunda, `appid` y `refresh`.
Los resultados incluyen la hora de consulta. Si Todo está cerrado o Steam falla,
se devuelve un error; no se inventan resultados a partir del snapshot.
Después de actualizar el servidor, el cliente MCP debe volver a cargar su lista
de herramientas para descubrir estas consultas.

`get_steam_link` consulta el vínculo de una ficha de juego y su `link_version`.
`link_steam_game` enlaza la ficha existente con un AppID: requiere `item_id`,
`appid`, `expected_version` con la versión consultada y un `request_id` estable.
La escritura pasa por `TodoWorkspace`, valida que la ficha sea un juego,
comprueba los logros y confirma `savedLocally` después del guardado. El registro
de reintentos evita repetir una operación ya confirmada.

Referencias: [autenticación](https://partner.steamgames.com/doc/webapi_overview/auth),
[biblioteca](https://partner.steamgames.com/doc/webapi/IPlayerService) y
[logros](https://partner.steamgames.com/doc/webapi/ISteamUserStats).
