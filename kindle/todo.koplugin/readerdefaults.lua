-- Guarda la composición del libro en las preferencias globales nativas.
local Defaults={}
local function copy(value)
    if type(value)~='table' then return value end
    local result={};for k,v in pairs(value) do result[k]=copy(v) end;return result
end

function Defaults.values(settings)
    local values={}
    for key,value in pairs(settings) do
        if key:match('^copt_') then values[key]=copy(value) end
    end
    if settings.font_face then values.cre_font=settings.font_face end
    if settings.font_family_fonts then values.cre_font_family_fonts=copy(settings.font_family_fonts) end
    if settings.css then values.copt_css=settings.css end
    return values
end

function Defaults.applyPending(directory,global)
    local Storage=dofile(debug.getinfo(1,'S').source:match('^@(.*/)')..'storage.lua')
    local path=directory..'/reader_defaults_request.json'
    local request=Storage.load(path)
    if not request then return false end
    assert(type(request.source)=='string' and require('libs/libkoreader-lfs').attributes(request.source,'mode')=='file',
        'No se encuentra el libro del que guardar los ajustes.')
    local source=require('docsettings'):open(request.source)
    local values=Defaults.values(source.data)
    assert(values.cre_font and values.copt_font_size,'El libro no tiene ajustes de lectura guardados.')
    for key,value in pairs(values) do global:saveSetting(key,value) end
    global:flush()
    assert(os.remove(path),'No se pudo retirar la petición de ajustes ya aplicada.')
    return true
end
return Defaults
