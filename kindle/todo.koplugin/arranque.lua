-- Control del arranque instalado; las marcas no modifican la agenda ni los libros.
local lfs = require('libs/libkoreader-lfs')
local Arranque = {}
local base = '/mnt/us/system/todo-koreader/'
local rescate = '/mnt/us/DESACTIVAR_INICIO_TODO'

function Arranque.disponible()
    return lfs.attributes(base .. 'launch.sh', 'mode') == 'file'
end

function Arranque.habilitado()
    return lfs.attributes(base .. 'activado', 'mode') == 'file'
        and not lfs.attributes(base .. 'desactivado', 'mode')
        and not lfs.attributes(rescate, 'mode')
end

function Arranque.habilitar(valor)
    if valor then
        if lfs.attributes(rescate, 'mode') then
            return nil, 'Retira DESACTIVAR_INICIO_TODO de la raíz USB para habilitar el inicio automático.'
        end
        if lfs.attributes(base .. 'desactivado', 'mode') then
            local ok, message = os.remove(base .. 'desactivado')
            if not ok then return nil, message end
        end
        local file, message = io.open(base .. 'activado', 'wb')
        if not file then return nil, message end
        return file:close()
    end
    local file, message = io.open(base .. 'desactivado', 'wb')
    if not file then return nil, message end
    return file:close()
end

return Arranque
