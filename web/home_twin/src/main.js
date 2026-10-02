import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { VirtualCottageAudio } from './virtual_cottage_audio.js';
import { addDeskDetails } from './desk_details.js';
import { placeDeskAgainstRightWall } from './desk_placement.js';
import { createEntranceDoor } from './entrance_doors.js';
import { createHallwayLightSwitch, createLightSwitch } from './light_switch.js';
import { addDesktopOverlay } from './desktop_overlays.js';
import { addHallwayDetails } from './hallway_details.js';
import { createSecondRoomLamp } from './second_room_lamp.js';
import { createEchoDot } from './echo_dot.js';
import { frameOrthographicCamera } from './camera_framing.js';

const state = document.getElementById('estado');
const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.shadowMap.enabled = false;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.0;
document.body.appendChild(renderer.domElement);

const scene = new THREE.Scene();
const camera = new THREE.OrthographicCamera(-5, 5, 5, -5, 0.1, 200);
camera.position.set(-8, 14, 9);
camera.lookAt(0, 0, 0);
camera.layers.enable(1);
const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.dampingFactor = 0.08;
controls.maxPolarAngle = Math.PI * 0.49;
controls.minDistance = 2;
controls.maxDistance = 40;
controls.screenSpacePanning = true;

scene.add(new THREE.HemisphereLight(0xfff6e9, 0x777a68, 0.66));
const sun = new THREE.DirectionalLight(0xffead0, 0.7);
sun.position.set(-4, 9, 6);
scene.add(sun);

const loader = new GLTFLoader();
const raycaster = new THREE.Raycaster();
const pointer = new THREE.Vector2();
const roots = [];
const rooms = new Map();
const entranceDoors = new Map();
const controllableObjects = new Map();
const ceilingLights = new Map();
const lightAnimations = new Set();
const lightSwitches = new Map();
let hallwayLamp = null;
let hallwayLightAnimation = null;
let latestHallwayLightState = null;
let secondRoomLamp = null;
let secondRoomLightAnimation = null;
let latestSecondRoomLightState = null;
const desktopOverlays = [];
let rightMonitorWallpaper = null;
let wardrobeDoor = null;
let pcFans = null;
const windowBlinds = new Map();
const outdoorScenes = new Map();
let latestEnvironment = null;
const latestBlindOpen = new Map();
const soundButton = document.getElementById('sonido');
const cottageAudio = new VirtualCottageAudio(
  soundButton,
  document.getElementById('panel-audio'),
  document.getElementById('audio-mute'),
);
const roomWalls = [];
let latestLightState = null;
const wholeHouse = new THREE.Group();
scene.add(wholeHouse);
let selectedHelper = null;
let down = null;
let pendingFocus = null;
let cameraTween = null;

function hasControls(room, object) {
  return object.id === 'ventana' || room.id === 'dormitorio' && ['luz_techo', 'echo_dot'].includes(object.id);
}

function weatherStyle(value) {
  const condition = value?.condition || 'unknown';
  const temperature = value?.temperatureC;
  const phase = timeOfDayScene(value);
  const night = ['noche', 'tarde_noche'].includes(phase);
  let sceneName = 'despejado';
  if (['lightning', 'lightning-rainy'].includes(condition)) sceneName = 'tormenta';
  else if (['rainy', 'pouring', 'hail', 'snowy-rainy'].includes(condition)) sceneName = 'lluvia';
  else if (condition === 'snowy') sceneName = 'frío';
  else if (['fog', 'exceptional'].includes(condition)) sceneName = 'niebla';
  else if (typeof temperature === 'number' && temperature < 18) sceneName = 'frío';
  else if (typeof temperature === 'number' && temperature >= 28) sceneName = 'calor';
  else if (['cloudy', 'partlycloudy', 'windy', 'windy-variant'].includes(condition)) sceneName = 'nublado';
  return { sceneName, night, phase };
}

