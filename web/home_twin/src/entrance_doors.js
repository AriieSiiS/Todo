import * as THREE from 'three';

const DOOR_LEFT = -0.88;
const DOOR_FRONT = 2.05;

const GLASS_WIDTH = 0.26;
const GLASS_HEIGHT = 0.30;
const GLASS_GAP = 0.03;
const GLASS_BOTTOM = 0.45;
const LEAF_WIDTH = 0.73;
const LEAF_HEIGHT = 2.15;

function createSwingDoor(root, roomId, config) {
  const leaves = config.leafNames.map((name) => root.getObjectByName(name));
  if (leaves.some((part) => !part)) return null;

  const hinge = new THREE.Group();
  hinge.name = `bisagra_puerta_${roomId}`;
  hinge.position.set(...config.hinge);
  root.add(hinge);
  root.updateWorldMatrix(true, true);
  for (const part of leaves) {
    hinge.attach(part);
    if (!config.interactionTargetName) part.userData.entranceDoorRoomId = roomId;
  }
  if (config.interactionTargetName) {
    const target = hinge.getObjectByName(config.interactionTargetName);
    if (target) target.userData.entranceDoorRoomId = roomId;
  }

  hinge.rotation.y = config.closedAngle;
  let open = false;
  let motion = null;
  return {
    toggle() {
      open = !open;
      motion = {
        from: hinge.rotation.y,
        to: open ? config.openAngle : config.closedAngle,
        start: performance.now(),
        duration: 720,
      };
    },
    update(now) {
      if (!motion) return;
      const progress = Math.min(1, (now - motion.start) / motion.duration);
      const eased = progress * progress * (3 - 2 * progress);
      hinge.rotation.y = THREE.MathUtils.lerp(motion.from, motion.to, eased);
      if (progress >= 1) motion = null;
    },
  };
}

