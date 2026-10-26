local DataStorage = require('datastorage')
local Device = require('device')
local UIManager = require('ui/uimanager')
local Trapper = require('ui/trapper')
local NetworkMgr = require('ui/network/manager')
local WidgetContainer = require('ui/widget/container/widgetcontainer')
local InputContainer = require('ui/widget/container/inputcontainer')
local FrameContainer = require('ui/widget/container/framecontainer')
local VerticalGroup = require('ui/widget/verticalgroup')
local HorizontalGroup = require('ui/widget/horizontalgroup')
local HorizontalSpan = require('ui/widget/horizontalspan')
local VerticalSpan = require('ui/widget/verticalspan')
local CenterContainer = require('ui/widget/container/centercontainer')
local LineWidget = require('ui/widget/linewidget')
local TextBoxWidget = require('ui/widget/textboxwidget')
local ButtonTable = require('ui/widget/buttontable')
local Button = require('ui/widget/button')
local ButtonDialog = require('ui/widget/buttondialog')
local TextViewer = require('ui/widget/textviewer')
local InfoMessage = require('ui/widget/infomessage')
local TrapWidget = require('ui/widget/trapwidget')
local Font = require('ui/font')
local Geom = require('ui/geometry')
local Blitbuffer = require('ffi/blitbuffer')
local lfs = require('libs/libkoreader-lfs')
local json = require('json')
local util = require('util')
local plugin_dir = debug.getinfo(1, 'S').source:match('^@(.*/)')
local Queue = dofile(plugin_dir .. 'queue.lua')
local Storage = dofile(plugin_dir .. 'storage.lua')
local Transport = dofile(plugin_dir .. 'transport.lua')
local Library = dofile(plugin_dir .. 'library.lua')
local Navigation = dofile(plugin_dir .. 'navigation.lua')
local Footer = dofile(plugin_dir .. 'footer.lua')
local Arranque = dofile(plugin_dir .. 'arranque.lua')
local Reading = dofile(plugin_dir .. 'reading.lua')
local Statistics = dofile(plugin_dir .. 'statistics.lua')
local reading_shared
local Todo = WidgetContainer:extend{name='todo', is_doc_only=false}
local startup_handled = false
local sync_cancelled = {}
local full_weekdays = {'domingo','lunes','martes','miércoles','jueves','viernes','sábado'}
local months = {'enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre'}

local function shift(day, offset)
    local y, m, d = day:match('^(%d+)%-(%d+)%-(%d+)$')
    return os.date('%Y-%m-%d', os.time{year=tonumber(y), month=tonumber(m), day=tonumber(d)+offset, hour=12})
end
local function fullDate(day)
    local y,m,d=day:match('^(%d+)%-(%d+)%-(%d+)$')
    local time=os.time{year=tonumber(y),month=tonumber(m),day=tonumber(d),hour=12}
    local name=full_weekdays[tonumber(os.date('%w',time))+1]
    return name:sub(1,1):upper() .. name:sub(2) .. ', ' .. tonumber(d) .. ' de ' .. months[tonumber(m)]
end

local function center(widget,width,height)
    return CenterContainer:new{dimen=Geom:new{w=width,h=height},widget}
end

