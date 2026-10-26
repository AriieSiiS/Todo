-- Comprueba la entrada de recuperación y la habilitación del siguiente arranque.
local archivos={}
package.loaded['libs/libkoreader-lfs']={attributes=function(path) return archivos[path] and 'file' or nil end}
local io_real,remove_real=io.open,os.remove
io.open=function(path,mode)
    if mode=='wb' then
        return {close=function() archivos[path]=true; return true end}
    end
    return nil
end
os.remove=function(path) archivos[path]=nil; return true end
local Arranque=dofile('kindle/todo.koplugin/arranque.lua')
local base='/mnt/us/system/todo-koreader/'
assert(not Arranque.disponible())
archivos[base .. 'launch.sh']=true
archivos[base .. 'activado']=true
assert(Arranque.disponible() and Arranque.habilitado())
assert(Arranque.habilitar(false))
assert(not Arranque.habilitado() and archivos[base .. 'desactivado'])
assert(Arranque.habilitar(true))
assert(Arranque.habilitado())
archivos['/mnt/us/DESACTIVAR_INICIO_TODO']=true
assert(not Arranque.habilitado())
assert(not Arranque.habilitar(true), 'La marca USB de recuperación requiere retirarla expresamente')
io.open,os.remove=io_real,remove_real
print('Arranque: controles de habilitación y recuperación verificados.')
