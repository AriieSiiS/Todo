import * as THREE from 'three';

const WIDTH = 1040;
const HEIGHT = 600;

function drawIcon(context, kind, x, y) {
  context.save();
  context.translate(x, y);
  if (kind === 'papelera') {
    context.fillStyle = '#e4eef3';
    context.fillRect(8, 10, 27, 29);
    context.fillRect(4, 7, 35, 5);
    context.fillRect(14, 3, 15, 4);
    context.fillStyle = '#86b9d0';
    context.fillRect(14, 16, 4, 17);
    context.fillRect(22, 16, 4, 17);
    context.fillRect(30, 16, 4, 17);
  } else if (kind === 'equipo') {
    context.fillStyle = '#a9d8eb';
    context.fillRect(3, 5, 37, 26);
    context.fillStyle = '#254b70';
    context.fillRect(6, 8, 31, 20);
    context.fillStyle = '#dce9ed';
    context.fillRect(18, 31, 7, 5);
    context.fillRect(10, 36, 23, 3);
  } else if (kind === 'todo') {
    context.fillStyle = '#6d9c78';
    context.fillRect(4, 4, 35, 35);
    context.strokeStyle = '#f6fff4';
    context.lineWidth = 5;
    context.beginPath();
    context.moveTo(11, 22);
    context.lineTo(19, 29);
    context.lineTo(33, 13);
    context.stroke();
  } else if (kind === 'musica') {
    context.fillStyle = '#bb7da4';
    context.fillRect(7, 4, 31, 34);
    context.fillStyle = '#f9e8f0';
    context.font = 'bold 31px Segoe UI Symbol, sans-serif';
    context.fillText('♫', 9, 33);
  } else if (kind === 'fotos') {
    context.fillStyle = '#edf1e7';
    context.fillRect(4, 4, 35, 35);
    context.fillStyle = '#78b5cb';
    context.fillRect(7, 7, 29, 29);
    context.fillStyle = '#e8d9a5';
    context.fillRect(25, 10, 6, 6);
    context.fillStyle = '#5a8c7a';
    context.beginPath();
    context.moveTo(8, 33);
    context.lineTo(18, 20);
    context.lineTo(25, 27);
    context.lineTo(31, 22);
    context.lineTo(36, 33);
    context.fill();
  } else if (kind === 'notas') {
    context.fillStyle = '#f0d991';
    context.fillRect(6, 3, 31, 37);
    context.fillStyle = '#826a4a';
    for (const line of [14, 21, 28]) context.fillRect(12, line, 18, 2);
  } else {
    context.fillStyle = '#e7bf66';
    context.fillRect(3, 13, 37, 24);
    context.fillStyle = '#f3d58a';
    context.fillRect(5, 7, 17, 10);
    context.fillRect(5, 16, 34, 19);
  }
  context.restore();
}

function drawTaskbarIcon(context, kind, x, y) {
  context.save();
  context.translate(x, y);
  if (kind === 'inicio') {
    context.fillStyle = '#89c9f5';
    for (const dx of [-8, 2]) {
      for (const dy of [-8, 2]) context.fillRect(dx, dy, 8, 8);
    }
  } else if (kind === 'explorador') {
    context.fillStyle = '#f7ce72';
    context.fillRect(-10, -5, 20, 15);
    context.fillStyle = '#efb849';
    context.fillRect(-10, -9, 10, 5);
  } else if (kind === 'navegador') {
    context.fillStyle = '#45bdcf';
    context.beginPath();
    context.arc(0, 0, 11, 0, Math.PI * 2);
    context.fill();
    context.fillStyle = '#276aa7';
    context.beginPath();
    context.arc(3, 2, 6, 0, Math.PI * 2);
    context.fill();
  } else if (kind === 'todo') {
    context.fillStyle = '#88b796';
    context.fillRect(-10, -10, 20, 20);
    context.strokeStyle = '#f9fff8';
    context.lineWidth = 3;
    context.beginPath();
    context.moveTo(-5, 0);
    context.lineTo(-1, 4);
    context.lineTo(6, -5);
    context.stroke();
  } else {
    context.fillStyle = '#9d8dc3';
    context.fillRect(-9, -10, 18, 20);
    context.fillStyle = '#e6def5';
    context.fillRect(-5, -5, 10, 10);
  }
  context.restore();
}

