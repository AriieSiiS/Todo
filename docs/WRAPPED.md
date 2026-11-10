# Wrapped de Biblioteca

Resúmenes anuales con forma de historias animadas: pasan solos como un vídeo,
tienen banda sonora y cada diapositiva se descarga como imagen vertical de
1080 × 1920. El vídeo MP4 con música (necesita ffmpeg) se genera solo en
segundo plano, así que descargarlo es copiar un archivo ya hecho.

Hay cuatro: el **general** (toda la Biblioteca), **libros**, **series y
películas** y **videojuegos** (`WrappedTipo` en
`lib/application/wrapped/wrapped_modelo.dart`). Todos se publican a la vez y
llega una sola notificación de Windows para todos.

## Cómo funciona

- **Publicación automática.** Por defecto, el 31 de diciembre a las 10:00 la app
  marca el Wrapped del año como listo, muestra una tarjeta flotante «Tu Wrapped
  está listo» y lanza una notificación de Windows. Avisa durante 45 días o hasta
  que se abre.
- **Datos vivos.** Se calcula al abrirlo, así que cuenta todo lo leído hasta ese
  momento, incluido lo del 31 de diciembre.
- **Vista previa.** Desde el botón ✨ de la cabecera de Biblioteca se puede
  abrir cualquier tipo y año; antes de la fecha aparece como vista previa.
- **Datos de cada tipo.** Libros: Kindle (KOReader), páginas, citas. Series y
  películas: duración de cada ficha (las series se estiman por episodios si
  falta el dato), países, directores, estrenos y maratones. Videojuegos: los
  `logros.json` de `Documents\Todo\steam_icons\<appid>` (fecha exacta de cada
  logro y su rareza) y las horas de `Documents\Todo\steam\horas_familia.json`,
  que son horas totales en Steam, no solo del año. El general suma los tres y
  usa los ajustes `excluir` de cada uno más los suyos.
- **Descargas.** Las imágenes y el vídeo se guardan en
  `Imágenes\Wrapped\<año> · Libros`.
- **Vídeo automático.** Al publicarse el Wrapped, y también al abrirlo, la app
  genera el vídeo fuera de pantalla y lo deja en
  `Documents\Todo\wrapped\videos`. Cada vídeo lleva una firma de los datos, los
  ajustes, la música y la versión instalada: si algo cambia, se rehace solo.
  Mientras se ve un Wrapped, la generación va más despacio para no dar tirones.
- **Kindle.** Usa las estadísticas de KOReader: horas, días, racha, día récord,
  horas del día, páginas por hora y top por tiempo. Si un año no tiene historial,
  esas diapositivas se omiten solas.

## Archivos

| Archivo | Contenido |
| --- | --- |
| `Documents\Todo\wrapped\ajustes.json` | Variables (se puede editar a mano) |
| `Documents\Todo\wrapped\estado.json` | Cuándo se avisó y se vio cada Wrapped |
| `assets/wrapped/musica/*.mp3` | Bandas sonoras originales (compuestas con `tooling/wrapped_musica`) |
| `Documents\Todo\wrapped\videos` | Vídeos ya generados, listos para descargar |
| `lib/application/wrapped/` | Modelo, ajustes, publicación y cálculo de datos |
| `lib/presentation/wrapped/` | Reproductor, piezas visuales, diapositivas y avisos |

## Variables

Se pueden cambiar desde el botón «Personalizar» del reproductor o editando
`ajustes.json`. Cada tipo usa su clave (`general`, `libros`, `pantalla`,
`juegos`): `libros` vale para todos los años y `libros-2026` solo para ese año
(gana sobre la general). Las obras se indican por título (sin importar
mayúsculas ni tildes) o por id.

```json
{
  "automatico": true,
  "publicacion": { "mes": 12, "dia": 31, "hora": 10 },
  "libros": { "paleta": "automatica" },
  "libros-2026": {
    "portada": "Circe",
    "destacado": "La mascarada del carnicero",
    "excluir": ["Juego de dos"],
    "ocultar": ["notas", "curiosidades"],
    "titulo": "Un año de mazmorras",
    "nombre": "Ale",
    "mensajeFinal": "Nos vemos en 2027.",
    "cita": "Puedes hacerlo",
    "musica": "C:\\ruta\\cancion.mp3",
    "segundosPorDiapositiva": 7
  }
}
```

