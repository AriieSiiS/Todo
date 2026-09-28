import * as THREE from 'three';

function roundedShape(width, height, radius) {
  const shape = new THREE.Shape();
  const left = -width / 2;
  const right = width / 2;
  const bottom = -height / 2;
  const top = height / 2;
  shape.moveTo(left + radius, bottom);
  shape.lineTo(right - radius, bottom);
  shape.quadraticCurveTo(right, bottom, right, bottom + radius);
  shape.lineTo(right, top - radius);
  shape.quadraticCurveTo(right, top, right - radius, top);
  shape.lineTo(left + radius, top);
  shape.quadraticCurveTo(left, top, left, top - radius);
  shape.lineTo(left, bottom + radius);
  shape.quadraticCurveTo(left, bottom, left + radius, bottom);
  return shape;
}

export function createLightSwitch(root, {
  roomId = 'dormitorio',
  position = [0.15, 1.12, 1.989],
  rotationY = 0,
} = {}) {
  const switchGroup = new THREE.Group();
  switchGroup.name = `interruptor_luz_${roomId}`;
  switchGroup.position.set(...position);
  switchGroup.rotation.y = rotationY;
  switchGroup.userData.lightSwitchRoomId = roomId;
  root.add(switchGroup);

  const plate = new THREE.Mesh(
    new THREE.ExtrudeGeometry(roundedShape(0.086, 0.086, 0.008), {
      depth: 0.004, bevelEnabled: true, bevelSize: 0.002,
      bevelThickness: 0.002, bevelSegments: 3, curveSegments: 8,
    }),
    new THREE.MeshStandardMaterial({
      color: 0xe4e1d5, roughness: 0.42, metalness: 0.02,
    }),
  );
  plate.name = 'placa_interruptor_marfil';
  switchGroup.add(plate);

  const recess = new THREE.Mesh(
    new THREE.BoxGeometry(0.058, 0.064, 0.002),
    new THREE.MeshStandardMaterial({ color: 0xa7a69d, roughness: 0.85 }),
  );
  recess.name = 'hueco_de_la_tecla';
  recess.position.z = -0.0035;
  switchGroup.add(recess);

  const rocker = new THREE.Group();
  rocker.name = 'tecla_basculante';
  rocker.position.z = -0.007;
  switchGroup.add(rocker);
  const rockerMaterial = new THREE.MeshStandardMaterial({
    color: 0xf2f0e9, roughness: 0.49, metalness: 0.01,
  });
  const key = new THREE.Mesh(
    new THREE.ExtrudeGeometry(roundedShape(0.049, 0.055, 0.003), {
      depth: 0.003, bevelEnabled: true, bevelSize: 0.0009,
      bevelThickness: 0.001, bevelSegments: 2, curveSegments: 6,
    }),
    rockerMaterial,
  );
  key.name = 'tecla_interruptor';
  key.position.z = -0.003;
  rocker.add(key);

  const edge = new THREE.Mesh(
    new THREE.BoxGeometry(0.041, 0.001, 0.0006),
    new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.4 }),
  );
  edge.name = 'reflejo_borde_superior';
  edge.position.set(0, 0.021, -0.005);
  rocker.add(edge);

  const target = new THREE.Mesh(
    new THREE.BoxGeometry(0.12, 0.13, 0.014),
    new THREE.MeshBasicMaterial({
      transparent: true, opacity: 0, depthWrite: false,
    }),
  );
  target.name = 'zona_click_interruptor';
  target.position.z = -0.013;
  switchGroup.add(target);

  return {
    group: switchGroup,
    setOn(on) {
      rocker.rotation.x = on ? 0.085 : -0.085;
    },
  };
}

export function createHallwayLightSwitch(root) {
  // La placa mira hacia el pasillo, junto a la jamba derecha de Habitación.
  return createLightSwitch(root, {
    roomId: 'pasillo',
    position: [0.15, 1.12, 2.12],
    rotationY: Math.PI,
  });
}
