// Visor 3D de una miniatura de Custodio, construido con piezas simples.
// Cada pieza pertenece a una zona de pintura (armadura, capa, penacho…) y la
// app le indica el color de cada zona según el paso de la guía.
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';

const lienzo = document.getElementById('lienzo');
const capaLineas = document.getElementById('lineas');
const capaEtiquetas = document.getElementById('etiquetas');
const pista = document.getElementById('pista');

const renderer = new THREE.WebGLRenderer({
  canvas: lienzo,
  antialias: true,
  alpha: true,
  preserveDrawingBuffer: true,
});
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 0.82;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;

const scene = new THREE.Scene();
const pmrem = new THREE.PMREMGenerator(renderer);
scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
scene.environmentIntensity = 0.85;

const camera = new THREE.PerspectiveCamera(30, 1, 0.1, 50);
camera.position.set(1.4, 2.0, 6.2);
const controls = new OrbitControls(camera, lienzo);
controls.target.set(0, 1.38, 0);
controls.enableDamping = true;
controls.dampingFactor = 0.08;
controls.enablePan = false;
controls.minDistance = 2.4;
controls.maxDistance = 8;
controls.minPolarAngle = 0.35;
controls.maxPolarAngle = Math.PI * 0.62;
controls.autoRotate = true;
controls.autoRotateSpeed = 1.1;
controls.update();

let ultimaInteraccion = 0;
controls.addEventListener('start', () => {
  controls.autoRotate = false;
  ultimaInteraccion = performance.now();
  pista.style.opacity = '0';
});
controls.addEventListener('end', () => {
  ultimaInteraccion = performance.now();
});

// Luces: clave cálida, contraluz frío y relleno suave.
scene.add(new THREE.HemisphereLight(0xfff3df, 0x2a2018, 0.55));
const clave = new THREE.DirectionalLight(0xffe2b8, 2.1);
clave.position.set(2.8, 4.5, 3.2);
clave.castShadow = true;
clave.shadow.mapSize.set(1024, 1024);
clave.shadow.camera.left = -2;
clave.shadow.camera.right = 2;
clave.shadow.camera.top = 3;
clave.shadow.camera.bottom = -1;
clave.shadow.bias = -0.0006;
scene.add(clave);
const contraluz = new THREE.DirectionalLight(0x9cc8ff, 1.7);
contraluz.position.set(-3, 3, -3.5);
scene.add(contraluz);
const relleno = new THREE.PointLight(0xffb070, 1.2, 9);
relleno.position.set(-2.2, 1.2, 2.4);
scene.add(relleno);

// Suelo que solo recibe sombra.
const suelo = new THREE.Mesh(
  new THREE.CircleGeometry(3, 48),
  new THREE.ShadowMaterial({ opacity: 0.32 }),
);
suelo.rotation.x = -Math.PI / 2;
suelo.receiveShadow = true;
scene.add(suelo);

// --- Zonas de pintura ------------------------------------------------------

const PLASTICO = '#8d9198';
const zonas = new Map();

function zona(nombre) {
  if (!zonas.has(nombre)) {
    const material = new THREE.MeshStandardMaterial({
      color: PLASTICO,
      roughness: 0.82,
      metalness: 0,
    });
    zonas.set(nombre, { material, anclas: [], piezas: [] });
  }
  return zonas.get(nombre);
}

function pieza(geometria, nombreZona, padre, { pos, rot, esc } = {}) {
  const z = zona(nombreZona);
  const malla = new THREE.Mesh(geometria, z.material);
  malla.castShadow = true;
  malla.receiveShadow = true;
  if (pos) malla.position.set(...pos);
  if (rot) malla.rotation.set(...rot);
  if (esc) malla.scale.set(...esc);
  padre.add(malla);
  z.piezas.push(malla);
  return malla;
}

function ancla(nombreZona, padre, pos) {
  const marcador = new THREE.Object3D();
  marcador.position.set(...pos);
  padre.add(marcador);
  zona(nombreZona).anclas.push(marcador);
}

const figura = new THREE.Group();
scene.add(figura);

