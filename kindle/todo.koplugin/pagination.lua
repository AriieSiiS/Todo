-- Usa las etiquetas del documento; los mapas sintéticos no son páginas impresas.
local Pagination={}
local estimates={
    ['Eisenhorn Omnibus']={author='Dan Abnett',pages=1088},
    ['Hábitos atómicos']={author='James Clear',pages=336},
    ['La mascarada del carnicero']={author='Matt Dinniman',pages=744},
    ['Proyecto Hail Mary']={author='Andy Weir',pages=544},
}

function Pagination.calibrate(document,target)
    local lo,hi,best,error_size=16,65536,nil,math.huge
    while lo<=hi do
        local chars=math.floor((lo+hi)/2)
        document:buildSyntheticPageMap(chars)
        local count=#document:getPageMap()
        local difference=math.abs(count-target)
        if difference<error_size then best,error_size=chars,difference end
        if count==target then return chars,count end
        if count>target then lo=chars+1 else hi=chars-1 end
    end
    document:buildSyntheticPageMap(best)
    return best,#document:getPageMap()
end

function Pagination.prepare(ui)
    local map,document=ui.pagemap,ui.document
    if not map or not document or document.info.has_pages or Pagination.publisher(ui) then return false end
    local selected,unit=Pagination.selected(ui)
    if selected then
        local target=ui.doc_settings:readSetting('todo_estimated_pages')
        if unit~='estimated_page' or #document:getPageMap()==target then return false end
    end
    local props=ui.doc_props or {}
    local profile=estimates[props.title]
    if not profile or props.authors~=profile.author then return false end
    local chars,count=Pagination.calibrate(document,profile.pages)
    map.has_pagemap=true; map.chars_per_synthetic_page=chars; map.page_labels_cache=nil
    ui.doc_settings:saveSetting('todo_estimated_pages',profile.pages)
    ui.doc_settings:saveSetting('pagemap_chars_per_synthetic_page',chars)
    ui.doc_settings:saveSetting('pagemap_doc_pages',count)
    return true
end
function Pagination.publisher(ui)
    local map=ui.pagemap
    return map and map.has_pagemap and map.has_pagemap_document_provided
        and not map.chars_per_synthetic_page and map or nil
end
function Pagination.selected(ui)
    if not ui then return end
    local map=Pagination.publisher(ui)
    if map then return map,'page' end
    map=ui.pagemap
    local settings=ui.doc_settings
    local target=settings and settings.readSetting and settings:readSetting('todo_estimated_pages')
    if type(target)=='number' and target>0 and map and map.has_pagemap and map.chars_per_synthetic_page then
        return map,'estimated_page'
    end
end
function Pagination.enable(ui)
    local map=Pagination.selected(ui)
    if not map or map.use_page_labels then return false end
    map.use_page_labels=true
    map.page_labels_cache=nil
    ui.doc_settings:saveSetting('pagemap_use_page_labels',true)
    return true
end
function Pagination.current(ui)
    local map,unit=Pagination.selected(ui)
    if not map then return end
    local ok,label,last=pcall(function()
        return map:getCurrentPageLabel(true),map:getLastPageLabel(true)
    end)
    if ok and type(label)=='string' and label~='' then
        return label,tonumber(last) or 0,unit
    end
end
function Pagination.quote(ui,item)
    local map,unit=Pagination.selected(ui)
    local xp=item.pos0 or item.page
    if not map or type(xp)~='string' then return end
    local ok,label=pcall(map.getXPointerPageLabel,map,xp,true)
    if ok and type(label)=='string' and label~='' then return label,unit end
end
return Pagination