function drawDesktop(context, monitorIndex, now) {
  context.clearRect(0, 0, WIDTH, HEIGHT);
  const icons = monitorIndex === 1
    ? [['papelera', 'Papelera'], ['equipo', 'Este equipo'],
      ['carpeta', 'Juegos'], ['todo', 'Todo']]
    : [['carpeta', 'Carpeta'], ['fotos', 'Fotos'],
      ['musica', 'Música'], ['notas', 'Notas']];
  context.textAlign = 'center';
  context.font = '15px Segoe UI, sans-serif';
  context.shadowColor = '#08131bc9';
  context.shadowBlur = 4;
  for (const [index, [kind, label]] of icons.entries()) {
    const x = 24;
    const y = 18 + index * 92;
    drawIcon(context, kind, x, y);
    context.fillStyle = '#ffffff';
    context.fillText(label, x + 21, y + 60);
  }
  context.shadowBlur = 0;

  context.fillStyle = 'rgba(22, 29, 37, 0.81)';
  context.fillRect(0, HEIGHT - 43, WIDTH, 43);
  context.fillStyle = 'rgba(237, 244, 250, 0.21)';
  context.fillRect(0, HEIGHT - 43, WIDTH, 1);
  const pinned = ['inicio', 'explorador', 'navegador', 'todo', 'aplicacion'];
  const startX = 26;
  pinned.forEach((kind, index) =>
    drawTaskbarIcon(context, kind, startX + index * 32, HEIGHT - 21));
  context.fillStyle = '#b5d8eb';
  context.fillRect(startX + (monitorIndex === 1 ? 3 : 99), HEIGHT - 3, 26, 2);

  context.strokeStyle = '#e9eef2';
  context.lineWidth = 2;
  for (const radius of [4, 8]) {
    context.beginPath();
    context.arc(WIDTH - 134, HEIGHT - 18, radius, Math.PI * 1.18, Math.PI * 1.82);
    context.stroke();
  }
  context.fillStyle = '#e9eef2';
  context.beginPath();
  context.arc(WIDTH - 134, HEIGHT - 15, 2, 0, Math.PI * 2);
  context.fill();
  context.fillRect(WIDTH - 116, HEIGHT - 24, 5, 11);
  context.beginPath();
  context.moveTo(WIDTH - 111, HEIGHT - 24);
  context.lineTo(WIDTH - 104, HEIGHT - 29);
  context.lineTo(WIDTH - 104, HEIGHT - 9);
  context.lineTo(WIDTH - 111, HEIGHT - 14);
  context.fill();

  const time = now.toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit' });
  const date = now.toLocaleDateString('es-ES', { day: '2-digit', month: '2-digit' });
  context.font = '15px Segoe UI, sans-serif';
  context.textAlign = 'right';
  context.fillStyle = '#f0f3f5';
  context.fillText(time, WIDTH - 15, HEIGHT - 24);
  context.font = '12px Segoe UI, sans-serif';
  context.fillText(date, WIDTH - 15, HEIGHT - 8);
}

export function addDesktopOverlay(root, monitorIndex) {
  const screen = root.getObjectByName(`pantalla_${monitorIndex}`);
  if (!screen?.parent) return null;
  const canvas = document.createElement('canvas');
  canvas.width = WIDTH;
  canvas.height = HEIGHT;
  const context = canvas.getContext('2d');
  if (!context) return null;
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.minFilter = THREE.LinearMipmapLinearFilter;
  texture.magFilter = THREE.LinearFilter;
  const overlay = new THREE.Mesh(
    new THREE.PlaneGeometry(screen.scale.x * 0.985, screen.scale.y * 0.985),
    new THREE.MeshBasicMaterial({
      map: texture,
      transparent: true,
      depthWrite: false,
      toneMapped: false,
    }),
  );
  overlay.name = `escritorio_windows_monitor_${monitorIndex}`;
  overlay.position.copy(screen.position);
  overlay.position.z += screen.scale.z / 2 + 0.012;
  overlay.renderOrder = 10;
  screen.parent.add(overlay);
  const update = () => {
    drawDesktop(context, monitorIndex, new Date());
    texture.needsUpdate = true;
  };
  update();
  return update;
}