function createGlazedDoor(root, roomId) {
  const corridorRoom = roomId === 'cuarto_pasillo';
  // La hoja sigue las jambas del modelo cuando se ajustan las medidas del pasillo.
  const left = corridorRoom
    ? root.getObjectByName('marco_puerta_habitacion_pasillo_izquierdo')?.position.x
    : roomId === 'habitacion_vacia'
      ? root.getObjectByName('marco_puerta_izquierdo_vacia')?.position.x
      : DOOR_LEFT;
  const right = corridorRoom
    ? root.getObjectByName('marco_puerta_habitacion_pasillo_derecho')?.position.x
    : roomId === 'habitacion_vacia'
      ? root.getObjectByName('marco_puerta_derecho_vacia')?.position.x
      : -0.06;
  const z = corridorRoom
    ? root.getObjectByName('marco_puerta_habitacion_pasillo_superior')?.position.z
    : DOOR_FRONT;
  if (left == null || right == null || z == null) return null;
  const outside = corridorRoom ? -1 : 1;
  const center = (left + right) / 2;

  // Las tres habitaciones usan la misma hoja y el mismo marco. Se ocultan las
  // piezas antiguas del GLB sin modificar los generadores de cada habitación.
  const oldParts = corridorRoom
    ? [
        'hoja_puerta_habitacion_pasillo', 'tirador_puerta_habitacion_pasillo',
        'marco_puerta_habitacion_pasillo_izquierdo',
        'marco_puerta_habitacion_pasillo_derecho',
        'marco_puerta_habitacion_pasillo_superior',
      ]
    : roomId === 'habitacion_vacia'
      ? [
          'hoja_puerta_vacia_izquierdo', 'hoja_puerta_vacia_derecho',
          'hoja_puerta_vacia_superior', 'hoja_puerta_vacia_inferior',
          'cristales_puerta_vacia', 'parteluz_puerta_vacia',
          'tirador_puerta_vacia',
          ...[1, 2, 3].map((index) => `travesaño_puerta_vacia_${index}`),
          'marco_puerta_izquierdo_vacia', 'marco_puerta_derecho_vacia',
          'marco_puerta_arriba_vacia',
        ]
      : [
          'puerta', 'marco_puerta_izquierdo',
          'marco_puerta_derecho', 'marco_puerta_arriba',
        ];
  for (const name of oldParts) {
    const oldPart = root.getObjectByName(name);
    if (oldPart) oldPart.visible = false;
  }

  const white = new THREE.MeshStandardMaterial({ color: 0xe7e3d9, roughness: 0.78 });
  const edge = new THREE.MeshStandardMaterial({ color: 0xf4f0e7, roughness: 0.68 });
  const recess = new THREE.MeshStandardMaterial({ color: 0xcfc9be, roughness: 0.9 });
  const brass = new THREE.MeshStandardMaterial({
    color: 0x8a6840, metalness: 0.63, roughness: 0.42,
  });
  const frosted = new THREE.MeshStandardMaterial({
    color: 0xc5d0cc, transparent: true, opacity: 0.53,
    roughness: 0.83, metalness: 0, depthWrite: false,
    side: THREE.DoubleSide,
  });
  const etched = new THREE.LineBasicMaterial({
    color: 0xecefe9, transparent: true, opacity: 0.22,
    depthWrite: false,
  });
  const frame = new THREE.Group();
  frame.name = `marco_cristales_${roomId}`;
  root.add(frame);
  const leaf = new THREE.Group();
  leaf.name = `hoja_cristales_${roomId}`;
  root.add(leaf);

  function piece(parent, name, material, x, y, zPosition, width, height, depth) {
    const mesh = new THREE.Mesh(new THREE.BoxGeometry(width, height, depth), material);
    mesh.name = name;
    mesh.position.set(x, y, zPosition);
    parent.add(mesh);
    return mesh;
  }

  // Marco fijo: jambas, dintel y una moldura sobre la cara del pasillo.
  for (const [side, x] of [['izquierda', left], ['derecha', right]]) {
    piece(frame, `jamba_${side}`, white, x, 1.10, z, 0.065, 2.20, 0.125);
    piece(frame, `moldura_jamba_${side}`, edge,
      x + (side === 'izquierda' ? -0.024 : 0.024), 1.10,
      z + outside * 0.066, 0.022, 2.22, 0.018);
  }
  piece(frame, 'dintel', white, center, 2.19, z,
    right - left + 0.13, 0.075, 0.125);
  piece(frame, 'moldura_dintel', edge,
    center, 2.215, z + outside * 0.066,
    right - left + 0.18, 0.025, 0.018);

  // Hoja de 73 × 215 cm: costados de 9 cm y dos columnas de cristales de 26 cm.
  for (const [side, x] of [
    ['izquierdo', center - LEAF_WIDTH / 2 + 0.045],
    ['derecho', center + LEAF_WIDTH / 2 - 0.045],
  ]) {
    piece(leaf, `larguero_${side}`, white,
      x, LEAF_HEIGHT / 2, z, 0.09, LEAF_HEIGHT, 0.045);
    piece(leaf, `filete_larguero_${side}`, edge,
      x, LEAF_HEIGHT / 2, z + outside * 0.025,
      0.012, LEAF_HEIGHT - 0.04, 0.006);
  }
  piece(leaf, 'travesaño_superior_9_cm', white,
    center, 2.11, z, LEAF_WIDTH, 0.08, 0.045);
  piece(leaf, 'parteluz_central_3_cm', white,
    center, (GLASS_BOTTOM + 2.07) / 2, z,
    GLASS_GAP, 2.07 - GLASS_BOTTOM, 0.045);

  // Los cristales empiezan a 45 cm del suelo: cinco filas de 30 cm, con 3 cm
  // entre filas. El tamaño y los huecos siguen las medidas aportadas.
  for (let row = 0; row < 5; row++) {
    const bottom = GLASS_BOTTOM + row * (GLASS_HEIGHT + GLASS_GAP);
    const y = bottom + GLASS_HEIGHT / 2;
    if (row < 4) {
      piece(leaf, `travesaño_entre_filas_${row + 1}`, white,
        center, bottom + GLASS_HEIGHT + GLASS_GAP / 2, z,
        LEAF_WIDTH - 0.18, GLASS_GAP, 0.045);
    }
    for (const [side, sign] of [['izquierdo', -1], ['derecho', 1]]) {
      const x = center + sign * (GLASS_WIDTH + GLASS_GAP) / 2;
      piece(leaf, `cristal_${side}_fila_${row + 1}`, frosted,
        x, y, z, GLASS_WIDTH, GLASS_HEIGHT, 0.012);
      // El mismo grabado tenue aparece en las dos caras de los diez cristales.
      for (const [faceName, faceSign] of [['exterior', outside], ['interior', -outside]]) {
        const lines = [];
        for (const offset of [-0.073, 0, 0.073]) {
          const cx = x + offset;
          const cy = y + 0.018;
          const radius = 0.024;
          const depth = z + faceSign * 0.008;
          lines.push(
            cx, cy + radius, depth, cx + radius, cy, depth,
            cx + radius, cy, depth, cx, cy - radius, depth,
            cx, cy - radius, depth, cx - radius, cy, depth,
            cx - radius, cy, depth, cx, cy + radius, depth,
          );
        }
        const engraving = new THREE.LineSegments(
          new THREE.BufferGeometry().setAttribute(
            'position', new THREE.Float32BufferAttribute(lines, 3),
          ), etched,
        );
        engraving.name = `grabado_cristal_${side}_fila_${row + 1}_${faceName}`;
        leaf.add(engraving);
      }
      const face = z + outside * 0.027;
      for (const [edgeName, edgeX] of [
        ['izquierda', x - GLASS_WIDTH / 2],
        ['derecha', x + GLASS_WIDTH / 2],
      ]) {
        piece(leaf, `junquillo_${side}_${row + 1}_${edgeName}`, edge,
          edgeX, y, face, 0.008, GLASS_HEIGHT + 0.008, 0.008);
      }
      for (const [edgeName, edgeY] of [
        ['inferior', bottom], ['superior', bottom + GLASS_HEIGHT],
      ]) {
        piece(leaf, `junquillo_${side}_${row + 1}_${edgeName}`, edge,
          x, edgeY, face, GLASS_WIDTH + 0.008, 0.008, 0.008);
      }
    }
  }

  // Dos paneles inferiores de madera embutida: no hay cristal en los 45 cm bajos.
  piece(leaf, 'zócalo_madera_inferior', white,
    center, GLASS_BOTTOM / 2, z, LEAF_WIDTH, GLASS_BOTTOM, 0.045);
  for (const [side, sign] of [['izquierdo', -1], ['derecho', 1]]) {
    const x = center + sign * (GLASS_WIDTH + GLASS_GAP) / 2;
    const face = z + outside * 0.026;
    piece(leaf, `panel_madera_${side}`, recess,
      x, 0.235, face, GLASS_WIDTH, 0.32, 0.006);
    for (const [edgeName, edgeX] of [
      ['izquierda', x - GLASS_WIDTH / 2],
      ['derecha', x + GLASS_WIDTH / 2],
    ]) {
      piece(leaf, `moldura_panel_${side}_${edgeName}`, edge,
        edgeX, 0.235, face + outside * 0.005,
        0.013, 0.34, 0.008);
    }
    for (const [edgeName, edgeY] of [
      ['inferior', 0.075], ['superior', 0.395],
    ]) {
      piece(leaf, `moldura_panel_${side}_${edgeName}`, edge,
        x, edgeY, face + outside * 0.005,
        GLASS_WIDTH + 0.012, 0.013, 0.008);
    }
  }

  // Mano invertida: bisagras a la izquierda y manilla a la derecha.
  const handleX = center + LEAF_WIDTH / 2 - 0.056;
  for (const [faceName, faceSign] of [['exterior', outside], ['interior', -outside]]) {
    const handleZ = z + faceSign * 0.039;
    piece(leaf, `placa_manilla_${faceName}`, brass,
      handleX, 0.91, handleZ, 0.043, 0.18, 0.013);
    piece(leaf, `eje_manilla_${faceName}`, brass,
      handleX, 0.96, handleZ + faceSign * 0.021, 0.019, 0.019, 0.04);
    piece(leaf, `manilla_horizontal_${faceName}`, brass,
      handleX - 0.055, 0.96, handleZ + faceSign * 0.040,
      0.13, 0.022, 0.024);
  }
  for (const [index, y] of [0.31, 1.09, 1.87].entries()) {
    piece(leaf, `bisagra_visible_${index + 1}`, brass,
      center - LEAF_WIDTH / 2, y, z + outside * 0.012,
      0.019, 0.075, 0.029);
  }

  // Solo esta hoja recibe clics; el marco y el hueco alrededor quedan fuera.
  const interactionTarget = new THREE.Mesh(
    new THREE.BoxGeometry(LEAF_WIDTH, LEAF_HEIGHT, 0.24),
    new THREE.MeshBasicMaterial({ transparent: true, opacity: 0, depthWrite: false, colorWrite: false }),
  );
  interactionTarget.name = `zona_interaccion_hoja_${roomId}`;
  interactionTarget.position.set(center, LEAF_HEIGHT / 2, z);
  leaf.add(interactionTarget);

  return createSwingDoor(root, roomId, {
    leafNames: [leaf.name],
    interactionTargetName: interactionTarget.name,
    hinge: [center - LEAF_WIDTH / 2, 0, z],
    closedAngle: 0,
    openAngle: -outside * Math.PI / 2,
  });
}

export function createEntranceDoor(root, roomId) {
  if (roomId === 'bano') {
    const jamb = root.getObjectByName('marco_entrada_bano_sur');
    const leaf = root.getObjectByName('hoja_puerta_bano');
    if (!jamb || !leaf) return null;
    return createSwingDoor(root, roomId, {
      leafNames: [
        'hoja_puerta_bano', 'tirador_puerta_bano', 'placa_tirador_puerta_bano',
        ...['superior', 'central'].flatMap((panel) => [
          `panel_${panel}_puerta_bano`,
          ...['izquierda', 'derecha', 'arriba', 'abajo']
            .map((side) => `moldura_${panel}_${side}_puerta_bano`),
        ]),
        ...[1, 2, 3, 4].map((index) => `veta_vertical_${index}_puerta_bano`),
        ...[1, 2].map((index) => `bisagra_${index}_puerta_bano`),
      ],
      hinge: [jamb.position.x, 0, leaf.position.z],
      closedAngle: 0,
      openAngle: Math.PI / 2,
    });
  }
  if (['dormitorio', 'habitacion_vacia', 'cuarto_pasillo'].includes(roomId)) {
    return createGlazedDoor(root, roomId);
  }
  return null;
}