// --- Peana -----------------------------------------------------------------
const peana = new THREE.Mesh(
  new THREE.CylinderGeometry(0.95, 1.0, 0.14, 72),
  [zona('borde').material, zona('peana').material, zona('borde').material],
);
peana.position.y = 0.07;
peana.castShadow = true;
peana.receiveShadow = true;
figura.add(peana);
zona('peana').piezas.push(peana);
zona('borde').piezas.push(peana);
ancla('peana', figura, [0.55, 0.15, 0.55]);
ancla('borde', figura, [-0.7, 0.07, 0.62]);
// Piedras sobre la peana.
for (const [x, z, r] of [[0.55, 0.42, 0.09], [-0.48, -0.5, 0.11], [0.62, -0.18, 0.06], [-0.3, 0.6, 0.05]]) {
  pieza(new THREE.DodecahedronGeometry(r, 0), 'peana', figura, { pos: [x, 0.16, z], rot: [x * 3, z * 2, 0] });
}

// --- Piernas ---------------------------------------------------------------
const piernas = new THREE.Group();
figura.add(piernas);
const cuerpo = new THREE.Group();
cuerpo.position.y = 0.2;
cuerpo.scale.set(0.9, 1, 0.92);
figura.add(cuerpo);

function pierna(lado) {
  const g = new THREE.Group();
  g.position.set(0.2 * lado, 0, 0);
  g.rotation.z = 0.04 * lado;
  piernas.add(g);
  pieza(new THREE.CapsuleGeometry(0.11, 0.22, 6, 16), 'armadura', g, { pos: [0, 0.23, 0.07], rot: [Math.PI / 2, 0, 0] });
  pieza(new THREE.CylinderGeometry(0.15, 0.12, 0.52, 24), 'armadura', g, { pos: [0, 0.56, 0] });
  pieza(new THREE.CylinderGeometry(0.095, 0.095, 0.14, 16), 'traje', g, { pos: [0, 0.86, 0] });
  pieza(new THREE.SphereGeometry(0.145, 24, 16), 'armadura', g, { pos: [0, 0.87, 0.07], esc: [1, 0.85, 0.8] });
  pieza(new THREE.CylinderGeometry(0.175, 0.14, 0.48, 24), 'armadura', g, { pos: [0, 1.1, 0] });
}
pierna(1);
pierna(-1);
ancla('traje', piernas, [0.21, 0.86, 0.1]);

// Faldón rojo delantero con dientes dorados.
pieza(new THREE.BoxGeometry(0.28, 0.6, 0.035), 'capa', cuerpo, { pos: [0, 0.86, 0.29], rot: [-0.08, 0, 0] });
ancla('capa', cuerpo, [0, 0.75, 0.31]);
for (let i = 0; i < 5; i++) {
  pieza(new THREE.ConeGeometry(0.025, 0.08, 8), 'armadura', cuerpo, {
    pos: [-0.1 + i * 0.05, 0.55, 0.315],
    rot: [Math.PI, 0, 0],
  });
}
// Placas laterales de la cadera.
for (let i = 0; i < 7; i++) {
  const angulo = -1.45 + i * 0.48;
  if (Math.abs(angulo) < 0.3) continue;
  pieza(new THREE.BoxGeometry(0.17, 0.3, 0.035), 'armadura', cuerpo, {
    pos: [Math.sin(angulo) * 0.33, 1.0, Math.cos(angulo) * 0.3],
    rot: [-0.18, angulo, 0],
  });
}

