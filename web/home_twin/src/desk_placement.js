// Coloca el escritorio contra la pared derecha y conserva encima el ordenador.
export function placeDeskAgainstRightWall(room) {
  const table = room.getObjectByName('escritorio');
  const tabletop = room.getObjectByName('tablero_escritorio');
  const computer = room.getObjectByName('ordenador');
  const rightWall = room.getObjectByName('pared_larga_derecha');
  if (!table || !tabletop || !computer || !rightWall) return;

  const wallInnerEdge = rightWall.position.x - rightWall.scale.x / 2;
  const tabletopRightEdge = table.position.x + tabletop.position.x + tabletop.scale.x / 2;
  const clearance = 0.005;
  const shift = wallInnerEdge - clearance - tabletopRightEdge;
  table.position.x += shift;
  computer.position.x += shift;
}
