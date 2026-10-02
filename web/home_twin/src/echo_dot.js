import * as THREE from 'three';

export function createEchoDot(room) {
  const computer = room.getObjectByName('ordenador');
  if (!computer) return null;

  const echo = new THREE.Group();
  echo.name = 'echo_dot';
  echo.position.set(0.7, 1.2175, -1.66);
  computer.add(echo);

  const fabric = new THREE.MeshStandardMaterial({
    color: 0x25272b,
    roughness: 0.95,
  });
  const base = new THREE.MeshStandardMaterial({
    color: 0x17191d,
    roughness: 0.67,
  });
  const body = new THREE.Mesh(new THREE.SphereGeometry(0.05, 28, 20), fabric);
  body.name = 'cuerpo_echo_dot';
  body.scale.y = 0.8;
  body.position.y = 0.049;
  echo.add(body);

  const foot = new THREE.Mesh(new THREE.CylinderGeometry(0.043, 0.043, 0.009, 28), base);
  foot.name = 'base_echo_dot';
  foot.position.y = 0.0045;
  echo.add(foot);

  const ring = new THREE.Mesh(
    new THREE.TorusGeometry(0.043, 0.002, 6, 32),
    new THREE.MeshBasicMaterial({ color: 0x5f7692, toneMapped: false }),
  );
  ring.name = 'aro_echo_dot';
  ring.rotation.x = Math.PI / 2;
  ring.position.y = 0.009;
  echo.add(ring);

  const buttons = new THREE.MeshStandardMaterial({ color: 0x44474c, roughness: 0.76 });
  for (const [index, x, z] of [[1, -0.016, 0], [2, 0.016, 0], [3, 0, -0.016], [4, 0, 0.016]]) {
    const button = new THREE.Mesh(new THREE.CylinderGeometry(0.004, 0.004, 0.0015, 12), buttons);
    button.name = `boton_echo_dot_${index}`;
    button.position.set(x, 0.089, z);
    echo.add(button);
  }
  return echo;
}
