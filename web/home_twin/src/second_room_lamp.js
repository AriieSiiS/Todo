import * as THREE from 'three';

const CEILING = 3.08;
const SHADE_TOP = 1.84;
const SHADE_BOTTOM = 1.49;
const SHADE_RAISE = (2.864 - SHADE_TOP) / 2;

function fabricTexture() {
  const canvas = document.createElement('canvas');
  canvas.width = 1024;
  canvas.height = 512;
  const context = canvas.getContext('2d');
  context.fillStyle = '#e9dcc5';
  context.fillRect(0, 0, canvas.width, canvas.height);

  // Trama y pequeñas irregularidades del tejido crema de la pantalla real.
  let seed = 41;
  const random = () => {
    seed = (seed * 1664525 + 1013904223) >>> 0;
    return seed / 4294967296;
  };
  for (let index = 0; index < 18000; index++) {
    const x = random() * canvas.width;
    const y = random() * canvas.height;
    context.fillStyle = index % 3 === 0 ? '#fff8e72c' : '#9d88671c';
    context.fillRect(x, y, 1 + random() * 2, 1 + random() * 3);
  }
  context.lineWidth = 2;
  context.strokeStyle = '#af9e7952';
  for (let motif = 0; motif < 13; motif++) {
    const x = motif * 82 + 16;
    const y = 130 + (motif % 3) * 73;
    context.beginPath();
    context.moveTo(x - 30, y + 42);
    context.bezierCurveTo(x + 22, y + 10, x - 12, y - 25, x + 30, y - 50);
    context.stroke();
    for (const side of [-1, 1]) {
      context.beginPath();
      context.ellipse(x + side * 17, y - 6, 17, 5, side * 0.55, 0, Math.PI * 2);
      context.stroke();
      context.beginPath();
      context.ellipse(x + side * 7, y + 22, 12, 4, side * 0.7, 0, Math.PI * 2);
      context.stroke();
    }
  }
  for (let index = 0; index < 170; index++) {
    const x = random() * canvas.width;
    const y = random() * canvas.height;
    const size = random() * 4 + 1;
    context.fillStyle = '#9d76512c';
    context.beginPath();
    context.ellipse(x, y, size, size * 0.5, random(), 0, Math.PI * 2);
    context.fill();
  }
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.wrapS = THREE.RepeatWrapping;
  texture.anisotropy = 8;
  return texture;
}

function addRosette(group, plaster, relief) {
  const disk = new THREE.Mesh(
    new THREE.CylinderGeometry(0.295, 0.295, 0.018, 96), plaster,
  );
  disk.name = 'disco_estuco_roseton';
  disk.position.y = CEILING;
  group.add(disk);
  for (const [index, radius, thickness] of [
    [1, 0.287, 0.007], [2, 0.265, 0.005],
    [3, 0.237, 0.004], [4, 0.104, 0.006], [5, 0.079, 0.004],
  ]) {
    const ring = new THREE.Mesh(
      new THREE.TorusGeometry(radius, thickness, 8, 96), relief,
    );
    ring.name = `moldura_circular_roseton_${index}`;
    ring.rotation.x = Math.PI / 2;
    ring.position.y = CEILING - 0.013;
    group.add(ring);
  }

  // Las hojas y tallos del estuco forman ocho ramos alrededor del florón.
  for (let branch = 0; branch < 8; branch++) {
    const angle = branch * Math.PI / 4;
    for (const [index, radius, length] of [
      [1, 0.145, 0.056], [2, 0.200, 0.044],
    ]) {
      const leaf = new THREE.Mesh(new THREE.SphereGeometry(1, 18, 10), relief);
      leaf.name = `hoja_relieve_${branch + 1}_${index}`;
      leaf.scale.set(length, 0.008, 0.021);
      leaf.position.set(
        Math.cos(angle) * radius,
        CEILING - 0.020,
        Math.sin(angle) * radius,
      );
      leaf.rotation.y = -angle + (index === 1 ? 0.32 : -0.28);
      group.add(leaf);
    }
    const stem = new THREE.CatmullRomCurve3([
      new THREE.Vector3(Math.cos(angle) * 0.11, CEILING - 0.021, Math.sin(angle) * 0.11),
      new THREE.Vector3(Math.cos(angle + 0.12) * 0.17, CEILING - 0.022, Math.sin(angle + 0.12) * 0.17),
      new THREE.Vector3(Math.cos(angle + 0.22) * 0.225, CEILING - 0.021, Math.sin(angle + 0.22) * 0.225),
    ]);
    const vine = new THREE.Mesh(
      new THREE.TubeGeometry(stem, 16, 0.0025, 5, false), relief,
    );
    vine.name = `tallo_relieve_${branch + 1}`;
    group.add(vine);
  }
}