function timeOfDayScene(value, now = new Date()) {
  if (value?.preview) {
    if (['madrugada', 'atardecer', 'tarde_noche', 'noche'].includes(value.timeScene)) {
      return value.timeScene;
    }
    return value.condition === 'clear-night' ? 'noche' : 'despejado';
  }
  const hour = now.getHours() + now.getMinutes() / 60;
  const elevation = !value?.stale && Number.isFinite(value?.sunElevation)
    ? value.sunElevation : null;
  if (elevation !== null) {
    if (hour < 12) {
      if (elevation < -10) return 'noche';
      return elevation < 10 ? 'madrugada' : 'despejado';
    }
    if (elevation >= 10) return 'despejado';
    if (elevation >= -1) return 'atardecer';
    return elevation >= -11 ? 'tarde_noche' : 'noche';
  }
  if (hour < 6 || hour >= 22) return 'noche';
  if (hour < 8) return 'madrugada';
  if (hour < 18) return 'despejado';
  if (hour < 20) return 'atardecer';
  return 'tarde_noche';
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

function createOutdoorScene(root, roomId) {
  const glassName = roomId === 'habitacion_vacia' ? 'cristal_ventana_vacia' : 'cristal_ventana';
  const glass = root.getObjectByName(glassName);
  const windowX = glass?.position.x ?? 0.415;
  if (glass?.isMesh) {
    glass.material = glass.material.clone();
    glass.material.opacity = 0.18;
    glass.material.transparent = true;
    glass.material.depthWrite = false;
  }
  const geometry = new THREE.PlaneGeometry(0.975, 1.32);
  const layers = new Map();
  const names = ['despejado', 'nublado', 'tormenta', 'noche',
    'madrugada', 'atardecer', 'tarde_noche'];
  for (const [index, name] of names.entries()) {
    const material = new THREE.MeshBasicMaterial({
      color: name === 'despejado' ? 0x819bb1 : 0xffffff,
      transparent: index !== 0,
      opacity: index === 0 ? 1 : 0,
      depthWrite: index === 0,
      side: THREE.DoubleSide,
      toneMapped: false,
    });
    const panel = new THREE.Mesh(geometry, material);
    panel.name = `paisaje_exterior_${name}`;
    panel.userData.windowSurfaceRoomId = roomId;
    panel.position.set(windowX, 1.585, -2.025 + index * 0.0004);
    panel.renderOrder = index;
    panel.visible = index === 0;
    root.add(panel);
    layers.set(name, panel);
  }
  const textureLoader = new THREE.TextureLoader();
  for (const name of names) {
    textureLoader.loadAsync(`/weather/panorama_${name}.png`).then((texture) => {
      texture.colorSpace = THREE.SRGBColorSpace;
      texture.minFilter = THREE.LinearMipmapLinearFilter;
      texture.magFilter = THREE.NearestFilter;
      const artAspect = texture.image.width / texture.image.height;
      cropPanorama(texture, root, artAspect);
      const panel = layers.get(name);
      panel.material.map = texture;
      panel.material.needsUpdate = true;
    }).catch((error) => {
      console.warn(`No se pudo cargar el paisaje ${name}.`, error);
    });
  }
  const canvas = document.createElement('canvas');
  canvas.width = 1536;
  canvas.height = 640;
  const context = canvas.getContext('2d');
  const overlayTexture = new THREE.CanvasTexture(canvas);
  cropPanorama(overlayTexture, root, canvas.width / canvas.height);
  const overlay = new THREE.Mesh(
    geometry,
    new THREE.MeshBasicMaterial({
      map: overlayTexture,
      transparent: true,
      opacity: 0.7,
      depthWrite: false,
      side: THREE.DoubleSide,
      toneMapped: false,
    }),
  );
  overlay.name = 'efectos_exteriores';
  overlay.userData.windowSurfaceRoomId = roomId;
  overlay.position.set(windowX, 1.585, -2.022);
  overlay.renderOrder = 6;
  overlay.visible = false;
  root.add(overlay);
  const daylight = new THREE.DirectionalLight(0xc8dcff, 0);
  daylight.position.set(windowX, 2.5, -2.8);
  daylight.target.position.set(windowX, 1.3, 0.2);
  root.add(daylight, daylight.target);
  return { layers, context, overlayTexture, overlay, daylight, lastDraw: 0 };
}

function drawOutdoorScene(seconds) {
  for (const [roomId, outdoor] of outdoorScenes) {
    const blind = windowBlinds.get(roomId);
    if (blind && blind.fraction >= 0.99) continue;
    drawOneOutdoorScene(outdoor, seconds);
  }
}

function drawOneOutdoorScene(outdoor, seconds) {
  const value = latestEnvironment || {};
  const { sceneName, night, phase } = weatherStyle(value);
  const selected = sceneName === 'tormenta' ? 'tormenta'
    : phase === 'despejado' && ['nublado', 'lluvia', 'niebla', 'frío'].includes(sceneName)
      ? 'nublado' : phase;
  for (const [name, panel] of outdoor.layers) {
    if (name === 'despejado') continue;
    const target = selected === name ? 1 : 0;
    panel.material.opacity += (target - panel.material.opacity) * 0.085;
    panel.visible = panel.material.map != null && panel.material.opacity > 0.005;
  }
  const tint = sceneName === 'calor' ? 0xfff2e1
    : sceneName === 'frío' ? 0xe8f2ff : 0xffffff;
  outdoor.layers.get(selected).material.color.setHex(tint);
  if (seconds - outdoor.lastDraw < 0.08) return;
  outdoor.lastDraw = seconds;
  const context = outdoor.context;
  const width = context.canvas.width;
  const height = context.canvas.height;
  context.clearRect(0, 0, width, height);
  // Las nubes cruzan lentamente el cielo sin tapar el paisaje dibujado.
  if (['despejado', 'nublado', 'calor', 'frío', 'niebla'].includes(sceneName) && !night) {
    const cloudCount = sceneName === 'nublado' ? 4 : 2;
    context.fillStyle = sceneName === 'nublado' ? '#e3eaf424' : '#fff9e922';
    for (let index = 0; index < cloudCount; index++) {
      const x = ((index * 169 + seconds * (sceneName === 'frío' ? 6 : 3)) % (width + 130)) - 110;
      const y = 85 + index * 64;
      context.fillRect(x + 16, y, 62, 8);
      context.fillRect(x, y + 8, 104, 12);
      context.fillRect(x + 22, y + 20, 68, 6);
    }
  }
  // Pequeños destellos sobre el lago mantienen viva la escena sin crear un foco.
  if (!['niebla', 'tormenta'].includes(sceneName)) {
    context.fillStyle = night ? '#aac3e555' : sceneName === 'calor' ? '#fff1c477' : '#edf8ff66';
    for (let index = 0; index < 22; index++) {
      const pulse = Math.sin(seconds * 2.2 + index * 2.7);
      if (pulse < 0.3) continue;
      const x = 35 + (index * 137) % (width - 80);
      const y = 430 + (index * 47) % 72;
      context.fillRect(x, y, 2 + Math.round(pulse * 7), 2);
    }
  }
  if (['lluvia', 'tormenta'].includes(sceneName)) {
    context.strokeStyle = '#dce8f26b';
    context.lineWidth = 1.6;
    for (let index = 0; index < (sceneName === 'tormenta' ? 52 : 35); index++) {
      const x = (index * 83 + 13) % width;
      const y = (index * 127 + seconds * (sceneName === 'tormenta' ? 190 : 130)) % height;
      context.beginPath();
      context.moveTo(x, y);
      context.lineTo(x - 7, y + 19);
      context.stroke();
    }
  }
  if (sceneName === 'frío') {
    context.fillStyle = '#f7fcfc';
    for (let index = 0; index < (value.condition === 'snowy' ? 52 : 12); index++) {
      const x = (index * 79 + Math.sin(seconds + index) * 22) % width;
      const y = (index * 113 + seconds * 35) % height;
      context.beginPath();
      context.arc(x, y, value.condition === 'snowy' ? 2.5 : 1.4, 0, Math.PI * 2);
      context.fill();
    }
  }
  if (sceneName === 'niebla') {
    for (let index = 0; index < 5; index++) {
      const x = ((seconds * (index % 2 ? -5 : 5) + index * 143) % 750 + 750) % 750 - 220;
      context.fillStyle = index % 2 ? '#e6e9e829' : '#e6e9e820';
      context.fillRect(x, 280 + index * 52, 330, 28);
    }
  }
  if (sceneName === 'calor') {
    context.fillStyle = '#ffe8ab38';
    for (let index = 0; index < 9; index++) {
      const x = (index * 97 + seconds * 9) % width;
      const y = 335 + (index * 61) % 200 + Math.sin(seconds * 1.5 + index) * 5;
      context.fillRect(x, y, 12, 2);
    }
  }
  if (night && !['tormenta', 'lluvia'].includes(sceneName)) {
    context.fillStyle = '#d8e7ff9c';
    for (let index = 0; index < 17; index++) {
      if (Math.sin(seconds * 1.7 + index * 2.3) < 0.35) continue;
      context.fillRect(18 + (index * 127) % (width - 36), 34 + (index * 83) % 238, 2, 2);
    }
  }
  if (sceneName === 'tormenta' && (seconds % 8 < 0.12 || seconds % 8 > 0.24 && seconds % 8 < 0.30)) {
    context.fillStyle = '#ffffff29';
    context.fillRect(0, 0, width, height);
  }
  outdoor.overlay.visible = true;
  outdoor.overlayTexture.needsUpdate = true;
}

window.actualizarAmbiente = (value) => {
  latestEnvironment = value;
  for (const outdoor of outdoorScenes.values()) outdoor.lastDraw = 0;
};

window.actualizarPersiana = (roomId, open) => {
  if (typeof roomId === 'boolean') {
    open = roomId;
    roomId = 'dormitorio';
  }
  const requested = !!open;
  const target = requested ? 0.04 : 1;
  const blind = windowBlinds.get(roomId);
  if (blind && latestBlindOpen.get(roomId) === requested
      && Math.abs((blind.transition?.to ?? blind.fraction) - target) < 0.001) return;
  latestBlindOpen.set(roomId, requested);
  if (!blind) return;
  blind.transition = {
    from: blind.fraction,
    to: target,
    start: performance.now(),
    duration: 650,
  };
};
window.actualizarPersianas = (values) => {
  for (const [roomId, open] of Object.entries(values || {})) {
    window.actualizarPersiana(roomId, open);
  }
};

async function addRightMonitorWallpaper(root) {
  const screen = root.getObjectByName('pantalla_2');
  if (!screen?.parent) return;
  const names = ['dia', 'atardecer', 'noche'];
  const textureLoader = new THREE.TextureLoader();
  const textures = await Promise.all(names.map((name) =>
    textureLoader.loadAsync(`/wallpapers/monitor_derecho_${name}.png`)));
  const materials = textures.map((texture, index) => {
    texture.colorSpace = THREE.SRGBColorSpace;
    texture.magFilter = THREE.NearestFilter;
    texture.minFilter = THREE.LinearMipmapLinearFilter;
    texture.wrapS = THREE.ClampToEdgeWrapping;
    texture.wrapT = THREE.ClampToEdgeWrapping;
    texture.repeat.set(0.94, 0.98);
    return new THREE.MeshBasicMaterial({
      map: texture,
      transparent: index !== 0,
      opacity: index === 0 ? 1 : 0,
      depthWrite: index === 0,
      toneMapped: false,
    });
  });
  for (let index = 0; index < materials.length; index++) {
    const image = new THREE.Mesh(
      new THREE.PlaneGeometry(screen.scale.x * 0.985, screen.scale.y * 0.985),
      materials[index],
    );
    image.name = `fondo_monitor_derecho_${names[index]}`;
    image.position.copy(screen.position);
    image.position.z += screen.scale.z / 2 + 0.003 + index * 0.0005;
    image.renderOrder = index + 1;
    screen.parent.add(image);
  }
  const video = document.createElement('video');
  video.src = '/wallpapers/monitor_derecho.mp4';
  video.autoplay = true;
  video.loop = true;
  video.muted = true;
  video.playsInline = true;
  video.preload = 'auto';
  const videoTexture = new THREE.VideoTexture(video);
  videoTexture.colorSpace = THREE.SRGBColorSpace;
  videoTexture.magFilter = THREE.LinearFilter;
  videoTexture.minFilter = THREE.LinearFilter;
  const videoMaterial = new THREE.MeshBasicMaterial({
    map: videoTexture,
    toneMapped: false,
  });
  const animated = new THREE.Mesh(
    new THREE.PlaneGeometry(screen.scale.x * 0.985, screen.scale.y * 0.985),
    videoMaterial,
  );
  animated.name = 'fondo_animado_monitor_derecho';
  animated.position.copy(screen.position);
  animated.position.z += screen.scale.z / 2 + 0.006;
  animated.renderOrder = 4;
  animated.visible = false;
  screen.parent.add(animated);
  video.addEventListener('playing', () => { animated.visible = true; });
  video.addEventListener('error', () => { animated.visible = false; });
  video.play().catch((error) => {
    console.warn('No se pudo reproducir el fondo animado del monitor derecho.', error);
  });
  rightMonitorWallpaper = { textures, materials, videoMaterial };
}

async function addLeftMonitorWallpaper(root) {
  const screen = root.getObjectByName('pantalla_1');
  if (!screen?.parent) return;
  const posterTexture = await new THREE.TextureLoader().loadAsync(
    '/wallpapers/monitor_izquierdo.png',
  );
  posterTexture.colorSpace = THREE.SRGBColorSpace;
  posterTexture.magFilter = THREE.NearestFilter;
  const geometry = new THREE.PlaneGeometry(
    screen.scale.x * 0.985,
    screen.scale.y * 0.985,
  );
  const poster = new THREE.Mesh(
    geometry,
    new THREE.MeshBasicMaterial({ map: posterTexture, toneMapped: false }),
  );
  poster.name = 'fondo_monitor_izquierdo';
  poster.position.copy(screen.position);
  poster.position.z += screen.scale.z / 2 + 0.003;
  screen.parent.add(poster);

  const video = document.createElement('video');
  video.src = '/wallpapers/monitor_izquierdo.mp4';
  video.autoplay = true;
  video.loop = true;
  video.muted = true;
  video.playsInline = true;
  video.preload = 'auto';
  const videoTexture = new THREE.VideoTexture(video);
  videoTexture.colorSpace = THREE.SRGBColorSpace;
  videoTexture.magFilter = THREE.NearestFilter;
  videoTexture.minFilter = THREE.LinearFilter;
  const animated = new THREE.Mesh(
    geometry,
    new THREE.MeshBasicMaterial({ map: videoTexture, toneMapped: false }),
  );
  animated.name = 'fondo_animado_monitor_izquierdo';
  animated.position.copy(poster.position);
  animated.position.z += 0.001;
  animated.visible = false;
  screen.parent.add(animated);
  video.addEventListener('playing', () => { animated.visible = true; });
  video.addEventListener('error', () => { animated.visible = false; });
  video.play().catch((error) => {
    console.warn('No se pudo reproducir el fondo animado del monitor izquierdo.', error);
  });
}

function updateRightMonitorWallpaper(seconds) {
  const wallpaper = rightMonitorWallpaper;
  if (!wallpaper) return;
  const now = new Date();
  const hour = now.getHours() + now.getMinutes() / 60;
  let dusk = 0;
  let night = 0;
  if (hour < 6.5 || hour >= 21) {
    night = 1;
  } else if (hour < 8.5) {
    night = 1 - (hour - 6.5) / 2;
  } else if (hour >= 17 && hour < 19) {
    dusk = (hour - 17) / 2;
  } else if (hour >= 19) {
    dusk = 1;
    night = (hour - 19) / 2;
  }
  wallpaper.materials[1].opacity = dusk;
  wallpaper.materials[2].opacity = night;
  const tint = new THREE.Color(0xffffff);
  tint.lerp(new THREE.Color(0xeab9a9), dusk * 0.25);
  tint.lerp(new THREE.Color(0x536aa3), night * 0.75);
  wallpaper.videoMaterial.color.copy(tint);
  const sway = Math.sin(seconds * 0.32) * 0.013 + Math.sin(seconds * 0.87) * 0.003;
  const rise = Math.sin(seconds * 0.25) * 0.003;
  for (const texture of wallpaper.textures) {
    texture.offset.set(0.03 + sway, 0.01 + rise);
  }
}

function createPendantLamp() {
  const group = new THREE.Group();
  group.name = 'lámpara_mimbre_modelada';
  group.position.z = 0.12;
  const wicker = new THREE.MeshStandardMaterial({ color: 0xa97948, roughness: 0.85, side: THREE.DoubleSide });
  const wickerEdge = new THREE.MeshStandardMaterial({ color: 0x825632, roughness: 0.88 });
  const ceilingWhite = new THREE.MeshStandardMaterial({ color: 0xe9e4db, roughness: 0.93 });
  const cable = new THREE.MeshStandardMaterial({ color: 0x282522, roughness: 0.78 });

  function ring(name, radius, height, thickness, material) {
    const mesh = new THREE.Mesh(new THREE.TorusGeometry(radius, thickness, 6, 80), material);
    mesh.name = name;
    mesh.rotation.x = Math.PI / 2;
    mesh.position.y = height;
    group.add(mesh);
  }

  function strandBetween(start, end, radius, material) {
    const direction = end.clone().sub(start);
    const mesh = new THREE.Mesh(new THREE.CylinderGeometry(radius, radius, direction.length(), 5), material);
    mesh.position.copy(start).add(end).multiplyScalar(0.5);
    mesh.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), direction.normalize());
    group.add(mesh);
  }

  function weave(name, profile, count, turn) {
    const lower = profile[0][0];
    const upper = profile[profile.length - 1][0];
    const radiusAt = (height) => {
      for (let index = 1; index < profile.length; index++) {
        if (height <= profile[index][0]) {
          const [lowY, lowR] = profile[index - 1];
          const [highY, highR] = profile[index];
          return THREE.MathUtils.lerp(lowR, highR, (height - lowY) / (highY - lowY));
        }
      }
      return profile[profile.length - 1][1];
    };
    const strands = [];
    for (const direction of [-1, 1]) {
      for (let index = 0; index < count; index++) {
        const startAngle = index * Math.PI * 2 / count;
        const points = [];
        for (let step = 0; step <= 14; step++) {
          const progress = step / 14;
          const height = THREE.MathUtils.lerp(lower, upper, progress);
          const angle = startAngle + direction * turn * progress;
          const radius = radiusAt(height);
          points.push(new THREE.Vector3(radius * Math.cos(angle), height, radius * Math.sin(angle)));
        }
        strands.push(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(points), 14, 0.0028, 4, false));
      }
    }
    const mesh = new THREE.Mesh(mergeGeometries(strands), wicker);
    mesh.name = name;
    group.add(mesh);
    for (const geometry of strands) geometry.dispose();
  }

  const medallion = new THREE.Mesh(new THREE.CylinderGeometry(0.15, 0.15, 0.025, 48), ceilingWhite);
  medallion.name = 'florón_circular';
  medallion.position.y = 3.085;
  group.add(medallion);
  ring('moldura_florón_exterior', 0.126, 3.068, 0.006, ceilingWhite);
  ring('moldura_florón_interior', 0.079, 3.058, 0.005, ceilingWhite);
  const cord = new THREE.Mesh(new THREE.TubeGeometry(new THREE.CatmullRomCurve3([
    new THREE.Vector3(0, 3.045, 0),
    new THREE.Vector3(0.025, 2.95, 0),
    new THREE.Vector3(0.04, 2.82, 0.005),
    new THREE.Vector3(0, 2.72, 0),
  ]), 24, 0.004, 6, false), cable);
  cord.name = 'cable_colgante';
  group.add(cord);

  const upperProfile = [[2.29, 0.405], [2.43, 0.425], [2.60, 0.375], [2.71, 0.285]];
  weave('trenzado_pantalla_superior', upperProfile, 58, 0.68);
  ring('aro_superior', 0.285, 2.71, 0.009, wickerEdge);
  ring('aro_central_superior', 0.425, 2.43, 0.007, wicker);
  ring('borde_pantalla_superior', 0.405, 2.29, 0.013, wickerEdge);

  const lowerProfile = [[2.055, 0.305], [2.18, 0.325], [2.37, 0.315]];
  weave('trenzado_pantalla_inferior', lowerProfile, 50, 0.62);
  ring('aro_pantalla_inferior', 0.315, 2.37, 0.009, wickerEdge);
  ring('borde_pantalla_inferior', 0.305, 2.055, 0.013, wickerEdge);

  for (const diagonal of [-1, 1]) {
    const along = new THREE.Vector2(1, diagonal).normalize();
    const across = new THREE.Vector2(-along.y, along.x);
    for (let index = -8; index <= 8; index++) {
      const offset = index * 0.035;
      const reach = Math.sqrt(0.285 ** 2 - offset ** 2);
      const center = across.clone().multiplyScalar(offset);
      const left = center.clone().addScaledVector(along, -reach);
      const right = center.addScaledVector(along, reach);
      strandBetween(
        new THREE.Vector3(left.x, 2.057, left.y),
        new THREE.Vector3(right.x, 2.057, right.y),
        0.0025,
        wicker,
      );
    }
  }

  const socket = new THREE.Mesh(new THREE.CylinderGeometry(0.035, 0.035, 0.08, 16), cable);
  socket.position.y = 2.69;
  group.add(socket);
  const bulb = new THREE.Mesh(
    new THREE.SphereGeometry(0.055, 20, 12),
    new THREE.MeshStandardMaterial({ color: 0xfff5df, emissive: 0xffffff, emissiveIntensity: 0 }),
  );
  bulb.name = 'bombilla_luz_techo_modelada';
  bulb.position.y = 2.58;
  group.add(bulb);
  return { group, bulb };
}

