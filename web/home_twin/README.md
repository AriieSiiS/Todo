# Ajustar la habitación en 3D

La geometría añadida al escritorio, incluido el PC y los peluches, está en
[`src/desk_details.js`](src/desk_details.js). Los dos ventiladores del fondo
se colocan en el bucle que llama a `makeFan('ventilador_fondo_…')`.
Los tres peluches están ocultos, pero su geometría sigue guardada en ese
archivo: cambia `showPcPlushies` a `true` para volver a mostrarlos.

```js
makeFan(`ventilador_fondo_${index + 1}`, left + 0.077, y, back + 0.02);
```

Los tres valores después del nombre son **X, Y y Z**, en metros. En este
ejemplo, `0.01` equivale a un centímetro. Cambiar `0.077` mueve ambos
ventiladores horizontalmente; un valor menor los acerca a la esquina izquierda.
Cambiar `0.02` mueve ambos desde la pared del fondo hacia el frente; un valor
menor los acerca al fondo. Las alturas están en la lista inmediatamente encima
de esa llamada. Conviene hacer cambios de uno o dos centímetros y mirar si
alguna pieza atraviesa el marco.

## Vista previa sin instalar Todo

Abre una terminal en `web/home_twin` y ejecuta:

```powershell
npm run preview
```

Abre `http://127.0.0.1:8788/` en el navegador. La vista carga **solo el
dormitorio** al abrirse. El selector superior permite elegir otra habitación:
recarga la página y carga únicamente el modelo elegido, sin mantener el resto
de la casa en memoria. También puedes abrir directamente una habitación con
`?habitacion=bano`, por ejemplo. El botón «Ver habitación» centra la cámara y
«Ver PC» aparece solo en el dormitorio. Al guardar un archivo de
`src/`, el navegador se actualiza automáticamente. Detén el servidor con `Ctrl+C`.
La posición de la cámara y el punto al que mira se guardan por habitación.
Al recargar, incluso tras un cambio de código, se recupera el mismo encuadre.
Los botones «Ver habitación» y «Ver PC» permiten cambiarlo cuando quieras.
Para acercarte a una tecla, al ratón o a otra pieza pequeña, coloca el cursor
sobre ella y gira la rueda: el zoom sigue el cursor en vez del centro de la sala.
Los monitores muestran sus fondos estáticos, iconos y barra de tareas. Los
vídeos de los monitores se reservan para el visor de Todo, para que la preview
consuma menos recursos. Esta vista no controla la bombilla ni modifica los
datos de Todo.
Pulsa la hoja o el marco de cualquiera de las puertas de entrada para abrirla
o cerrarla con una animación.
El botón de persiana aparece al elegir una habitación con ventana. Ambas
ventanas conservan tramos distintos del mismo paisaje panorámico.

## Buscar y mover objetos

Los objetos principales están marcados con comentarios fáciles de buscar:
«Monitor 1», «Monitor 2», «Silla», «Sofá», «Cojín 1», «Cojín 2»,
«Ventana», «Puerta», «Mesa», «Vitrina», «Librería» y «Armario» en
`tooling/generate_home_twin_room.py`. Busca «Teclado», «Ratón»,
«Alfombrilla», «Tarjeta gráfica», «Procesador», «Ventiladores»,
«Lamparita» o «Resplandor local» en `src/desk_details.js`.
El teclado y el ratón tienen sus coordenadas de posición en
`src/k70_keyboard.js` y `src/razer_viper_mouse.js`.

En Python, `box(nombre, material, (X, Y, Z), (ancho, alto, fondo))` usa
metros: **X** mueve a izquierda o derecha, **Y** sube o baja y **Z** va del
fondo a la entrada. En JavaScript, `position.set(X, Y, Z)` sigue los mismos
ejes. Cambiar `0.01` desplaza un centímetro. Los objetos de los demás cuartos
están comentados en el generador propio de cada habitación, listado abajo.

Los cambios en `src/*.js` se ven al guardar. Si cambias los números de la
estructura o el mobiliario básico del dormitorio en el archivo Python,
regenera solo ese modelo desde la raíz del repositorio y recarga el navegador:

```powershell
python tooling/generate_home_twin_room.py --importar
```

## Editar cada habitación por separado

El dormitorio se genera en `tooling/generate_home_twin_room.py`. La habitación
contigua, vacía y de 2,10 × 4,10 × 3,10 metros, se genera en
`tooling/generate_home_twin_empty_room.py`. Sus modelos GLB se guardan por
separado en `assets/home_twin_models`. La nueva habitación se sitúa a 2,10
metros a la derecha; la pared derecha del dormitorio sirve de separación y
mantiene su contorno visible al girar la cámara. La habitación vacía tiene su
propia pared frontal, un hueco y una puerta abierta hacia el pasillo. También
tiene el mismo marco de ventana, persiana y viga de entrada que el dormitorio.
Los siete panoramas están en `assets/home_twin_web/weather/panorama_*.png`.

## Estructura provisional de la casa

El vídeo del pasillo y el baño se ha traducido en tres modelos independientes:
`tooling/generate_home_twin_hallway.py`,
`tooling/generate_home_twin_third_room.py` y
`tooling/generate_home_twin_bathroom.py`. Comparten únicamente el escritor de
geometría de `tooling/home_twin_simple_geometry.py`. El pasillo discurre delante
de las dos habitaciones existentes y acaba en una puerta blanca acristalada;
la habitación vacía nueva queda junto a ese extremo y el baño en el opuesto.
Las medidas y los muebles son aproximados y se ajustarán cuando haya un plano.

Para regenerar e importar los tres modelos locales, desde la raíz del
repositorio ejecuta los comandos en este orden:

```powershell
python tooling/generate_home_twin_hallway.py --importar
python tooling/generate_home_twin_third_room.py --importar
python tooling/generate_home_twin_bathroom.py --importar
```

Esto conserva los modelos y los datos de las dos habitaciones anteriores.
Después pulsa «Actualizar maqueta» en Todo o recarga la vista previa.

Después de modificar el generador de la habitación vacía, ejecuta desde la
raíz del repositorio:

```powershell
python tooling/generate_home_twin_empty_room.py --importar
```

Recarga la vista previa para ver el nuevo modelo. `--importar` actualiza solo
esa habitación en los datos locales, conservando el dormitorio y los objetos
que ya contiene.

## Llevar el cambio a Todo

Para cambios solo en el código del visor, desde la raíz del repositorio ejecuta:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tooling\install_home_twin_web.ps1
```

El comando compila el JavaScript, copia únicamente `scene.js` a la instalación
y verifica su hash. Después pulsa «Actualizar maqueta» en Todo: el servidor lee
el archivo instalado de nuevo y el visor carga una URL distinta. No hace falta
cerrar la app ni recompilar Flutter para los siguientes cambios del visor. La
vista previa del navegador sigue siendo la opción más rápida mientras ajustas
números.

Los cambios en la interfaz de Flutter sí necesitan la compilación e instalación
completas de Windows. Los cambios en el archivo `.glb` necesitan generar o
importar de nuevo ese modelo.
