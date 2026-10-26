-- Cola persistente: un grupo por familia y fecha; los envíos sellados son inmutables.
local Queue = {}
Queue.__index = Queue

function Queue.new(items, new_id)
    return setmetatable({items=items or {}, new_id=new_id}, Queue)
end

function Queue:find(root_id, day)
    for _, item in ipairs(self.items) do
        if item.body.root_task_id == root_id and item.body.occurrence_date == day then return item end
    end
end

function Queue:toggle(root, task, day)
    local item = self:find(root.id, day)
    if item and item.state ~= 'draft' then error('Este envío ya se intentó. Reinténtalo o revisa el conflicto.') end
    if not item then
        item = {state='draft', title=root.title, body={request_id=self.new_id(),
            root_task_id=root.id, occurrence_date=day,
            expected_version=root.task_version, task_ids={}}}
        table.insert(self.items, item)
    end
    for index, value in ipairs(item.body.task_ids) do
        if value == task.id then
            table.remove(item.body.task_ids, index)
            if #item.body.task_ids == 0 then self:discard(item) end
            return
        end
    end
    table.insert(item.body.task_ids, task.id)
end

function Queue:seal(item)
    assert(item.state ~= 'conflict', 'Primero revisa el conflicto.')
    item.state = 'sending'
    return item.body
end

function Queue:discard(item)
    assert(item.state ~= 'sending', 'La respuesta del envío sigue pendiente.')
    for index, value in ipairs(self.items) do
        if value == item then table.remove(self.items, index); return end
    end
end

function Queue:receive(item, status, result)
    if status == 200 and result.savedLocally == true and result.status == 'saved'
        and result.request_id == item.body.request_id then
        item.state = 'saved'
        self:discard(item)
        return true
    elseif status == 409 and result.status == 'conflict' then
        item.state = 'conflict'
        item.current = type(result.current) == 'table' and result.current or nil
        item.error = result.error or 'La tarea cambió. Revisa la marca.'
    elseif status == 400 then
        item.state, item.current = 'conflict', nil
        item.error = result.error or 'La marca no es válida. Revísala antes de descartarla.'
    else
        item.error = result.error or 'Sin confirmación de guardado. Se conserva el envío.'
    end
    return false
end

function Queue:confirm(item)
    assert(item.state == 'conflict' and item.current, 'La tarea ya no está disponible.')
    local current = item.current
    local members = {}
    local function visit(task)
        members[task.id] = task
        for _, child in ipairs(task.subtasks or {}) do visit(child) end
    end
    visit(current)
    for _, task_id in ipairs(item.body.task_ids) do
        assert(members[task_id] and not members[task_id].blocked and not current.blocked,
            'Revisa esta tarea desde Todo.')
    end
    item.body.request_id = self.new_id()
    item.body.expected_version = current.task_version
    item.state, item.current, item.error = 'draft', nil, nil
end

return Queue