function createWickerProjection() {
  const canvas = document.createElement('canvas');
  canvas.width = 256;
  canvas.height = 256;
  const context = canvas.getContext('2d');
  const pixels = context.createImageData(canvas.width, canvas.height);
  const period = 14;
  for (let y = 0; y < canvas.height; y++) {
    for (let x = 0; x < canvas.width; x++) {
      const diagonalA = (x + y) % period;
      const diagonalB = (x - y + canvas.width * period) % period;
      const strand = Math.min(diagonalA, period - diagonalA) < 2
        || Math.min(diagonalB, period - diagonalB) < 2;
      const level = strand ? 112 : 255;
      const index = (y * canvas.width + x) * 4;
      pixels.data[index] = level;
      pixels.data[index + 1] = level;
      pixels.data[index + 2] = level;
      pixels.data[index + 3] = 255;
    }
  }
  context.putImageData(pixels, 0, 0);
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.minFilter = THREE.LinearFilter;
  texture.magFilter = THREE.LinearFilter;
  return texture;
}

function addWickerLightPattern(root, source) {
  const texture = createWickerProjection();
  const targets = [
    [-0.99, 1.75, 0.12], [0.99, 1.75, 0.12],
    [0, 1.75, -1.99], [0, 1.75, 1.99],
  ];
  root.updateWorldMatrix(true, true);
  return targets.map(([x, y, z]) => {
    const spot = new THREE.SpotLight(0xffffff, 0, 3.4, 0.76, 0.72, 1.5);
    spot.name = 'reflejo_trama_mimbre';
    spot.map = texture;
    spot.layers.set(1);
    spot.position.copy(source);
    spot.target.position.copy(root.localToWorld(new THREE.Vector3(x, y, z)));
    scene.add(spot, spot.target);
    return spot;
  });
}

