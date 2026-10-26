local files={state='estado anterior'}
local fail_write,fail_rename=false,false
package.loaded.json={encode=function() return 'estado nuevo' end,
    decode=function(text) assert(text=='estado anterior' or text=='estado nuevo'); return {value=text} end}
package.loaded.util={readFromFile=function(path) return files[path] end}
package.loaded['ffi/util']={fsyncOpenedFile=function() end,fsyncDirectory=function() end}
io.open=function(path)
    return {write=function(_,content) if fail_write then return nil end; files[path]=content; return true end,
        flush=function() return true end,close=function() return true end}
end
os.rename=function(source,target)
    if fail_rename then return nil,'fallo simulado' end
    files[target]=files[source]; files[source]=nil; return true
end
local Storage=dofile('kindle/todo.koplugin/storage.lua')
fail_write=true
assert(not pcall(Storage.save,'state',{}))
assert(Storage.load('state',{}).value=='estado anterior', 'Un fallo de escritura conserva la cola anterior')
fail_write=false; fail_rename=true
assert(not pcall(Storage.save,'state',{}))
assert(Storage.load('state',{}).value=='estado anterior', 'Una interrupción antes de confirmar conserva la cola anterior')
fail_rename=false
Storage.save('state',{})
assert(Storage.load('state',{}).value=='estado nuevo', 'El guardado completo sustituye la cola')
files.state='datos corruptos'
assert(not pcall(Storage.load,'state',{}), 'No restablecer una cola corrupta silenciosamente')
print('Persistencia: fallos de escritura y recuperación verificados')
