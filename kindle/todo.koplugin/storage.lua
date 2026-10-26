local json = require('json')
local util = require('util')
local ffiutil = require('ffi/util')
local Storage = {}

function Storage.load(path, default)
    local content = util.readFromFile(path)
    if not content then return default end
    local ok, result = pcall(json.decode, content)
    assert(ok and type(result) == 'table', 'No se pudieron leer los datos de Todo. Conserva el archivo para recuperarlo.')
    return result
end

function Storage.save(path, value)
    local temporary = path .. '.tmp'
    local file = assert(io.open(temporary, 'wb'), 'No se pudo abrir el archivo de la cola.')
    local ok, err = pcall(function()
        assert(file:write(json.encode(value)), 'No se pudo escribir la cola en el Kindle.')
        assert(file:flush(), 'No se pudo guardar la cola en el Kindle.')
        ffiutil.fsyncOpenedFile(file)
    end)
    file:close()
    assert(ok, err)
    assert(os.rename(temporary, path), 'No se pudo confirmar el guardado local de la cola.')
    ffiutil.fsyncDirectory(path)
end

return Storage
