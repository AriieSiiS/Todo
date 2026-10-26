local original=dofile
local Button={}
function Button:new(value)
    value.setText=function(self,text) self.text=text end
    return value
end
package.loaded['ui/widget/button']=Button
local shown={}
local InfoMessage={new=function(_,message) shown[#shown+1]=message; return message end}
package.loaded['ui/widget/infomessage']=InfoMessage
local calls={}
local Reader={showReaderCoroutine=function(self,file,provider,seamless)
    calls[#calls+1]={self,file,provider,seamless}
    InfoMessage:new{text="Abriendo archivo 'documents/Autor/Un libro.epub'.",timeout=0,invisible=seamless}
    InfoMessage:new{text='Un aviso independiente.',timeout=0}
    if file=='fallo.epub' then error('Fallo de prueba al abrir el libro') end
end}
package.loaded['apps/reader/readerui']=Reader
local ticks={}
package.loaded['ui/uimanager']={tickAfterNext=function(_,callback) ticks[#ticks+1]=callback end}
local opened,library,extras=0,0,0
local old_freed=0
local ui={}
function ui:setupLayout()
    local old={width=64,height=64,padding=8,free=function() old_freed=old_freed+1 end}
    self.title_bar={right_button=old,old}
end
function ui:onShowPlusMenu() extras=extras+1 end
local todo={ui=ui,open=function() opened=opened+1 end,openLibrary=function() library=library+1 end}
local Navigation=original('kindle/todo.koplugin/navigation.lua')
Navigation.install(todo)
ui:setupLayout()
assert(ui:onHome() and library==1, 'La casa abre los libros en lugar de una carpeta')
local button=ui.title_bar.right_button
assert(button.text=='Todo', 'El regreso a las tareas tiene un botón visible con su nombre')
button.callback()
assert(opened==1, 'El botón del explorador abre Todo directamente')
button.hold_callback()
assert(extras==1, 'La pulsación larga conserva las opciones de archivos')
ui.selected_files={}
button:setIcon('check')
button.callback()
assert(extras==2 and opened==1, 'La selección de archivos conserva sus acciones')
ui.selected_files=nil
button:setIcon('plus')
assert(button.text=='Todo', 'Al salir de la selección vuelve el acceso a Todo')
ui:setupLayout()
ui.title_bar.right_button.callback()
assert(opened==2 and old_freed==2, 'El acceso sigue funcionando tras reconstruir la cabecera')
local old={width=64,height=64,padding=8,free=function() end}
local bar={right_button=old,old}
Navigation.todoButton(bar,function() opened=opened+1 end)
bar.right_button.callback()
assert(opened==3, 'La biblioteca usa el mismo acceso visible a Todo')
local toggles=0
local left={width=64,height=64,padding=8,free=function() end,callback=function() extras=extras+1 end}
local titlebar={left_button=left,left}
Navigation.libraryViewButton(titlebar,'covers',function() toggles=toggles+1 end)
assert(titlebar.left_button.text=='Lista')
titlebar.left_button.callback()
titlebar.left_button.hold_callback()
assert(toggles==1 and extras==3, 'El botón cambia la vista y la pulsación larga conserva el menú de colección')
local closed=0
local reading={document={},menu={menu_items={filemanager={icon='appbar.filebrowser'}},
    onTapCloseMenu=function() closed=closed+1 end}}
Navigation.install({ui=reading,openLibrary=function() library=library+1 end})
assert(not reading.setupLayout, 'La instalación en lectura no sustituye la cabecera del explorador')
local before=library
reading.menu.menu_items.filemanager.callback()
assert(closed==1 and library==before, 'Cerrar el menú antes de mostrar la biblioteca')
table.remove(ticks,1)()
assert(library==before+1 and reading.menu.menu_items.filemanager.icon=='home',
    'El antiguo explorador es una casa que abre Mis libros desde la lectura')
assert(reading:onHome())
table.remove(ticks,1)()
assert(library==before+2, 'La acción Inicio desde lectura también lleva a Mis libros')
local factory=InfoMessage.new
Reader:showReaderCoroutine('/carpeta/libro.epub','proveedor',false)
assert(shown[1].text=='Abriendo libro…' and shown[1].invisible==false,
    'El aviso de apertura no muestra el nombre ni la carpeta del archivo')
assert(shown[2].text=='Un aviso independiente.' and InfoMessage.new==factory,
    'Los demás avisos conservan su contenido y su constructor')
Reader:showReaderCoroutine('/carpeta/libro.epub','proveedor',true)
assert(shown[3].invisible==true and calls[2][2]=='/carpeta/libro.epub'
    and calls[2][3]=='proveedor' and calls[2][4]==true,
    'El cambio conserva los argumentos y la apertura sin aviso visible')
assert(not pcall(Reader.showReaderCoroutine,Reader,'fallo.epub'))
assert(InfoMessage.new==factory, 'Un fallo al abrir no altera los avisos posteriores')
for _,context in ipairs({'reader','filemanager'}) do
    local order={['KOMenu:menu_buttons']={'setting','main'}}
    package.loaded['ui/elements/' .. context .. '_menu_order']=order
    local items={}
    Navigation.menuItem({document=context=='reader' and {} or nil},items,function() opened=opened+1 end)
    Navigation.menuItem({document=context=='reader' and {} or nil},items,function() opened=opened+1 end)
    assert(#order['KOMenu:menu_buttons']==3 and order['KOMenu:menu_buttons'][2]=='todo_shortcut'
        and order.todo_shortcut and not items.todo_shortcut.sorting_hint,
        'El acceso se añade una sola vez al orden superior, sin tratarlo como un submenú existente')
    items.todo_shortcut.callback()
end
assert(opened==5, 'Los accesos de lectura y explorador abren Todo')
print('Navegación: casa, acceso a Todo, cabeceras y selección de archivos verificados')
