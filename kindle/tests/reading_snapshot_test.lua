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
assert(snapshot.chapter=='Capítulo siete','Capturar el capítulo de la página actual, no el de una cita')
assert(#snapshot.quotes==1 and snapshot.quotes[1].page=='v' and snapshot.quotes[1].note=='Mi nota')
ui.document.info.has_pages=true
ui.paging=ui.rolling
local item=ui.annotation.annotations[2]
item.pos0={x=2,y=1,page=5}; item.pos1={page=5,x=10,y=1}
local first=Reading.snapshot(ui,100).quotes[1].anchor
item.pos0={page=5,y=1,x=2}; item.pos1={y=1,x=10,page=5}
assert(Reading.snapshot(ui,100).quotes[1].anchor==first)
ui.toc.getTocTitleByPage=function() error('Índice no disponible') end
assert(Reading.snapshot(ui,100).chapter=='')
ui.toc=nil
assert(Reading.snapshot(ui,100).chapter=='')
print('Lectura: porcentaje, páginas estables, notas y posiciones EPUB/PDF correctos')