export function createSecondRoomLamp(root) {
  if (!root || root.getObjectByName('lampara_segunda_habitacion')) return null;
  const anchor = root.getObjectByName('ancla_luz_dormitorio');
  if (anchor) anchor.visible = false;
  const group = new THREE.Group();
  group.name = 'lampara_segunda_habitacion';
  group.userData.lightingTarget = {
    roomId: 'habitacion_vacia', objectId: 'luz_techo',
  };
  group.userData.twinObject = {
    roomId: 'habitacion_vacia', objectId: 'luz_techo',
    objectName: 'Luz del techo',
  };
  root.add(group);

  const plaster = new THREE.MeshStandardMaterial({
    color: 0xece6db, roughness: 0.96, side: THREE.DoubleSide,
  });
  const relief = new THREE.MeshStandardMaterial({
    color: 0xd9d0c1, roughness: 0.91,
  });
  const ceramic = new THREE.MeshStandardMaterial({
    color: 0xded9cd, roughness: 0.82,
  });
  const cableMaterial = new THREE.MeshStandardMaterial({
    color: 0xa29176, roughness: 0.94,
  });
  addRosette(group, plaster, relief);

  const canopy = new THREE.Mesh(new THREE.LatheGeometry([
    new THREE.Vector2(0.086, 3.050),
    new THREE.Vector2(0.077, 3.025),
    new THREE.Vector2(0.071, 2.980),
    new THREE.Vector2(0.060, 2.922),
    new THREE.Vector2(0.046, 2.884),
    new THREE.Vector2(0.022, 2.864),
  ], 48), ceramic);
  canopy.name = 'floron_blanco_ovalado';
  group.add(canopy);

  const verticalCable = new THREE.Mesh(
    new THREE.CylinderGeometry(0.0038, 0.0038, SHADE_RAISE, 10),
    cableMaterial,
  );
  verticalCable.name = 'cable_largo_beige';
  verticalCable.position.y = 2.864 - SHADE_RAISE / 2;
  group.add(verticalCable);

  // La pantalla sube medio metro; la longitud visible del cable queda a la mitad.
  const shadeAssembly = new THREE.Group();
  shadeAssembly.name = 'conjunto_pantalla_y_bombilla';
  shadeAssembly.position.y = SHADE_RAISE;
  group.add(shadeAssembly);

  // El cable adicional discurre por el techo hacia la pared derecha.
  const ceilingCable = new THREE.CatmullRomCurve3([
    new THREE.Vector3(0.070, 3.060, 0),
    new THREE.Vector3(0.33, 3.034, 0.012),
    new THREE.Vector3(0.69, 3.027, 0.015),
    new THREE.Vector3(1.08, 3.059, 0.025),
  ]);
  const cableRun = new THREE.Mesh(
    new THREE.TubeGeometry(ceilingCable, 42, 0.0038, 8, false),
    cableMaterial,
  );
  cableRun.name = 'cable_sobre_techo';
  group.add(cableRun);

  const fitting = new THREE.Mesh(new THREE.LatheGeometry([
    new THREE.Vector2(0.024, SHADE_TOP + 0.025),
    new THREE.Vector2(0.040, SHADE_TOP + 0.008),
    new THREE.Vector2(0.057, SHADE_TOP - 0.035),
    new THREE.Vector2(0.061, SHADE_TOP - 0.055),
  ], 48), ceramic);
  fitting.name = 'casquillo_superior_pantalla';
  shadeAssembly.add(fitting);

  const shadeProfile = [
    [0.064, 1.791], [0.096, 1.774], [0.126, 1.739],
    [0.155, 1.687], [0.192, 1.628], [0.243, 1.570],
    [0.298, 1.520], [0.340, SHADE_BOTTOM],
  ];
  const shadeMaterial = new THREE.MeshStandardMaterial({
    map: fabricTexture(), color: 0xfff6e6, roughness: 0.96,
    side: THREE.DoubleSide, emissive: 0xffe1ae, emissiveIntensity: 0.20,
    transparent: true, opacity: 0.95,
  });
  const shade = new THREE.Mesh(
    new THREE.LatheGeometry(
      shadeProfile.map(([radius, y]) => new THREE.Vector2(radius, y)), 96,
    ),
    shadeMaterial,
  );
  shade.name = 'pantalla_campana_tejido_floral';
  shadeAssembly.add(shade);

  const linerMaterial = new THREE.MeshStandardMaterial({
    color: 0xffeed0, roughness: 0.98, side: THREE.BackSide,
    emissive: 0xffd89a, emissiveIntensity: 0.30,
  });
  const liner = new THREE.Mesh(
    new THREE.LatheGeometry(
      shadeProfile.map(([radius, y]) => new THREE.Vector2(radius * 0.963, y + 0.008)), 96,
    ),
    linerMaterial,
  );
  liner.name = 'forro_interior_pantalla';
  shadeAssembly.add(liner);

  const rim = new THREE.Mesh(
    new THREE.TorusGeometry(0.340, 0.007, 8, 96),
    new THREE.MeshStandardMaterial({ color: 0xcbb892, roughness: 0.96 }),
  );
  rim.name = 'ribete_borde_pantalla';
  rim.rotation.x = Math.PI / 2;
  rim.position.y = SHADE_BOTTOM;
  shadeAssembly.add(rim);
  for (let index = 0; index < 18; index++) {
    const angle = index * Math.PI * 2 / 18;
    const stitch = new THREE.Mesh(
      new THREE.BoxGeometry(0.019, 0.002, 0.004),
      relief,
    );
    stitch.name = `costura_borde_${index + 1}`;
    stitch.position.set(Math.cos(angle) * 0.34, SHADE_BOTTOM + 0.003, Math.sin(angle) * 0.34);
    stitch.rotation.y = -angle;
    shadeAssembly.add(stitch);
  }

  const bulbMaterial = new THREE.MeshStandardMaterial({
    color: 0xfff5dc, emissive: 0xffdc9c, emissiveIntensity: 1.3,
    roughness: 0.55,
  });
  const bulb = new THREE.Mesh(new THREE.SphereGeometry(0.082, 32, 24), bulbMaterial);
  bulb.name = 'bombilla_tapo_segunda_habitacion';
  bulb.position.y = 1.594;
  shadeAssembly.add(bulb);
  const light = new THREE.PointLight(0xffdda5, 1.1, 3.3, 2);
  light.name = 'luz_ambiente_segunda_habitacion';
  light.position.copy(bulb.position);
  shadeAssembly.add(light);

  const target = new THREE.Mesh(
    new THREE.CylinderGeometry(0.325, 0.355, 0.36, 24),
    new THREE.MeshBasicMaterial({ transparent: true, opacity: 0, colorWrite: false, depthWrite: false }),
  );
  target.name = 'zona_interaccion_lampara_segunda_habitacion';
  target.position.y = 1.665;
  shadeAssembly.add(target);

  return {
    group,
    setPower(power) {
      const level = Math.max(0, Math.min(1, power));
      light.intensity = 1.1 * level;
      bulbMaterial.emissiveIntensity = 1.3 * level;
      shadeMaterial.emissiveIntensity = 0.20 * level;
      linerMaterial.emissiveIntensity = 0.30 * level;
    },
    setColor(color) {
      light.color.set(color);
      bulbMaterial.emissive.set(color);
      shadeMaterial.emissive.set(color);
      linerMaterial.emissive.set(color);
    },
  };
}