function kelvinColor(kelvin) {
  const value = Math.max(1000, Math.min(40000, kelvin)) / 100;
  const red = value <= 66 ? 255 : 329.698727446 * (value - 60) ** -0.1332047592;
  const green = value <= 66
    ? 99.4708025861 * Math.log(value) - 161.1195681661
    : 288.1221695283 * (value - 60) ** -0.0755148492;
  const blue = value >= 66 ? 255 : value <= 19
    ? 0 : 138.5177312231 * Math.log(value - 10) - 305.0447927307;
  return new THREE.Color().setRGB(
    Math.max(0, Math.min(255, red)) / 255,
    Math.max(0, Math.min(255, green)) / 255,
    Math.max(0, Math.min(255, blue)) / 255,
    THREE.SRGBColorSpace,
  );
}

function applyLight(value) {
  latestLightState = value;
  lightSwitches.get(value.roomId)?.setOn(value.on);
  const rig = ceilingLights.get(`${value.roomId}/${value.objectId}`);
  if (!rig || !value.available) return;
  const color = Array.isArray(value.rgb) && value.rgb.length >= 3
    ? new THREE.Color().setRGB(
      value.rgb[0] / 255, value.rgb[1] / 255, value.rgb[2] / 255,
      THREE.SRGBColorSpace,
    )
    : kelvinColor(value.temperature || 3000);
  rig.light.color.copy(color);
  for (const spot of rig.patternLights) spot.color.copy(color);
  rig.bulb.traverse((mesh) => {
    if (!mesh.isMesh || !mesh.material?.emissive) return;
    mesh.material.emissive.copy(color);
  });
  updateLightAnimation(rig, value);
}

