# Wrapped de Biblioteca

Resúmenes anuales con forma de historias animadas: pasan solos como un vídeo,
tienen banda sonora y cada diapositiva se descarga como imagen vertical de
1080 × 1920. También se puede crear un MP4 con música si ffmpeg está instalado.

De momento existe el de **libros**. El general, el de series y películas y el
de videojuegos ya tienen su sitio (`WrappedTipo` en
`lib/application/wrapped/wrapped_modelo.dart`) y aparecen como «Próximamente».

## Cómo funciona

- **Publicación automática.** Por defecto, el 31 de diciembre a las 10:00 la app
  marca el Wrapped del año como listo, muestra una tarjeta flotante «Tu Wrapped
  está listo» y lanza una notificación de Windows. Avisa durante 45 días o hasta
  que se abre.
- **Datos vivos.** Se calcula al abrirlo, así que cuenta todo lo leído hasta ese
  momento, incluido lo del 31 de diciembre.
- **Vista previa.** Desde el botón ✨ de la cabecera de Biblioteca (vista de
  libros) se puede abrir cualquier año; antes de la fecha aparece como vista
  previa.
- **Descargas.** Las imágenes y el vídeo se guardan en
  `Imágenes\Wrapped\<año> · Libros`.
- **Kindle.** Usa las estadísticas de KOReader: horas, días, racha, día récord,
  horas del día, páginas por hora y top por tiempo. Si un año no tiene historial,
  esas diapositivas se omiten solas.

## Archivos

| Archivo | Contenido |
| --- | --- |
| `Documents\Todo\wrapped\ajustes.json` | Variables (se puede editar a mano) |
| `Documents\Todo\wrapped\estado.json` | Cuándo se avisó y se vio cada Wrapped |
| `assets/wrapped/musica/libros.mp3` | Banda sonora original del Wrapped de libros |
| `lib/application/wrapped/` | Modelo, ajustes, publicación y cálculo de datos |
| `lib/presentation/wrapped/` | Reproductor, piezas visuales, diapositivas y avisos |

## Variables

Se pueden cambiar desde el botón «Personalizar» del reproductor o editando
`ajustes.json`. La clave `libros` vale para todos los años; `libros-2026`, solo
para ese año y gana sobre la general. Los libros se indican por título (sin
importar mayúsculas ni tildes) o por id.

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
| `musica` | Ruta de un audio propio, o `ninguna` |
| `paleta` | `automatica` (colores de las portadas), `ciclo` o una fija: `aurora`, `atardecer`, `oceano`, `orquidea`, `bosque`, `brasa`, `oro`, `noche` |
| `segundosPorDiapositiva` | Duración base (3 a 30; algunas duran un poco más) |

## Diapositivas del Wrapped de libros

`inicio`, `terminados`, `paginas`, `kindle`, `calendario`, `dia-record`,
`reloj`, `meses`, `top`, `autor`, `sagas`, `generos`, `epocas`,
`curiosidades`, `notas`, `propositos`, `cita`, `libro-del-ano`, `perfil`,
`lo-que-viene` y `resumen`.

Cada una aparece solo si hay datos para ella. `sagas` y `lo-que-viene` buscan la
siguiente entrega en la Biblioteca y en el catálogo de Colecciones, con su
fecha prevista si la tiene.

## Revisar las diapositivas sin abrir la app

```text
flutter test test/capturas/wrapped_libros_captura_test.dart --dart-define=CAPTURAS=<carpeta> --dart-define=FUENTES=<carpeta>
```

Lee la Biblioteca real en modo lectura. `FUENTES` debe contener los TTF de
Bricolage Grotesque (`Titular-*.ttf`), Fraunces (`Serif-*.ttf`) y Plus Jakarta
Sans (`Texto-*.ttf`).

## Añadir otro tipo

1. Calcular sus datos en `lib/application/wrapped/` (como `resumen_libros.dart`).
2. Construir sus diapositivas como `DiapositivaWrapped` en
   `lib/presentation/wrapped/` y reutilizar `ReproductorWrapped`.
3. Marcar el tipo como `disponible: true`, darle datos en `hayDatosWrapped` y
   enlazarlo en `_PantallaWrapped`.