// --- Torso -----------------------------------------------------------------
pieza(new THREE.TorusGeometry(0.31, 0.065, 12, 40), 'armadura', cuerpo, { pos: [0, 1.13, 0], rot: [Math.PI / 2, 0, 0], esc: [1, 0.85, 1] });
pieza(new THREE.CylinderGeometry(0.29, 0.3, 0.26, 28), 'traje', cuerpo, { pos: [0, 1.26, 0], esc: [1, 1, 0.82] });
const pecho = pieza(new THREE.SphereGeometry(0.44, 40, 28), 'armadura', cuerpo, { pos: [0, 1.56, 0.02], esc: [1, 0.82, 0.74] });
pecho.geometry.computeVertexNormals();
// Águila del pecho: dos alas en relieve.
for (const lado of [1, -1]) {
  pieza(new THREE.BoxGeometry(0.26, 0.06, 0.05), 'armadura', cuerpo, { pos: [0.13 * lado, 1.66, 0.33], rot: [0, 0, 0.35 * lado] });
  pieza(new THREE.BoxGeometry(0.2, 0.05, 0.05), 'armadura', cuerpo, { pos: [0.11 * lado, 1.6, 0.335], rot: [0, 0, 0.5 * lado] });
}
ancla('armadura', cuerpo, [0.18, 1.55, 0.33]);
// Gorguera y cuello.
pieza(new THREE.TorusGeometry(0.19, 0.075, 14, 32), 'armadura', cuerpo, { pos: [0, 1.88, 0], rot: [Math.PI / 2, 0, 0] });
pieza(new THREE.CylinderGeometry(0.11, 0.12, 0.16, 20), 'traje', cuerpo, { pos: [0, 1.93, 0] });

// --- Casco y penacho -----------------------------------------------------
const casco = new THREE.Group();
casco.position.set(0, 1.96, 0.01);
cuerpo.add(casco);
const perfil = [
  [0.0, 0.0], [0.155, 0.0], [0.17, 0.08], [0.168, 0.18], [0.15, 0.28],
  [0.115, 0.38], [0.07, 0.47], [0.03, 0.53], [0.0, 0.55],
].map(([r, y]) => new THREE.Vector2(r, y));
pieza(new THREE.LatheGeometry(perfil, 40), 'armadura', casco, { esc: [1, 1, 1.12] });
// Cresta y visor.
pieza(new THREE.BoxGeometry(0.035, 0.32, 0.36), 'armadura', casco, { pos: [0, 0.4, -0.02] });
pieza(new THREE.BoxGeometry(0.2, 0.05, 0.05), 'empunadura', casco, { pos: [0, 0.17, 0.17] });
for (const lado of [1, -1]) {
  pieza(new THREE.SphereGeometry(0.022, 12, 8), 'ojos', casco, { pos: [0.05 * lado, 0.18, 0.185] });
}
ancla('ojos', casco, [0.05, 0.18, 0.19]);
const curvaPenacho = new THREE.CatmullRomCurve3([
  new THREE.Vector3(0, 0.5, 0.06),
  new THREE.Vector3(0, 0.66, -0.04),
  new THREE.Vector3(0, 0.7, -0.24),
  new THREE.Vector3(0, 0.58, -0.44),
  new THREE.Vector3(0, 0.36, -0.55),
  new THREE.Vector3(0, 0.12, -0.6),
]);
pieza(new THREE.TubeGeometry(curvaPenacho, 60, 0.075, 14), 'penacho', casco, { esc: [0.75, 1, 1] });
// Mechones para dar volumen.
for (let i = 0; i < 9; i++) {
  const t = 0.08 + i * 0.1;
  const p = curvaPenacho.getPoint(t);
  pieza(new THREE.ConeGeometry(0.045, 0.2, 8), 'penacho', casco, {
    pos: [0, p.y + 0.06, p.z],
    rot: [-0.6 - t * 1.5, 0, 0],
  });
}
ancla('penacho', casco, [0, 0.66, -0.3]);

// --- Hombreras -------------------------------------------------------------
function hombrera(lado) {
  const g = new THREE.Group();
  g.position.set(0.5 * lado, 1.76, 0);
  g.rotation.z = -0.32 * lado;
  cuerpo.add(g);
  pieza(new THREE.SphereGeometry(0.27, 32, 16, 0, Math.PI * 2, 0, Math.PI / 2), 'armadura', g, { esc: [1.15, 0.95, 1.12] });
  pieza(new THREE.TorusGeometry(0.29, 0.03, 10, 40), 'armadura', g, { rot: [Math.PI / 2, 0, 0], esc: [1.12, 1.1, 1] });
  pieza(new THREE.SphereGeometry(0.04, 12, 10), 'gemas', g, { pos: [0.02 * lado, 0.24, 0.12] });
}
hombrera(1);
hombrera(-1);

