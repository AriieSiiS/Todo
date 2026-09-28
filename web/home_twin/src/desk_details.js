import * as THREE from "three";
import alfombrillaGalaxia from "./alfombrilla_galaxia.jpg";
import { addK70Keyboard } from "./k70_keyboard.js";
import { MORADO_BOMBILLA } from "./pc_lighting_palette.js";
import { addRazerViperMouse } from "./razer_viper_mouse.js";

export function addDeskDetails(room) {
  const desk = room.getObjectByName("ordenador");
  if (!desk) return;

  const materials = {
    case: new THREE.MeshStandardMaterial({
      color: 0xe9e9e5,
      roughness: 0.34,
      metalness: 0.18,
    }),
    trim: new THREE.MeshStandardMaterial({
      color: 0xc7cbcb,
      roughness: 0.36,
      metalness: 0.28,
    }),
    glass: new THREE.MeshPhysicalMaterial({
      color: 0xd6edf0,
      transparent: true,
      opacity: 0.17,
      roughness: 0.1,
      depthWrite: false,
      side: THREE.DoubleSide,
    }),
    black: new THREE.MeshStandardMaterial({ color: 0x1b2027, roughness: 0.65 }),
    board: new THREE.MeshStandardMaterial({ color: 0x373843, roughness: 0.78 }),
    fan: new THREE.MeshStandardMaterial({ color: 0xdde3e4, roughness: 0.52 }),
    fanDark: new THREE.MeshStandardMaterial({
      color: 0x596369,
      roughness: 0.64,
      metalness: 0.16,
    }),
    fanRecess: new THREE.MeshStandardMaterial({
      color: 0x293239,
      roughness: 0.88,
      side: THREE.DoubleSide,
    }),
    fanBlade: new THREE.MeshStandardMaterial({
      color: 0xb9c7ca,
      roughness: 0.57,
      metalness: 0.1,
      side: THREE.DoubleSide,
      emissive: MORADO_BOMBILLA,
      emissiveIntensity: 0.12,
    }),
    fanDiffuser: new THREE.MeshStandardMaterial({
      color: 0xc9a2dd,
      roughness: 0.45,
      metalness: 0.08,
      emissive: MORADO_BOMBILLA,
      emissiveIntensity: 1.3,
    }),
    rubber: new THREE.MeshStandardMaterial({
      color: 0x4b555a,
      roughness: 0.96,
    }),
    tube: new THREE.MeshStandardMaterial({ color: 0xe3e6e3, roughness: 0.48 }),
    frog: new THREE.MeshStandardMaterial({ color: 0x9caf9a, roughness: 1 }),
    frogFace: new THREE.MeshStandardMaterial({ color: 0xc4d0bd, roughness: 1 }),
    frogBelly: new THREE.MeshStandardMaterial({
      color: 0xb8c7b2,
      roughness: 1,
    }),
    frogSeam: new THREE.MeshStandardMaterial({ color: 0x7d927b, roughness: 1 }),
    yellow: new THREE.MeshStandardMaterial({ color: 0xe8ba48, roughness: 1 }),
    yellowLight: new THREE.MeshStandardMaterial({
      color: 0xf2c85d,
      roughness: 1,
    }),
    brown: new THREE.MeshStandardMaterial({ color: 0x6c4030, roughness: 1 }),
    brownSeam: new THREE.MeshStandardMaterial({
      color: 0x503025,
      roughness: 1,
    }),
    blue: new THREE.MeshStandardMaterial({ color: 0x204f8e, roughness: 1 }),
    red: new THREE.MeshStandardMaterial({ color: 0xad3e45, roughness: 1 }),
    redLight: new THREE.MeshStandardMaterial({ color: 0xd46068, roughness: 1 }),
    pink: new THREE.MeshStandardMaterial({ color: 0xcd7788, roughness: 1 }),
    strap: new THREE.MeshStandardMaterial({ color: 0xb5b7a1, roughness: 1 }),
    glint: new THREE.MeshStandardMaterial({ color: 0xf4f1e9, roughness: 1 }),
    mint: new THREE.MeshStandardMaterial({ color: 0x9bdbd7, roughness: 0.9 }),
    mane: new THREE.MeshStandardMaterial({ color: 0xf1efdf, roughness: 1 }),
    eye: new THREE.MeshStandardMaterial({ color: 0x141a21, roughness: 0.7 }),
    orange: new THREE.MeshStandardMaterial({ color: 0xd7823d, roughness: 1 }),
    lampGlass: new THREE.MeshPhysicalMaterial({
      color: 0xedf2ed,
      transparent: true,
      opacity: 0.38,
      roughness: 0.18,
      depthWrite: false,
      side: THREE.DoubleSide,
    }),
    mouseShell: new THREE.MeshStandardMaterial({
      color: 0x30343a,
      roughness: 0.55,
      metalness: 0.08,
    }),
    mouseButton: new THREE.MeshStandardMaterial({
      color: 0x3e4248,
      roughness: 0.67,
    }),
    mouseWheel: new THREE.MeshStandardMaterial({
      color: 0x677079,
      roughness: 0.88,
    }),
  };

  const group = (parent, name, x = 0, y = 0, z = 0) => {
    const object = new THREE.Group();
    object.name = name;
    object.position.set(x, y, z);
    parent.add(object);
    return object;
  };
  const cube = (parent, name, material, x, y, z, width, height, depth) => {
    const mesh = new THREE.Mesh(
      new THREE.BoxGeometry(width, height, depth),
      material,
    );
    mesh.name = name;
    mesh.position.set(x, y, z);
    parent.add(mesh);
    return mesh;
  };
  const sphere = (parent, name, material, x, y, z, width, height, depth) => {
    const mesh = new THREE.Mesh(new THREE.SphereGeometry(1, 18, 12), material);
    mesh.name = name;
    mesh.position.set(x, y, z);
    mesh.scale.set(width, height, depth);
    parent.add(mesh);
    return mesh;
  };
  const cylinder = (parent, name, material, x, y, z, top, bottom, height) => {
    const mesh = new THREE.Mesh(
      new THREE.CylinderGeometry(top, bottom, height, 20),
      material,
    );
    mesh.name = name;
    mesh.position.set(x, y, z);
    parent.add(mesh);
    return mesh;
  };
  const torus = (
    parent,
    name,
    material,
    x,
    y,
    z,
    radius,
    thickness,
    rotationX = 0,
  ) => {
    const mesh = new THREE.Mesh(
      new THREE.TorusGeometry(radius, thickness, 6, 24),
      material,
    );
    mesh.name = name;
    mesh.position.set(x, y, z);
    mesh.rotation.x = rotationX;
    parent.add(mesh);
    return mesh;
  };
  const stitch = (parent, name, material, points, radius = 0.0012) => {
    const curve = new THREE.CatmullRomCurve3(
      points.map(([x, y, z]) => new THREE.Vector3(x, y, z)),
    );
    const mesh = new THREE.Mesh(
      new THREE.TubeGeometry(curve, 16, radius, 4),
      material,
    );
    mesh.name = name;
    parent.add(mesh);
    return mesh;
  };

  // Los periféricos sustituyen los dos cubos del modelo y conservan su escala.
  const roundedPanel = (
    parent,
    name,
    mat,
    x,
    bottomY,
    z,
    width,
    depth,
    height,
    radius = 0.005,
  ) => {
    const halfWidth = width / 2;
    const halfDepth = depth / 2;
    const r = Math.min(radius, halfWidth, halfDepth);
    const shape = new THREE.Shape();
    shape.moveTo(-halfWidth + r, -halfDepth);
    shape.lineTo(halfWidth - r, -halfDepth);
    shape.quadraticCurveTo(halfWidth, -halfDepth, halfWidth, -halfDepth + r);
    shape.lineTo(halfWidth, halfDepth - r);
    shape.quadraticCurveTo(halfWidth, halfDepth, halfWidth - r, halfDepth);
    shape.lineTo(-halfWidth + r, halfDepth);
    shape.quadraticCurveTo(-halfWidth, halfDepth, -halfWidth, halfDepth - r);
    shape.lineTo(-halfWidth, -halfDepth + r);
    shape.quadraticCurveTo(-halfWidth, -halfDepth, -halfWidth + r, -halfDepth);
    const mesh = new THREE.Mesh(
      new THREE.ExtrudeGeometry(shape, {
        depth: height,
        bevelEnabled: true,
        bevelThickness: Math.min(0.001, height / 5),
        bevelSize: Math.min(0.0015, r / 3),
        bevelSegments: 2,
        curveSegments: 5,
      }),
      mat,
    );
    mesh.name = name;
    mesh.rotation.x = -Math.PI / 2;
    mesh.position.set(x, bottomY, z);
    parent.add(mesh);
    return mesh;
  };
  // Alfombrilla Warhammer bajo teclado y ratón. La impresión queda en una pieza fina sobre el tablero. El recorte UV
  // utiliza solo la alfombrilla de la fotografía original, sin el fondo blanco.
  const matX = -0.03;
  const matZ = -1.37;
  const matWidth = 0.8;
  const matDepth = 0.3;
  const matTop = 0.772;
  const mat = group(desk, "alfombrilla_galaxia_warhammer");
  const matRubber = new THREE.MeshStandardMaterial({
    color: 0x171313,
    roughness: 0.99,
    metalness: 0,
  });
  roundedPanel(
    mat,
    "base_de_goma_antideslizante",
    matRubber,
    matX,
    0.768,
    matZ,
    matWidth,
    matDepth,
    0.0032,
    0.009,
  );
  const artwork = new THREE.TextureLoader().load(alfombrillaGalaxia);
  artwork.colorSpace = THREE.SRGBColorSpace;
  artwork.anisotropy = 8;
  const artMaterial = new THREE.MeshStandardMaterial({
    map: artwork,
    roughness: 0.97,
    metalness: 0,
    side: THREE.DoubleSide,
  });
  const topShape = new THREE.Shape();
  const artWidth = matWidth - 0.005;
  const artDepth = matDepth - 0.005;
  const halfArtWidth = artWidth / 2;
  const halfArtDepth = artDepth / 2;
  const corner = 0.008;
  topShape.moveTo(-halfArtWidth + corner, -halfArtDepth);
  topShape.lineTo(halfArtWidth - corner, -halfArtDepth);
  topShape.quadraticCurveTo(
    halfArtWidth,
    -halfArtDepth,
    halfArtWidth,
    -halfArtDepth + corner,
  );
  topShape.lineTo(halfArtWidth, halfArtDepth - corner);
  topShape.quadraticCurveTo(
    halfArtWidth,
    halfArtDepth,
    halfArtWidth - corner,
    halfArtDepth,
  );
  topShape.lineTo(-halfArtWidth + corner, halfArtDepth);
  topShape.quadraticCurveTo(
    -halfArtWidth,
    halfArtDepth,
    -halfArtWidth,
    halfArtDepth - corner,
  );
  topShape.lineTo(-halfArtWidth, -halfArtDepth + corner);
  topShape.quadraticCurveTo(
    -halfArtWidth,
    -halfArtDepth,
    -halfArtWidth + corner,
    -halfArtDepth,
  );
  const artGeometry = new THREE.ShapeGeometry(topShape, 6);
  const uvs = artGeometry.getAttribute("uv");
  for (let index = 0; index < uvs.count; index++) {
    const u = (uvs.getX(index) + halfArtWidth) / artWidth;
    const v = (uvs.getY(index) + halfArtDepth) / artDepth;
    uvs.setXY(index, (123 + 945 * u) / 1200, (1200 - 780 + 357 * v) / 1200);
  }
  uvs.needsUpdate = true;
  const artSurface = new THREE.Mesh(artGeometry, artMaterial);
  artSurface.name = "mapa_galactico_impreso";
  artSurface.rotation.x = -Math.PI / 2;
  artSurface.position.set(matX, matTop, matZ);
  mat.add(artSurface);
  const seamPoints = topShape
    .getPoints(80)
    .map(
      (point) =>
        new THREE.Vector3(
          matX + point.x * 0.992,
          matTop + 0.0003,
          matZ - point.y * 0.982,
        ),
    );
  const stitchedBorder = new THREE.LineLoop(
    new THREE.BufferGeometry().setFromPoints(seamPoints),
    new THREE.LineDashedMaterial({
      color: 0xb1a19c,
      dashSize: 0.003,
      gapSize: 0.003,
      transparent: true,
      opacity: 0.65,
    }),
  );
  stitchedBorder.name = "costura_del_borde";
  stitchedBorder.computeLineDistances();
  mat.add(stitchedBorder);

  // Teclado Corsair K70: posición y teclas en src/k70_keyboard.js.
  addK70Keyboard(desk, { roundedPanel, stitch });
  // Ratón Razer Viper Ultimate: posición y carcasa en src/razer_viper_mouse.js.
  addRazerViperMouse(desk, { roundedPanel, stitch });

  // Caja panorámica de 28 × 45 × 43 cm, apoyada sobre el tablero.
  const tower = group(desk, "torre_pc");
  const pcX = 0.63;
  const pcZ = -1.585;
  const bottom = 0.7675;
  const top = bottom + 0.45;
  const front = pcZ + 0.215;
  const back = pcZ - 0.215;
  const left = pcX - 0.14;
  const right = pcX + 0.14;
  cube(
    tower,
    "base_blanca_pc",
    materials.case,
    pcX,
    bottom + 0.028,
    pcZ,
    0.28,
    0.056,
    0.43,
  );
  for (const x of [left + 0.035, right - 0.035]) {
    for (const z of [front - 0.04, back + 0.04]) {
      cube(
        tower,
        `pata_antideslizante_${x}_${z}`,
        materials.rubber,
        x,
        bottom - 0.006,
        z,
        0.028,
        0.012,
        0.032,
      );
    }
  }
  cube(
    tower,
    "borde_superior_frontal_pc",
    materials.case,
    pcX,
    top - 0.008,
    front - 0.008,
    0.28,
    0.016,
    0.016,
  );
  cube(
    tower,
    "borde_superior_trasero_pc",
    materials.case,
    pcX,
    top - 0.008,
    back + 0.008,
    0.28,
    0.016,
    0.016,
  );
  cube(
    tower,
    "borde_superior_izquierdo_pc",
    materials.case,
    left + 0.008,
    top - 0.008,
    pcZ,
    0.016,
    0.016,
    0.43,
  );
  cube(
    tower,
    "borde_superior_derecho_pc",
    materials.case,
    right - 0.008,
    top - 0.008,
    pcZ,
    0.016,
    0.016,
    0.43,
  );
  cube(
    tower,
    "panel_derecho_pc",
    materials.case,
    right - 0.006,
    bottom + 0.225,
    pcZ,
    0.012,
    0.42,
    0.42,
  );
  cube(
    tower,
    "panel_trasero_pc",
    materials.case,
    pcX,
    bottom + 0.225,
    back + 0.006,
    0.28,
    0.42,
    0.012,
  );
  for (const x of [left + 0.007, right - 0.007]) {
    for (const z of [front - 0.007, back + 0.007]) {
      cube(
        tower,
        `montante_pc_${x}_${z}`,
        materials.trim,
        x,
        bottom + 0.225,
        z,
        0.014,
        0.45,
        0.014,
      );
    }
  }
  for (const y of [bottom + 0.008, top - 0.008]) {
    cube(
      tower,
      `marco_frontal_pc_${y}`,
      materials.case,
      pcX,
      y,
      front - 0.006,
      0.28,
      0.014,
      0.014,
    );
    cube(
      tower,
      `marco_lateral_pc_${y}`,
      materials.case,
      left + 0.007,
      y,
      pcZ,
      0.014,
      0.014,
      0.43,
    );
  }
  cube(
    tower,
    "cristal_frontal_pc",
    materials.glass,
    pcX,
    bottom + 0.248,
    front + 0.001,
    0.258,
    0.374,
    0.003,
  );
  cube(
    tower,
    "cristal_lateral_pc",
    materials.glass,
    left - 0.001,
    bottom + 0.248,
    pcZ,
    0.003,
    0.374,
    0.408,
  );
  cube(
    tower,
    "tapa_cristal_pc",
    materials.glass,
    pcX,
    top + 0.002,
    pcZ,
    0.25,
    0.003,
    0.4,
  );
  // Placa base y conectores visibles detrás del cristal.
  cube(
    tower,
    "placa_base_pc",
    materials.board,
    right - 0.031,
    0.996,
    pcZ - 0.025,
    0.012,
    0.29,
    0.27,
  );
  for (let index = 0; index < 8; index++) {
    cube(
      tower,
      `conector_placa_${index + 1}`,
      index % 2 ? materials.trim : materials.black,
      right - 0.042,
      1.114 - index * 0.027,
      pcZ - 0.115 + index * 0.011,
      0.006,
      0.014,
      0.018,
    );
  }
  // Tarjeta gráfica y aletas de refrigeración.
  cube(
    tower,
    "tarjeta_grafica_pc",
    materials.black,
    pcX - 0.013,
    0.932,
    pcZ - 0.025,
    0.19,
    0.037,
    0.19,
  );
  cube(
    tower,
    "cubierta_tarjeta_pc",
    materials.trim,
    pcX - 0.013,
    0.952,
    pcZ - 0.025,
    0.19,
    0.005,
    0.19,
  );
  cube(
    tower,
    "canto_visible_grafica_pc",
    materials.board,
    left + 0.063,
    0.932,
    pcZ - 0.025,
    0.008,
    0.033,
    0.19,
  );
  for (let index = 0; index < 11; index++) {
    cube(
      tower,
      `aleta_refrigeracion_grafica_${index + 1}`,
      materials.trim,
      left + 0.069,
      0.928,
      pcZ - 0.111 + index * 0.017,
      0.002,
      0.016,
      0.008,
    );
  }
  // Dos VENGEANCE RGB DDR5 en sus ranuras. Cada módulo conserva diez zonas RGB
  // separadas para una posible integración futura.
  const ramBody = new THREE.MeshStandardMaterial({
    color: 0x2d3137,
    metalness: 0.42,
    roughness: 0.56,
  });
  const ramEdge = new THREE.MeshStandardMaterial({
    color: 0x7b8288,
    metalness: 0.72,
    roughness: 0.38,
  });
  const ramDiffuser = new THREE.MeshStandardMaterial({
    color: 0xc1c5c5,
    roughness: 0.63,
    emissive: MORADO_BOMBILLA,
    emissiveIntensity: 0.18,
  });
  for (const [index, ramZ] of [pcZ + 0.052, pcZ + 0.028].entries()) {
    const module = group(
      tower,
      `memoria_corsair_vengeance_rgb_${index + 1}`,
      right - 0.073,
      1.06,
      ramZ,
    );
    module.userData.lightingTarget = {
      type: "corsair-vengeance-rgb-ddr5",
      module: index + 1,
    };
    cube(
      module,
      "placa_del_modulo",
      materials.board,
      0.017,
      0,
      0,
      0.014,
      0.127,
      0.007,
    );
    cube(
      module,
      "disipador_aluminio",
      ramBody,
      -0.002,
      0,
      0,
      0.039,
      0.119,
      0.01,
    );
    cube(module, "perfil_superior", ramEdge, -0.022, 0, 0, 0.004, 0.126, 0.011);
    cube(
      module,
      "difusor_cubierta",
      ramDiffuser,
      -0.025,
      0,
      0,
      0.003,
      0.123,
      0.012,
    );
    for (let pin = 0; pin < 10; pin++) {
      cube(
        module,
        `contacto_dorado_${pin + 1}`,
        materials.trim,
        0.025,
        -0.053 + pin * 0.0117,
        0,
        0.004,
        0.005,
        0.008,
      );
    }
    for (let zone = 0; zone < 10; zone++) {
      const zoneMaterial = new THREE.MeshStandardMaterial({
        color: 0xd3d6d2,
        roughness: 0.36,
        metalness: 0,
        emissive: MORADO_BOMBILLA,
        emissiveIntensity: 1.05,
      });
      const led = cube(
        module,
        `zona_rgb_${zone + 1}`,
        zoneMaterial,
        -0.027,
        -0.055 + zone * 0.0122,
        0,
        0.002,
        0.0109,
        0.011,
      );
      led.userData.lightingTarget = {
        type: "corsair-vengeance-rgb-ddr5-zone",
        module: index + 1,
        zone: zone + 1,
      };
    }
  }
  // Procesador / bloque de refrigeración: anillo orientado hacia los monitores.
  const processorX = right - 0.088;
  const processorZ = pcZ - 0.05;
  cube(
    tower,
    "bloque_refrigeracion_pc",
    materials.case,
    processorX,
    1.047,
    processorZ,
    0.07,
    0.065,
    0.07,
  );
  const processorRing = torus(
    tower,
    "anillo_bloque_refrigeracion",
    materials.trim,
    processorX - 0.038,
    1.05,
    processorZ,
    0.025,
    0.003,
  );
  processorRing.rotation.y = -Math.PI / 2;
  cylinder(
    tower,
    "tapa_bloque_refrigeracion",
    materials.board,
    processorX - 0.039,
    1.05,
    processorZ,
    0.018,
    0.018,
    0.003,
  ).rotation.z = Math.PI / 2;

  // Tubos de refrigeración: terminan sobre los ventiladores verticales derechos.
  const fanColumnZ = front - 0.07;
  cube(
    tower,
    "conector_superior_ventiladores_pc",
    materials.case,
    right - 0.067,
    top - 0.025,
    fanColumnZ,
    0.06,
    0.014,
    0.055,
  );
  for (const [index, side] of [-1, 1].entries()) {
    const endZ = fanColumnZ + side * 0.014;
    cylinder(
      tower,
      `racor_superior_${index + 1}`,
      materials.trim,
      right - 0.067,
      top - 0.016,
      endZ,
      0.008,
      0.008,
      0.007,
    );
    const curve = new THREE.CatmullRomCurve3([
      new THREE.Vector3(processorX + 0.026, 1.068, processorZ + side * 0.013),
      new THREE.Vector3(processorX + 0.015, 1.137, pcZ + side * 0.01),
      new THREE.Vector3(
        right - 0.078,
        1.185,
        fanColumnZ - 0.045 + side * 0.009,
      ),
      new THREE.Vector3(right - 0.067, top - 0.011, endZ),
    ]);
    const tube = new THREE.Mesh(
      new THREE.TubeGeometry(curve, 32, 0.0055, 8),
      materials.tube,
    );
    tube.name = `tubo_refrigeracion_${index + 1}`;
    tower.add(tube);
  }

  const fanAssemblies = group(tower, "ventiladores_pc_preparados_para_control");
  const bladeOutline = new THREE.Shape();
  bladeOutline.moveTo(0.01, -0.003);
  bladeOutline.bezierCurveTo(0.021, -0.001, 0.038, 0.007, 0.043, 0.021);
  bladeOutline.quadraticCurveTo(0.04, 0.029, 0.03, 0.033);
  bladeOutline.bezierCurveTo(0.028, 0.021, 0.018, 0.015, 0.01, 0.008);
  bladeOutline.closePath();
  const bladeGeometry = new THREE.ExtrudeGeometry(bladeOutline, {
    depth: 0.0015,
    bevelEnabled: true,
    bevelThickness: 0.0005,
    bevelSize: 0.0005,
    bevelSegments: 1,
    curveSegments: 5,
  });
  const rotors = [];
  const makeFan = (name, x, y, z, rotationX = 0, rotationY = 0) => {
    const housing = group(fanAssemblies, name, x, y, z);
    housing.rotation.set(rotationX, rotationY, 0);
    const recess = new THREE.Mesh(
      new THREE.CircleGeometry(0.046, 40),
      materials.fanRecess,
    );
    recess.name = `${name}_fondo_oscuro`;
    recess.position.z = -0.007;
    housing.add(recess);
    for (const side of [-1, 1]) {
      cube(
        housing,
        `${name}_montante_vertical_${side}`,
        materials.case,
        side * 0.052,
        0,
        0.003,
        0.009,
        0.113,
        0.013,
      );
      cube(
        housing,
        `${name}_montante_horizontal_${side}`,
        materials.case,
        0,
        side * 0.052,
        0.003,
        0.113,
        0.009,
        0.013,
      );
      for (const other of [-1, 1]) {
        cube(
          housing,
          `${name}_goma_${side}_${other}`,
          materials.rubber,
          side * 0.049,
          other * 0.049,
          0.012,
          0.011,
          0.011,
          0.004,
        );
        cylinder(
          housing,
          `${name}_tornillo_${side}_${other}`,
          materials.trim,
          side * 0.049,
          other * 0.049,
          0.015,
          0.0028,
          0.0028,
          0.0015,
        ).rotation.x = Math.PI / 2;
      }
    }
    if (name.startsWith("ventilador_lateral_derecho_")) {
      torus(
        housing,
        `${name}_canal_difusor_circular`,
        materials.fanDiffuser,
        0,
        0,
        0.009,
        0.044,
        0.003,
      );
    } else {
      const corners = [
        [-0.033, -0.044],
        [0.033, -0.044],
        [0.046, -0.027],
        [0.046, 0.027],
        [0.033, 0.044],
        [-0.033, 0.044],
        [-0.046, 0.027],
        [-0.046, -0.027],
      ].map(([px, py]) => new THREE.Vector3(px, py, 0.009));
      const outline = new THREE.CurvePath();
      for (let index = 0; index < corners.length; index++) {
        outline.add(
          new THREE.LineCurve3(
            corners[index],
            corners[(index + 1) % corners.length],
          ),
        );
      }
      const diffuser = new THREE.Mesh(
        new THREE.TubeGeometry(outline, 64, 0.0025, 6, true),
        materials.fanDiffuser,
      );
      diffuser.name = `${name}_canal_difusor_angular`;
      housing.add(diffuser);
    }
    torus(
      housing,
      `${name}_borde_interior`,
      materials.fanDark,
      0,
      0,
      0.013,
      0.038,
      0.0014,
    );
    const rotor = group(housing, `${name}_rotor`);
    rotors.push(rotor);
    for (let index = 0; index < 7; index++) {
      const angle = (index * Math.PI * 2) / 7;
      const blade = new THREE.Mesh(bladeGeometry, materials.fanBlade);
      blade.name = `${name}_pala_curva_${index + 1}`;
      blade.rotation.z = angle;
      blade.position.z = 0.001;
      rotor.add(blade);
    }
    cylinder(
      rotor,
      `${name}_buje`,
      materials.fanDark,
      0,
      0,
      0.008,
      0.014,
      0.014,
      0.008,
    ).rotation.x = Math.PI / 2;
    cylinder(
      rotor,
      `${name}_insignia_central`,
      materials.trim,
      0,
      0,
      0.013,
      0.008,
      0.008,
      0.0015,
    ).rotation.x = Math.PI / 2;
  };
  // Ventiladores 1 a 3: columna vertical en la esquina derecha.
  for (const [index, y] of [
    bottom + 0.16,
    bottom + 0.265,
    bottom + 0.37,
  ].entries()) {
    makeFan(
      `ventilador_lateral_derecho_${index + 1}`,
      right - 0.014,
      y,
      front - 0.07,
      0,
      -Math.PI / 2,
    );
  }
  // Ventiladores 4 a 6: fila inferior cerca del cristal lateral.
  for (const [index, z] of [
    back + 0.08,
    pcZ - 0.025,
    front - 0.129,
  ].entries()) {
    makeFan(
      `ventilador_inferior_${index + 1}`,
      left + 0.071,
      bottom + 0.075,
      z,
      -Math.PI / 2,
    );
  }
  // Ventiladores 7 y 8: dos unidades en el fondo izquierdo de la caja.
  for (const [index, y] of [bottom + 0.27, bottom + 0.38].entries()) {
    makeFan(`ventilador_fondo_${index + 1}`, left + 0.077, y, back + 0.02);
  }

  // Panel frontal inferior: USB A, USB C, audio, reinicio y encendido.
  const controlsY = bottom + 0.029;
  cube(
    tower,
    "franja_controles_pc",
    materials.trim,
    pcX,
    controlsY,
    front + 0.002,
    0.271,
    0.049,
    0.004,
  );
  cube(
    tower,
    "boca_usb_a_pc",
    materials.black,
    left + 0.048,
    controlsY,
    front + 0.006,
    0.019,
    0.018,
    0.002,
  );
  cube(
    tower,
    "lengüeta_usb_a_pc",
    materials.blue,
    left + 0.048,
    controlsY - 0.002,
    front + 0.0075,
    0.012,
    0.005,
    0.001,
  );
  for (const offset of [-0.003, 0, 0.003]) {
    cube(
      tower,
      `contacto_usb_a_${offset}`,
      materials.trim,
      left + 0.048 + offset,
      controlsY + 0.004,
      front + 0.008,
      0.001,
      0.003,
      0.0005,
    );
  }
  cube(
    tower,
    "marco_usb_c_pc",
    materials.black,
    left + 0.105,
    controlsY,
    front + 0.006,
    0.013,
    0.021,
    0.002,
  );
  cube(
    tower,
    "ranura_usb_c_pc",
    materials.trim,
    left + 0.105,
    controlsY,
    front + 0.0075,
    0.005,
    0.013,
    0.0005,
  );
  cylinder(
    tower,
    "conector_audio_pc",
    materials.black,
    left + 0.157,
    controlsY,
    front + 0.004,
    0.008,
    0.008,
    0.002,
  ).rotation.x = Math.PI / 2;
  cylinder(
    tower,
    "boton_reinicio_pc",
    materials.fanDark,
    left + 0.194,
    controlsY,
    front + 0.004,
    0.006,
    0.006,
    0.002,
  ).rotation.x = Math.PI / 2;
  const powerButton = group(
    tower,
    "boton_encendido_pc",
    right - 0.034,
    controlsY,
    front + 0.003,
  );
  powerButton.userData.pcPowerButton = true;
  const powerRing = new THREE.MeshBasicMaterial({
    color: 0xf5f9f6,
    toneMapped: false,
  });
  torus(powerButton, "aro_encendido_pc", powerRing, 0, 0, 0, 0.008, 0.0025);
  cylinder(
    powerButton,
    "superficie_pulsable_pc",
    materials.trim,
    0,
    0,
    0.001,
    0.011,
    0.011,
    0.002,
  ).rotation.x = Math.PI / 2;

  // Lamparita del PC: pieza independiente sobre la caja, preparada para control.
  const lamp = group(desk, "lamparita_pc_preparada_para_control");
  const lampX = 0.555;
  const lampZ = -1.515;
  cylinder(
    lamp,
    "base_lamparita",
    materials.case,
    lampX,
    top + 0.013,
    lampZ,
    0.037,
    0.037,
    0.024,
  );
  cylinder(
    lamp,
    "difusor_lamparita",
    materials.lampGlass,
    lampX,
    top + 0.065,
    lampZ,
    0.04,
    0.036,
    0.077,
  );
  torus(
    lamp,
    "aro_superior_lamparita",
    materials.trim,
    lampX,
    top + 0.104,
    lampZ,
    0.039,
    0.003,
    Math.PI / 2,
  );
  for (let index = 0; index < 12; index++) {
    const angle = (index * Math.PI) / 6;
    cylinder(
      lamp,
      `relieve_lamparita_${index + 1}`,
      materials.lampGlass,
      lampX + Math.cos(angle) * 0.038,
      top + 0.064,
      lampZ + Math.sin(angle) * 0.038,
      0.002,
      0.002,
      0.071,
    );
  }

  // Los tres peluches quedan guardados aquí para recuperarlos cuando se desee.
  const showPcPlushies = false;
  if (showPcPlushies) {
    // Peluche rana: guardado y oculto mientras showPcPlushies sea false.
    const frog = group(desk, "peluche_rana_pc");
    const frogX = 0.525;
    const frogZ = -1.72;
    sphere(
      frog,
      "cuerpo_relleno_rana",
      materials.frog,
      frogX,
      top + 0.063,
      frogZ,
      0.056,
      0.064,
      0.047,
    );
    sphere(
      frog,
      "barriga_clara_rana",
      materials.frogBelly,
      frogX,
      top + 0.065,
      frogZ + 0.039,
      0.038,
      0.045,
      0.015,
    );
    sphere(
      frog,
      "cabeza_ancha_rana",
      materials.frog,
      frogX,
      top + 0.145,
      frogZ + 0.007,
      0.071,
      0.054,
      0.049,
    );
    sphere(
      frog,
      "morro_ancho_rana",
      materials.frogFace,
      frogX,
      top + 0.119,
      frogZ + 0.046,
      0.056,
      0.026,
      0.018,
    );
    for (const side of [-1, 1]) {
      sphere(
        frog,
        `bulto_ojo_rana_${side}`,
        materials.frog,
        frogX + side * 0.053,
        top + 0.18,
        frogZ + 0.014,
        0.021,
        0.02,
        0.02,
      );
      sphere(
        frog,
        `ojo_rana_${side}`,
        materials.eye,
        frogX + side * 0.053,
        top + 0.184,
        frogZ + 0.032,
        0.006,
        0.006,
        0.003,
      );
      sphere(
        frog,
        `brillo_ojo_rana_${side}`,
        materials.glint,
        frogX + side * 0.051,
        top + 0.186,
        frogZ + 0.035,
        0.0018,
        0.0018,
        0.001,
      );
      sphere(
        frog,
        `narina_rana_${side}`,
        materials.frogSeam,
        frogX + side * 0.018,
        top + 0.13,
        frogZ + 0.063,
        0.0023,
        0.0015,
        0.001,
      );
      const arm = sphere(
        frog,
        `brazo_caido_rana_${side}`,
        materials.frog,
        frogX + side * 0.059,
        top + 0.062,
        frogZ + 0.025,
        0.022,
        0.042,
        0.025,
      );
      arm.rotation.z = side * 0.28;
      sphere(
        frog,
        `mano_rana_${side}`,
        materials.frogFace,
        frogX + side * 0.07,
        top + 0.026,
        frogZ + 0.042,
        0.021,
        0.015,
        0.025,
      );
      sphere(
        frog,
        `muslo_rana_${side}`,
        materials.frog,
        frogX + side * 0.039,
        top + 0.034,
        frogZ + 0.027,
        0.029,
        0.028,
        0.032,
      );
      sphere(
        frog,
        `pie_alargado_rana_${side}`,
        materials.frog,
        frogX + side * 0.045,
        top + 0.014,
        frogZ + 0.058,
        0.033,
        0.014,
        0.032,
      );
      for (let toe = -1; toe <= 1; toe++) {
        sphere(
          frog,
          `dedo_rana_${side}_${toe}`,
          materials.frogFace,
          frogX + side * 0.045 + toe * 0.012,
          top + 0.011,
          frogZ + 0.084,
          0.009,
          0.008,
          0.011,
        );
      }
    }
    stitch(
      frog,
      "sonrisa_bordada_rana",
      materials.frogSeam,
      [
        [frogX - 0.026, top + 0.113, frogZ + 0.061],
        [frogX, top + 0.107, frogZ + 0.066],
        [frogX + 0.026, top + 0.113, frogZ + 0.061],
      ],
      0.001,
    );
    sphere(
      frog,
      "medalla_naranja_rana",
      materials.orange,
      frogX,
      top + 0.082,
      frogZ + 0.055,
      0.017,
      0.017,
      0.004,
    );
    sphere(
      frog,
      "centro_medalla_rana",
      materials.redLight,
      frogX,
      top + 0.082,
      frogZ + 0.059,
      0.006,
      0.006,
      0.001,
    );
    stitch(
      frog,
      "costura_barriga_rana",
      materials.frogSeam,
      [
        [frogX - 0.028, top + 0.094, frogZ + 0.049],
        [frogX - 0.037, top + 0.061, frogZ + 0.053],
        [frogX - 0.018, top + 0.031, frogZ + 0.048],
      ],
      0.0008,
    );

    // Peluche pulpo amarillo: guardado y oculto.
    const yellow = group(desk, "peluche_pulpo_pc");
    const yellowX = 0.675;
    const yellowZ = -1.69;
    sphere(
      yellow,
      "cuerpo_tela_azul_pulpo",
      materials.blue,
      yellowX,
      top + 0.055,
      yellowZ,
      0.054,
      0.047,
      0.046,
    );
    sphere(
      yellow,
      "cabeza_redonda_pulpo",
      materials.yellow,
      yellowX,
      top + 0.14,
      yellowZ + 0.009,
      0.073,
      0.067,
      0.058,
    );
    sphere(
      yellow,
      "casquete_marron_pulpo",
      materials.brown,
      yellowX,
      top + 0.19,
      yellowZ + 0.002,
      0.067,
      0.024,
      0.05,
    );
    for (const side of [-1, 1]) {
      sphere(
        yellow,
        `mechon_casquete_pulpo_${side}`,
        materials.brown,
        yellowX + side * 0.045,
        top + 0.179,
        yellowZ + 0.034,
        0.022,
        0.016,
        0.018,
      );
    }
    stitch(
      yellow,
      "costura_casquete_pulpo",
      materials.brownSeam,
      [
        [yellowX - 0.052, top + 0.177, yellowZ + 0.041],
        [yellowX, top + 0.177, yellowZ + 0.061],
        [yellowX + 0.052, top + 0.177, yellowZ + 0.041],
      ],
      0.001,
    );
    for (const side of [-1, 1]) {
      sphere(
        yellow,
        `ojo_negro_pulpo_${side}`,
        materials.eye,
        yellowX + side * 0.032,
        top + 0.146,
        yellowZ + 0.064,
        0.01,
        0.012,
        0.004,
      );
      sphere(
        yellow,
        `brillo_ojo_pulpo_${side}`,
        materials.glint,
        yellowX + side * 0.029,
        top + 0.151,
        yellowZ + 0.068,
        0.002,
        0.002,
        0.001,
      );
      for (let index = 0; index < 3; index++) {
        sphere(
          yellow,
          `peca_pulpo_${side}_${index}`,
          materials.mint,
          yellowX + side * (0.047 + (index % 2) * 0.007),
          top + 0.119 - index * 0.009,
          yellowZ + 0.056 - index * 0.002,
          0.0035,
          0.0035,
          0.002,
        );
      }
      const tentacle = sphere(
        yellow,
        `tentaculo_rojo_pulpo_${side}`,
        materials.red,
        yellowX + side * 0.068,
        top + 0.052,
        yellowZ + 0.025,
        0.029,
        0.019,
        0.046,
      );
      tentacle.rotation.z = side * 0.26;
      sphere(
        yellow,
        `punta_tentaculo_pulpo_${side}`,
        materials.redLight,
        yellowX + side * 0.082,
        top + 0.027,
        yellowZ + 0.057,
        0.021,
        0.015,
        0.025,
      );
      for (let index = 0; index < 3; index++) {
        sphere(
          yellow,
          `ventosa_pulpo_${side}_${index}`,
          materials.pink,
          yellowX + side * (0.063 + index * 0.008),
          top + 0.06 - index * 0.013,
          yellowZ + 0.067,
          0.004,
          0.003,
          0.0015,
        );
      }
      sphere(
        yellow,
        `tentaculo_amarillo_pulpo_${side}`,
        materials.yellowLight,
        yellowX + side * 0.037,
        top + 0.02,
        yellowZ + 0.049,
        0.031,
        0.017,
        0.033,
      );
      stitch(
        yellow,
        `tirante_gris_pulpo_${side}`,
        materials.strap,
        [
          [yellowX + side * 0.039, top + 0.091, yellowZ + 0.027],
          [yellowX + side * 0.01, top + 0.061, yellowZ + 0.049],
          [yellowX - side * 0.021, top + 0.039, yellowZ + 0.037],
        ],
        0.0032,
      );
    }
    sphere(
      yellow,
      "hocico_tubular_pulpo",
      materials.orange,
      yellowX,
      top + 0.112,
      yellowZ + 0.063,
      0.028,
      0.029,
      0.015,
    );
    torus(
      yellow,
      "labio_rosa_pulpo",
      materials.pink,
      yellowX,
      top + 0.112,
      yellowZ + 0.078,
      0.019,
      0.007,
    );
    sphere(
      yellow,
      "boca_oscura_pulpo",
      materials.eye,
      yellowX,
      top + 0.112,
      yellowZ + 0.078,
      0.015,
      0.016,
      0.003,
    );
    sphere(
      yellow,
      "hebilla_tirantes_pulpo",
      materials.strap,
      yellowX,
      top + 0.061,
      yellowZ + 0.053,
      0.01,
      0.006,
      0.002,
    );
  }
  // Resplandor local suave del PC y teclado: sin proyectar sombras.
  const caseGlow = new THREE.PointLight(MORADO_BOMBILLA, 0.65, 0.35, 2);
  caseGlow.name = "resplandor_violeta_interior_pc";
  caseGlow.position.set(pcX - 0.055, bottom + 0.29, pcZ + 0.025);
  desk.add(caseGlow);
  const keyboardGlow = new THREE.PointLight(MORADO_BOMBILLA, 0.04, 0.2, 2);
  keyboardGlow.name = "resplandor_violeta_teclado";
  keyboardGlow.position.set(-0.06, 0.91, -1.37);
  desk.add(keyboardGlow);

  let spinning = true;
  let speed = 0;
  let lastUpdate = null;
  return {
    togglePower() {
      spinning = !spinning;
      powerRing.color.setHex(spinning ? 0xf5f9f6 : 0x64706e);
    },
    update(seconds) {
      const elapsed =
        lastUpdate === null ? 0 : Math.min(0.05, seconds - lastUpdate);
      lastUpdate = seconds;
      speed += ((spinning ? 10 : 0) - speed) * (1 - Math.exp(-elapsed * 4));
      for (const rotor of rotors) rotor.rotation.z += speed * elapsed;
    },
  };
}
