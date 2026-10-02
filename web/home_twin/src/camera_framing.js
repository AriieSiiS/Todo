import * as THREE from 'three';

// Ajusta el encuadre a las dimensiones proyectadas y al formato del visor.
export function frameOrthographicCamera(camera, bounds, direction) {
  const center = bounds.getCenter(new THREE.Vector3());
  const size = bounds.getSize(new THREE.Vector3());
  camera.position.copy(center).add(direction.clone().normalize()
    .multiplyScalar(Math.max(size.length() * 2, 20)));
  camera.lookAt(center);
  camera.updateMatrixWorld(true);
  const projected = new THREE.Box3();
  for (const x of [bounds.min.x, bounds.max.x]) {
    for (const y of [bounds.min.y, bounds.max.y]) {
      for (const z of [bounds.min.z, bounds.max.z]) {
        projected.expandByPoint(new THREE.Vector3(x, y, z)
          .applyMatrix4(camera.matrixWorldInverse));
      }
    }
  }
  const width = Math.max(projected.max.x - projected.min.x, 0.1);
  const height = Math.max(projected.max.y - projected.min.y, 0.1);
  camera.zoom = Math.min(
    (camera.right - camera.left) / width,
    (camera.top - camera.bottom) / height,
  ) * 0.84;
  camera.updateProjectionMatrix();
  return center;
}