// --- Brazos ----------------------------------------------------------------
function brazo(lado, giroCodo, giroHombro) {
  const hombro = new THREE.Group();
  hombro.position.set(0.55 * lado, 1.66, 0);
  hombro.rotation.set(giroHombro[0], giroHombro[1], giroHombro[2]);
  cuerpo.add(hombro);
  pieza(new THREE.CylinderGeometry(0.11, 0.1, 0.36, 20), 'traje', hombro, { pos: [0, -0.2, 0] });
  pieza(new THREE.SphereGeometry(0.11, 20, 14), 'traje', hombro, { pos: [0, -0.39, 0] });
  const antebrazo = new THREE.Group();
  antebrazo.position.set(0, -0.39, 0);
  antebrazo.rotation.x = giroCodo;
  hombro.add(antebrazo);
  pieza(new THREE.CylinderGeometry(0.115, 0.13, 0.3, 20), 'armadura', antebrazo, { pos: [0, -0.18, 0] });
  pieza(new THREE.SphereGeometry(0.11, 20, 14), 'armadura', antebrazo, { pos: [0, -0.37, 0], esc: [1, 1.05, 1.1] });
  return antebrazo;
}
const brazoDerecho = brazo(-1, -1.05, [0.1, 0, -0.18]);
const brazoIzquierdo = brazo(1, -1.25, [0.05, 0.25, 0.22]);

// --- Espada centinela ------------------------------------------------------
const espada = new THREE.Group();
espada.position.set(0, -0.37, 0);
espada.rotation.set(1.85, 0, 0.1);
brazoDerecho.add(espada);
const formaHoja = new THREE.Shape();
formaHoja.moveTo(-0.06, 0);
formaHoja.lineTo(0.06, 0);
formaHoja.lineTo(0.055, 0.95);
formaHoja.lineTo(0, 1.08);
formaHoja.lineTo(-0.055, 0.95);
formaHoja.closePath();
const hoja = pieza(
  new THREE.ExtrudeGeometry(formaHoja, { depth: 0.012, bevelEnabled: true, bevelThickness: 0.012, bevelSize: 0.012, bevelSegments: 2 }),
  'hoja', espada, { pos: [0, 0.12, -0.006] },
);
hoja.geometry.computeVertexNormals();
pieza(new THREE.BoxGeometry(0.012, 0.7, 0.05), 'energia', espada, { pos: [0, 0.5, 0] });
pieza(new THREE.BoxGeometry(0.34, 0.06, 0.09), 'empunadura', espada, { pos: [0, 0.1, 0] });
pieza(new THREE.CylinderGeometry(0.03, 0.03, 0.24, 12), 'empunadura', espada, { pos: [0, -0.04, 0] });
pieza(new THREE.SphereGeometry(0.045, 14, 10), 'armadura', espada, { pos: [0, -0.18, 0] });
ancla('hoja', espada, [0.02, 0.85, 0.02]);
ancla('energia', espada, [0, 0.45, 0.02]);
ancla('empunadura', espada, [0.16, 0.1, 0.02]);

