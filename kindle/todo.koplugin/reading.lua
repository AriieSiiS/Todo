local Reading={}
Reading.__index=Reading
local function copy(value)
    if type(value)~='table' then return value end
    local result={}; for k,v in pairs(value) do result[k]=copy(v) end; return result
end
-- Orden estable para posiciones PDF y comparación, sin depender del orden JSON.
local function signature(value)
    if type(value)~='table' then return string.format('%q',tostring(value)) end
    local keys={}; for k in pairs(value) do keys[#keys+1]=k end
    table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
    local result={}
    for _,k in ipairs(keys) do result[#result+1]=signature(k)..':'..signature(value[k]) end
    return '{'..table.concat(result,',')..'}'
end
function Reading.new(state,source,id)
    state.books=state.books or {}; state.sequence=state.sequence or 0
    return setmetatable({state=state,source=source,id=id},Reading)
end
function Reading:capture(snapshot)
    local key=snapshot.document_id
    local book=self.state.books[key] or {ack_quotes={}}
    self.state.books[key]=book
    local compared=copy(snapshot); compared.observed_at=nil
    local hash=signature(compared)
    if book.signature==hash then return false end
    book.latest=copy(snapshot); book.signature=hash
    return true
end
function Reading:next()
    if self.state.sealed then return self.state.sealed.body end
    local keys={}; for k in pairs(self.state.books) do keys[#keys+1]=k end; table.sort(keys)
    for _,key in ipairs(keys) do
        local book=self.state.books[key]
        if not book.needs_link then
            local quotes,hashes,bytes={},{},0
            for _,quote in ipairs(book.latest.quotes) do
                local hash=signature(quote)
                local size=#quote.anchor+#quote.text+#quote.note+#quote.page+#quote.chapter+#quote.created_at
                if book.ack_quotes[quote.anchor]~=hash and #quotes<20 and (bytes+size<=60000 or #quotes==0) then
                    quotes[#quotes+1]=copy(quote); hashes[quote.anchor]=hash
                    bytes=bytes+size
                end
            end
            if #quotes>0 or book.ack_signature~=book.signature then
                self.state.sequence=self.state.sequence+1
                local body=copy(book.latest)
                body.quotes=quotes; body.source_id=self.source; body.sequence=self.state.sequence
                body.request_id=self.id(self.state.sequence); body.library_item_id=book.library_item_id
                self.state.sealed={body=body,signature=book.signature,quote_hashes=hashes}
                return body
            end
        end
    end
end
function Reading:receive(status,result)
    local sealed=self.state.sealed
    if not sealed then return false end
    local book=self.state.books[sealed.body.document_id]
    if status==200 and result.status=='needs_link' then
        book.needs_link=true; book.candidates=result.books or {}; self.state.sealed=nil
    elseif status==200 and result.savedLocally==true and result.request_id==sealed.body.request_id then
        book.library_item_id=result.library_item_id; book.ack_signature=sealed.signature
        for k,v in pairs(sealed.quote_hashes) do book.ack_quotes[k]=v end
        self.state.sealed=nil
        return true
    end
    return false
end
function Reading:link(document,target)
    local book=assert(self.state.books[document],'Abre primero el libro.')
    assert(not self.state.sealed or self.state.sealed.body.document_id~=document,
        'Sincroniza primero el envío pendiente de confirmación.')
    book.library_item_id=target; book.needs_link=nil; book.candidates=nil; book.ack_signature=nil
end
function Reading.snapshot(ui,now,statistics)
    if not ui.document or not ui.doc_settings then return end
    local document=ui.doc_settings:readSetting('partial_md5_checksum')
    local props=ui.doc_props or {}
    local title=props.title or props.display_title
    if not document or not title or title=='' then return end
    local reader=ui.document.info.has_pages and ui.paging or ui.rolling
    if not reader then return end
    local progress=reader:getLastPercent()
    if type(progress)~='number' or progress~=progress then return end
    local position=tostring(reader:getLastProgress() or '')
    local page=ui.view and ui.view.state and ui.view.state.page
    local chapter=''
    if page and ui.toc and ui.toc.getTocTitleByPage then
        local ok,title=pcall(ui.toc.getTocTitleByPage,ui.toc,page)
        if ok and type(title)=='string' then chapter=title end
    end
    local total=ui.document.getPageCount and ui.document:getPageCount() or ui.doc_settings:readSetting('doc_pages')
    if type(total)~='number' then total=0 end
    local quotes={}
    for _,item in ipairs(ui.annotation and ui.annotation.annotations or {}) do
        if item.drawer and type(item.text)=='string' and item.text:match('%S') and not item.is_tmp then
            quotes[#quotes+1]={anchor=signature({start=item.pos0 or item.page,finish=item.pos1}),
                text=item.text,note=item.note or '',page=tostring(item.pageref or item.pageno or ''),
                chapter=item.chapter or '',created_at=item.datetime or ''}
        end
    end
    return {document_id=document,title=title,author=props.authors or '',observed_at=now,statistics=statistics,
        progress=math.max(0,math.min(1,progress)),page=tostring(page or ''),total_pages=math.floor(total),position=position,chapter=chapter,quotes=quotes}
end
return Reading
