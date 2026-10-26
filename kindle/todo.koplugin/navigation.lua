local Button = require('ui/widget/button')
local UIManager = require('ui/uimanager')
local Navigation = {}

function Navigation.closeMenu(ui)
    if ui.document then
        ui.menu:onTapCloseMenu()
    else
        ui.menu:onCloseFileManagerMenu()
    end
end

function Navigation.installOpening()
    local ReaderUI=require('apps/reader/readerui')
    if ReaderUI.todo_opening_message then return end
    local InfoMessage=require('ui/widget/infomessage')
    local original=ReaderUI.showReaderCoroutine
    ReaderUI.showReaderCoroutine=function(...)
        local previous=rawget(InfoMessage,'new')
        local constructor=InfoMessage.new
        local first=true
        InfoMessage.new=function(class,message,...)
            if first then
                first=false
                if type(message)=='table' and message.timeout==0 then
                    message.text='Abriendo libro…'
                end
            end
            return constructor(class,message,...)
        end
        local ok,result=pcall(original,...)
        InfoMessage.new=previous
        if not ok then error(result,0) end
        return result
    end
    ReaderUI.todo_opening_message=true
end

function Navigation.todoButton(bar,callback,alternative,selection)
    local previous=bar and bar.right_button
    if not previous or previous.todo_shortcut then return end
    local button=Button:new{text='Todo',text_font_size=16,text_font_bold=true,
        width=previous.width+2*(previous.padding or 0),height=previous.height+2*(previous.padding or 0),
        padding=0,padding_h=0,padding_v=0,bordersize=0,margin=0,overlap_align='right',
        callback=function()
            if selection and selection() then alternative() else callback() end
        end,
        hold_callback=alternative,todo_shortcut=true}
    button.setIcon=function(value)
        value:setText(selection and selection() and '✓' or 'Todo')
    end
    for index,child in ipairs(bar) do
        if child==previous then bar[index]=button; break end
    end
    bar.right_button=button
    previous:free()
end

function Navigation.libraryViewButton(bar,view,callback)
    local previous=bar and bar.left_button
    if not previous or previous.todo_library_toggle then return end
    local button=Button:new{text=view=='covers' and 'Lista' or 'Portadas',text_font_size=14,
        width=previous.width+2*(previous.padding or 0),height=previous.height+2*(previous.padding or 0),
        padding=0,padding_h=0,padding_v=0,bordersize=0,margin=0,overlap_align='left',
        callback=callback,hold_callback=previous.callback,todo_library_toggle=true}
    for index,child in ipairs(bar) do if child==previous then bar[index]=button; break end end
    bar.left_button=button
    previous:free()
end

function Navigation.install(todo)
    Navigation.installOpening()
    local ui=todo.ui
    if ui.document then
        local function openLibrary()
            Navigation.closeMenu(ui)
            UIManager:tickAfterNext(function() todo:openLibrary() end)
        end
        ui.onHome=function() openLibrary(); return true end
        local button=ui.menu and ui.menu.menu_items and ui.menu.menu_items.filemanager
        if button then
            button.icon='home'
            button.text='Mis libros'
            button.callback=openLibrary
        end
        return
    end
    ui.onHome=function() todo:openLibrary(); return true end
    local setup=ui.setupLayout
    if setup then
        ui.setupLayout=function(value,...)
            setup(value,...)
            Navigation.todoButton(value.title_bar,function() todo:open() end,
                function() value:onShowPlusMenu() end,function() return value.selected_files end)
        end
    end
end

function Navigation.menuItem(ui,items,callback)
    local context=ui.document and 'reader' or 'filemanager'
    local order=require('ui/elements/' .. context .. '_menu_order')
    if not order.todo_shortcut then
        order.todo_shortcut={}
        local buttons=order['KOMenu:menu_buttons']
        table.insert(buttons,#buttons,'todo_shortcut')
    end
    items.todo_shortcut={text='Todo',icon='check',remember=false,callback=callback}
end

return Navigation