| Variable | Qué hace |
| --- | --- |
| `automatico` | `false` desactiva la publicación y los avisos |
| `publicacion` | Mes, día y hora de publicación. En enero o febrero se refiere al año ya cerrado |
| `portada` | Libro grande de la primera diapositiva |
| `destacado` | Libro del año (por defecto, mejor nota y después más horas) |
| `excluir` | Libros que no cuentan |
| `ocultar` | Diapositivas que no salen (ids abajo) |
| `titulo` | Texto de la portada en lugar de «Tu año en libros» |
| `nombre` | Saludo en la portada |
| `mensajeFinal` | Frase de la última diapositiva |
| `cita` | Fragmento de la cita que se quiere destacar |
| `musica` | Una pista (`aurora`, `taberna`, `bardo`, `cafe`, `cronica`, `neon`), la ruta de un audio propio o `ninguna`. También se elige desde el botón de música del reproductor |
| `paleta` | `automatica` (colores de las portadas), `ciclo` o una fija: `aurora`, `atardecer`, `oceano`, `orquidea`, `bosque`, `brasa`, `oro`, `noche` |
| `segundosPorDiapositiva` | Duración base (3 a 30; algunas duran un poco más) |

## Música

Todas las pistas son composiciones originales hechas por síntesis, sin
derechos de terceros. Se regeneran con
`python tooling/wrapped_musica/pistas.py <pista> <salida.wav>` (y `aurora.py`
para Aurora) y se pasan a mp3 con ffmpeg.

| Pista | Estilo |
| --- | --- |
| `aurora` | Épica suave (por defecto) |
| `taberna` | Lofi medieval: laúd, flauta dulce y pandero |
| `bardo` | Lofi medieval lento: arpa, zanfona, flauta y lluvia |
| `cafe` | Lofi jazz: piano eléctrico y batería suave |
| `cronica` | Épica orquestal: cuerdas, metales, coro y timbales |
| `neon` | Synthwave |

## Diapositivas

- **Libros:** `inicio`, `terminados`, `paginas`, `kindle`, `calendario`,
  `dia-record`, `reloj`, `meses`, `top`, `autor`, `sagas`, `generos`, `epocas`,
  `curiosidades`, `notas`, `propositos`, `cita`, `libro-del-ano`, `perfil`,
  `lo-que-viene` y `resumen`.
- **Series y películas:** `inicio`, `terminados`, `pantalla`, `extremos`,
  `maraton`, `semana`, `meses`, `creador`, `paises`, `sagas`, `generos`,
  `estrenos`, `epocas`, `curiosidades`, `notas`, `propositos`, `destacado`,
  `perfil`, `lo-que-viene` y `resumen`.
- **Videojuegos:** `inicio`, `terminados`, `logros`, `calendario`,
  `dia-record`, `reloj`, `raro`, `top-logros`, `cien`, `horas`, `meses`,
  `creador`, `sagas`, `generos`, `epocas`, `curiosidades`, `notas`,
  `propositos`, `destacado`, `perfil`, `lo-que-viene` y `resumen`.
- **General:** `inicio`, `terminados`, `reparto`, `horas`, `mejores`, `meses`,
  `dias`, `universo`, `generos`, `creador`, `sagas`, `epocas`, `curiosidades`,
  `notas`, `propositos`, `destacado`, `perfil`, `lo-que-viene` y `resumen`.

Cada una aparece solo si hay datos para ella. `sagas` y `lo-que-viene` buscan la
siguiente entrega en la Biblioteca y en el catálogo de Colecciones, con su
fecha prevista si la tiene.

## Revisar las diapositivas sin abrir la app

```text
flutter test test/capturas/wrapped_libros_captura_test.dart --dart-define=CAPTURAS=<carpeta> --dart-define=FUENTES=<carpeta> --dart-define=TIPO=libros
```

`TIPO` puede ser `libros`, `pantalla`, `juegos` o `general`.

Lee la Biblioteca real en modo lectura. `FUENTES` debe contener los TTF de
Bricolage Grotesque (`Titular-*.ttf`), Fraunces (`Serif-*.ttf`) y Plus Jakarta
Sans (`Texto-*.ttf`).

## Cómo está hecho

- `resumen_obras.dart` calcula lo común (notas, creadores, géneros, sagas,
  épocas, propósitos, días récord); `resumen_libros.dart`,
  `resumen_pantalla.dart`, `resumen_juegos.dart` y `resumen_general.dart`
  añaden lo propio de cada tipo.
- `wrapped_diapositivas.dart` es una biblioteca con partes: `wrapped_comun.dart`
  tiene las diapositivas compartidas, que cambian sus textos con los rótulos de
  cada tipo, y cada tipo tiene su archivo con las suyas.
- `wrapped_centro.dart` prepara cualquier tipo (`prepararWrapped`), abre el
  reproductor, el panel «Personalizar» y los avisos.
