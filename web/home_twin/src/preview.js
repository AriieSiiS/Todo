// Vista local de la maqueta para ajustar posiciones sin compilar Todo.
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { addDeskDetails } from './desk_details.js';
import { placeDeskAgainstRightWall } from './desk_placement.js';
import { addDesktopOverlay } from './desktop_overlays.js';
import { createEntranceDoor } from './entrance_doors.js';
import { addHallwayDetails } from './hallway_details.js';
import { createHallwayLightSwitch } from './light_switch.js';
import { createSecondRoomLamp } from './second_room_lamp.js';

const status = document.getElementById('estado');
const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
// La vista de edición prioriza fluidez sobre resolución de pantalla completa.
renderer.setPixelRatio(Math.min(devicePixelRatio || 1, 1.25));
renderer.outputColorSpace = THREE.SRGBColorSpace;
document.body.appendChild(renderer.domElement);
const scene = new THREE.Scene();
scene.background = new THREE.Color(0xded1bd);
scene.add(new THREE.HemisphereLight(0xfff6e9, 0x777a68, 0.9));
const sun = new THREE.DirectionalLight(0xffead0, 1.1);
sun.position.set(-4, 9, 6);
scene.add(sun);
const camera = new THREE.PerspectiveCamera(48, 1, 0.005, 80);
const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.dampingFactor = 0.08;
controls.maxPolarAngle = Math.PI * 0.49;
// La rueda se acerca al punto bajo el cursor, no al centro de la habitación.
// Así se puede inspeccionar el ratón, las teclas y otras piezas pequeñas.
controls.zoomToCursor = true;
const roomRoots = new Map();
const entranceDoors = new Map();
const roomWalls = [];
const previewWindows = new Map();
const weatherLoader = new THREE.TextureLoader();
let pcRig;
let activeCameraRoomId = null;
let cameraSaveTimer = null;

function cameraStorageKey(roomId) {
  return `todo:maqueta:camara:${roomId}`;
}

function saveCamera() {
  clearTimeout(cameraSaveTimer);
  cameraSaveTimer = null;
  if (!activeCameraRoomId) return;
  try {
    localStorage.setItem(cameraStorageKey(activeCameraRoomId), JSON.stringify({
      position: camera.position.toArray(),
      target: controls.target.toArray(),
    }));
  } catch (error) {
    console.warn('No se pudo guardar la cámara de la vista previa.', error);
  }
}

function restoreCamera(roomId) {
  try {
    const saved = JSON.parse(localStorage.getItem(cameraStorageKey(roomId)));
    const validVector = (value) => Array.isArray(value)
      && value.length === 3 && value.every(Number.isFinite);
    if (!validVector(saved?.position) || !validVector(saved?.target)) return false;
    camera.position.fromArray(saved.position);
    controls.target.fromArray(saved.target);
    controls.update();
    return true;
  } catch (error) {
    console.warn('No se pudo recuperar la cámara de la vista previa.', error);
    return false;
  }
}

// Se guarda al mover la cámara y también justo antes de una recarga automática.
controls.addEventListener('change', () => {
  if (!activeCameraRoomId) return;
  clearTimeout(cameraSaveTimer);
  cameraSaveTimer = setTimeout(saveCamera, 150);
});
addEventListener('pagehide', saveCamera);

function resize() {
  camera.aspect = innerWidth / Math.max(innerHeight, 1);
  camera.updateProjectionMatrix();
  renderer.setSize(innerWidth, innerHeight);
}

function focus(node, close) {
  if (!node) return;
  const bounds = new THREE.Box3().setFromObject(node);
  if (bounds.isEmpty()) return;
  const center = bounds.getCenter(new THREE.Vector3());
  const size = bounds.getSize(new THREE.Vector3());
  const distance = close ? 1.1 : Math.max(3, Math.max(size.x, size.z, size.y) * 1.65);
  controls.target.copy(center);
  camera.position.copy(center).add(new THREE.Vector3(0.65, 0.65, 1).normalize().multiplyScalar(distance));
  controls.update();
}