local function taskRows(tasks)
    local rows={}
    local function visit(root,task,depth)
        rows[#rows+1]={root=root,task=task,depth=depth}
        for _,child in ipairs(task.subtasks or {}) do visit(root,child,depth+1) end
    end
    for _,root in ipairs(tasks) do visit(root,root,0) end
    return rows
end

local function taskTitle(row)
    local time=(row.task.scheduled_at or ''):match('T(%d%d:%d%d)')
    if time=='00:00' then time=nil end
    return (time and time .. '  ' or '') .. row.task.title
end

local function paginate(rows,budget,context_height)
    local pages={}
    for _,row in ipairs(rows) do
        local page=pages[#pages]
        if not page or (#page>0 and page.used+row.height>page.budget) then
            local context=row.entry.depth>0 and row.entry.root.title or nil
            page={used=0,budget=budget-(context and context_height or 0),context=context}
            pages[#pages+1]=page
        end
        page[#page+1]=row
        page.used=page.used+row.height
    end
    if #pages==0 then pages[1]={used=0,budget=budget} end
    return pages
end

local function expandRows(rows,budget)
    local used=0
    for _,row in ipairs(rows) do used=used+row.height end
    local extra=#rows>0 and math.max(0,math.floor((budget-used)/#rows)) or 0
    for _,row in ipairs(rows) do row.height=row.height+extra end
end

function Todo:init()
    self.ui.menu:registerToMainMenu(self)
    self.directory = DataStorage:getSettingsDir() .. '/todo'
    lfs.mkdir(self.directory)
    self.state_path = self.directory .. '/state.json'
    self.reading_path = self.directory .. '/reading.json'
    self.reading_task = function()
        if not self.suspended then
            local ok=pcall(function() if not self.state then self:load() end end)
            if ok then self:captureReading(); self:sync(false) end
            if self.reader_ready then UIManager:scheduleIn(60,self.reading_task) end
        end
    end
    self.refresh_task = function()
        if self.state and not self.suspended and (self.panel or self:screensaverEnabled()) then
            self:sync(false); self:schedule()
        end
    end
    self.clock_task = function() if self.panel and not self.suspended then self:render(); UIManager:scheduleIn(60,self.clock_task) end end
    self.send_task = function() if self.panel and not self.suspended then self:sync(false) end end
    self.render_task = function() if self.panel and not self.modal then self:render() end end
    self.status = 'Agenda guardada'
    Navigation.install(self)
    Footer.install(self.ui.view and self.ui.view.footer)
    if not startup_handled then
        startup_handled=true
        if self:startupEnabled() then
            self.start_task=function()
                self.start_task=nil
                if self:startupEnabled() then self:open() end
            end
            UIManager:nextTick(self.start_task)
        end
    end
end

function Todo:addToMainMenu(items)
    items.todo = {text='Todo', sorting_hint='more_tools', callback=function() self:open() end}
    items.todo_reading = {text='Sincronizar lectura con Todo', sorting_hint='more_tools',
        callback=function() self:captureReading(); self:sync(true) end}
    items.todo_link_book = {text='Vincular libro con Todo', sorting_hint='more_tools',
        callback=function() self:linkReading() end}
    Navigation.menuItem(self.ui,items,function()
        Navigation.closeMenu(self.ui)
        UIManager:tickAfterNext(function() self:open() end)
    end)
    items.todo_startup = {text='Todo al iniciar', sorting_hint='more_tools',
        checked_func=function() return self:startupEnabled() end,
        callback=function()
            G_reader_settings:saveSetting('todo_startup', not self:startupEnabled())
        end}
    items.todo_screensaver = {text='Todo como salvapantallas', sorting_hint='more_tools',
        checked_func=function() return self:screensaverEnabled() end,
        callback=function()
            G_reader_settings:saveSetting('todo_screensaver', not self:screensaverEnabled())
            if not self.panel then self:stopTimers() end
        end}
    if Arranque.disponible() then
        items.todo_device_startup = {text='Inicio automático de KOReader', sorting_hint='more_tools',
            checked_func=Arranque.habilitado,
            callback=function()
                local ok, message=Arranque.habilitar(not Arranque.habilitado())
                if not ok then UIManager:show(InfoMessage:new{text=message or 'No se ha podido cambiar el inicio automático.'}) end
            end}
        items.todo_kindle_system = {text='Volver al sistema Kindle', sorting_hint='more_tools',
            callback=function()
                local ok, message=Arranque.habilitar(false)
                if not ok then
                    UIManager:show(InfoMessage:new{text=message or 'No se ha podido preparar la recuperación.'})
                    return
                end
                Navigation.closeMenu(self.ui)
                UIManager:broadcastEvent(require('ui/event'):new('Exit'))
            end}
    end
end

function Todo:screensaverEnabled() return G_reader_settings:nilOrTrue('todo_screensaver') end
function Todo:startupEnabled() return G_reader_settings:nilOrTrue('todo_startup') end

function Todo:header(width,day,passive)
    local now,offset=self:serverTime()
    local height=Device.screen:scaleBySize(44)
    local side=math.floor(width*0.25)
    local middle=width-2*side
    local function cell(text,w,size,alignment,bold)
        return center(TextBoxWidget:new{width=w,text=text,face=Font:getFace('cfont',size),
            alignment=alignment,bold=bold},w,height)
    end
    return VerticalGroup:new{align='left',
        HorizontalGroup:new{align='center',
            cell(passive and '' or 'TODO',side,18,'left',true),
            cell(passive and 'TODO' or os.date('!%H:%M',now+offset),middle,36,'center',passive),
            cell(Device.powerd:getCapacity() .. ' %',side,16,'right')},
        TextBoxWidget:new{width=width,text=fullDate(day),face=Font:getFace('cfont',18),alignment='center'},
        VerticalSpan:new{height=Device.screen:scaleBySize(8)},
        LineWidget:new{dimen=Geom:new{w=width,h=1}},
        VerticalSpan:new{height=Device.screen:scaleBySize(8)}}
end

function Todo:layoutRows(tasks,width,day,passive,budget)
    local entries=taskRows(tasks)
    local root_size=passive and (#entries<=4 and 36 or 28) or (#entries<=4 and 30 or 22)
    local child_size=passive and (#entries<=4 and 28 or 23) or (#entries<=4 and 24 or 18)
    local rows={}
    repeat
        rows={}
        local total=0
        for _,entry in ipairs(entries) do
            local size=entry.depth==0 and root_size or child_size
            local text=taskTitle(entry)
            local pending=self:pendingFor(entry.root,entry.task,day)
            local icon=entry.task.completed and '✓' or pending and '…' or '□'
            local indent=Device.screen:scaleBySize(36*math.min(entry.depth,3))
            local icon_width=passive and Device.screen:scaleBySize(entry.depth==0 and 36 or 28) or 0
            local text_width=width-indent-icon_width
            local box=TextBoxWidget:new{width=text_width,text=text,face=Font:getFace('cfont',size),bold=entry.depth==0}
            local height=math.max(Device.screen:scaleBySize(entry.depth==0 and 42 or 34),
                box:getSize().h+Device.screen:scaleBySize(10))
            box:free()
            rows[#rows+1]={entry=entry,font=size,text=text,icon=icon,height=height,
                indent=indent,icon_width=icon_width,text_width=text_width}
            total=total+height
        end
        if not passive or total<=budget or child_size<=17 then break end
        root_size,child_size=root_size-1,child_size-1
    until false
    return rows
end

function Todo:updatedText()
    local clock=self.state.clock
    local _,offset=self:serverTime()
    return clock and 'Actualizado ' .. os.date('!%H:%M',clock.server_epoch+offset) or 'Sin descargar'
end

function Todo:message(text) UIManager:show(InfoMessage:new{text=tostring(text)}) end

function Todo:load()
    self.config = Storage.load(self.directory .. '/config.json', {})
    assert(self.config.protocol_version == 1 and self.config.device_id,
        'Prepara la conexión Kindle por USB desde el PC.')
    self.state = Storage.load(self.state_path, {weeks={}, queue={}, counter=0})
    self.state.weeks = self.state.weeks or {}
    self.queue = Queue.new(self.state.queue or {}, function()
        self.state.counter = (self.state.counter or 0)+1
        return self.config.device_id .. '-' .. tostring(os.time()) .. '-' .. self.state.counter
    end)
    if not reading_shared then
        reading_shared=Reading.new(Storage.load(self.reading_path,{}),self.config.device_id,function(sequence)
            return self.config.device_id .. '-lectura-' .. os.time() .. '-' .. sequence
        end)
    end
    self.reading=reading_shared
end

function Todo:saveReading() Storage.save(self.reading_path,self.reading.state) end
function Todo:captureReading()
    if not self.reader_ready then return end
    local ok,err=pcall(function()
        if not self.state then self:load() end
        local now=self:serverTime()
        if not self.statistics_origin then
            local path=self.directory..'/statistics.json'
            local data=Storage.load(path,{})
            if not data.origin then
                data.origin='historial-'..os.time()..'-'..self.config.device_id:sub(-48)
                Storage.save(path,data)
            end
            self.statistics_origin=data.origin
        end
        local collected,statistics=pcall(Statistics.capture,self.ui,self.statistics_origin)
        if not collected then
            require('logger').warn('Todo: no se pudieron leer las estadísticas',statistics)
            statistics=nil
        end
        local snapshot=Reading.snapshot(self.ui,math.floor(now),statistics)
        if snapshot and self.reading:capture(snapshot) then self:saveReading() end
    end)
    if not ok then self.status='No se pudo guardar la lectura: '..tostring(err) end
end
function Todo:onDocSettingsLoad(settings,document)
    local checksum=document and document.file and util.partialMD5(document.file)
    if checksum then settings:saveSetting('partial_md5_checksum',checksum) end
end
function Todo:onReaderReady()
    self:onDocSettingsLoad(self.ui.doc_settings,self.ui.document)
    self.reader_ready=true; self:captureReading()
    UIManager:scheduleIn(5,self.reading_task)
end
function Todo:onPageUpdate()
    if not self.reader_ready then return end
    self:captureReading()
    UIManager:unschedule(self.reading_task); UIManager:scheduleIn(15,self.reading_task)
end
Todo.onPosUpdate=Todo.onPageUpdate
function Todo:onAnnotationsModified()
    if not self.reader_ready then return end
    -- Capturar después de que KOReader termine de actualizar la anotación.
    UIManager:nextTick(function() self:captureReading() end)
    UIManager:unschedule(self.reading_task); UIManager:scheduleIn(5,self.reading_task)
end
function Todo:onCloseDocument()
    self:captureReading(); self.reader_ready=false
end
function Todo:linkReading()
    self:captureReading()
    if not self.state then
        local ok,err=pcall(function() self:load() end)
        if not ok then self:message(err); return end
    end
    if not NetworkMgr:isConnected() then self:showReadingLinks(); return end
    if self.syncing then self:message('Espera a que termine la sincronización y vuelve a abrir este menú.'); return end
    self.syncing=true
    Trapper:wrap(function()
        local ok,err=pcall(function()
            local status,result=self:request('GET','/v1/kindle/books')
            assert(status==200 and type(result.books)=='table',result.error or 'No se pudo consultar Biblioteca.')
            for _,book in pairs(self.reading.state.books) do
                if book.needs_link then book.candidates=result.books end
            end
            self:saveReading()
        end)
        self.syncing=false
        if ok then self:showReadingLinks()
        elseif err~=sync_cancelled then self:message(err) end
    end)
end
function Todo:showReadingLinks()
    local entries={}
    for document,book in pairs(self.reading.state.books) do
        if book.needs_link then entries[#entries+1]={document=document,book=book} end
    end
    if #entries==0 then self:message('Los libros enviados están vinculados. Abre un libro y sincroniza para comprobarlo.'); return end
    local Menu=require('ui/widget/menu')
    local dialog
    local buttons={}
    for _,entry in ipairs(entries) do
        local current=entry
        buttons[#buttons+1]={text=current.book.latest.title,callback=function()
            UIManager:close(dialog)
            local choices={}; local picker
            for _,candidate in ipairs(current.book.candidates or {}) do
                local target=candidate
                choices[#choices+1]={text=target.title..' · '..target.author,callback=function()
                    local ok,err=pcall(function() self.reading:link(current.document,target.id); self:saveReading() end)
                    UIManager:close(picker)
                    if ok then self:sync(true) else self:message(err) end
                end}
            end
            picker=Menu:new{title='Elegir ficha de Biblioteca',item_table=choices}; UIManager:show(picker)
        end}
    end
    dialog=Menu:new{title='Libros pendientes de vincular',item_table=buttons}; UIManager:show(dialog)
end

function Todo:save()
    self.state.queue = self.queue.items
    Storage.save(self.state_path, self.state)
end

function Todo:open()
    if self.panel then return end
    local ok, err = pcall(function() self:load() end)
    if not ok then self:message(err); return end
    if self.reader_ready and self.ui.statistics and self.ui.statistics.onReadingPaused then
        self:captureReading()
        self.ui.statistics:onReadingPaused()
        self.todo_paused_reading=true
    end
    self.page, self.day_index, self.today_view = 1, 1, true
    self.week = self.state.clock and self.state.clock.logical_date or os.date('%Y-%m-%d')
    self.suspended = false
    self:render()
    self:schedule()
    UIManager:scheduleIn(0.2, self.send_task)
end

function Todo:stopTimers()
    if self.start_task then UIManager:unschedule(self.start_task); self.start_task=nil end
    UIManager:unschedule(self.refresh_task)
    UIManager:unschedule(self.clock_task)
    UIManager:unschedule(self.send_task)
    UIManager:unschedule(self.render_task)
    UIManager:unschedule(self.reading_task)
end

function Todo:schedule()
    self:stopTimers()
    if self.panel and not self.suspended then
        UIManager:scheduleIn(300,self.refresh_task)
        UIManager:scheduleIn(60,self.clock_task)
    end
end

function Todo:close()
    self:hideSleepPanel()
    if self.modal then UIManager:close(self.modal); self.modal=nil end
    if self.panel then UIManager:close(self.panel,'full'); self.panel=nil end
    self:stopTimers()
    self:cancelSync()
    if self.todo_paused_reading then
        if self.ui.statistics and self.ui.statistics.onReadingResumed then self.ui.statistics:onReadingResumed() end
        self.todo_paused_reading=nil
    end
    if self.reader_ready and not self.suspended then UIManager:scheduleIn(15,self.reading_task) end
end

function Todo:openLibrary()
    local ok,name=pcall(Library.prepare,self.ui)
    if not ok then self:message(name); return end
    self:close()
    self.ui.collections:onShowColl(name)
    local menu=self.ui.collections.booklist_menu
    local close,select=menu.close_callback,menu.onMenuSelect
    menu.close_callback=function() close(); self:open() end
    menu.onReturn=menu.close_callback
    menu.onMenuSelect=function(widget,item)
        local return_to_todo=widget.close_callback
        widget.close_callback=close
        local result=select(widget,item)
        widget.close_callback=return_to_todo
        return result
    end
    Navigation.todoButton(menu.title_bar,menu.close_callback)
    Navigation.libraryViewButton(menu.title_bar,Library.view(),function()
        close()
        Library.toggleView()
        self:openLibrary()
    end)
end

function Todo:showModal(widget)
    self.modal=widget
    local original=widget.onCloseWidget
    widget.onCloseWidget=function(value,...)
        if original then original(value,...) end
        if self.modal==value then
            self.modal=nil
            UIManager:scheduleIn(0,self.render_task)
        end
    end
    UIManager:show(widget)
end
function Todo:hideSleepPanel()
    if self.sleep_panel then
        local widget=self.sleep_panel
        self.sleep_panel=nil
        UIManager:close(widget)
    end
end

function Todo:buildSleepPanel()
    local screen=Device.screen
    local w,h=screen:getWidth(),screen:getHeight()
    local padding=math.floor(w*0.045)
    local width=w-2*padding
    local clock=self.state.clock
    local day=clock and clock.logical_date or os.date('%Y-%m-%d')
    local agenda=self.state.weeks[day]
    local tasks=agenda and agenda.days[1].tasks or {}
    local header=self:header(width,day,true)
    local footer_height=screen:scaleBySize(24)
    local budget=h-2*padding-header:getSize().h-footer_height
    local rows=self:layoutRows(tasks,width,day,true,budget)
    local page=paginate(rows,budget,0)[1]
    expandRows(page,budget)
    local body=VerticalGroup:new{align='left'}
    for _,row in ipairs(page) do
        local line=HorizontalGroup:new{align='top',HorizontalSpan:new{width=row.indent},
            TextBoxWidget:new{width=row.icon_width,text=row.icon,face=Font:getFace('cfont',row.font)},
            TextBoxWidget:new{width=row.text_width,text=row.text,
                face=Font:getFace('cfont',row.font),bold=row.entry.depth==0}}
        body[#body+1]=center(line,width,row.height)
    end
    if #page==0 then body[#body+1]=TextBoxWidget:new{width=width,alignment='center',face=Font:getFace('cfont',22),
        text=agenda and 'No hay tareas pendientes para este día.' or 'Agenda no descargada. Abre Todo y pulsa Actualizar.'} end
    local footer=self:updatedText()
    if #rows>#page then footer='+' .. (#rows-#page) .. ' más · ' .. footer end
    if #self.queue.items>0 then footer=#self.queue.items .. ' marcas pendientes · ' .. footer end
    local elements=VerticalGroup:new{align='left',header,center(body,width,budget),
        center(TextBoxWidget:new{width=width,alignment='center',face=Font:getFace('cfont',14),text=footer},width,footer_height)}
    return FrameContainer:new{width=w,height=h,padding=padding,margin=0,bordersize=0,modal=true,
        background=Blitbuffer.COLOR_WHITE,elements}
end

function Todo:onSuspend()
    self:captureReading()
    self.suspended=true
    self:cancelSync()
    self:stopTimers()
    -- Un segundo total como máximo; si la red se corta, reintentar al despertar.
    if self.reading and NetworkMgr:isConnected() and not self.reading.sending and self.reading:next() then
        pcall(function()
            local deadline=Transport.deadline(1)
            while self.reading:next() do
                local body=self.reading:next(); self:saveReading()
                local status,result=Transport.request(self.config,'POST','/v1/kindle/reading',body,deadline)
                self.reading:receive(status,result); self:saveReading()
                if status~=200 or self.reading.state.sealed then break end
            end
        end)
    end
    if not self:screensaverEnabled() or self.sleep_panel then return end
    local ok,widget=pcall(function()
        if not self.state then self:load() end
        return self:buildSleepPanel()
    end)
    if ok then self.sleep_panel=widget; UIManager:show(widget,'full')
    else self.status=tostring(widget) end
end
function Todo:onResume()
    self:hideSleepPanel()
    self.suspended=false
    if self.panel and self.todo_paused_reading then
        UIManager:nextTick(function()
            if self.panel and self.ui.statistics then self.ui.statistics:onReadingPaused() end
        end)
    end
    if self.reader_ready or (self.reading and next(self.reading.state.books)) then
        UIManager:scheduleIn(2,self.reading_task)
    end
    if self.panel then self:render(); self:schedule() end
    if self.panel or self:screensaverEnabled() then
        if not self.state then
            local ok,err=pcall(function() self:load() end)
            if not ok then self.status=tostring(err); return end
        end
        UIManager:scheduleIn(1,self.refresh_task)
    end
end
function Todo:onNetworkConnected()
    if self.suspended or not (self.panel or self:screensaverEnabled()) then return end
    if not self.state then
        local ok=pcall(function() self:load() end)
        if not ok then return end
    end
    self:sync(false)
end
function Todo:onCloseWidget() self:captureReading(); self:close() end

function Todo:serverTime()
    local c = self.state.clock
    if not c then return os.time(), 0 end
    return c.server_epoch + os.time() - c.received_at, c.utc_offset_minutes * 60
end

function Todo:canMark()
    local c = self.state.clock
    if not c or not self.today_view or self.week ~= c.logical_date then return false end
    local now = self:serverTime()
    return now >= c.server_epoch and now < c.day_valid_until
end

function Todo:canMarkTask(root,task)
    local pending=self.queue:find(root.id,self:day())
    return self:canMark() and not task.completed and not task.blocked
        and (not pending or pending.state=='draft')
end

function Todo:mark(root, task)
    if not self:canMark() then self:message('Actualiza Hoy antes de crear nuevas marcas.'); return end
    if task.blocked or task.completed then return end
    local previous = json.encode(self.state)
    local ok, err = pcall(function()
        self.queue:toggle(root,task,self.state.clock.logical_date)
        self:save()
    end)
    if not ok then
        self.state = json.decode(previous)
        self:load()
        self:message(err)
    else
        self.status='Marcas guardadas en el Kindle: pendientes de enviar'
        UIManager:unschedule(self.send_task)
        UIManager:scheduleIn(2,self.send_task)
    end
    self:render()
end

function Todo:cancelSync()
    if self.sync_wait then self.sync_wait.dismiss_callback() end
end

function Todo:request(method,path,body)
    local wait=TrapWidget:new{resend_event=true}
    self.sync_wait=wait
    UIManager:show(wait)
    local ran,completed,ok,status,result,address=pcall(function()
        return Trapper:dismissableRunInSubprocess(function()
            local success,code,value=pcall(Transport.request,self.config,method,path,body)
            return success,code,value,Transport.last_address
        end,wait)
    end)
    self.sync_wait=nil
    UIManager:close(wait)
    if not ran then error(completed,0) end
    if not completed then error(sync_cancelled,0) end
    if not ok then error(status or 'El PC no está disponible.',0) end
    Transport.last_address=address
    return status,result
end

function Todo:sync(explicit)
    if self.syncing then return end
    if not self.state then
        local ok,err=pcall(function() self:load() end)
        if not ok then self:message(err); return end
    end
    if explicit and not NetworkMgr:isConnected() then
        NetworkMgr:runWhenConnected(function() if not self.suspended then self:sync(false) end end)
        return
    end
    if not NetworkMgr:isConnected() then
        self.status='Sin Wi-Fi · consulta sin conexión'
        if self.panel then self:render() end
        return
    end
    self.syncing = true
    Trapper:wrap(function()
        local ok, err = pcall(function()
            local index = 1
            while index <= #self.queue.items do
                local item = self.queue.items[index]
                if item.state == 'conflict' then index=index+1
                else
                    local body = self.queue:seal(item)
                    self:save() -- Persistir el cuerpo inmutable antes de transmitirlo.
                    local status, result = self:request('POST','/v1/kindle/completions',body)
                    local saved = self.queue:receive(item,status,result)
                    self:save()
                    if not saved then index=index+1 end
                    if status ~= 200 and status ~= 409 then error(result.error or 'El PC no está disponible.') end
                end
            end
            local function download(path)
                local status, agenda=self:request('GET',path)
                assert(status==200 and agenda.protocol_version==1 and type(agenda.days)=='table'
                    and #agenda.days==7 and type(agenda.server_epoch)=='number',
                    agenda.error or 'La agenda del PC no es válida.')
                return agenda
            end
            local agenda=download('/v1/kindle/agenda')
            self.state.clock = {logical_date=agenda.logical_date, server_epoch=agenda.server_epoch,
                received_at=os.time(), utc_offset_minutes=agenda.utc_offset_minutes,
                day_valid_until=agenda.day_valid_until}
            if self.today_view then self.week=agenda.logical_date end
            self.state.weeks[agenda.logical_date]=agenda
            if self.panel and not self.today_view and self.week~=agenda.logical_date then
                self.state.weeks[self.week]=download('/v1/kindle/agenda?start_date=' .. self.week)
            end
            self:save()
            while not self.reading.sending do
                local body=self.reading:next()
                if not body then break end
                self:saveReading() -- El envío conserva identificador y contenido tras una interrupción.
                self.reading.sending=true
                local sent,status,result=pcall(function() return self:request('POST','/v1/kindle/reading',body) end)
                self.reading.sending=false
                if not sent then error(status,0) end
                self.reading:receive(status,result); self:saveReading()
                if status~=200 then error(result.error or 'No se pudo enviar la lectura.') end
                if self.reading.state.sealed then error('La lectura no tiene confirmación de guardado.') end
            end
            self.status='Actualizado · ' .. #self.queue.items .. ' grupos pendientes'
            for _,book in pairs(self.reading.state.books) do
                if book.needs_link then self.status='Hay libros pendientes: menú → Vincular libro con Todo'; break end
            end
        end)
        self.syncing = false
        if not ok and err~=sync_cancelled then self.status=tostring(err):gsub('^.-:%d+: ', '') end
        if self.panel and (ok or err~=sync_cancelled) then self:render() end
        if explicit and not self.panel and (ok or err~=sync_cancelled) then self:message(self.status) end
    end)
end

function Todo:pendingFor(root,task,day)
    local item = self.queue:find(root.id,day)
    if not item then return false end
    for _, id in ipairs(item.body.task_ids) do if id==task.id then return true end end
    return false
end
function Todo:pending(root,task) return self:pendingFor(root,task,self:day()) end
function Todo:day() return shift(self.week,(self.day_index or 1)-1) end

function Todo:showTask(root, task)
    local viewer
    local displayed_day=self:day()
    local buttons = {{
        {text=self:pending(root,task) and 'Cancelar marca' or 'Completar',
            enabled=self:canMarkTask(root,task),
            callback=function()
                UIManager:close(viewer)
                if displayed_day~=self:day() then self:message('El día ha cambiado. Revisa Hoy antes de marcar.'); return end
                self:mark(root,task)
            end},
        {text='Cerrar', callback=function() UIManager:close(viewer) end},
    }}
    for _, child in ipairs(task.subtasks or {}) do
        local child_task = child
        table.insert(buttons, {{text=(child.completed and '✓ ' or '□ ') .. child.title,
            callback=function() UIManager:close(viewer); self:showTask(root,child_task) end}})
    end
    local description=task.description and task.description~='' and task.description .. '\n\n' or ''
    viewer=TextViewer:new{title=task.title, text=task.title .. '\n\n' .. description .. 'Fecha: ' .. self:day(), buttons_table=buttons}
    self:showModal(viewer)
end

function Todo:showQueue()
    local buttons, dialog = {}, nil
    for _, entry in ipairs(self.queue.items) do
        local item=entry
        table.insert(buttons, {{text=item.title .. ' · ' .. item.body.occurrence_date ..
            (item.state=='conflict' and ' · Revisar' or ' · Pendiente de enviar'), callback=function()
            UIManager:close(dialog)
            self:review(item)
        end}})
    end
    table.insert(buttons, {{text='Cerrar', callback=function() UIManager:close(dialog) end}})
    dialog=ButtonDialog:new{title='Marcas pendientes', buttons=buttons}
    self:showModal(dialog)
end

function Todo:review(item)
    local viewer
    local current=item.current
    local text=item.title .. '\nFecha original: ' .. item.body.occurrence_date .. '\n\n' ..
        (item.error or 'La marca está guardada en el Kindle y aún no tiene confirmación del PC.')
    local function describe(task,indent)
        text=text .. '\n' .. indent .. task.title .. (task.completed and ' · completada' or '') ..
            '\n' .. indent .. (task.description or '')
        for _, child in ipairs(task.subtasks or {}) do describe(child,indent .. '  ') end
    end
    if current then text=text .. '\n\nVersión actual en Todo:'; describe(current,'') end
    viewer=TextViewer:new{title='Revisar marca', text=text, buttons_table={
        {{text='Confirmar versión actual', enabled=item.state=='conflict' and current~=nil and not current.blocked,
            callback=function()
                local ok,err=pcall(function() self.queue:confirm(item); self:save() end)
                if ok then UIManager:close(viewer); self:sync(true) else self:message(err) end
            end}},
        {{text='Descartar marca', enabled=item.state~='sending', callback=function()
            self.queue:discard(item); self:save(); UIManager:close(viewer); self:render()
        end}},
        {{text='Reintentar envío', callback=function() UIManager:close(viewer); self:sync(true) end},
         {text='Cerrar', callback=function() UIManager:close(viewer) end}},
    }}
    self:showModal(viewer)
end

function Todo:render()
    if self.suspended or self.modal then return end
    local screen=Device.screen
    local w,h=screen:getWidth(),screen:getHeight()
    local padding=math.floor(w*0.045)
    local width=w-2*padding
    local function button(text,callback,enabled,bold)
        return {text=text,callback=callback,enabled=enabled~=false,font_size=17,font_bold=bold or false,
            height=screen:scaleBySize(32)}
    end
    local top=VerticalGroup:new{align='left',self:header(width,self:day())}
    top[#top+1]=ButtonTable:new{width=width,buttons={{
        button('Hoy',function() self.today_view=true; self.day_index=1; self.page=1;
            self.week=self.state.clock and self.state.clock.logical_date or self.week; self:render(); self:sync(false) end,true,self.today_view),
        button('Semana',function() self.today_view=false; self:render() end,true,not self.today_view),
        button('Actualizar',function() self:sync(true) end),
    }}}
    if not self.today_view then
        local nav={button('‹',function() self.week=shift(self.week,-7); self.page=1; self:sync(false) end)}
        for index=1,7 do
            local day_index=index
            nav[#nav+1]=button(shift(self.week,index-1):sub(9,10),function() self.day_index=day_index; self.page=1; self:render() end)
        end
        nav[#nav+1]=button('›',function() self.week=shift(self.week,7); self.page=1; self:sync(false) end)
        top[#top+1]=ButtonTable:new{width=width,buttons={nav}}
    end
    local agenda=self.state.weeks[self.week]
    local tasks=agenda and agenda.days[self.day_index or 1].tasks or {}
    local action_buttons={
        button('Marcas (' .. #self.queue.items .. ')',function() self:showQueue() end),
        button('Mis libros',function() self:openLibrary() end),
    }
    action_buttons[#action_buttons+1]=button(self.ui.document and 'Seguir leyendo' or 'KOReader',function() self:close() end)
    local actions=ButtonTable:new{width=width,buttons={action_buttons}}
    local status=self:updatedText()
    if not self.status:match('^Actualizado') and self.status~='Agenda guardada' then status=self.status .. ' · ' .. status end
    local footer=TextBoxWidget:new{width=width,alignment='center',face=Font:getFace('cfont',14),text=status}
    local budget=h-2*padding-top:getSize().h-actions:getSize().h-footer:getSize().h
    local context_height=screen:scaleBySize(24)
    local rows=self:layoutRows(tasks,width-math.floor(width*0.085)-screen:scaleBySize(12),self:day(),false,budget)
    local pages=paginate(rows,budget,context_height)
    local pager
    local function pageControls(total)
        return ButtonTable:new{width=width,buttons={{
            button('‹ Anterior',function() self.page=self.page-1; self:render() end,self.page>1),
            button(self.page .. ' / ' .. total,function() end,false),
            button('Siguiente ›',function() self.page=self.page+1; self:render() end,self.page<total)}}}
    end
    self.page=math.max(1,math.min(self.page or 1,#pages))
    if #pages>1 then
        pager=pageControls(#pages)
        budget=budget-pager:getSize().h
        pages=paginate(rows,budget,context_height)
        self.page=math.min(self.page,#pages)
        pager=pageControls(#pages)
    end
    local page=pages[self.page]
    expandRows(page,page.budget-#page*2)
    local body=VerticalGroup:new{align='left'}
    if page.context then body[#body+1]=center(TextBoxWidget:new{width=width,alignment='center',
        text=page.context,face=Font:getFace('cfont',15),bold=true},width,context_height) end
    for _,row in ipairs(page) do
        local root,task=row.entry.root,row.entry.task
        local mark_width=math.floor(width*0.085)
        body[#body+1]=HorizontalGroup:new{align='center',
            HorizontalSpan:new{width=row.indent},
            Button:new{text=row.icon,width=mark_width,height=row.height,text_font_size=22,
                padding=0,padding_h=0,padding_v=0,bordersize=0,margin=0,
                enabled=self:canMarkTask(root,task),callback=function() self:mark(root,task) end},
            Button:new{text=row.text,width=width-row.indent-mark_width,height=row.height,text_font_size=row.font,
                text_font_bold=row.entry.depth==0,align='left',padding=0,padding_h=screen:scaleBySize(6),
                padding_v=0,bordersize=0,margin=0,callback=function() self:showTask(root,task) end}}
        body[#body+1]=LineWidget:new{dimen=Geom:new{w=width,h=1},background=Blitbuffer.COLOR_GRAY}
    end
    if #page==0 then body[#body+1]=TextBoxWidget:new{width=width,alignment='center',face=Font:getFace('cfont',22),
        text=agenda and 'No hay tareas pendientes para este día.' or 'Agenda no descargada. Pulsa Actualizar.'} end
    local elements=VerticalGroup:new{align='left',top,center(body,width,budget)}
    if pager then elements[#elements+1]=pager end
    elements[#elements+1]=actions
    elements[#elements+1]=footer
    local panel=InputContainer:new{dimen=Geom:new{x=0,y=0,w=w,h=h},covers_fullscreen=true,
        FrameContainer:new{width=w,height=h,padding=padding,margin=0,bordersize=0,
            background=Blitbuffer.COLOR_WHITE,elements}}
    if self.panel then UIManager:close(self.panel) end
    self.panel=panel
    UIManager:show(panel)
    UIManager:setDirty(panel,'ui')
end

return Todo
