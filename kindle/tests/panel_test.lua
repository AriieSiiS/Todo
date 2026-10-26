local function copy(value)
    if type(value)~='table' then return value end
    local result={}; for key,item in pairs(value) do result[key]=copy(item) end; return result
end
local Class={}
function Class:extend(value) return setmetatable(value or {},{__index=self}) end
function Class:new(value)
    value=setmetatable(value or {},{__index=self})
    if value.init then value:init() end
    return value
end
function Class:getSize()
    if self.dimen then return self.dimen end
    if self._kind=='horizontalspan' then return {w=self.width,h=0} end
    if self.height then return {w=self.width or 0,h=self.height} end
    if self.face then
        local line=math.ceil((self.face.size or 18)*1.5*1.3)
        local columns=math.max(1,math.floor((self.width or 100)/(self.face.size or 18)))
        return {w=self.width,h=line*math.max(1,math.ceil(#(self.text or '')/columns))}
    end
    if self.buttons then
        local height=0
        for _,row in ipairs(self.buttons) do
            local tallest=0
            for _,button in ipairs(row) do tallest=math.max(tallest,button.height or 60) end
            height=height+tallest
        end
        return {w=self.width,h=height}
    end
    local width,height=0,0
    for _,child in ipairs(self) do
        local size=child:getSize()
        if self._kind=='horizontalgroup' then width=width+size.w; height=math.max(height,size.h)
        else width=math.max(width,size.w); height=height+size.h end
    end
    return {w=width,h=height}
end
function Class:free() end
local UI={jobs={}, ticks={}, shown=0, stack={}}
local preferences={}
G_reader_settings={nilOrTrue=function(_,key) return preferences[key]~=false end,
    saveSetting=function(_,key,value) preferences[key]=value end}
function UI:scheduleIn(_,job) self.jobs[job]=true end
function UI:nextTick(job) self.ticks[#self.ticks+1]=job; self:scheduleIn(0,job) end
function UI:tickAfterNext(job) self:nextTick(function() self:nextTick(job) end) end
function UI:runNextTicks()
    local ticks=self.ticks; self.ticks={}
    for _,job in ipairs(ticks) do
        if self.jobs[job] then self.jobs[job]=nil; job() end
    end
end
function UI:unschedule(job) self.jobs[job]=nil end
function UI:show(widget,mode)
    self.stack[#self.stack+1]=widget
    if widget._kind~='trapwidget' then self.shown=self.shown+1 end
    if mode then self:setDirty(widget,mode) end
end
function UI:close(widget,mode)
    if widget.onCloseWidget then widget:onCloseWidget() end
    for index=#self.stack,1,-1 do
        if self.stack[index]==widget then table.remove(self.stack,index) end
    end
    if mode then self:setDirty(nil,mode) end
end
function UI:buffer()
    for index=#self.stack,1,-1 do
        if self.stack[index]._kind~='trapwidget' then return self.stack[index] end
    end
end
function UI:setDirty(_,mode)
    if mode then self.displayed=self:buffer() end
end
package.loaded['ui/uimanager']=UI
local trapper={deferred=false}
function trapper:wrap(callback)
    local ok,message=coroutine.resume(coroutine.create(callback))
    assert(ok,message)
end
function trapper:dismissableRunInSubprocess(task,widget)
    if not self.deferred then return true,task() end
    local co=coroutine.running()
    assert(co, 'La red debe ceder el control a la interfaz')
    self.pending={task=task,co=co}
    widget.dismiss_callback=function() self:finish(false) end
    return coroutine.yield()
end
function trapper:finish(completed)
    local pending=assert(self.pending)
    self.pending=nil
    local ok,message
    if completed then ok,message=coroutine.resume(pending.co,true,pending.task())
    else ok,message=coroutine.resume(pending.co,false) end
    assert(ok,message)
end
package.loaded['ui/trapper']=trapper
for _,name in ipairs({'container/widgetcontainer','container/inputcontainer','container/framecontainer','container/centercontainer',
    'verticalgroup','horizontalgroup','horizontalspan','verticalspan','linewidget',
    'textboxwidget','buttontable','button','buttondialog','textviewer','infomessage','trapwidget'}) do
    package.loaded['ui/widget/' .. name]=Class:extend{_kind=name}
end
package.loaded.datastorage={getSettingsDir=function() return 'settings' end}
package.loaded.device={screen={getWidth=function() return 1072 end,getHeight=function() return 1448 end,
    scaleBySize=function(_,n) return n*1.5 end},powerd={getCapacity=function() return 80 end}}
package.loaded['ui/font']={getFace=function(_,name,size) return {size=size or 18} end}
package.loaded['ui/geometry']=Class
package.loaded['ui/elements/reader_menu_order']={['KOMenu:menu_buttons']={'setting','main'}}
package.loaded['ui/elements/filemanager_menu_order']={['KOMenu:menu_buttons']={'setting','main'}}
package.loaded['ffi/blitbuffer']={COLOR_WHITE=0}
package.loaded['libs/libkoreader-lfs']={mkdir=function() end,attributes=function() end}
local network={connected=false}
function network:isConnected() return self.connected end
function network:runWhenConnected(callback) self.connected=true; callback() end
package.loaded['ui/network/manager']=network
package.loaded.json={encode=copy,decode=copy}
package.loaded.util={}
package.loaded['apps/reader/readerui']={showReaderCoroutine=function() end}
local day=os.date('%Y-%m-%d')
local task={id='r',root_task_id='r',task_version='version-1',title='Cuidados',description='',priority='medium',
    scheduled_at='',subtasks={{id='a',title='Agua',description='',subtasks={
        {id='aa',title='Revisar maceta',completed=true,subtasks={}}}}}}
local agenda={protocol_version=1,logical_date=day,server_epoch=os.time(),day_valid_until=os.time()+3600,
    utc_offset_minutes=0,days={}}
for index=1,7 do agenda.days[index]={date=day,tasks={copy(task)}} end
local database={}
local storage={load=function(path,default)
    if path:match('config.json$') then return {protocol_version=1,device_id='prueba'} end
    return copy(database[path] or default)
end,save=function(path,value) database[path]=copy(value) end}
local calls=0
local paths={}
local posts={}
local transport={request=function(_,method,path,body)
    calls=calls+1
    paths[#paths+1]=path
    if method=='POST' then
        posts[#posts+1]=copy(body)
        return 200,{status='saved',savedLocally=true,request_id=body.request_id}
    end
    assert(method=='GET')
    local result=copy(agenda)
    if path:find('start_date=') then result.days[1].tasks[1].title='Tarea de otra semana' end
    return 200,result
end}
local original=dofile
local arranque={instalado=false,activo=true,fallo=false}
package.loaded['ui/event']={new=function(_,name) return {name=name} end}
dofile=function(path)
    if path:match('/storage.lua$') then return storage end
    if path:match('/transport.lua$') then return transport end
    if path:match('/library.lua$') then return {prepare=function() return 'Mis libros' end,
        view=function() return preferences.todo_library_view or 'covers' end,
        toggleView=function() preferences.todo_library_view=preferences.todo_library_view=='list' and 'covers' or 'list' end} end
    if path:match('/arranque.lua$') then return {
        disponible=function() return arranque.instalado end,
        habilitado=function() return arranque.activo end,
        habilitar=function(value)
            if arranque.fallo then return nil,'Fallo de prueba' end
            arranque.activo=value; return true
        end,
    } end
    return original(path)
end
local Todo=original('kindle/todo.koplugin/main.lua')
local inherited_identity={partial_md5_checksum=string.rep('a',32)}
local identity_settings={saveSetting=function(_,key,value) inherited_identity[key]=value end}
package.loaded.util.partialMD5=function(file)
    assert(file=='/documentos/Segundo.epub')
    return string.rep('b',32)
end
assert(type(Todo.onDocSettingsLoad)=='function', 'Preparar la identidad antes de leer los ajustes del libro')
Todo.onDocSettingsLoad({},identity_settings,{file='/documentos/Segundo.epub'})
assert(inherited_identity.partial_md5_checksum==string.rep('b',32),
    'Al cambiar de libro se usa su archivo, aunque KOReader conserve la huella anterior')
inherited_identity.partial_md5_checksum=string.rep('a',32)
local identity_task=function() end
Todo.onReaderReady({ui={doc_settings=identity_settings,document={file='/documentos/Segundo.epub'}},
    onDocSettingsLoad=Todo.onDocSettingsLoad,reading_task=identity_task,captureReading=function()
        assert(inherited_identity.partial_md5_checksum==string.rep('b',32),
            'Validar también la identidad justo antes de la primera captura de lectura')
    end})
UI:unschedule(identity_task)
package.loaded.util.partialMD5=nil
local function visibleText(widget,seen)
    seen=seen or {}
    if seen[widget] then return '' end
    seen[widget]=true
    local text=type(widget.text)=='string' and widget.text or ''
    for _,child in pairs(widget) do
        if type(child)=='table' then text=text .. '\n' .. visibleText(child,seen) end
    end
    return text
end
local function subtaskMark(widget)
    for index,child in ipairs(widget) do
        if type(child.text)=='string' and child.text:find('Agua') and index>1 then
            return widget[index-1].callback
        end
    end
    for _,child in pairs(widget) do
        if type(child)=='table' then local found=subtaskMark(child); if found then return found end end
    end
end
local function nextPage(widget)
    if type(widget.text)=='string' and widget.text:find('Siguiente') and widget.enabled~=false then return widget.callback end
    for _,child in pairs(widget) do
        if type(child)=='table' then local found=nextPage(child); if found then return found end end
    end
end
local function buttonCallback(widget,text)
    if widget.text==text and widget.callback then return widget.callback end
    for _,child in pairs(widget) do
        if type(child)=='table' then
            local found=buttonCallback(child,text)
            if found then return found end
        end
    end
end
local panel=Todo:new{ui={menu={registerToMainMenu=function() end}}}
assert(not panel.panel and #UI.ticks==1, 'El inicio espera a que KOReader haya preparado su pantalla')
UI:runNextTicks()
assert(panel.panel and panel.today_view and calls==0, 'KOReader abre Hoy con la agenda local antes de consultar la red')
assert(panel.panel and not panel:canMark(), 'Sin agenda no se crean marcas')
panel:sync(true)
assert(panel:canMark() and calls==1, 'Actualizar obtiene Hoy')
local active_text=visibleText(panel.panel)
assert(active_text:find('Agua') and active_text:find('Revisar maceta'),
    'Las subtareas y sus descendientes se ven directamente en la lista')
assert(not active_text:find('Media') and not active_text:find('Prioridad'), 'La lista no muestra prioridades')
assert(subtaskMark(panel.panel), 'Una subtarea tiene su propio control de completar')
subtaskMark(panel.panel)()
assert(#panel.queue.items==1 and #database[panel.state_path].queue==1, 'La marca se guarda antes de enviar')
assert(panel.queue.items[1].body.task_ids[1]=='a', 'El control de una subtarea marca esa subtarea, no la tarea principal')
panel.today_view=false
assert(not panel:canMark(), 'La semana es de consulta')
panel.today_view=true
panel:showTask(task,task)
local before=UI.shown
panel:render()
assert(UI.shown==before and panel.modal, 'El reloj no tapa un detalle abierto')
panel:onSuspend()
assert(not next(UI.jobs), 'La suspensión cancela los temporizadores')
assert(panel.sleep_panel, 'El salvapantallas muestra Todo incluso sobre un detalle abierto')
local sleeping_text=visibleText(panel.sleep_panel)
assert(sleeping_text:find('Cuidados') and sleeping_text:find('Agua') and sleeping_text:find('Revisar maceta'),
    'El salvapantallas muestra las tareas y sus subtareas')
assert(not sleeping_text:find('En reposo') and not sleeping_text:find('al despertar') and not sleeping_text:find('Media'),
    'El salvapantallas omite prioridades y explicaciones de reposo')
assert(calls==1, 'Suspender no consulta la red')
panel:onResume()
assert(not panel.sleep_panel and panel.modal, 'Despertar retira el salvapantallas y conserva el detalle anterior')
assert(next(UI.jobs), 'Al despertar se reanuda la actualización')
panel.state.clock.day_valid_until=os.time()-1
assert(not panel:canMark(), 'El cambio de día exige actualizar antes de nuevas marcas')
panel:close()
assert(not panel.panel and not panel.modal and not next(UI.jobs), 'Salir limpia la pantalla y los temporizadores')
local reading=Todo:new{ui={menu={registerToMainMenu=function() end}}}
assert(not reading.panel and #UI.ticks==0, 'Cambiar entre libros y explorador no vuelve a abrir Todo')
reading:onSuspend()
assert(reading.sleep_panel and not reading.panel, 'El salvapantallas funciona también mientras se está leyendo')
assert(not next(UI.jobs), 'La vista de reposo no mantiene temporizadores')
reading:onResume()
assert(not reading.sleep_panel and not reading.panel, 'Despertar conserva la lectura')
local shown=UI.shown
reading.refresh_task()
assert(calls==3 and not reading.panel and UI.shown==shown and #reading.queue.items==0,
    'Al despertar se actualiza la caché sin abrir el panel sobre la lectura')
assert(paths[#paths]=='/v1/kindle/agenda', 'La actualización en segundo plano descarga Hoy')
reading:open()
reading.today_view=false
reading.week='1999-01-01'
reading:sync(false)
assert(paths[#paths]=='/v1/kindle/agenda?start_date=1999-01-01', 'Se mantiene la consulta de otra semana')
reading:onSuspend()
local other_week_sleep=visibleText(reading.sleep_panel)
assert(other_week_sleep:find('Cuidados') and not other_week_sleep:find('Tarea de otra semana'),
    'El salvapantallas muestra Hoy aunque se estuviera consultando otra semana')
reading:onResume()
assert(reading.week=='1999-01-01' and not reading.today_view, 'Se recupera la semana que se estaba consultando')
local many={}
for index=1,20 do local item=copy(task); item.title='Tarea ' .. index; many[index]=item end
reading.state.weeks[day].days[1].tasks=many
local long_list=visibleText(reading:buildSleepPanel())
assert(long_list:find('%+%d+ más') and not long_list:find('Tarea 20'),
    'La lista cabe en la pantalla e indica las tareas restantes')
local long_family=copy(task)
long_family.title='Rutina extensa'
long_family.subtasks={}
for index=1,30 do long_family.subtasks[index]={id='paso-' .. index,title='Paso ' .. index,subtasks={}} end
reading.state.weeks[day].days[1].tasks={long_family}
reading.week,reading.day_index,reading.today_view,reading.page=day,1,true,1
reading:render()
assert(nextPage(reading.panel), 'Una familia larga permite consultar todas sus subtareas por páginas')
nextPage(reading.panel)()
assert(visibleText(reading.panel):find('Rutina extensa'), 'Una página que continúa subtareas conserva el nombre de su tarea principal')
local turns=0
while nextPage(reading.panel) and turns<20 do nextPage(reading.panel)(); turns=turns+1 end
assert(visibleText(reading.panel):find('Paso 30') and turns<20, 'Se puede alcanzar la última subtarea sin perder filas')
reading:close()
local items={}
reading:addToMainMenu(items)
assert(not items.todo_kindle_system, 'Sin instalación de arranque no se ofrecen acciones de recuperación')
assert(items.todo_screensaver.checked_func(), 'Todo como salvapantallas está activado inicialmente')
items.todo_screensaver.callback()
assert(not items.todo_screensaver.checked_func(), 'Se puede recuperar el salvapantallas habitual')
reading:onSuspend()
assert(not reading.sleep_panel and not next(UI.jobs), 'Desactivar respeta el salvapantallas de KOReader')
reading:onResume()
assert(not next(UI.jobs), 'Desactivar no deja consultas en segundo plano')
local startup_calls=calls
local RestartedTodo=original('kindle/todo.koplugin/main.lua')
local restarted=RestartedTodo:new{ui={menu={registerToMainMenu=function() end}}}
UI:runNextTicks()
assert(restarted.panel and visibleText(restarted.panel):find('Cuidados') and calls==startup_calls,
    'Un nuevo arranque vuelve a mostrar la agenda guardada aunque no haya conexión')
restarted:close()
local startup_items={}
restarted:addToMainMenu(startup_items)
assert(startup_items.todo_startup.checked_func(), 'Todo es la pantalla inicial predeterminada')
startup_items.todo_startup.callback()
assert(not startup_items.todo_startup.checked_func(), 'El inicio automático se puede desactivar')
local DisabledTodo=original('kindle/todo.koplugin/main.lua')
local disabled=DisabledTodo:new{ui={menu={registerToMainMenu=function() end}}}
UI:runNextTicks()
assert(not disabled.panel and not next(UI.jobs), 'Desactivar conserva el inicio habitual y no deja temporizadores')
disabled:open()
assert(disabled.panel, 'Todo sigue disponible desde el menú con el inicio automático desactivado')
disabled:close()
local opened_collection,selected_file
local library_ui={menu={registerToMainMenu=function() end},collections={}}
function library_ui.collections:onShowColl(name)
    opened_collection=name
    local left={width=64,height=64,free=function() end}
    self.booklist_menu={close_callback=function() self.booklist_menu=nil end,
        title_bar={left_button=left,left},
        onMenuSelect=function(widget,item) widget.close_callback(); selected_file=item.file end}
end
local library_panel=Todo:new{ui=library_ui}
library_panel:open()
assert(visibleText(library_panel.panel):find('Mis libros') and not visibleText(library_panel.panel):find('Volver a leer'),
    'Desde Todo se distingue el acceso a los libros')
library_panel:openLibrary()
assert(opened_collection=='Mis libros' and not library_panel.panel and not next(UI.jobs),
    'Mis libros abre la biblioteca y detiene las actualizaciones del panel')
assert(library_ui.collections.booklist_menu.title_bar.left_button.text=='Lista')
library_ui.collections.booklist_menu.title_bar.left_button.callback()
assert(not library_panel.panel and library_ui.collections.booklist_menu.title_bar.left_button.text=='Portadas',
    'Cambiar de vista reconstruye Mis libros sin abrir Todo ni perder sus accesos')
library_ui.collections.booklist_menu.close_callback()
assert(library_panel.panel, 'Cerrar la biblioteca recupera Todo')
library_panel:openLibrary()
local books=library_ui.collections.booklist_menu
books:onMenuSelect({file='/libros/Novela.epub'})
assert(selected_file=='/libros/Novela.epub' and not library_panel.panel,
    'Elegir un libro abre la lectura sin superponer Todo')
library_ui.document={}
library_panel:open()
assert(visibleText(library_panel.panel):find('Seguir leyendo'), 'Todo permite recuperar el libro en curso')
library_panel:close()
local menu_closed=false
library_ui.menu.onTapCloseMenu=function() menu_closed=true end
local direct_items={}
library_panel:addToMainMenu(direct_items)
direct_items.todo_shortcut.callback()
assert(menu_closed and not library_panel.panel, 'El acceso espera a que termine de repintarse la lectura')
UI:runNextTicks()
UI:runNextTicks()
assert(library_panel.panel and not direct_items.todo_shortcut.sorting_hint,
    'El acceso superior abre Todo después de cerrar y repintar el menú de lectura')
library_panel:close()
library_ui.document=nil
library_ui.menu.onTapCloseMenu=nil
library_ui.menu.onCloseFileManagerMenu=function() menu_closed=true end
menu_closed=false
local explorer_items={}
library_panel:addToMainMenu(explorer_items)
explorer_items.todo_shortcut.callback()
assert(menu_closed and not library_panel.panel,
    'El explorador cierra su propio menú antes de abrir las tareas')
UI:runNextTicks()
UI:runNextTicks()
assert(library_panel.panel, 'El icono Todo funciona en el explorador sin métodos exclusivos de lectura')
library_panel:close()
arranque.instalado=true
local recovery_items={}
library_panel:addToMainMenu(recovery_items)
assert(recovery_items.todo_device_startup.checked_func())
recovery_items.todo_device_startup.callback()
assert(not recovery_items.todo_device_startup.checked_func())
recovery_items.todo_device_startup.callback()
local exit_event
function UI:broadcastEvent(event) exit_event=event.name end
arranque.fallo=true
recovery_items.todo_kindle_system.callback()
assert(not exit_event and arranque.activo, 'Un fallo de guardado no cierra KOReader')
arranque.fallo=false
recovery_items.todo_kindle_system.callback()
assert(exit_event=='Exit' and not arranque.activo, 'Recuperar desactiva el arranque y usa la salida normal que guarda la lectura')

local responsive=Todo:new{ui={menu={registerToMainMenu=function() end}}}
responsive:open()
local previous_calls=calls
trapper.deferred=true
responsive:sync(false)
assert(responsive.syncing and trapper.pending and calls==previous_calls,
    'Una consulta pendiente cede el control sin ejecutar la red en el hilo de la interfaz')
local unchanged_panel,unchanged_shown=responsive.panel,UI.shown
responsive.sync_wait.dismiss_callback()
assert(not responsive.syncing and responsive.panel==unchanged_panel and UI.shown==unchanged_shown,
    'Cancelar con un toque conserva los controles que recibirán ese mismo toque')
responsive:sync(false)
responsive:close()
assert(not responsive.panel and not responsive.syncing and not trapper.pending and calls==previous_calls,
    'Salir cancela la consulta sin esperar al PC ni reabrir el panel')

responsive:open()
responsive:mark(task,task.subtasks[1])
responsive:sync(false)
local sealed=copy(database[responsive.state_path].queue[1].body)
assert(responsive.queue.items[1].state=='sending' and trapper.pending,
    'La marca se sella y persiste antes de esperar al proceso de red')
responsive:onSuspend()
assert(not responsive.syncing and not trapper.pending and not next(UI.jobs),
    'Suspender cancela la consulta y sus temporizadores')
local preserved=database[responsive.state_path].queue[1]
assert(preserved.state=='sending' and preserved.body.request_id==sealed.request_id
    and preserved.body.occurrence_date==sealed.occurrence_date
    and preserved.body.expected_version==sealed.expected_version,
    'Interrumpir conserva el identificador, la fecha y la versión de la marca')
trapper.deferred=false
responsive:onResume()
responsive:sync(false)
assert(#responsive.queue.items==0 and posts[#posts].request_id==sealed.request_id
    and posts[#posts].task_ids[1]==sealed.task_ids[1],
    'Al reintentar se envía la marca original y solo se retira tras la confirmación')
responsive:close()

for _,reading_book in ipairs({false,true}) do
    local destination=Class:new{text=reading_book and 'Lectura' or 'Explorador'}
    UI:show(destination,'full')
    local closing=Todo:new{ui={document=reading_book and {} or nil,menu={registerToMainMenu=function() end}}}
    closing:open()
    assert(UI.displayed==closing.panel, 'Todo es visible antes de pulsar el botón inferior')
    buttonCallback(closing.panel,reading_book and 'Seguir leyendo' or 'KOReader')()
    assert(UI:buffer()==destination, 'Cerrar cambia el dibujo interno al destino')
    assert(UI.displayed==destination,
        'El botón inferior también refresca la pantalla física; no basta con cambiar el framebuffer')
    UI:close(destination)
end
print('Panel: inicio, navegación, persistencia, detalles y suspensión verificados')
local book_ui={document={info={has_pages=false}},doc_props={title='Libro de prueba',authors='Autora'},
    menu={registerToMainMenu=function() end},
    doc_settings={readSetting=function() return string.rep('a',32) end},
    rolling={getLastPercent=function() return .14 end,getLastProgress=function() return '/p[42]' end},
    view={state={page=42}},annotation={annotations={}}}
book_ui.view.footer={settings={all_at_once=false},mode_index={[1]='page_progress'},mode=1,
    genFooterText=function() return '42 / 200' end,
    applyFooterMode=function(value) value.genFooterText=function() return '42 / 200' end end,
    onUpdateFooter=function() end}
local book_panel=Todo:new{ui=book_ui}
assert(book_ui.view.footer:genFooterText()=='Libro · 42 / 200',
    'El complemento conecta la barra real de lectura, que pertenece a ReaderView')
function transport.deadline(seconds) assert(seconds==1); return 100 end
book_panel:onReaderReady()
local pauses,resumes=0,0
book_ui.statistics={onReadingPaused=function() pauses=pauses+1 end,
    onReadingResumed=function() resumes=resumes+1 end}
book_panel:open()
assert(pauses==1,'Consultar Todo pausa el cómputo del tiempo del libro')
book_panel:close()
assert(resumes==1,'Volver al libro reanuda el cómputo')
assert(database[book_panel.reading_path].books[string.rep('a',32)].latest.progress==.14,
    'Abrir un libro guarda el progreso en la cola privada antes de transmitirlo')
book_panel:onSuspend()
assert(not book_panel.reading:next() and paths[#paths]=='/v1/kindle/reading',
    'Dormir intenta enviar la última lectura y retira solo un envío confirmado')
assert(book_panel.suspended and not next(UI.jobs),'La lectura respeta la suspensión y cancela sus temporizadores')
print('Panel: captura de lectura y confirmación limitada al dormir verificadas')