window.actualizarLuz = applyLight;

function createLightAnimation(setPower) {
  const animation = {
    setPower, on: null, power: 0, targetPower: 0,
    startPower: 0, transitionStart: 0, transitionDuration: 0,
  };
  lightAnimations.add(animation);
  return animation;
}

function updateLightAnimation(animation, value) {
  const power = value.on ? Math.max(0.02, Math.min(1, value.brightness / 255)) : 0;
  if (animation.on !== null && animation.on !== value.on) {
    animation.startPower = animation.power;
    animation.targetPower = power;
    animation.transitionStart = performance.now();
    animation.transitionDuration = Math.max(0, value.powerTransitionMs ?? 2000);
    if (animation.transitionDuration === 0) animation.power = power;
  } else if (animation.transitionDuration === 0) {
    animation.power = power;
    animation.targetPower = power;
  } else {
    animation.targetPower = power;
  }
  animation.on = value.on;
  animation.setPower(animation.power);
}

function applyHallwayLight(value) {
  latestHallwayLightState = value;
  lightSwitches.get('pasillo')?.setOn(value.on);
  if (!hallwayLamp || !value?.available) return;
  const color = Array.isArray(value.rgb) && value.rgb.length >= 3
    ? new THREE.Color().setRGB(
      value.rgb[0] / 255, value.rgb[1] / 255, value.rgb[2] / 255,
      THREE.SRGBColorSpace,
    )
    : kelvinColor(value.temperature || 3000);
  hallwayLamp.setColor(color);
  updateLightAnimation(hallwayLightAnimation, value);
}