function wallSide(name) {
  if (name.startsWith('pared_fondo_') || name.startsWith('pared_bajo_ventana') || name.startsWith('pared_sobre_ventana')) return 'fondo';
  if (name.startsWith('pared_entrada_')) return 'entrada';
  if (name.startsWith('pared_larga_izquierda')) return 'izquierda';
  if (name.startsWith('pared_larga_derecha')) return 'derecha';
  return null;
}

function updateWalls() {
  for (const { root, sides, roomId } of roomWalls) {
    root.updateWorldMatrix(true, false);
    const viewpoint = root.worldToLocal(camera.position.clone());
    const horizontal = Math.hypot(viewpoint.x, viewpoint.z) || 1;
    const direction = {
      izquierda: -viewpoint.x / horizontal,
      derecha: viewpoint.x / horizontal,
      fondo: -viewpoint.z / horizontal,
      entrada: viewpoint.z / horizontal,
    };
    for (const [side, walls] of sides) {
      const fade = THREE.MathUtils.smoothstep(direction[side], 0.08, 0.42);
      const streetWall = (roomId === 'dormitorio' || roomId === 'habitacion_vacia')
        && side === 'fondo';
      const opacity = streetWall ? 1 : 1 - fade;
      for (const wall of walls) {
        wall.material.opacity = opacity;
        wall.material.transparent = opacity < 0.98;
        wall.material.depthWrite = opacity >= 0.98;
        wall.visible = opacity > 0.02;
      }
    }
  }
}

function cropPanorama(texture, root, aspect) {
  const panoramaWidth = 1.32 * aspect;
  const panoramaLeft = 1.465 - panoramaWidth / 2;
  const glass = root.getObjectByName('cristal_ventana_vacia')
    || root.getObjectByName('cristal_ventana');
  const windowLeft = root.position.x + (glass?.position.x ?? 0.415) - 0.975 / 2;
  texture.repeat.set(0.975 / panoramaWidth, 1);
  texture.offset.set((windowLeft - panoramaLeft) / panoramaWidth, 0);
  texture.wrapS = THREE.ClampToEdgeWrapping;
}

function addWindow(root, roomId) {
  const empty = roomId === 'habitacion_vacia';
  const windowGroup = root.getObjectByName(empty ? 'ventana_vacia' : 'ventana');
  const blind = root.getObjectByName(empty ? 'persiana_ventana_vacia' : 'persiana_ventana');
  const bottom = root.getObjectByName(empty ? 'borde_inferior_persiana_vacia' : 'borde_inferior_persiana');
  const glass = root.getObjectByName(empty ? 'cristal_ventana_vacia' : 'cristal_ventana');
  if (!windowGroup || !blind || !bottom || !glass) return;
  const windowX = glass.position.x;
  glass.material = glass.material.clone();
  glass.material.opacity = 0.18;
  glass.material.transparent = true;
  glass.material.depthWrite = false;
  windowGroup.traverse((node) => {
    if (node.isMesh) node.userData.previewWindowRoomId = roomId;
  });
  const landscape = new THREE.Mesh(
    new THREE.PlaneGeometry(0.975, 1.32),
    new THREE.MeshBasicMaterial({ color: 0x819bb1, side: THREE.DoubleSide, toneMapped: false }),
  );
  landscape.name = `paisaje_exterior_${roomId}`;
  landscape.position.set(windowX, 1.585, -2.025);
  landscape.userData.previewWindowRoomId = roomId;
  root.add(landscape);
  previewWindows.set(roomId, {
    root, blind, bottom, landscape,
    centerY: blind.position.y,
    fullHeight: blind.scale.y,
    bottomY: bottom.position.y,
    fraction: 1,
    open: false,
    motion: null,
  });
  setWeather(document.getElementById('escena').value);
}

