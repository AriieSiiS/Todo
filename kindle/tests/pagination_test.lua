local Pagination=dofile('kindle/todo.koplugin/pagination.lua')
local chars
local document={buildSyntheticPageMap=function(_,value) chars=value end,
    getPageMap=function() local result={}; for i=1,math.ceil(100000/chars) do result[i]={} end;return result end}
local calibrated,count=Pagination.calibrate(document,100)
assert(count==100 and calibrated==chars,'La paginación fija alcanza el total solicitado')
local saved={}
local ui={doc_settings={saveSetting=function(_,k,v) saved[k]=v end},
    pagemap={has_pagemap=true,has_pagemap_document_provided=true}}
assert(Pagination.enable(ui))
assert(saved.pagemap_use_page_labels and ui.pagemap.use_page_labels)
assert(not Pagination.enable(ui),'Activar una sola vez sin recargar el libro')
ui.pagemap.use_page_labels=false
ui.pagemap.chars_per_synthetic_page=1500
assert(not Pagination.enable(ui),'No confundir los mapas sintéticos con los de la edición')
ui.pagemap=nil
assert(not Pagination.enable(ui))
ui.doc_settings.readSetting=function(_,key) if key=='todo_estimated_pages' then return 1088 end end
ui.pagemap={has_pagemap=true,chars_per_synthetic_page=2100,
    getCurrentPageLabel=function() return '7' end,
    getLastPageLabel=function() return '1088' end,
    getXPointerPageLabel=function() return '6' end}
local page,total,unit=Pagination.current(ui)
assert(page=='7' and total==1088 and unit=='estimated_page',
    'La estimación aprobada conserva su unidad y no se confunde con páginas editoriales')
assert(Pagination.enable(ui))
local quote,quote_unit=Pagination.quote(ui,{pos0='/p[5]'})
assert(quote=='6' and quote_unit=='estimated_page')
ui.doc_settings.readSetting=function() return nil end
assert(Pagination.current(ui)==nil,'Otros mapas sintéticos no se activan por accidente')
print('Paginación: mapas de la edición y estimaciones autorizadas, sin cambiar posiciones')