// --- Escudo praesidium -----------------------------------------------------
const escudo = new THREE.Group();
escudo.position.set(0.04, -0.3, 0.2);
escudo.rotation.set(1.25, 0.6, 0);
brazoIzquierdo.add(escudo);
function formaEscudo(ancho, alto, chaflan) {
  const f = new THREE.Shape();
  f.moveTo(-ancho / 2, -alto / 2 + chaflan);
  f.lineTo(-ancho / 2 + chaflan, -alto / 2);
  f.lineTo(ancho / 2 - chaflan, -alto / 2);
  f.lineTo(ancho / 2, -alto / 2 + chaflan);
  f.lineTo(ancho / 2, alto / 2 - chaflan * 1.6);
  f.lineTo(ancho / 2 - chaflan * 1.6, alto / 2);
  f.lineTo(-ancho / 2 + chaflan * 1.6, alto / 2);
  f.lineTo(-ancho / 2, alto / 2 - chaflan * 1.6);
  f.closePath();
  return f;
}
const grupoEscudo = new THREE.Group();
escudo.add(grupoEscudo);
pieza(
  new THREE.ExtrudeGeometry(formaEscudo(0.6, 1.08, 0.08), { depth: 0.04, bevelEnabled: true, bevelThickness: 0.015, bevelSize: 0.02, bevelSegments: 2 }),
  'armadura', grupoEscudo, { pos: [0, 0, -0.05] },
);
pieza(
  new THREE.ExtrudeGeometry(formaEscudo(0.5, 0.96, 0.065), { depth: 0.03, bevelEnabled: true, bevelThickness: 0.01, bevelSize: 0.012, bevelSegments: 2 }),
  'escudo', grupoEscudo, { pos: [0, 0, -0.01] },
);
// Alas grabadas y gema central.
for (const lado of [1, -1]) {
  for (let i = 0; i < 4; i++) {
    pieza(new THREE.BoxGeometry(0.17 - i * 0.025, 0.03, 0.02), 'armadura', grupoEscudo, {
      pos: [0.11 * lado, 0.22 - i * 0.07, 0.04],
      rot: [0, 0, -0.35 * lado],
    });
  }
}
pieza(new THREE.SphereGeometry(0.05, 16, 12), 'gemas', grupoEscudo, { pos: [0, 0.3, 0.045] });
ancla('escudo', grupoEscudo, [0.16, -0.25, 0.05]);

// --- Capa ------------------------------------------------------------------
const capaGeo = new THREE.CylinderGeometry(0.48, 0.8, 1.95, 40, 14, true, Math.PI * 0.6, Math.PI * 0.8);
const pos = capaGeo.attributes.position;
for (let i = 0; i < pos.count; i++) {
  const x = pos.getX(i);
  const y = pos.getY(i);
  const z = pos.getZ(i);
  const angulo = Math.atan2(x, z);
  const caida = (0.98 - y) / 1.95;
  const onda = Math.sin(angulo * 7) * 0.035 * caida;
  const radio = Math.hypot(x, z) + onda;
  pos.setXYZ(i, Math.sin(angulo) * radio, y, Math.cos(angulo) * radio);
}
capaGeo.computeVertexNormals();
const capa = pieza(capaGeo, 'capa', cuerpo, { pos: [0, 0.88, -0.06] });
capa.material.side = THREE.DoubleSide;
ancla('capa', cuerpo, [-0.42, 0.7, -0.45]);

// --- Cordones --------------------------------------------------------------
function cordon(puntos, grosor) {
  const curva = new THREE.CatmullRomCurve3(puntos.map(([x, y, z]) => new THREE.Vector3(x, y, z)));
  pieza(new THREE.TubeGeometry(curva, 40, grosor, 8), 'cordones', cuerpo);
}
cordon([[-0.36, 1.78, 0.18], [-0.25, 1.5, 0.33], [0.0, 1.38, 0.36], [0.22, 1.47, 0.33], [0.36, 1.74, 0.2]], 0.022);
cordon([[-0.3, 1.74, 0.22], [-0.18, 1.32, 0.36], [0.05, 1.22, 0.35], [0.26, 1.34, 0.32], [0.33, 1.7, 0.23]], 0.018);
cordon([[0.3, 1.32, 0.3], [0.34, 1.16, 0.34], [0.33, 0.98, 0.33]], 0.02);
ancla('cordones', cuerpo, [-0.22, 1.42, 0.36]);

// --- Gemas -----------------------------------------------------------------
for (const p of [[0, 1.48, 0.335], [0, 1.13, 0.31], [-0.17, 1.13, 0.27], [0.17, 1.13, 0.27]]) {
  pieza(new THREE.SphereGeometry(0.038, 16, 12), 'gemas', cuerpo, { pos: p });
}
pieza(new THREE.SphereGeometry(0.03, 14, 10), 'gemas', casco, { pos: [0, 0.3, 0.155] });
ancla('gemas', cuerpo, [0, 1.48, 0.36]);

