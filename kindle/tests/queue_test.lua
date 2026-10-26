local Queue = dofile('kindle/todo.koplugin/queue.lua')
local function check(value, message) assert(value, message) end
local count = 0
local function id() count = count + 1; return 'marca-prueba-' .. count end
local root = {id='r', title='Cuidados', root_task_id='r', task_version='version-1',
    subtasks={{id='a', title='Agua'}, {id='b', title='Comida'}}}
local q = Queue.new({}, id)
q:toggle(root, root.subtasks[1], '2026-10-23')
q:toggle(root, root.subtasks[2], '2026-10-23')
check(#q.items == 1 and #q.items[1].body.task_ids == 2, 'Las hermanas forman un grupo')
local body = q:seal(q.items[1])
local original_id = body.request_id
q = Queue.new(q.items, id)
check(q:seal(q.items[1]).request_id == original_id, 'El reinicio conserva el envío sellado')
check(not pcall(function() q:toggle(root, root.subtasks[1], '2026-10-23') end), 'No se modifica un envío incierto')
q:receive(q.items[1], 503, {error='PC apagado'})
check(#q.items == 1 and q.items[1].body.occurrence_date == '2026-10-23', 'Conservar fecha y cuerpo')
q:receive(q.items[1], 409, {status='conflict', current=root, error='Cambió'})
check(q.items[1].state == 'conflict', 'El conflicto requiere revisión')
q:confirm(q.items[1])
check(q.items[1].body.request_id ~= original_id, 'La revisión crea una operación nueva')
q:receive(q.items[1], 200, {savedLocally=true, status='saved', request_id=q.items[1].body.request_id})
check(#q.items == 0, 'Solo el guardado confirmado retira la marca')
q:toggle(root, root.subtasks[1], '2026-10-23')
q:toggle(root, root.subtasks[1], '2026-10-23')
check(#q.items == 0, 'Se puede cancelar una marca sin enviar')
print('Cola: pruebas superadas')
