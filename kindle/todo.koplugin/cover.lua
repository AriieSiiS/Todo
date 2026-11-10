-- Portada nativa del libro actual, también disponible sin conexión.
local Cover={}

function Cover.empty(agenda,index)
    local day=agenda and agenda.days and agenda.days[index or 1]
    return day and type(day.tasks)=='table' and #day.tasks==0 or false
end

function Cover.file(ui)
    local file=ui.document and ui.document.file
    if not file and G_reader_settings.readSetting then file=G_reader_settings:readSetting('lastfile') end
    if file and require('libs/libkoreader-lfs').attributes(file,'mode')=='file' then return file end
end

function Cover.create(ui,width,height)
    local file=Cover.file(ui)
    if not file then return end
    local ok,image=pcall(function()
        local info=ui.bookinfo or require('apps/filemanager/filemanagerbookinfo')
        return info:getCoverImage(ui.document,file)
    end)
    if not ok or not image then return end
    return require('ui/widget/imagewidget'):new{image=image,image_disposable=true,
        width=width,height=height,scale_factor=0,original_in_nightmode=true}
end

return Cover
