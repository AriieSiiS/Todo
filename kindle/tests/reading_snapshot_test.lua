local Reading=dofile('kindle/todo.koplugin/reading.lua')
local ui={document={info={has_pages=false},getPageCount=function() return 1300 end},doc_props={title='Circe',authors='Madeline Miller'},
    doc_settings={readSetting=function() return string.rep('a',32) end},
    rolling={getLastPercent=function() return .14 end,getLastProgress=function() return '/p[42]' end},
    view={state={page=42}},toc={getTocTitleByPage=function(_,page)
        assert(page==42); return 'Capítulo siete'
    end},annotation={annotations={
        {page='/p[4]',pageno=4},
        {drawer='lighten',pos0='/p[5]:0',pos1='/p[5]:20',text='Una cita',note='Mi nota',pageref='v',pageno=5,chapter='Uno',datetime='2026-10-24'},
    }}}
local snapshot=assert(Reading.snapshot(ui,100))
assert(snapshot.progress==.14 and snapshot.page=='42' and snapshot.position=='/p[42]')
assert(snapshot.total_pages==1300)
assert(snapshot.page_unit=='screen','Un EPUB informa pantallas, no páginas de la edición')
assert(snapshot.chapter=='Capítulo siete','Capturar el capítulo de la página actual, no el de una cita')
assert(#snapshot.quotes==1 and snapshot.quotes[1].page=='5' and snapshot.quotes[1].note=='Mi nota')
ui.document.info.has_pages=true
ui.paging=ui.rolling
assert(Reading.snapshot(ui,100).page_unit=='page','Los PDF conservan su paginación fija')
assert(Reading.snapshot(ui,100).quotes[1].page=='v','Conservar las etiquetas de las páginas fijas')
local item=ui.annotation.annotations[2]
item.pos0={x=2,y=1,page=5}; item.pos1={page=5,x=10,y=1}
local first=Reading.snapshot(ui,100).quotes[1].anchor
item.pos0={page=5,y=1,x=2}; item.pos1={y=1,x=10,page=5}
assert(Reading.snapshot(ui,100).quotes[1].anchor==first)
ui.toc.getTocTitleByPage=function() error('Índice no disponible') end
assert(Reading.snapshot(ui,100).chapter=='')
ui.toc=nil
assert(Reading.snapshot(ui,100).chapter=='')
ui.document.info.has_pages=false
item.pos0='/p[5]:0'
ui.pagemap={has_pagemap=true,has_pagemap_document_provided=true,
    getCurrentPageLabel=function() return '83',83,669 end,
    getLastPageLabel=function() return '669' end,
    getXPointerPageLabel=function(_,xp) assert(xp==item.pos0); return 'v' end}
local mapped=Reading.snapshot(ui,100)
assert(mapped.page=='83' and mapped.total_pages==669 and mapped.page_unit=='page',
    'El mapa de la edición sustituye las pantallas sin cambiar el porcentaje')
assert(mapped.progress==.14 and mapped.position=='/p[42]')
assert(mapped.quotes[1].page=='v' and mapped.quotes[1].page_unit=='page')
ui.pagemap.chars_per_synthetic_page=1500
local synthetic=Reading.snapshot(ui,100)
assert(synthetic.page=='42' and synthetic.page_unit=='screen')
assert(synthetic.quotes[1].page=='5' and synthetic.quotes[1].page_unit=='screen',
    'Una etiqueta sintética o antigua nunca se presenta como página editorial')
ui.pagemap.chars_per_synthetic_page=nil
ui.pagemap.has_pagemap_document_provided=false
assert(Reading.snapshot(ui,100).page_unit=='screen')
ui.pagemap.chars_per_synthetic_page=2100
local old_read=ui.doc_settings.readSetting
ui.doc_settings.readSetting=function(settings,key)
    if key=='todo_estimated_pages' then return 1088 end
    return old_read(settings,key)
end
local estimated=Reading.snapshot(ui,100)
assert(estimated.page_unit=='estimated_page' and estimated.quotes[1].page_unit=='estimated_page')
assert(estimated.progress==.14 and estimated.position=='/p[42]')
print('Lectura: porcentaje, páginas estables, notas y posiciones EPUB/PDF correctos')
