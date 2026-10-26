local Footer=dofile('kindle/todo.koplugin/footer.lua')
local settings={chapter_progress_bar=true,item_prefix='icons',all_at_once=false}
local chapter_count,chapter_left=20,7
local toc={getChapterPageCount=function() return chapter_count end,
    getChapterPagesLeft=function() return chapter_left end}
local modes={[0]='off',[1]='page_progress',[6]='percentage',
    [7]='book_time_to_read',[8]='chapter_time_to_read',[9]='frontlight'}
local resets,updates=0,0
local footer={settings=settings,mode_index=modes,pageno=57,percent_finished=57/1083,
    ui={toc=toc,statistics={}},progress_bar={}}
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
show(1,'Libro · 57 / 1083',book)
local first_resets=resets
show(6,'Libro · 5%',book)
show(7,'Libro · faltan 19h 28m',book)
assert(resets==first_resets, 'Cambiar entre datos del libro no cambia la escala ni los marcadores')
show(8,'Capítulo · faltan 12m',0.65)
assert(settings.chapter_progress_bar and not footer.progress_bar.ticks)
show(1,'Libro · 57 / 1083',book)
assert(not settings.chapter_progress_bar and footer.progress_bar.ticks,
    'Volver al libro restaura su escala y sus marcas de capítulos')
settings.item_prefix='compact_items'
show(7,'Libro · faltan 19h 28m',book)
show(6,'Libro · 5%',book)
show(8,'Capítulo · faltan 12m',0.65)
chapter_count,chapter_left=nil,nil
show(8,'Libro · faltan 19h 28m',book)
show(0,'',book)
show(9,'☼ 10',book)
settings.all_at_once=true
show(7,'19h 28m',book)
assert(not Footer.install(nil), 'El explorador no tiene una barra de lectura que modificar')
assert(updates==12, 'Cada actualización se delega una sola vez en KOReader')
print('Barra: ámbitos coherentes, etiquetas, tiempos nativos y ausencia de capítulos verificados')