async function setWeather(name) {
  for (const window of previewWindows.values()) {
    const texture = await weatherLoader.loadAsync(`/weather/panorama_${name}.png`);
    texture.colorSpace = THREE.SRGBColorSpace;
    texture.magFilter = THREE.NearestFilter;
    texture.minFilter = THREE.LinearMipmapLinearFilter;
    cropPanorama(texture, window.root, texture.image.width / texture.image.height);
    window.landscape.material.map = texture;
    window.landscape.material.needsUpdate = true;
  }
}

function toggleWindow(roomId) {
  const window = previewWindows.get(roomId);
  if (!window) return;
  window.open = !window.open;
  window.motion = {
    from: window.fraction,
    to: window.open ? 0.04 : 1,
    start: performance.now(),
    duration: 650,
  };
}

function updateWindows(now) {
  for (const window of previewWindows.values()) {
    if (window.motion) {
      const progress = Math.min(1, (now - window.motion.start) / window.motion.duration);
      const eased = progress * progress * (3 - 2 * progress);
      window.fraction = THREE.MathUtils.lerp(window.motion.from, window.motion.to, eased);
      if (progress >= 1) window.motion = null;
    }
    window.blind.scale.y = window.fullHeight * window.fraction;
    window.blind.position.y = window.centerY + window.fullHeight * (1 - window.fraction) / 2;
    window.bottom.position.y = window.bottomY + window.fullHeight * (1 - window.fraction);
  }
}

// Fondos de ambos monitores: la preview usa imágenes fijas para ahorrar recursos.
// Los iconos y la barra de tareas son los mismos que se montan en Todo.
async function addMonitorWallpapers(root) {
  const hour = new Date().getHours();
  const rightTime = hour < 7 || hour >= 21 ? 'noche'
    : hour >= 17 ? 'atardecer' : 'dia';
  for (const [index, file] of [
    [1, 'monitor_izquierdo.png'],
    [2, `monitor_derecho_${rightTime}.png`],
  ]) {
    const screen = root.getObjectByName(`pantalla_${index}`);
    if (!screen?.parent) continue;
    addDesktopOverlay(root, index);
    try {
      const texture = await weatherLoader.loadAsync(`/wallpapers/${file}`);
      texture.colorSpace = THREE.SRGBColorSpace;
      texture.magFilter = THREE.NearestFilter;
      const wallpaper = new THREE.Mesh(
        new THREE.PlaneGeometry(screen.scale.x * 0.985, screen.scale.y * 0.985),
        new THREE.MeshBasicMaterial({ map: texture, toneMapped: false }),
      );
      wallpaper.name = `fondo_monitor_${index}_preview`;
      wallpaper.position.copy(screen.position);
      wallpaper.position.z += screen.scale.z / 2 + 0.003;
      screen.parent.add(wallpaper);
    } catch (error) {
      console.warn(`No se pudo cargar el fondo del monitor ${index}.`, error);
    }
  }
}

