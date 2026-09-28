import * as THREE from "three";
import razerLogo from "./razer_logo_oficial.png";

// Ratón Razer Viper Ultimate RZ01-03050: 126,7 × 66,2 × 37,8 mm.
// X mueve izquierda/derecha, Y sube/baja y Z va del fondo a la entrada; todo en metros.
export function addRazerViperMouse(desk, { stitch }) {
  const mouse = new THREE.Group();
  mouse.name = "raton_inalambrico_razer_viper_ultimate";
  // Posición del ratón sobre la alfombrilla: cambia estos tres números para moverlo.
  mouse.position.set(0.3, 0, -1.36);
  desk.add(mouse);

  const base = 0.773;
  const length = 0.1267;
  const dark = new THREE.MeshStandardMaterial({
    color: 0x1c2025,
    roughness: 0.6,
    metalness: 0.05,
  });
  const top = new THREE.MeshStandardMaterial({
    color: 0x2a2d32,
    roughness: 0.62,
    metalness: 0.05,
    side: THREE.DoubleSide,
  });
  const rubber = new THREE.MeshStandardMaterial({
    color: 0x11161b,
    roughness: 0.98,
  });
  const gripDot = new THREE.MeshStandardMaterial({
    color: 0x3b4146,
    roughness: 1,
  });
  const seam = new THREE.MeshStandardMaterial({
    color: 0x0b0f13,
    roughness: 0.91,
  });
  const wheelRim = new THREE.MeshStandardMaterial({
    color: 0x525960,
    roughness: 0.58,
    metalness: 0.27,
  });
  // La carcasa apoya directamente sobre la alfombrilla, sin plataforma adicional.
  // Carcasa curva: cada fila define Z, semiancho y altura del perfil.
  const profile = [
    [-length / 2, 0.011, 0.011],
    [-0.057, 0.021, 0.021],
    [-0.044, 0.027, 0.028],
    [-0.025, 0.031, 0.034],
    [-0.003, 0.0331, 0.0378],
    [0.02, 0.031, 0.036],
    [0.042, 0.027, 0.029],
    [0.056, 0.02, 0.019],
    [length / 2, 0.01, 0.009],
  ];
  function shapeAt(z) {
    for (let index = 1; index < profile.length; index++) {
      if (z > profile[index][0]) continue;
      const before = profile[index - 1];
      const after = profile[index];
      const t = (z - before[0]) / (after[0] - before[0]);
      return [
        THREE.MathUtils.lerp(before[1], after[1], t),
        THREE.MathUtils.lerp(before[2], after[2], t),
      ];
    }
    return [profile.at(-1)[1], profile.at(-1)[2]];
  }
  function surfaceHeight(x, z) {
    const [halfWidth, height] = shapeAt(z);
    const ratio = Math.min(0.99, Math.abs(x) / halfWidth);
    return base + (height * (1 + Math.sqrt(1 - ratio * ratio))) / 2;
  }

  const vertices = [];
  const indices = [];
  const around = 24;
  for (const [z, halfWidth, height] of profile) {
    for (let angleIndex = 0; angleIndex <= around; angleIndex++) {
      const angle = (angleIndex * 2 * Math.PI) / around;
      vertices.push(
        halfWidth * Math.cos(angle),
        base + (height * (1 + Math.sin(angle))) / 2,
        z,
      );
    }
  }
  for (let row = 0; row < profile.length - 1; row++) {
    for (let column = 0; column < around; column++) {
      const a = row * (around + 1) + column;
      const b = a + around + 1;
      indices.push(a, a + 1, b, a + 1, b + 1, b);
    }
  }
  const shellGeometry = new THREE.BufferGeometry();
  shellGeometry.setAttribute(
    "position",
    new THREE.Float32BufferAttribute(vertices, 3),
  );
  shellGeometry.setIndex(indices);
  shellGeometry.computeVertexNormals();
  const shell = new THREE.Mesh(shellGeometry, dark);
  shell.name = "carcasa_ambidiestra_curva";
  mouse.add(shell);

  // Botón izquierdo y botón derecho: las placas siguen la curvatura y dejan visible
  // la hendidura central del Viper Ultimate.
  for (const side of [-1, 1]) {
    const buttonVertices = [];
    const buttonIndices = [];
    const stations = [-0.057, -0.048, -0.034, -0.019, -0.005];
    for (const z of stations) {
      const [halfWidth] = shapeAt(z);
      for (const fraction of [0.13, 0.36, 0.62, 0.84]) {
        const x = side * halfWidth * fraction;
        buttonVertices.push(x, surfaceHeight(x, z) + 0.0012, z);
      }
    }
    for (let row = 0; row < stations.length - 1; row++) {
      for (let column = 0; column < 3; column++) {
        const a = row * 4 + column;
        buttonIndices.push(a, a + 4, a + 1, a + 1, a + 4, a + 5);
      }
    }
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute(
      "position",
      new THREE.Float32BufferAttribute(buttonVertices, 3),
    );
    geometry.setIndex(buttonIndices);
    geometry.computeVertexNormals();
    const button = new THREE.Mesh(geometry, top);
    button.name = side < 0 ? "boton_izquierdo" : "boton_derecho";
    mouse.add(button);
    stitch(
      mouse,
      `ranura_exterior_${side}`,
      seam,
      stations.map((z) => {
        const [halfWidth] = shapeAt(z);
        const x = side * halfWidth * 0.88;
        return [x, surfaceHeight(x, z) + 0.0016, z];
      }),
      0.0007,
    );
  }
  stitch(
    mouse,
    "separacion_de_los_dos_botones",
    seam,
    [
      [0, base + 0.021, -0.059],
      [0, base + 0.029, -0.047],
      [0, base + 0.033, -0.031],
      [0, base + 0.037, -0.012],
    ],
    0.0013,
  );

  // Rueda central de goma con aro gris y relieve transversal.
  const wheel = new THREE.Mesh(
    new THREE.CylinderGeometry(0.008, 0.008, 0.011, 28),
    rubber,
  );
  wheel.name = "rueda_goma_texturizada";
  wheel.rotation.z = Math.PI / 2;
  wheel.position.set(0, base + 0.025, -0.04);
  mouse.add(wheel);
  for (const side of [-1, 1]) {
    const rim = new THREE.Mesh(
      new THREE.TorusGeometry(0.0075, 0.0008, 6, 28),
      wheelRim,
    );
    rim.name = `aro_rueda_${side}`;
    rim.rotation.y = Math.PI / 2;
    rim.position.set(side * 0.0057, base + 0.025, -0.04);
    mouse.add(rim);
  }
  for (let index = 0; index < 20; index++) {
    const angle = (index * Math.PI * 2) / 20;
    const ridge = new THREE.Mesh(
      new THREE.BoxGeometry(0.008, 0.001, 0.001),
      wheelRim,
    );
    ridge.name = `relieve_rueda_${index + 1}`;
    ridge.position.set(
      0,
      base + 0.025 + Math.sin(angle) * 0.008,
      -0.04 + Math.cos(angle) * 0.008,
    );
    ridge.rotation.x = -angle;
    mouse.add(ridge);
  }

  // Emblema oficial de Razer: su silueta se conserva y se ilumina en morado.
  // El PNG contiene píxeles blancos transparentes: usarlo como alphaMap dibuja
  // sus canales de color y deja líneas. El lienzo conserva solo su alfa real.
  const logoCanvas = document.createElement("canvas");
  logoCanvas.width = 256;
  logoCanvas.height = 256;
  const logoTexture = new THREE.CanvasTexture(logoCanvas);
  logoTexture.colorSpace = THREE.SRGBColorSpace;
  logoTexture.magFilter = THREE.LinearFilter;
  const logoImage = new Image();
  logoImage.onload = () => {
    const context = logoCanvas.getContext("2d");
    context.drawImage(logoImage, 0, 0, logoCanvas.width, logoCanvas.height);
    context.globalCompositeOperation = "source-in";
    context.fillStyle = "#d537c4";
    context.fillRect(0, 0, logoCanvas.width, logoCanvas.height);
    logoTexture.needsUpdate = true;
  };
  logoImage.src = razerLogo;
  const logoMaterial = new THREE.MeshBasicMaterial({
    map: logoTexture,
    transparent: true,
    depthWrite: false,
    side: THREE.DoubleSide,
    toneMapped: false,
  });
  const logo = new THREE.Mesh(
    new THREE.PlaneGeometry(0.027, 0.027),
    logoMaterial,
  );
  logo.name = "emblema_razer_en_lomo";
  logo.rotation.x = -Math.PI / 2;
  logo.position.set(0, base + 0.0366, 0.021);
  mouse.add(logo);
  mouse.userData.lightingTarget = {
    type: "razer-viper-ultimate",
    zone: "logo",
  };
  return mouse;
}
