-- Permite mostrar u ocultar el porcentaje total junto a los indicadores nativos.
local Footer={}
local Pagination=dofile(debug.getinfo(1,'S').source:match('^@(.*/)')..'pagination.lua')
local managed={off=true,page_progress=true,percentage=true,book_time_to_read=true,chapter_time_to_read=true}

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
    local menu=footer.addToMainMenu
    if menu then
        footer.addToMainMenu=function(self,items)
            menu(self,items)
            table.insert(items.status_bar.sub_item_table,1,{
                text='Mostrar porcentaje del libro',
                checked_func=function() return G_reader_settings:nilOrTrue('todo_reading_percentage') end,
                callback=function()
                    G_reader_settings:saveSetting('todo_reading_percentage',
                        not G_reader_settings:nilOrTrue('todo_reading_percentage'))
                    G_reader_settings:flush()
                    self:applyFooterMode()
                    self:onUpdateFooter(true,true)
                end,
            })
        end
    end
    footer.applyFooterMode=function(self,requested,...)
        self.settings.percentage=false
        local selected=requested==nil and self.mode or requested
        local only_bar=self.mode_index[selected]=='off'
        local saved_mode=selected
        if self.mode_index[selected]=='percentage' or self.mode_index[selected]=='off' then
            for index,name in pairs(self.mode_index) do
                if name=='page_progress' then selected=index; break end
            end
        end
        apply(self,selected,...)
        if only_bar then
            self.mode=saved_mode
            self.genFooterText=function() return '' end
            return
        end
        local mode=self.mode_index[self.mode]
        local native=self.genFooterText
        self.genFooterText=function(value)
            local text=native(value)
            local _,unit=Pagination.selected(value.ui)
            if mode=='page_progress' and unit=='estimated_page' then text='≈ '..text end
            if not value.settings.all_at_once and managed[mode] then
                local duration=mode=='book_time_to_read' or mode=='chapter_time_to_read'
                local compact=value.settings.item_prefix=='compact_items'
                if mode~='page_progress' and not (compact and mode~='chapter_time_to_read') then
                    text=text:gsub('^%S+%s+','',1)
                end
                text=(isChapter(value,mode) and 'Capítulo · ' or '')..(duration and 'faltan ' or '')..text
            end
            if not G_reader_settings:nilOrTrue('todo_reading_percentage') then return text end
            local digits=math.max(0,math.min(2,tonumber(value.settings.progress_pct_format) or 0))
            local percent=string.format('%.'..digits..'f%%',math.max(0,math.min(1,value.percent_finished or 0))*100)
            return percent..(text~='' and ' · '..text or '')
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
    footer.settings.percentage=false
    if footer.settings.all_at_once and footer.updateFooterTextGenerator then footer:updateFooterTextGenerator() end
    footer:applyFooterMode()
    return true
end

return Footer
