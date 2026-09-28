import * as THREE from 'three';

// Los detalles pertenecen al pasillo largo, no a la franja de la habitación nueva.
export function addHallwayDetails(root, roomId) {
  if (!root) return null;
  if (roomId === 'cuarto_pasillo') {
    const oldAnchor = root.getObjectByName('luz_colgante_pasillo');
    if (oldAnchor) oldAnchor.visible = false;
    return null;
  }
  if (roomId !== 'pasillo' || root.getObjectByName('detalles_pasillo_interior')) return null;
  const anchor = root.getObjectByName('ancla_luz_pasillo');
  if (anchor) anchor.visible = false;
  const details = new THREE.Group();
  details.name = 'detalles_pasillo_interior';
  root.add(details);

  const wallWood = new THREE.MeshStandardMaterial({ color: 0x563927, roughness: 0.8 });
  const woodEdge = new THREE.MeshStandardMaterial({ color: 0x927054, roughness: 0.7 });
  const darkWood = new THREE.MeshStandardMaterial({ color: 0x292019, roughness: 0.84 });
  const paper = new THREE.MeshStandardMaterial({ color: 0xd8ccb3, roughness: 0.93 });
  const plaster = new THREE.MeshStandardMaterial({ color: 0xf0ebe3, roughness: 0.87 });
  const bronze = new THREE.MeshStandardMaterial({ color: 0x7b6548, metalness: 0.67, roughness: 0.4 });
  const glass = new THREE.MeshPhysicalMaterial({
    color: 0xf9f4e8, transparent: true, opacity: 0.72,
    transmission: 0.12, roughness: 0.56, metalness: 0, depthWrite: false,
    side: THREE.DoubleSide,
  });

  function box(parent, name, material, x, y, z, width, height, depth) {
    const mesh = new THREE.Mesh(new THREE.BoxGeometry(width, height, depth), material);
    mesh.name = name;
    mesh.position.set(x, y, z);
    parent.add(mesh);
    return mesh;
  }

  // Estantería entre las puertas, apoyada en la pared exterior del pasillo largo.
  const shelf = new THREE.Group();
  shelf.name = 'mueble_estanteria_pasillo';
  shelf.position.set(1.10, 0, 2.29);
  shelf.rotation.y = Math.PI / 2;
  details.add(shelf);
  for (const x of [-0.145, 0.145]) {
    for (const z of [-0.355, 0.355]) {
      box(shelf, `pata_estanteria_${x}_${z}`, wallWood,
        x, 0.65, z, 0.024, 1.30, 0.024);
    }
  }
  for (const [index, y] of [0.13, 0.47, 0.81, 1.24].entries()) {
    box(shelf, `balda_estanteria_${index + 1}`, wallWood,
      0, y, 0, 0.32, 0.027, 0.74);
    box(shelf, `canto_balda_${index + 1}`, woodEdge,
      -0.16, y, 0, 0.008, 0.012, 0.73);
  }
  // Libros, frascos y objetos pequeños de las baldas.
  for (const [index, z, color] of [
    [1, -0.21, 0x3f352a], [2, -0.12, 0x75634d], [3, -0.02, 0x4d4d45],
    [4, 0.10, 0x7b5444], [5, 0.20, 0x423f35],
  ]) {
    const cover = new THREE.MeshStandardMaterial({ color, roughness: 0.88 });
    box(shelf, `libro_estanteria_${index}`, cover,
      0.055, 0.94, z, 0.11, 0.21 + (index % 2) * 0.05, 0.035);
  }
  for (const [index, z, color] of [
    [1, -0.18, 0x8b3335], [2, -0.025, 0xb0a788], [3, 0.15, 0x434c42],
  ]) {
    const bottle = new THREE.Mesh(
      new THREE.CylinderGeometry(0.027, 0.03, 0.18, 12),
      new THREE.MeshStandardMaterial({ color, roughness: 0.52 }),
    );
    bottle.name = `bote_estanteria_${index}`;
    bottle.position.set(0.02, 1.35, z);
    shelf.add(bottle);
    box(shelf, `tapon_bote_${index}`, bronze,
      0.02, 1.45, z, 0.037, 0.018, 0.037);
  }
  box(shelf, 'caja_inferior_estanteria', darkWood,
    0.01, 0.26, 0.08, 0.25, 0.19, 0.29);

  function artwork(seed) {
    const canvas = document.createElement('canvas');
    canvas.width = 256;
    canvas.height = 320;
    const ctx = canvas.getContext('2d');
    const palettes = [
      ['#75604e', '#b5a382', '#302d2b'],
      ['#5c6964', '#a7aaa0', '#383c3b'],
      ['#65534d', '#ba9c7e', '#3d3330'],
      ['#686155', '#b9ac8b', '#3b403c'],
    ];
    const colors = palettes[seed % palettes.length];
    ctx.fillStyle = colors[0];
    ctx.fillRect(0, 0, 256, 320);
    ctx.fillStyle = colors[1];
    ctx.beginPath();
    ctx.moveTo(16, 240);
    ctx.lineTo(69, 135 + seed * 8);
    ctx.lineTo(123, 203);
    ctx.lineTo(177, 92 + seed * 11);
    ctx.lineTo(243, 234);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = colors[2];
    for (let index = 0; index < 19; index++) {
      const x = (index * 71 + seed * 29) % 250;
      const y = (index * 47 + seed * 53) % 310;
      ctx.fillRect(x, y, 3 + index % 4, 8 + index % 13);
    }
    const texture = new THREE.CanvasTexture(canvas);
    texture.colorSpace = THREE.SRGBColorSpace;
    return texture;
  }

  function picture(name, x, y, width, height, seed, frameMaterial) {
    const group = new THREE.Group();
    group.name = name;
    group.position.set(x, y, 3.19);
    details.add(group);
    box(group, 'marco_exterior', frameMaterial, 0, 0, 0,
      width, height, 0.034);
    box(group, 'passepartout', paper, 0, 0, -0.019,
      width - 0.055, height - 0.055, 0.005);
    const painted = new THREE.Mesh(
      new THREE.PlaneGeometry(width - 0.085, height - 0.085),
      new THREE.MeshStandardMaterial({ map: artwork(seed), roughness: 0.95, side: THREE.DoubleSide }),
    );
    painted.name = 'lámina_del_cuadro';
    painted.position.z = -0.024;
    group.add(painted);
  }

  // Los cuatro cuadros van sobre la cara interior de la pared marcada con X.
  picture('cuadro_pasillo_1', 1.15, 1.71, 0.48, 0.66, 0, bronze);
  picture('cuadro_pasillo_2', 1.90, 1.75, 0.37, 0.52, 1, darkWood);
  picture('cuadro_pasillo_3', 2.75, 1.83, 0.29, 0.44, 2, darkWood);
  picture('cuadro_pasillo_4', 3.53, 1.96, 0.69, 0.86, 3, bronze);

  // Lámpara en el extremo del pasillo largo, bajo el círculo del croquis.
  const lamp = new THREE.Group();
  lamp.name = 'lampara_colgante_pasillo';
  lamp.position.set(-0.10, 3.085, 2.65);
  lamp.userData.lightingTarget = { roomId: 'pasillo', objectId: 'luz_pasillo' };
  lamp.userData.twinObject = {
    roomId: 'pasillo', objectId: 'luz_pasillo', objectName: 'Luz del pasillo',
  };
  details.add(lamp);
  // Florón escalonado, cadena de eslabones ovalados y globo abierto, como en la foto.
  const rosette = new THREE.Mesh(new THREE.CylinderGeometry(0.145, 0.145, 0.03, 40), plaster);
  rosette.name = 'floron_techo_lampara_pasillo';
  lamp.add(rosette);
  for (const [index, radius, y] of [[1, 0.13, -0.018], [2, 0.105, -0.025], [3, 0.075, -0.035]]) {
    const ring = new THREE.Mesh(new THREE.TorusGeometry(radius, 0.006, 7, 40), plaster);
    ring.name = `moldura_floron_${index}`;
    ring.rotation.x = Math.PI / 2;
    ring.position.y = y;
    lamp.add(ring);
  }
  const canopy = new THREE.Mesh(new THREE.CylinderGeometry(0.035, 0.052, 0.053, 24), bronze);
  canopy.name = 'copa_laton_lampara_pasillo';
  canopy.position.y = -0.065;
  lamp.add(canopy);
  for (let index = 0; index < 13; index++) {
    const link = new THREE.Mesh(new THREE.TorusGeometry(0.014, 0.003, 6, 16), bronze);
    link.name = `eslabon_cadena_${index + 1}`;
    link.rotation.y = index % 2 ? Math.PI / 2 : 0;
    link.scale.y = 1.5;
    link.position.y = -0.12 - index * 0.044;
    lamp.add(link);
  }
  const cap = new THREE.Mesh(new THREE.LatheGeometry([
    new THREE.Vector2(0.038, -0.64), new THREE.Vector2(0.055, -0.665),
    new THREE.Vector2(0.070, -0.70), new THREE.Vector2(0.067, -0.74),
  ], 32), bronze);
  cap.name = 'casquillo_laton_lampara_pasillo';
  lamp.add(cap);
  const globe = new THREE.Mesh(new THREE.LatheGeometry([
    new THREE.Vector2(0.063, -0.73), new THREE.Vector2(0.105, -0.76),
    new THREE.Vector2(0.150, -0.82), new THREE.Vector2(0.180, -0.89),
    new THREE.Vector2(0.183, -0.93), new THREE.Vector2(0.163, -0.99),
    new THREE.Vector2(0.117, -1.05), new THREE.Vector2(0.075, -1.08),
  ], 48), glass);
  globe.name = 'globo_vidrio_lampara_pasillo';
  lamp.add(globe);
  const lip = new THREE.Mesh(new THREE.TorusGeometry(0.076, 0.007, 8, 40), glass);
  lip.name = 'borde_inferior_globo_pasillo';
  lip.rotation.x = Math.PI / 2;
  lip.position.y = -1.08;
  lamp.add(lip);
  const bulbMaterial = new THREE.MeshStandardMaterial({
    color: 0xffe9c1, emissive: 0xffd78f, emissiveIntensity: 1.0, roughness: 0.55,
  });
  const bulb = new THREE.Mesh(new THREE.SphereGeometry(0.075, 20, 16), bulbMaterial);
  bulb.name = 'bombilla_domotica_pasillo';
  bulb.position.y = -0.89;
  bulb.userData.lightingTarget = lamp.userData.lightingTarget;
  lamp.add(bulb);
  const light = new THREE.PointLight(0xffdda7, 1.05, 2.9, 2);
  light.name = 'luz_ambiente_lampara_pasillo';
  light.position.copy(bulb.position);
  lamp.add(light);

  // La futura integración puede llamar a este controlador con el estado real.
  return {
    group: lamp,
    setPower(power) {
      const level = Math.max(0, Math.min(1, power));
      light.intensity = 1.05 * level;
      bulbMaterial.emissiveIntensity = level;
    },
    setColor(color) {
      light.color.set(color);
      bulbMaterial.emissive.set(color);
    },
  };
}