// --- Magisterium Vexilla (solo Vexillarius) ---------------------------------
const vexilla = new THREE.Group();
vexilla.visible = false;
vexilla.position.set(0.72, 0, 0.22);
figura.add(vexilla);
pieza(new THREE.CylinderGeometry(0.025, 0.03, 3.0, 12), 'empunadura', vexilla, { pos: [0, 1.6, 0] });
pieza(new THREE.BoxGeometry(0.62, 0.95, 0.03), 'estandarte', vexilla, { pos: [0, 2.45, 0.03] });
pieza(new THREE.BoxGeometry(0.16, 0.7, 0.035), 'capa', vexilla, { pos: [0, 2.48, 0.05] });
pieza(new THREE.BoxGeometry(0.7, 0.05, 0.05), 'armadura', vexilla, { pos: [0, 2.94, 0.03] });
for (const lado of [1, -1]) {
  pieza(new THREE.BoxGeometry(0.34, 0.12, 0.03), 'estandarte', vexilla, { pos: [0.18 * lado, 3.18, 0.02], rot: [0, 0, 0.45 * lado] });
}
pieza(new THREE.SphereGeometry(0.07, 14, 10), 'estandarte', vexilla, { pos: [0, 3.1, 0.02] });
ancla('estandarte', vexilla, [0.24, 2.3, 0.06]);

// --- Estado que manda la app ------------------------------------------------

const ZONAS_METALICAS_POR_DEFECTO = new Set(['armadura', 'hoja']);
let resaltadas = new Set();
let etiquetas = [];

function colorZona(valor) {
  if (!valor) return { color: PLASTICO, metal: false, plastico: true };
  const metal = valor.endsWith('*');
  return { color: metal ? valor.slice(0, -1) : valor, metal, plastico: false };
}

function aplicar(estado = {}) {
  const colores = estado.zonas || {};
  for (const [nombre, z] of zonas) {
    const { color, metal, plastico } = colorZona(colores[nombre]);
    z.material.color.set(color);
    z.material.metalness = metal ? 0.92 : 0.02;
    z.material.roughness = plastico ? 0.82 : metal ? 0.3 : nombre === 'gemas' || nombre === 'ojos' ? 0.18 : 0.78;
    const brilla = !plastico && (nombre === 'gemas' || nombre === 'energia' || nombre === 'ojos');
    z.material.userData.brillo = brilla ? new THREE.Color(color).multiplyScalar(nombre === 'energia' ? 0.9 : 0.35) : null;
    z.material.emissive.set(0x000000);
  }
  const vex = Boolean(estado.vexilla);
  vexilla.visible = vex;
  escudo.visible = !vex;
  resaltadas = new Set(estado.resaltar || []);
  etiquetas = estado.etiquetas || [];
  if (typeof estado.giro === 'boolean') controls.autoRotate = estado.giro;
  pintarEtiquetas();
}

function pintarEtiquetas() {
  capaEtiquetas.innerHTML = '';
  for (const e of etiquetas) {
    const div = document.createElement('div');
    div.className = 'etiqueta' + (resaltadas.has(e.zona) ? ' activa' : '');
    const muestra = document.createElement('span');
    muestra.className = 'muestra';
    muestra.style.background = e.color || PLASTICO;
    div.appendChild(muestra);
    const texto = document.createElement('span');
    texto.textContent = e.nombre;
    div.appendChild(texto);
    if (e.detalle) {
      const pequeno = document.createElement('small');
      pequeno.textContent = e.detalle;
      div.appendChild(pequeno);
    }
    capaEtiquetas.appendChild(div);
    e.elemento = div;
  }
}

const vector = new THREE.Vector3();
const haciaCamara = new THREE.Vector3();

