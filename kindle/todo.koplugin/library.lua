local lfs = require('libs/libkoreader-lfs')
local DocumentRegistry = require('document/documentregistry')
local Library = {}
local directory=assert(debug.getinfo(1,'S').source:match('^@(.*/)'))
local Grid=dofile(directory..'covergrid.lua')
local formats = {epub=true,mobi=true,azw=true,azw3=true,pdf=true,fb2=true,djvu=true,djv=true,cbz=true,cbr=true}

function Library.view() return G_reader_settings:readSetting('todo_library_view','covers') end
function Library.toggleView()
    G_reader_settings:saveSetting('todo_library_view',Library.view()=='covers' and 'list' or 'covers')
end
function Library.recentSort(history)
    local ranks={}
    for index,item in ipairs(history) do if not ranks[item.file] then ranks[item.file]=index end end
    return function(a,b)
        local first,second=ranks[a.file] or math.huge,ranks[b.file] or math.huge
        if first~=second then return first<second end
        return (a.text or a.file)<(b.text or b.file)
    end
end

local function scan(path,files)
    for name in lfs.dir(path) do
        local lower=name:lower()
        if name:sub(1,1)~='.' and not lower:match('%.sdr$') and lower~='dictionaries' then
            local file=path .. '/' .. name
            local mode=lfs.attributes(file,'mode')
            if mode=='directory' then scan(file,files)
            elseif mode=='file' and formats[lower:match('%.([^%.]+)$')]
                and not lower:find('dictionary',1,true) and not lower:find('diccionario',1,true)
                and DocumentRegistry:hasProvider(file) then
                files[file]=true
            end
        end
    end
end

function Library.prepare(ui)
    assert(ui.coverbrowser and ui.collections, 'Activa el complemento de portadas de KOReader para abrir la biblioteca.')
    local collections=require('readcollection')
    local name='Mis libros'
    local changed=false
    if not collections.coll[name] then
        collections:addCollection(name)
        collections.coll_settings[name].collate='strcoll'
        changed=true
    end
    local files={}
    scan('/mnt/us/documents',files)
    local epubs={}
    for file in pairs(files) do
        if file:lower():match('%.epub$') then epubs[file:sub(1,-6):lower()]=true end
    end
    local function hasEpub(file)
        local stem,extension=file:lower():match('^(.*)%.([^%.]+)$')
        return (extension=='mobi' or extension=='azw' or extension=='azw3') and epubs[stem]
    end
    for file in pairs(files) do
        if not hasEpub(file) and not collections.coll[name][file] then
            collections:addItem(file,name)
            changed=true
        end
    end
    for file in pairs(collections.coll[name]) do
        if lfs.attributes(file,'mode')~='file' or not DocumentRegistry:hasProvider(file) or hasEpub(file) then
            collections:removeItem(file,name,true)
            changed=true
        end
    end
    if changed then collections:write({[name]=true}) end
    local covers=require('bookinfomanager')
    if not G_reader_settings:isTrue('todo_library_layout') then
        covers:saveSetting('files_per_page',7)
        covers:saveSetting('hide_file_info',true)
        covers:saveSetting('hide_page_info',false)
        covers:saveSetting('show_pages_read_as_progress',false)
        covers:saveSetting('show_pages_left_in_progress',false)
        ui.coverbrowser:setupFileManagerDisplayMode('list_image_meta')
        ui.coverbrowser.setupWidgetDisplayMode('collections','list_image_meta')
        G_reader_settings:saveSetting('todo_library_layout',true)
    end
    local mode=covers:getSetting('collection_display_mode')
    local baseline=mode and ui.coverbrowser.getUpdateItemTableFunc(mode)
        or require('apps/filemanager/filemanagercollection').updateItemTable
    ui.collections.updateItemTable=baseline
    if Library.view()=='covers' then
        Grid.install()
        local update=ui.coverbrowser.getUpdateItemTableFunc('mosaic_image')
        ui.collections.updateItemTable=function(manager,...)
            local menu=manager.booklist_menu
            if menu.path~=name then return baseline(manager,...) end
            menu.todo_cover_grid=true
            menu.nb_cols_portrait=2; menu.nb_rows_portrait=2
            menu.nb_cols_landscape=3; menu.nb_rows_landscape=1
            manager.sorting_func=Library.recentSort(require('readhistory').hist)
            return update(manager,...)
        end
    end
    return name
end

return Library
