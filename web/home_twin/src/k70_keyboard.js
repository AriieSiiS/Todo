import * as THREE from 'three';
import { MORADO_BOMBILLA } from './pc_lighting_palette.js';

// K70 RGB MK.2 español: 438 × 166 × 39 mm. Cada tecla conserva su propio
// grupo y dos materiales de iluminación para enlazarla después con iCUE.
export function addK70Keyboard(desk, { roundedPanel, stitch }) {
  const keyboard = new THREE.Group();
  keyboard.name = 'teclado_corsair_k70_rgb_mk2';
  keyboard.position.set(-0.06, 0, -1.37);
  keyboard.userData.lightingTarget = { type: 'corsair-k70-rgb-mk2' };
  desk.add(keyboard);

  const aluminum = new THREE.MeshStandardMaterial({ color: 0x272c32, metalness: 0.69, roughness: 0.42 });
  const upperPlate = new THREE.MeshStandardMaterial({ color: 0x3b4148, metalness: 0.77, roughness: 0.38 });
  const edge = new THREE.MeshStandardMaterial({ color: 0x151a20, metalness: 0.31, roughness: 0.67 });
  const rubber = new THREE.MeshStandardMaterial({ color: 0x171c22, roughness: 0.97 });
  const metal = new THREE.MeshStandardMaterial({ color: 0x767e85, metalness: 0.86, roughness: 0.3 });
  roundedPanel(keyboard, 'carcasa_aluminio_438_166', aluminum,
    0, 0.773, 0, 0.438, 0.166, 0.011, 0.008);
  roundedPanel(keyboard, 'placa_aluminio_cepillado', upperPlate,
    0, 0.784, 0.002, 0.427, 0.151, 0.002, 0.004);
  roundedPanel(keyboard, 'canto_delantero', edge,
    0, 0.773, 0.079, 0.426, 0.004, 0.009, 0.001);
  for (const side of [-1, 1]) {
    roundedPanel(keyboard, `taco_goma_${side}`, rubber,
      side * 0.188, 0.771, 0.058, 0.018, 0.022, 0.002, 0.002);
  }

  const legends = new Map();
  // Letras y símbolos visibles sobre cada tecla; la barra espaciadora queda lisa.
  function legendTexture(label) {
    if (legends.has(label)) return legends.get(label);
    const canvas = document.createElement('canvas');
    canvas.width = 128;
    canvas.height = 128;
    const context = canvas.getContext('2d');
    context.clearRect(0, 0, 128, 128);
    context.fillStyle = '#ffffff';
    context.font = `700 ${label.length > 5 ? 36 : label.length > 2 ? 47 : 68}px Arial`;
    context.textAlign = 'center';
    context.textBaseline = 'middle';
    context.fillText(label, 64, 65);
    const texture = new THREE.CanvasTexture(canvas);
    texture.colorSpace = THREE.SRGBColorSpace;
    legends.set(label, texture);
    return texture;
  }

  const pitch = 0.01775;
  const start = -0.207;
  const rowZ = [-0.048, -0.021, 0.003, 0.027, 0.051, 0.072];
  const keys = new Map();
  function addKey(id, label, x, z, width = 0.0155, depth = 0.0174) {
    const key = new THREE.Group();
    key.name = `tecla_${id}`;
    key.position.set(x, 0, z);
    key.userData.lightingTarget = { type: 'corsair-k70-rgb-mk2-key', key: id };
    keyboard.add(key);
    const diffuser = new THREE.MeshStandardMaterial({
      color: 0x38234a, roughness: 0.54, transparent: true, opacity: 0.46,
      emissive: MORADO_BOMBILLA, emissiveIntensity: 0.28,
    });
    const capMaterial = new THREE.MeshStandardMaterial({
      color: 0x191c23, roughness: 0.76, metalness: 0.03,
    });
    roundedPanel(key, 'difusor_led_individual', diffuser,
      0, 0.787, 0, width + 0.0012, depth + 0.0012, 0.006, 0.002);
    roundedPanel(key, 'tecla_con_perfil_curvo', capMaterial,
      0, 0.793, 0, width, depth, 0.011, 0.0028);
    if (label) {
      const material = new THREE.MeshBasicMaterial({
        map: legendTexture(label), color: 0xf0d6ff,
        transparent: true, opacity: 1, depthWrite: false,
        toneMapped: false,
        side: THREE.DoubleSide,
      });
      const legend = new THREE.Mesh(new THREE.PlaneGeometry(
        Math.min(width * 0.84, label.length > 3 ? 0.028 : 0.014), 0.012), material);
      legend.name = `leyenda_visible_${id}`;
      legend.rotation.x = -Math.PI / 2;
      // La tapa biselada alcanza Y = 0.805; por debajo de esto la letra queda oculta.
      legend.position.y = 0.806;
      key.add(legend);
      key.userData.legendMaterial = material;
    }
    key.userData.diffuserMaterial = diffuser;
    key.userData.capMaterial = capMaterial;
    keys.set(id, key);
    return key;
  }
  function unit(id, label, row, unitX, span = 1, depth = 0.0174) {
    return addKey(id, label,
      start + (unitX + span / 2) * pitch, rowZ[row],
      span * pitch - 0.0022, depth);
  }
  function row(rowIndex, items) {
    let position = 0;
    for (const [id, label, width = 1] of items) {
      unit(id, label, rowIndex, position, width);
      position += width;
    }
  }

  unit('Escape', 'Esc', 0, 0);
  for (let index = 1; index <= 12; index++) {
    const extraGap = index > 8 ? 1.5 : index > 4 ? 1 : 0.5;
    unit(`F${index}`, `F${index}`, 0, index + extraGap);
  }
  row(1, [
    ['IntlBackslash', 'º'], ['Digit1', '1'], ['Digit2', '2'], ['Digit3', '3'],
    ['Digit4', '4'], ['Digit5', '5'], ['Digit6', '6'], ['Digit7', '7'],
    ['Digit8', '8'], ['Digit9', '9'], ['Digit0', '0'], ['Quote', "'"],
    ['¡', '¡'], ['Backspace', '⌫', 2],
  ]);
  row(2, [
    ['Tab', 'Tab', 1.5], ['KeyQ', 'Q'], ['KeyW', 'W'], ['KeyE', 'E'],
    ['KeyR', 'R'], ['KeyT', 'T'], ['KeyY', 'Y'], ['KeyU', 'U'],
    ['KeyI', 'I'], ['KeyO', 'O'], ['KeyP', 'P'], ['Backquote', '`'],
    ['BracketRight', '+'],
  ]);
  row(3, [
    ['CapsLock', 'Bloq', 1.75], ['KeyA', 'A'], ['KeyS', 'S'], ['KeyD', 'D'],
    ['KeyF', 'F'], ['KeyG', 'G'], ['KeyH', 'H'], ['KeyJ', 'J'],
    ['KeyK', 'K'], ['KeyL', 'L'], ['Semicolon', 'Ñ'], ['BracketLeft', '´'],
    ['Backslash', 'Ç'],
  ]);
  addKey('Enter', '↵', start + 14.375 * pitch, 0.015,
    1.25 * pitch - 0.0022, 0.041);
  row(4, [
    ['ShiftLeft', 'Mayús', 1.25], ['IntlRo', '<'], ['KeyZ', 'Z'],
    ['KeyX', 'X'], ['KeyC', 'C'], ['KeyV', 'V'], ['KeyB', 'B'],
    ['KeyN', 'N'], ['KeyM', 'M'], ['Comma', ','], ['Period', '.'],
    ['Slash', '-'], ['ShiftRight', 'Mayús', 2.75],
  ]);
  row(5, [
    ['ControlLeft', 'Ctrl', 1.25], ['MetaLeft', 'Win', 1.25],
    ['AltLeft', 'Alt', 1.25], ['Space', '', 6],
    ['AltRight', 'Alt Gr', 1.25], ['Fn', 'Fn', 1],
    ['ContextMenu', '☰', 1.25],
    ['ControlRight', 'Ctrl', 1.25],
  ]);

  const navigationX = [0.079, 0.097, 0.115];
  const navigationRows = [
    [0, ['PrintScreen', 'ScrollLock', 'Pause'], ['Imp', 'Bloq', 'Pausa']],
    [1, ['Insert', 'Home', 'PageUp'], ['Ins', 'Inicio', 'Re Pág']],
    [2, ['Delete', 'End', 'PageDown'], ['Supr', 'Fin', 'Av Pág']],
    [4, [null, 'ArrowUp', null], ['', '↑', '']],
    [5, ['ArrowLeft', 'ArrowDown', 'ArrowRight'], ['←', '↓', '→']],
  ];
  for (const [line, ids, labels] of navigationRows) {
    for (let column = 0; column < 3; column++) {
      if (ids[column]) addKey(ids[column], labels[column],
        navigationX[column], rowZ[line]);
    }
  }
  const numX = [0.142, 0.160, 0.178, 0.196];
  const numRows = [
    [['NumLock', 'Núm'], ['NumpadDivide', '/'], ['NumpadMultiply', '*'], ['NumpadSubtract', '-']],
    [['Numpad7', '7'], ['Numpad8', '8'], ['Numpad9', '9'], ['NumpadAdd', '+']],
    [['Numpad4', '4'], ['Numpad5', '5'], ['Numpad6', '6'], null],
    [['Numpad1', '1'], ['Numpad2', '2'], ['Numpad3', '3'], ['NumpadEnter', '↵']],
    [['Numpad0', '0'], null, ['NumpadDecimal', '.'], null],
  ];
  for (let line = 0; line < numRows.length; line++) {
    for (let column = 0; column < 4; column++) {
      const definition = numRows[line][column];
      if (!definition) continue;
      const wideZero = definition[0] === 'Numpad0';
      const tall = definition[0] === 'NumpadAdd' || definition[0] === 'NumpadEnter';
      addKey(definition[0], definition[1],
        numX[column] + (wideZero ? 0.009 : 0),
        rowZ[line + 1] + (tall ? 0.012 : 0),
        wideZero ? 0.032 : 0.0155, tall ? 0.041 : 0.0174);
    }
  }

  // Controles superiores propios del K70: perfil, brillo, bloqueo, logo,
  // silencio, rueda de volumen y cuatro teclas multimedia.
  for (const [index, label] of ['P', '☼', '⊞'].entries()) {
    const button = new THREE.Mesh(new THREE.CylinderGeometry(0.006, 0.006, 0.003, 24), edge);
    button.name = `control_superior_${label}`;
    button.position.set(-0.190 + index * 0.021, 0.789, -0.072);
    keyboard.add(button);
    const symbol = new THREE.Mesh(new THREE.PlaneGeometry(0.008, 0.008),
      new THREE.MeshStandardMaterial({ map: legendTexture(label), transparent: true }));
    symbol.rotation.x = -Math.PI / 2;
    symbol.position.set(button.position.x, 0.791, -0.072);
    keyboard.add(symbol);
  }
  // Logo CORSAIR: textura panorámica propia para que la palabra no se recorte
  // ni se estire desde el lienzo cuadrado utilizado por las teclas.
  const logoCanvas = document.createElement('canvas');
  logoCanvas.width = 1024;
  logoCanvas.height = 200;
  const logoContext = logoCanvas.getContext('2d');
  logoContext.fillStyle = '#f0d6ff';
  logoContext.font = '700 150px Arial, sans-serif';
  logoContext.textAlign = 'center';
  logoContext.textBaseline = 'middle';
  logoContext.fillText('CORSAIR', 512, 104);
  const logoTexture = new THREE.CanvasTexture(logoCanvas);
  logoTexture.colorSpace = THREE.SRGBColorSpace;
  logoTexture.anisotropy = 8;
  const logo = new THREE.Mesh(new THREE.PlaneGeometry(0.046, 0.009),
    new THREE.MeshBasicMaterial({
      map: logoTexture, transparent: true, depthWrite: false, toneMapped: false,
    }));
  logo.name = 'insignia_corsair';
  logo.rotation.x = -Math.PI / 2;
  logo.position.set(-0.014, 0.788, -0.072);
  keyboard.add(logo);
  for (const [index, name] of ['bloqueo_numerico', 'mayusculas', 'desplazamiento'].entries()) {
    const indicator = new THREE.Mesh(new THREE.SphereGeometry(0.0017, 10, 6), rubber);
    indicator.name = `indicador_${name}`;
    indicator.position.set(0.070 + index * 0.010, 0.790, -0.072);
    indicator.userData.lightingTarget = { type: 'corsair-k70-status', indicator: name };
    keyboard.add(indicator);
  }
  const mute = new THREE.Mesh(new THREE.CylinderGeometry(0.006, 0.006, 0.003, 24), edge);
  mute.name = 'boton_silencio';
  mute.position.set(0.146, 0.79, -0.072);
  keyboard.add(mute);
  // Rueda de volumen: radio de 6,5 mm y longitud de 21 mm.
  const wheel = new THREE.Mesh(new THREE.CylinderGeometry(0.0065, 0.0065, 0.021, 32), metal);
  wheel.name = 'rueda_volumen_metalica';
  wheel.rotation.z = Math.PI / 2;
  wheel.position.set(0.190, 0.795, -0.073);
  keyboard.add(wheel);
  const usbFrame = new THREE.Mesh(new THREE.BoxGeometry(0.019, 0.009, 0.004), metal);
  usbFrame.name = 'puerto_usb_pasante';
  usbFrame.position.set(0.202, 0.785, -0.081);
  keyboard.add(usbFrame);
  const usbOpening = new THREE.Mesh(new THREE.BoxGeometry(0.012, 0.004, 0.001), rubber);
  usbOpening.position.set(0.202, 0.785, -0.084);
  keyboard.add(usbOpening);
  for (let index = 0; index < 4; index++) {
    roundedPanel(keyboard, `boton_multimedia_${index + 1}`, edge,
      0.143 + index * 0.017, 0.786, -0.060, 0.012, 0.006, 0.003, 0.0015);
  }
  stitch(keyboard, 'cable_trenzado_usb', rubber, [
    [0, 0.782, -0.083], [0, 0.785, -0.118], [0.01, 0.783, -0.18],
    [0.06, 0.78, -0.30], [0.075, 0.775, -0.49],
    [0.075, 0.768, -0.58], [0.075, 0.745, -0.595],
  ], 0.0022);
  return { keyboard, keys };
}