window.actualizarLuzPasillo = applyHallwayLight;

function applySecondRoomLight(value) {
  latestSecondRoomLightState = value;
  if (!secondRoomLamp || !value?.available) return;
  const color = Array.isArray(value.rgb) && value.rgb.length >= 3
    ? new THREE.Color().setRGB(
      value.rgb[0] / 255, value.rgb[1] / 255, value.rgb[2] / 255,
      THREE.SRGBColorSpace,
    )
    : kelvinColor(value.temperature || 3000);
  secondRoomLamp.setColor(color);
  updateLightAnimation(secondRoomLightAnimation, value);
}

window.actualizarLuzSegundaHabitacion = applySecondRoomLight;

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
      const facing = direction[side];
      const fade = THREE.MathUtils.smoothstep(facing, 0.08, 0.42);
      // Los muros de ambas ventanas dan a la calle y permanecen cerrados.
      const streetWall = (roomId === 'dormitorio' || roomId === 'habitacion_vacia')
        && side === 'fondo';
      const partition = rooms.size > 1 && root === rooms.get('dormitorio') && side === 'derecha';
      const target = partition ? 1 - fade * 0.62 : 1 - fade;
      for (const wall of walls) {
        const material = wall.material;
        material.opacity = streetWall ? 1 : material.opacity + (target - material.opacity) * 0.18;
        const translucent = material.opacity < 0.98;
        if (material.transparent !== translucent) {
          material.transparent = translucent;
          material.depthWrite = !translucent;
          material.needsUpdate = true;
        }
        wall.visible = material.opacity > 0.02;
      }
    }
  }
}

function resize() {
  const width = window.innerWidth;
  const height = window.innerHeight;
  const aspect = width / Math.max(height, 1);
  const span = 5.5;
  camera.left = -span * aspect;
  camera.right = span * aspect;
  camera.top = span;
  camera.bottom = -span;
  camera.updateProjectionMatrix();
  renderer.setSize(width, height);
}

function frame(target) {
  cameraTween = null;
  const bounds = new THREE.Box3().setFromObject(target);
  if (bounds.isEmpty()) return;
  const direction = target === wholeHouse
    ? new THREE.Vector3(8, 14, 9)
    : new THREE.Vector3(-8, 14, 9)
      .applyQuaternion(target.getWorldQuaternion(new THREE.Quaternion()));
  const center = frameOrthographicCamera(camera, bounds, direction);
  controls.target.copy(center);
  // El alejamiento conserva al menos el 65 % del tamaño del encuadre inicial.
  controls.minZoom = camera.zoom * 0.65;
  controls.update();
}

function clearSelection(notifyFlutter = false) {
  const hadSelection = selectedHelper !== null;
  if (selectedHelper) scene.remove(selectedHelper);
  selectedHelper = null;
  state.hidden = true;
  if (notifyFlutter && hadSelection && new URLSearchParams(location.search).has('deselect')) {
    window.flutter_inappwebview?.callHandler('deseleccionarObjeto');
  }
}

function selectObject(roomId, objectId, node) {
  clearSelection();
  const highlight = node.getObjectByName('trenzado_pantalla_superior') || node;
  selectedHelper = new THREE.BoxHelper(highlight, 0x8ca76d);
  scene.add(selectedHelper);
  state.textContent = `Seleccionado: ${node.userData.twinObject.objectName}`;
  state.hidden = false;
  if (window.flutter_inappwebview) {
    window.flutter_inappwebview.callHandler('seleccionarObjeto', roomId, objectId);
  }
}

function slideWardrobeDoor() {
  if (!wardrobeDoor) return;
  clearSelection(true);
  wardrobeDoor.atLeft = !wardrobeDoor.atLeft;
  wardrobeDoor.transition = {
    from: wardrobeDoor.node.position.z,
    to: wardrobeDoor.atLeft ? -0.70 : 0,
    start: performance.now(),
    duration: 650,
  };
}

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
  for (const hit of raycaster.intersectObjects(roots, true)) {
    let hiddenAncestor = hit.object;
    while (hiddenAncestor?.visible) hiddenAncestor = hiddenAncestor.parent;
    if (hiddenAncestor) continue;
    if (wallSide(hit.object.name) && hit.object.material.opacity < 0.5) continue;
    let node = hit.object;
    while (node && !node.userData.twinObject && !node.userData.slidingWardrobeDoor && !node.userData.windowSurfaceRoomId && !node.userData.pcPowerButton && !node.userData.entranceDoorRoomId && !node.userData.lightSwitchRoomId && !node.userData.lightingTarget) {
      node = node.parent;
    }
    if (['pasillo', 'habitacion_vacia'].includes(node?.userData.lightingTarget?.roomId)) {
      const { roomId, objectId } = node.userData.lightingTarget;
      const lamp = controllableObjects.get(`${roomId}/${objectId}`);
      if (lamp) selectObject(roomId, objectId, lamp);
      return;
    }
    if (node?.userData.lightSwitchRoomId) {
      clearSelection();
      window.flutter_inappwebview?.callHandler('alternarInterruptorLuz', node.userData.lightSwitchRoomId);
      return;
    }
    if (node?.userData.entranceDoorRoomId) {
      clearSelection(true);
      entranceDoors.get(node.userData.entranceDoorRoomId)?.toggle();
      return;
    }
    if (node?.userData.pcPowerButton) {
      clearSelection(true);
      pcFans?.togglePower();
      return;
    }
    if (node?.userData.windowSurfaceRoomId) {
      clearSelection(true);
      window.flutter_inappwebview?.callHandler('alternarPersiana', node.userData.windowSurfaceRoomId);
      return;
    }
    if (node?.userData.slidingWardrobeDoor) {
      slideWardrobeDoor();
      return;
    }
    if (node?.userData.twinObject) {
      const { roomId, objectId } = node.userData.twinObject;
      selectObject(roomId, objectId, node);
      if (objectId === 'ventana') {
        window.flutter_inappwebview?.callHandler('alternarPersiana', roomId);
      }
      return;
    }
  }
  clearSelection(true);
});

