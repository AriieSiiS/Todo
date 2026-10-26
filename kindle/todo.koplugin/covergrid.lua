-- Añade el porcentaje al mosaico nativo únicamente en la vista de portadas de Todo.
local Grid={}

function Grid.percent(item)
    local progress,status=item.percent_finished,item.status
    if progress==nil and item.menu and item.menu.getBookInfo and item.filepath then
        local info=item.menu.getBookInfo(item.filepath)
        progress,status=info.percent_finished,info.status
    end
    if status=='complete' then return '100%' end
    progress=tonumber(progress) or 0
    if progress~=progress then progress=0 end
    return math.floor(math.max(0,math.min(1,progress))*100+0.5)..'%'
end

local function decorate(item)
    if item.todo_cover_badge then return end
    item.todo_cover_badge=true
    local paint,free=item.paintTo,item.free
    item.paintTo=function(self,bb,x,y)
        self.show_progress_bar=false; self.do_hint_opened=false; self.has_description=false
        paint(self,bb,x,y)
        local target=self[1][1][1]
        local text=Grid.percent(self)
        if self.todo_progress_text~=text then
            if self.todo_progress_badge then self.todo_progress_badge:free() end
            local screen=require('device').screen
            self.todo_progress_badge=require('ui/widget/container/framecontainer'):new{
                background=require('ffi/blitbuffer').COLOR_WHITE,
                color=require('ffi/blitbuffer').COLOR_BLACK,
                bordersize=screen:scaleBySize(1),padding=screen:scaleBySize(4),margin=0,
                require('ui/widget/textwidget'):new{text=text,bold=true,face=require('ui/font'):getFace('cfont',14)}}
            self.todo_progress_text=text
        end
        local badge=self.todo_progress_badge
        local margin=require('device').screen:scaleBySize(3)
        badge:paintTo(bb,target.dimen.x+target.dimen.w-badge:getSize().w-margin,target.dimen.y+margin)
    end
    item.free=function(self,...)
        if self.todo_progress_badge then self.todo_progress_badge:free(); self.todo_progress_badge=nil end
        return free(self,...)
    end
    item.show_progress_bar=false; item.do_hint_opened=false; item.has_description=false
end

function Grid.install()
    local Mosaic=require('mosaicmenu')
    if Mosaic.todo_cover_badges then return end
    local build=Mosaic._updateItemsBuildUI
    Mosaic._updateItemsBuildUI=function(menu,...)
        local result=build(menu,...)
        if menu.todo_cover_grid then
            for _,row in ipairs(menu.layout) do
                for _,item in ipairs(row) do decorate(item) end
            end
        end
        return result
    end
    Mosaic.todo_cover_badges=true
end

return Grid
