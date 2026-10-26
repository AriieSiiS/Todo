-- Mantiene el ámbito de la barra y del indicador sin cambiar los cálculos nativos.
local Footer={}
local managed={page_progress=true,percentage=true,book_time_to_read=true,chapter_time_to_read=true}

local function isChapter(footer,mode)
    if mode~='chapter_time_to_read' then return false end
    local toc=footer.ui.toc
    local count=toc and toc:getChapterPageCount(footer.pageno)
    return type(count)=='number' and count>0
        and toc:getChapterPagesLeft(footer.pageno,true)~=nil
end

function Footer.install(footer)
    if not footer or footer.todo_scoped_progress then return false end
    local apply=footer.applyFooterMode
    local update=footer.onUpdateFooter
    footer.applyFooterMode=function(self,...)
        apply(self,...)
        local mode=self.mode_index[self.mode]
        if self.settings.all_at_once or not managed[mode] then return end
        local native=self.genFooterText
        self.genFooterText=function(value)
            local text=native(value)
            local duration=mode=='book_time_to_read' or mode=='chapter_time_to_read'
            local compact=value.settings.item_prefix=='compact_items'
            if mode~='page_progress' and not (compact and mode~='chapter_time_to_read') then
                text=text:gsub('^%S+%s+','',1)
            end
            local scope=isChapter(value,mode) and 'Capítulo' or 'Libro'
            return scope..' · '..(duration and 'faltan ' or '')..text
        end
    end
    footer.onUpdateFooter=function(self,...)
        local mode=self.mode_index[self.mode]
        if type(self.pageno)=='number' and not self.settings.all_at_once and managed[mode] then
            local chapter=isChapter(self,mode)
            if self.settings.chapter_progress_bar~=chapter then
                self.settings.chapter_progress_bar=chapter
                self:setTocMarkers(true)
            end
        end
        return update(self,...)
    end
    footer.todo_scoped_progress=true
    footer:applyFooterMode()
    return true
end

return Footer
