local original=dofile
local writes=0
local collections={coll={Favoritos={['/otros/libro.epub']={file='/otros/libro.epub'}}},coll_settings={Favoritos={order=1}}}
function collections:addCollection(name) self.coll[name]={}; self.coll_settings[name]={order=2} end
function collections:addItem(file,name) self.coll[name][file]={file=file} end
function collections:removeItem(file,name,no_write)
    assert(name=='Mis libros' and no_write==true)
    self.coll[name][file]=nil
end
function collections:write() writes=writes+1 end
package.loaded.readcollection=collections
local preferences={todo_library_view='list'}
G_reader_settings={isTrue=function(_,key) return preferences[key]==true end,
    readSetting=function(_,key,default) if preferences[key]~=nil then return preferences[key] end; return default end,
    saveSetting=function(_,key,value) preferences[key]=value end}
local cover_settings={}
package.loaded.bookinfomanager={saveSetting=function(_,key,value) cover_settings[key]=value end,
    getSetting=function(_,key) return cover_settings[key] end}
local tree={
    ['/mnt/us/documents']={'Autor','dictionaries','Descargas','Apuntes.sdr','Novela.epub','Novela.mobi','My Clippings.txt','KOReader.sh'},
    ['/mnt/us/documents/Autor']={'Otro libro.mobi'},
    ['/mnt/us/documents/dictionaries']={'Diccionario.azw'},
    ['/mnt/us/documents/Descargas']={'English Dictionary.azw','Tercer libro.azw3','Tercer libro.epub'},
    ['/mnt/us/documents/Apuntes.sdr']={'metadata.epub.lua'},
}
package.loaded['libs/libkoreader-lfs']={
    dir=function(path)
        local names=assert(tree[path],path); local index=0
        return function() index=index+1; return names[index] end
    end,
    attributes=function(path,field)
        assert(field=='mode')
        if path=='/mnt/us/documents/Eliminado.epub' then return nil end
        return tree[path] and 'directory' or 'file'
    end,
}
local azw3_available=false
package.loaded['document/documentregistry']={hasProvider=function(_,file)
    return not file:match('%.azw3$') or azw3_available
end}
local ui={collections={},coverbrowser={
    setupFileManagerDisplayMode=function(_,mode) cover_settings.explorer=mode end,
    setupWidgetDisplayMode=function(widget,mode) cover_settings[widget]=mode; cover_settings.collection_display_mode=mode end,
    getUpdateItemTableFunc=function() return function() end end,
}}
local Library=original('kindle/todo.koplugin/library.lua')
local name=Library.prepare(ui)
assert(name=='Mis libros', 'La biblioteca tiene un nombre visible en castellano')
local books=assert(collections.coll[name])
local count=0; for _ in pairs(books) do count=count+1 end
assert(count==3 and books['/mnt/us/documents/Autor/Otro libro.mobi'] and books['/mnt/us/documents/Novela.epub'],
    'La biblioteca reúne libros de varias carpetas sin incluir diccionarios ni archivos auxiliares')
assert(not books['/mnt/us/documents/Descargas/Tercer libro.azw3']
    and books['/mnt/us/documents/Descargas/Tercer libro.epub'],
    'Solo se ofrecen formatos con lector disponible, aunque exista un AZW3 del mismo libro')
assert(not books['/mnt/us/documents/Novela.mobi'],
    'Se ofrece el EPUB cuando existe el mismo libro en MOBI sin borrar su archivo')
collections:addItem('/mnt/us/documents/Novela.mobi',name)
collections:addItem('/mnt/us/documents/Descargas/Tercer libro.azw3',name)
collections:addItem('/mnt/us/documents/Eliminado.epub',name)
collections:addItem('/otros/Libro manual.epub',name)
Library.prepare(ui)
assert(not books['/mnt/us/documents/Descargas/Tercer libro.azw3']
    and not books['/mnt/us/documents/Eliminado.epub'] and books['/otros/Libro manual.epub']
    and not books['/mnt/us/documents/Novela.mobi'],
    'Se retiran entradas incompatibles o ausentes y se conservan libros válidos añadidos manualmente')
assert(collections.coll.Favoritos['/otros/libro.epub'], 'Se conservan las otras colecciones')
assert(cover_settings.collections=='list_image_meta' and cover_settings.files_per_page==7
    and cover_settings.hide_page_info==false and cover_settings.show_pages_read_as_progress==false,
    'La biblioteca muestra portadas pequeñas y el porcentaje de KOReader')
cover_settings.files_per_page=5
tree['/mnt/us/documents/Autor'][2]='Libro nuevo.pdf'
Library.prepare(ui)
assert(books['/mnt/us/documents/Autor/Libro nuevo.pdf'] and cover_settings.files_per_page==5,
    'Una nueva apertura descubre libros y respeta los ajustes posteriores de la biblioteca')
local previous=writes
Library.prepare(ui)
assert(writes==previous, 'Una consulta sin cambios no vuelve a guardar la colección')
local classic=function() end
package.loaded['apps/filemanager/filemanagercollection']={updateItemTable=classic}
cover_settings.collection_display_mode=nil
Library.prepare(ui)
assert(ui.collections.updateItemTable==classic, 'Si se elige la vista clásica se respeta también esa preferencia')
azw3_available=true
tree['/mnt/us/documents/Descargas'][4]='Solo AZW3.azw3'
Library.prepare(ui)
assert(books['/mnt/us/documents/Descargas/Solo AZW3.azw3'],
    'Un lector añadido posteriormente puede habilitar otro formato sin cambiar Todo')
local history={{file='/mnt/us/documents/Novela.epub'},{file='/mnt/us/documents/Autor/Otro libro.mobi'}}
local recent=Library.recentSort(history)
local sorted={{file='/sin/leer.epub',text='A'}, {file=history[2].file,text='B'}, {file=history[1].file,text='Z'}}
table.sort(sorted,recent)
assert(sorted[1].file==history[1].file and sorted[2].file==history[2].file,
    'El historial real ordena las portadas; leer metadatos no altera la última lectura')
Library.toggleView()
assert(Library.view()=='covers' and preferences.todo_library_view=='covers')
package.loaded.mosaicmenu={_updateItemsBuildUI=function() end}
package.loaded.readhistory={hist=history}
local rendered
ui.coverbrowser.getUpdateItemTableFunc=function(mode)
    return function(manager) rendered={mode=mode,menu=manager.booklist_menu} end
end
Library.prepare(ui)
ui.collections.booklist_menu={path='Mis libros'}
ui.collections:updateItemTable()
assert(rendered.mode=='mosaic_image' and rendered.menu.todo_cover_grid
    and rendered.menu.nb_cols_portrait==2 and rendered.menu.nb_rows_portrait==2,
    'La segunda vista usa cuatro portadas grandes sin cambiar la lista existente')
assert(cover_settings.collection_display_mode==nil and cover_settings.files_per_page==5,
    'La nueva vista no modifica las preferencias generales de las otras colecciones')
Library.toggleView()
assert(Library.view()=='list', 'Se puede volver a la lista y conservar la elección')
print('Biblioteca: libros agrupados, portadas, progreso y ajustes conservados')