async function load() {
  try {
    const response = await fetch('/api/house', { cache: 'no-store' });
    if (!response.ok) throw new Error('No se pudo leer la casa.');
    const manifest = await response.json();
    if (!manifest.rooms?.length) {
      state.textContent = 'Añade la primera habitación para ver tu casa.';
      return;
    }
    for (const room of manifest.rooms) {
      const gltf = await loader.loadAsync(`/${room.modelPath}`);
      const root = gltf.scene;
      root.position.set(room.position.x, room.position.y, room.position.z);
      root.rotation.y = (room.rotationDegrees || 0) * Math.PI / 180;
      root.traverse((node) => {
        if (node.isMesh) {
          node.receiveShadow = true;
        }
      });
      const sides = new Map();
      root.traverse((node) => {
        if (!node.isMesh) return;
        const side = wallSide(node.name);
        if (!side) return;
        node.material = node.material.clone();
        if (room.id === 'dormitorio') node.layers.enable(1);
        if (!sides.has(side)) sides.set(side, []);
        sides.get(side).push(node);
      });
      roomWalls.push({ root, sides, roomId: room.id });
      for (const object of room.objects || []) {
        const node = root.getObjectByName(object.nodeName);
        if (node && hasControls(room, object)) {
          node.userData.twinObject = {
          roomId: room.id,
          objectId: object.id,
          objectName: object.name,
          };
          controllableObjects.set(`${room.id}/${object.id}`, node);
        }
        if (node && room.id === 'dormitorio' && object.id === 'luz_techo') {
          node.traverse((part) => {
            if (part !== node) part.visible = false;
          });
          const pendant = createPendantLamp();
          node.add(pendant.group);
          const bulb = pendant.bulb;
          bulb.traverse((mesh) => {
            if (mesh.isMesh && mesh.material?.emissive) {
              mesh.material = mesh.material.clone();
              mesh.material.emissiveIntensity = 0;
            }
          });
          const lamp = new THREE.PointLight(0xffe6b7, 0, 6, 1.5);
          const bounds = new THREE.Box3().setFromObject(bulb);
          bounds.getCenter(lamp.position);
          scene.add(lamp);
          const patternLights = addWickerLightPattern(root, lamp.position);
          const animation = createLightAnimation((power) => {
            lamp.intensity = 6.5 * power;
            for (const spot of patternLights) spot.intensity = 4.5 * power;
            bulb.material.emissiveIntensity = 1.3 * power;
          });
          animation.light = lamp;
          animation.patternLights = patternLights;
          animation.bulb = bulb;
          ceilingLights.set(`${room.id}/${object.id}`, animation);
        }
      }
      const panel = root.getObjectByName(room.id === 'habitacion_vacia'
        ? 'persiana_ventana_vacia' : 'persiana_ventana');
      const bottom = root.getObjectByName(room.id === 'habitacion_vacia'
        ? 'borde_inferior_persiana_vacia' : 'borde_inferior_persiana');
      if (panel && bottom) {
        windowBlinds.set(room.id, {
          panel, bottom,
          centerY: panel.position.y,
          fullHeight: panel.scale.y,
          bottomY: bottom.position.y,
          fraction: 1,
          transition: null,
        });
        window.actualizarPersiana(room.id, latestBlindOpen.get(room.id) ?? false);
        outdoorScenes.set(room.id, createOutdoorScene(root, room.id));
      }
      if (room.id === 'dormitorio') {
        placeDeskAgainstRightWall(root);
        lightSwitches.set(room.id, createLightSwitch(root));
        pcFans = addDeskDetails(root);
        const echo = createEchoDot(root);
        if (echo) {
          echo.userData.twinObject = {
            roomId: room.id,
            objectId: 'echo_dot',
            objectName: 'Echo Dot',
          };
          controllableObjects.set('dormitorio/echo_dot', echo);
        }
        for (const index of [1, 2]) {
          const update = addDesktopOverlay(root, index);
          if (update) desktopOverlays.push(update);
        }
        const door = root.getObjectByName('puerta_corredera_armario');
        if (door) {
          door.userData.slidingWardrobeDoor = true;
          wardrobeDoor = { node: door, atLeft: false, transition: null };
        }
        try {
          await addRightMonitorWallpaper(root);
        } catch (error) {
          console.warn('No se pudo cargar el fondo del monitor derecho.', error);
        }
        try {
          await addLeftMonitorWallpaper(root);
        } catch (error) {
          console.warn('No se pudo cargar el fondo del monitor izquierdo.', error);
        }
      }
      if (room.id === 'pasillo' || room.id === 'cuarto_pasillo') {
        const details = addHallwayDetails(root, room.id);
        if (room.id === 'pasillo') {
          lightSwitches.set(room.id, createHallwayLightSwitch(root));
          hallwayLamp = details;
          if (details) {
            hallwayLightAnimation = createLightAnimation((power) => details.setPower(power));
          }
          if (details?.group) controllableObjects.set('pasillo/luz_pasillo', details.group);
        }
      }
      if (room.id === 'habitacion_vacia') {
        secondRoomLamp = createSecondRoomLamp(root);
        if (secondRoomLamp) {
          secondRoomLightAnimation = createLightAnimation(
            (power) => secondRoomLamp.setPower(power),
          );
        }
        if (secondRoomLamp?.group) {
          controllableObjects.set('habitacion_vacia/luz_techo', secondRoomLamp.group);
        }
      }
      const entranceDoor = createEntranceDoor(root, room.id);
      if (entranceDoor) entranceDoors.set(room.id, entranceDoor);
      roots.push(root);
      rooms.set(room.id, root);
      wholeHouse.add(root);
    }
    frame(wholeHouse);
    if (pendingFocus) {
      const [roomId, objectId] = pendingFocus;
      pendingFocus = null;
      window.enfocarObjeto(roomId, objectId);
    }
    if (latestLightState) applyLight(latestLightState);
    if (latestHallwayLightState) applyHallwayLight(latestHallwayLightState);
    if (latestSecondRoomLightState) applySecondRoomLight(latestSecondRoomLightState);
    state.hidden = true;
  } catch (error) {
    state.textContent = error?.message || 'No se pudo cargar la maqueta.';
  }
}