async function load() {
  try {
    const response = await fetch('/api/house');
    if (!response.ok) throw new Error('No se pudo leer la habitación.');
    const manifest = await response.json();
    if (!manifest.rooms?.length) throw new Error('No se encontraron habitaciones.');
    const selector = document.getElementById('habitacion');
    selector.replaceChildren(...manifest.rooms.map((room) => new Option(room.name, room.id)));
    // Una URL equivale a una sola habitación: al cambiarla se libera la escena anterior.
    const requestedId = new URL(location.href).searchParams.get('habitacion');
    const room = manifest.rooms.find((item) => item.id === requestedId)
      || manifest.rooms.find((item) => item.id === 'dormitorio')
      || manifest.rooms[0];
    selector.value = room.id;
    document.getElementById('enfocar-pc').hidden = room.id !== 'dormitorio';
    document.getElementById('persiana-dormitorio').hidden = room.id !== 'dormitorio';
    document.getElementById('persiana-vacia').hidden = room.id !== 'habitacion_vacia';
    const loader = new GLTFLoader();
    const gltf = await loader.loadAsync(`/${room.modelPath}`);
    const root = gltf.scene;
    root.position.set(room.position.x, room.position.y, room.position.z);
    root.rotation.y = (room.rotationDegrees || 0) * Math.PI / 180;
    if (room.id === 'dormitorio') placeDeskAgainstRightWall(root);
    const sides = new Map();
    root.traverse((node) => {
      if (!node.isMesh) return;
      const side = wallSide(node.name);
      if (!side) return;
      node.material = node.material.clone();
      if (!sides.has(side)) sides.set(side, []);
      sides.get(side).push(node);
    });
    roomWalls.push({ root, sides, roomId: room.id });
    scene.add(root);
    roomRoots.set(room.id, root);
    const entranceDoor = createEntranceDoor(root, room.id);
    if (entranceDoor) entranceDoors.set(room.id, entranceDoor);
    addWindow(root, room.id);
    if (room.id === 'pasillo' || room.id === 'cuarto_pasillo') {
      addHallwayDetails(root, room.id);
    }
    if (room.id === 'pasillo') createHallwayLightSwitch(root);
    if (room.id === 'habitacion_vacia') createSecondRoomLamp(root);
    focus(root, false);
    restoreCamera(room.id);
    activeCameraRoomId = room.id;
    if (room.id === 'dormitorio') {
      pcRig = addDeskDetails(root);
      await addMonitorWallpapers(root);
    }
    status.textContent = 'Arrastra para girar · Usa la rueda sobre un objeto para acercar · La cámara se conserva al recargar';
  } catch (error) {
    status.textContent = error.message || 'No se pudo cargar la vista previa.';
  }
}

document.getElementById('enfocar-pc').addEventListener('click', () => {
  focus(roomRoots.get('dormitorio')?.getObjectByName('torre_pc'), true);
});
document.getElementById('enfocar-habitacion').addEventListener('click', () => {
  focus(roomRoots.values().next().value, false);
});
document.getElementById('habitacion').addEventListener('change', (event) => {
  saveCamera();
  const url = new URL(location.href);
  url.searchParams.set('habitacion', event.target.value);
  location.assign(url.href);
});
document.getElementById('persiana-dormitorio').addEventListener('click', () => toggleWindow('dormitorio'));
document.getElementById('persiana-vacia').addEventListener('click', () => toggleWindow('habitacion_vacia'));
document.getElementById('escena').addEventListener('change', (event) => setWeather(event.target.value));
const raycaster = new THREE.Raycaster();
const pointer = new THREE.Vector2();
let down = null;
renderer.domElement.addEventListener('pointerdown', (event) => {
  down = [event.clientX, event.clientY];
});
renderer.domElement.addEventListener('pointerup', (event) => {
  if (!down || Math.hypot(event.clientX - down[0], event.clientY - down[1]) > 5) return;
  down = null;
  const rect = renderer.domElement.getBoundingClientRect();
  pointer.set(
    ((event.clientX - rect.left) / rect.width) * 2 - 1,
    -((event.clientY - rect.top) / rect.height) * 2 + 1,
  );
  raycaster.setFromCamera(pointer, camera);
  for (const hit of raycaster.intersectObjects([...roomRoots.values()], true)) {
    let hiddenAncestor = hit.object;
    while (hiddenAncestor?.visible) hiddenAncestor = hiddenAncestor.parent;
    if (hiddenAncestor) continue;
    if (wallSide(hit.object.name) && hit.object.material.opacity < 0.5) continue;
    const doorRoomId = hit.object.userData.entranceDoorRoomId;
    const windowRoomId = hit.object.userData.previewWindowRoomId;
    if (doorRoomId) {
      entranceDoors.get(doorRoomId)?.toggle();
      return;
    }
    if (windowRoomId) {
      toggleWindow(windowRoomId);
      return;
    }
  }
});
function animate(time) {
  pcRig?.update(time / 1000);
  for (const door of entranceDoors.values()) door.update(time);
  updateWindows(time);
  controls.update();
  updateWalls();
  renderer.render(scene, camera);
  requestAnimationFrame(animate);
}
addEventListener('resize', resize);
resize();
requestAnimationFrame(animate);
load();
