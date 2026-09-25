import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

const state = document.getElementById('estado');
const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.1;
document.body.appendChild(renderer.domElement);

const scene = new THREE.Scene();
const camera = new THREE.OrthographicCamera(-5, 5, 5, -5, 0.1, 200);
camera.position.set(8, 7, 9);
camera.lookAt(0, 0, 0);
const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.dampingFactor = 0.08;
controls.maxPolarAngle = Math.PI * 0.49;
controls.minDistance = 2;
controls.maxDistance = 40;
controls.screenSpacePanning = true;

scene.add(new THREE.HemisphereLight(0xfff6e9, 0x777a68, 1.8));
const sun = new THREE.DirectionalLight(0xffead0, 2.2);
sun.position.set(-4, 9, 6);
sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048);
sun.shadow.camera.left = -16;
sun.shadow.camera.right = 16;
sun.shadow.camera.top = 16;
sun.shadow.camera.bottom = -16;
sun.shadow.bias = -0.0002;
scene.add(sun);

const loader = new GLTFLoader();
const raycaster = new THREE.Raycaster();
const pointer = new THREE.Vector2();
const roots = [];
const rooms = new Map();
const wholeHouse = new THREE.Group();
scene.add(wholeHouse);
let selectedHelper = null;
let down = null;

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
  const bounds = new THREE.Box3().setFromObject(target);
  if (bounds.isEmpty()) return;
  const size = bounds.getSize(new THREE.Vector3());
  const center = bounds.getCenter(new THREE.Vector3());
  controls.target.copy(center);
  const radius = Math.max(size.x, size.z, size.y * 1.6, 2);
  camera.zoom = Math.min(2.1, Math.max(0.48, 5.5 / radius));
  camera.position.copy(center).add(new THREE.Vector3(8, 7, 9));
  camera.updateProjectionMatrix();
  controls.update();
}

function selectObject(roomId, objectId, node) {
  if (selectedHelper) scene.remove(selectedHelper);
  selectedHelper = new THREE.BoxHelper(node, 0x8ca76d);
  scene.add(selectedHelper);
  state.textContent = `Seleccionado: ${node.userData.twinObject.objectName}`;
  state.hidden = false;
  if (window.flutter_inappwebview) {
    window.flutter_inappwebview.callHandler('seleccionarObjeto', roomId, objectId);
  }
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
    let node = hit.object;
    while (node && !node.userData.twinObject) node = node.parent;
    if (node?.userData.twinObject) {
      const { roomId, objectId } = node.userData.twinObject;
      selectObject(roomId, objectId, node);
      return;
    }
  }
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
          node.castShadow = true;
          node.receiveShadow = true;
        }
      });
      for (const object of room.objects || []) {
        const node = root.getObjectByName(object.nodeName);
        if (node) node.userData.twinObject = {
          roomId: room.id,
          objectId: object.id,
          objectName: object.name,
        };
      }
      roots.push(root);
      rooms.set(room.id, root);
      wholeHouse.add(root);
    }
    frame(wholeHouse);
    state.hidden = true;
  } catch (error) {
    state.textContent = error?.message || 'No se pudo cargar la maqueta.';
  }
}

window.enfocarHabitacion = (roomId) => {
  const root = rooms.get(roomId);
  if (root) frame(root);
};
window.enfocarCasa = () => {
  if (roots.length) frame(wholeHouse);
};

function tick() {
  controls.update();
  renderer.render(scene, camera);
  requestAnimationFrame(tick);
}

window.addEventListener('resize', resize);
resize();
tick();
load();