function colocarEtiquetas(ancho, alto) {
  if (!etiquetas.length) {
    capaLineas.innerHTML = '';
    return;
  }
  const lados = { izquierda: [], derecha: [] };
  for (const e of etiquetas) {
    const z = zonas.get(e.zona);
    if (!z || !z.anclas.length) {
      e.elemento.style.opacity = '0';
      continue;
    }
    // El ancla más cercana a la cámara de esa zona.
    let mejor = null;
    for (const a of z.anclas) {
      if (!a.parent.visible || (a.parent.parent && !a.parent.parent.visible && a.parent.parent !== scene)) continue;
      a.getWorldPosition(vector);
      const distancia = vector.distanceTo(camera.position);
      if (!mejor || distancia < mejor.distancia) mejor = { punto: vector.clone(), distancia };
    }
    if (!mejor) {
      e.elemento.style.opacity = '0';
      continue;
    }
    haciaCamara.copy(camera.position).sub(mejor.punto).normalize();
    const proyectado = mejor.punto.clone().project(camera);
    const x = (proyectado.x * 0.5 + 0.5) * ancho;
    const y = (-proyectado.y * 0.5 + 0.5) * alto;
    const lado = x < ancho / 2 ? 'izquierda' : 'derecha';
    lados[lado].push({ e, x, y });
  }
  let svg = '';
  for (const [lado, lista] of Object.entries(lados)) {
    lista.sort((a, b) => a.y - b.y);
    let ultimo = -Infinity;
    for (const item of lista) {
      const ly = Math.max(item.y, ultimo + 34);
      ultimo = ly;
      const el = item.e.elemento;
      el.style.opacity = '1';
      el.style.top = `${ly}px`;
      const anchoEtiqueta = el.offsetWidth;
      const margen = 14;
      let lx;
      if (lado === 'izquierda') {
        lx = margen;
        el.style.left = `${lx}px`;
        el.style.right = '';
        svg += linea(lx + anchoEtiqueta, ly, item.x, item.y, resaltadas.has(item.e.zona));
      } else {
        lx = ancho - margen - anchoEtiqueta;
        el.style.left = `${lx}px`;
        svg += linea(lx, ly, item.x, item.y, resaltadas.has(item.e.zona));
      }
    }
  }
  capaLineas.innerHTML = svg;
}

function linea(x1, y1, x2, y2, activa) {
  const color = activa ? '#f0c35a' : 'rgba(255,248,236,.55)';
  const codo = x1 + (x2 - x1) * 0.35;
  return `<path d="M${x1},${y1} L${codo},${y1} L${x2},${y2}" fill="none" stroke="${color}" stroke-width="${activa ? 2 : 1.3}"/>` +
    `<circle cx="${x2}" cy="${y2}" r="${activa ? 4.5 : 3.5}" fill="${color}" stroke="rgba(0,0,0,.4)"/>`;
}

function ajustar() {
  const ancho = window.innerWidth;
  const alto = window.innerHeight;
  renderer.setSize(ancho, alto, false);
  camera.aspect = ancho / Math.max(alto, 1);
  // Más distancia cuando el visor es estrecho para que la figura quepa.
  const distancia = camera.aspect < 0.8 ? 7.4 : 6.2;
  const dir = camera.position.clone().sub(controls.target).normalize();
  camera.position.copy(controls.target).add(dir.multiplyScalar(distancia));
  camera.updateProjectionMatrix();
}
window.addEventListener('resize', ajustar);
ajustar();

const reloj = new THREE.Clock();
function animar() {
  const t = reloj.getElapsedTime();
  const pulso = 0.35 + 0.25 * Math.sin(t * 4);
  for (const [nombre, z] of zonas) {
    if (resaltadas.has(nombre)) {
      z.material.emissive.copy(z.material.color).multiplyScalar(pulso * 0.9);
    } else if (z.material.userData.brillo) {
      z.material.emissive.copy(z.material.userData.brillo);
    } else {
      z.material.emissive.setRGB(0, 0, 0);
    }
  }
  if (!controls.autoRotate && ultimaInteraccion && performance.now() - ultimaInteraccion > 6000) {
    controls.autoRotate = true;
  }
  controls.update();
  renderer.render(scene, camera);
  colocarEtiquetas(window.innerWidth, window.innerHeight);
  requestAnimationFrame(animar);
}

window.miniatura = { aplicar };
// Fondo oscuro solo para vistas previas fuera de la app.
if (location.search.includes('fondo')) {
  document.body.style.background = 'radial-gradient(circle at 50% 40%, #3a2f25, #121010)';
}
try {
  const inicial = decodeURIComponent(location.hash.slice(1));
  aplicar(inicial ? JSON.parse(inicial) : {});
} catch (_) {
  aplicar({});
}
animar();