window.enfocarHabitacion = (roomId) => {
  clearSelection();
  const root = rooms.get(roomId);
  if (root) frame(root);
};
window.enfocarCasa = () => {
  clearSelection();
  if (roots.length) frame(wholeHouse);
};
window.alternarPuerta = (roomId) => entranceDoors.get(roomId)?.toggle();
window.enfocarObjeto = (roomId, objectId) => {
  const node = controllableObjects.get(`${roomId}/${objectId}`);
  if (!node) {
    pendingFocus = [roomId, objectId];
    return;
  }
  selectObject(roomId, objectId, node);
  const focusPart = node.getObjectByName('trenzado_pantalla_superior') || node;
  const center = new THREE.Box3().setFromObject(focusPart).getCenter(new THREE.Vector3());
  const direction = new THREE.Vector3(-6, 5, 7).normalize().multiplyScalar(5.5);
  cameraTween = {
    start: performance.now(),
    duration: 600,
    fromPosition: camera.position.clone(),
    toPosition: center.clone().add(direction),
    fromTarget: controls.target.clone(),
    toTarget: center,
    fromZoom: camera.zoom,
    toZoom: 4.2,
  };
};

function tick() {
  const now = performance.now();
  const seconds = now / 1000;
  if (Math.floor(seconds / 30) !== tick.desktopClockInterval) {
    tick.desktopClockInterval = Math.floor(seconds / 30);
    for (const update of desktopOverlays) update();
  }
  pcFans?.update(seconds);
  for (const door of entranceDoors.values()) door.update(now);
  updateRightMonitorWallpaper(seconds);
  drawOutdoorScene(seconds);
  const ambienceStyle = weatherStyle(latestEnvironment || {});
  const openFraction = Math.min(1, ...[...windowBlinds.values()].map((blind) => blind.fraction));
  cottageAudio.updateWeather(ambienceStyle.sceneName, ambienceStyle.night, openFraction);
  for (const [roomId, blind] of windowBlinds) {
    if (blind.transition) {
      const motion = blind.transition;
      const progress = Math.min(1, (performance.now() - motion.start) / motion.duration);
      const eased = progress * progress * (3 - 2 * progress);
      blind.fraction = THREE.MathUtils.lerp(motion.from, motion.to, eased);
      if (progress >= 1) blind.transition = null;
    }
    blind.panel.scale.y = blind.fullHeight * blind.fraction;
    blind.panel.position.y = blind.centerY + blind.fullHeight * (1 - blind.fraction) / 2;
    blind.bottom.position.y = blind.bottomY + blind.fullHeight * (1 - blind.fraction);
    const outdoorScene = outdoorScenes.get(roomId);
    if (outdoorScene) {
      const value = latestEnvironment || {};
      const { sceneName, night } = weatherStyle(value);
      const cloudFactor = ['tormenta', 'lluvia', 'niebla', 'nublado'].includes(sceneName) ? 0.48 : 1;
      const sunFactor = night ? 0.09 : Math.max(0.25, Math.min(1, (value.sunElevation ?? 35) / 35));
      const staleFactor = value.stale ? 0.6 : 1;
      const amount = (1 - blind.fraction) * cloudFactor * sunFactor * staleFactor;
      outdoorScene.daylight.intensity += (0.28 * amount - outdoorScene.daylight.intensity) * 0.1;
      outdoorScene.daylight.color.set(sceneName === 'calor' ? 0xffd8ad : night ? 0x9eafe3 : 0xc8dcff);
    }
  }
  if (wardrobeDoor?.transition) {
    const motion = wardrobeDoor.transition;
    const progress = Math.min(1, (performance.now() - motion.start) / motion.duration);
    const eased = progress * progress * (3 - 2 * progress);
    wardrobeDoor.node.position.z = THREE.MathUtils.lerp(motion.from, motion.to, eased);
    if (progress >= 1) wardrobeDoor.transition = null;
  }
  if (cameraTween) {
    const progress = Math.min(1, (performance.now() - cameraTween.start) / cameraTween.duration);
    const eased = progress * progress * (3 - 2 * progress);
    camera.position.lerpVectors(cameraTween.fromPosition, cameraTween.toPosition, eased);
    controls.target.lerpVectors(cameraTween.fromTarget, cameraTween.toTarget, eased);
    camera.zoom = THREE.MathUtils.lerp(cameraTween.fromZoom, cameraTween.toZoom, eased);
    camera.updateProjectionMatrix();
    if (progress >= 1) cameraTween = null;
  }
  controls.update();
  updateWalls();
  for (const rig of lightAnimations) {
    if (rig.transitionDuration > 0) {
      const progress = Math.min(1, (performance.now() - rig.transitionStart) / rig.transitionDuration);
      const eased = progress * progress * (3 - 2 * progress);
      rig.power = THREE.MathUtils.lerp(rig.startPower, rig.targetPower, eased);
      if (progress >= 1) rig.transitionDuration = 0;
    }
    rig.setPower(rig.power);
  }
  renderer.render(scene, camera);
  requestAnimationFrame(tick);
}

window.addEventListener('resize', resize);
resize();
tick();
load();
