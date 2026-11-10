local Footer=dofile('kindle/todo.koplugin/footer.lua')
local preferences,flushes={},0
G_reader_settings={nilOrTrue=function(_,key) return preferences[key]~=false end,
    saveSetting=function(_,key,value) preferences[key]=value end,
    flush=function() flushes=flushes+1 end}
local settings={chapter_progress_bar=true,item_prefix='icons',all_at_once=false}
local chapter_count,chapter_left=20,7
local toc={getChapterPageCount=function() return chapter_count end,
    getChapterPagesLeft=function() return chapter_left end}
local modes={[0]='off',[1]='page_progress',[6]='percentage',
    [7]='book_time_to_read',[8]='chapter_time_to_read',[9]='frontlight'}
local resets,updates=0,0
local footer={settings=settings,mode_index=modes,pageno=57,percent_finished=57/1083,
    ui={toc=toc,statistics={}},progress_bar={},view={}}
local function nativeText(value)
    local mode=modes[value.mode]
    local compact=settings.item_prefix=='compact_items'
    if mode=='page_progress' then return '57 / 1083' end
    if mode=='percentage' then return (compact and '' or '⤠ ')..'5%' end
    if mode=='book_time_to_read' then return (compact and '' or '⏳ ')..'19h 28m' end
    if mode=='chapter_time_to_read' then return '⤻ '..(chapter_left and '12m' or '19h 28m') end
    if mode=='frontlight' then return '☼ 10' end
    return ''
end
function footer:applyFooterMode(mode)
    if mode~=nil then self.mode=mode end
    self.view.footer_visible=modes[self.mode]~='off'
    self.genFooterText=nativeText
end
function footer:setTocMarkers(reset)
    assert(reset)
    resets=resets+1
    if self.settings.chapter_progress_bar then self.progress_bar.ticks=nil
    else self.progress_bar.ticks={10,20} end
end
function footer:onUpdateFooter(force,full)
    updates=updates+1
    self.progress_bar.percentage=self.settings.chapter_progress_bar and 0.65 or self.percent_finished
    self.text=self:genFooterText()
    self.force,self.full=force,full
end
function footer:addToMainMenu(items)
    items.status_bar={sub_item_table={{text='Ajuste nativo'}}}
end
footer:applyFooterMode(1)
assert(Footer.install(footer))
assert(not Footer.install(footer), 'La instalación repetida no duplica etiquetas ni envoltorios')
local function show(mode,text,progress)
    footer:applyFooterMode(mode)
    footer:onUpdateFooter(true,false)
    assert(footer.text==text, footer.text..' no coincide con '..text)
    assert(footer.progress_bar.percentage==progress, 'La barra debe medir el ámbito indicado por el texto')
    assert(footer.force==true and footer.full==false, 'Se conserva el refresco solicitado por KOReader')
end
local book=57/1083
show(1,'5% · 57 / 1083',book)
local first_resets=resets
show(6,'5% · 57 / 1083',book)
assert(footer.mode==1 and settings.percentage==false,'El porcentaje fijo no ocupa un paso del carrusel')
show(7,'5% · faltan 19h 28m',book)
assert(resets==first_resets, 'Cambiar entre datos del libro no cambia la escala ni los marcadores')
show(8,'5% · Capítulo · faltan 12m',0.65)
assert(settings.chapter_progress_bar and not footer.progress_bar.ticks)
show(1,'5% · 57 / 1083',book)
assert(not settings.chapter_progress_bar and footer.progress_bar.ticks,
    'Volver al libro restaura su escala y sus marcas de capítulos')
settings.item_prefix='compact_items'
show(7,'5% · faltan 19h 28m',book)
show(6,'5% · 57 / 1083',book)
show(8,'5% · Capítulo · faltan 12m',0.65)
chapter_count,chapter_left=nil,nil
show(8,'5% · faltan 19h 28m',book)
show(0,'',book)
assert(footer.mode==0 and footer.view.footer_visible,
    'El paso sin texto conserva la barra visible y su lugar en el carrusel')
show(9,'5% · ☼ 10',book)
settings.all_at_once=true
show(7,'5% · 19h 28m',book)
footer.percent_finished=.14
show(7,'14% · 19h 28m',.14)
assert(not Footer.install(nil), 'El explorador no tiene una barra de lectura que modificar')
assert(updates==13, 'Cada actualización se delega una sola vez en KOReader')
settings.all_at_once=false
footer.ui.doc_settings={readSetting=function(_,key) if key=='todo_estimated_pages' then return 1088 end end}
footer.ui.pagemap={has_pagemap=true,chars_per_synthetic_page=2100}
show(1,'14% · ≈ 57 / 1083',.14)
show(7,'14% · faltan 19h 28m',.14)
footer.ui.pagemap=nil
show(1,'14% · 57 / 1083',.14)
local items={}
footer:addToMainMenu(items)
local option=items.status_bar.sub_item_table[1]
assert(option.text=='Mostrar porcentaje del libro' and option.checked_func(),
    'El porcentaje tiene una opción visible y está activado por defecto')
option.callback()
assert(not option.checked_func() and flushes==1,
    'Ocultar el porcentaje guarda la elección para los siguientes libros y reinicios')
show(1,'57 / 1083',.14)
show(7,'faltan 19h 28m',.14)
show(8,'faltan 19h 28m',.14)
chapter_count,chapter_left=20,7
show(8,'Capítulo · faltan 12m',0.65)
show(1,'57 / 1083',.14)
settings.all_at_once=true
show(7,'19h 28m',.14)
settings.all_at_once=false
option.callback()
assert(option.checked_func() and flushes==2)
show(1,'14% · 57 / 1083',.14)
assert(items.status_bar.sub_item_table[2].text=='Ajuste nativo',
    'Se conservan las opciones nativas de la barra')
show(8,'14% · Capítulo · faltan 12m',0.65)
show(0,'',.14)
assert(not settings.chapter_progress_bar and footer.mode==0 and footer.view.footer_visible,
    'Pasar del capítulo a solo barra recupera el ámbito del libro')
footer:applyFooterMode()
footer:onUpdateFooter(true,false)
assert(footer.text=='' and footer.view.footer_visible,
    'Recargar el modo guardado conserva solo la barra')
assert(option.checked_func(), 'El paso sin texto no cambia el interruptor del porcentaje')
show(1,'14% · 57 / 1083',.14)
print('Barra: ámbitos coherentes, etiquetas, tiempos nativos y ausencia de capítulos verificados')
