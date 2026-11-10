-- Exporta contadores acumulados sin modificar las estadísticas nativas.
local Stats={}
local Pagination=dofile(debug.getinfo(1,'S').source:match('^@(.*/)')..'pagination.lua')

-- Sitúa el historial antiguo como la vista page_stat de KOReader y usa el mapa.
function Stats.mapRows(rows,map,screens)
    assert(type(screens)=='number' and screens>0 and #map>0)
    local result={}
    local function lower(page)
        local lo,hi=1,#map+1
        while lo<hi do
            local mid=math.floor((lo+hi)/2)
            if map[mid].page<page then lo=mid+1 else hi=mid end
        end
        return lo
    end
    for _,row in ipairs(rows) do
        local first=math.floor((row.page-1)*screens/row.total_pages)+1
        local last=math.max(first,math.floor(row.page*screens/row.total_pages))
        local start=lower(first)
        if start>1 and (not map[start] or map[start].page>first) then start=start-1 end
        local finish=lower(last+1)-1
        local ids={}
        for index=start,finish do ids[#ids+1]=index end
        result[#result+1]={page=row.page,start=row.start,duration=row.duration,
            total_pages=row.total_pages,page_ids=ids}
    end
    return result
end

function Stats.periods(rows)
    local buckets,seen={},{ }
    for _,row in ipairs(rows) do
        local key=row.page..':'..row.start..':'..row.total_pages
        local previous=seen[key]
        if not previous or row.duration>previous.duration then seen[key]=row end
    end
    for _,row in pairs(seen) do
        local start,left=row.start,row.duration
        while left>0 do
            local hour=math.floor(start/3600)*3600
            local seconds=math.min(left,hour+3600-start)
            local bucket=buckets[hour] or {start=hour,seconds=0,pages=0,seen={}}
            buckets[hour]=bucket
            bucket.seconds=bucket.seconds+seconds
            local ids=row.page_ids or {row.page..':'..row.total_pages}
            for _,page in ipairs(ids) do
                if not bucket.seen[page] then bucket.seen[page]=true; bucket.pages=bucket.pages+1 end
            end
            start=start+seconds; left=left-seconds
        end
    end
    local result={}
    for _,bucket in pairs(buckets) do bucket.seen=nil; result[#result+1]=bucket end
    table.sort(result,function(a,b) return a.start<b.start end)
    assert(#result<=12000,'El historial de lectura supera el tamaño admitido.')
    return result
end

function Stats.capture(ui,origin)
    local native=ui.statistics
    if not native or not native.settings or not native.settings.is_enabled or not native.id_curr_book then return end
    local id=assert(tonumber(native.id_curr_book))
    local path=require('datastorage'):getSettingsDir()..'/statistics.sqlite3'
    local conn=require('lua-ljsqlite3/init').open(path)
    local ok,result=pcall(function()
        conn:exec('PRAGMA query_only=ON;')
        local stmt=conn:prepare('SELECT page,start_time,duration,total_pages FROM page_stat_data WHERE id_book=?;')
        local data,count=stmt:bind(id):resultset('i')
        stmt:close()
        local rows={}
        for i=1,count do rows[#rows+1]={page=tonumber(data[1][i]),start=tonumber(data[2][i]),duration=tonumber(data[3][i]),total_pages=tonumber(data[4][i])} end
        local now=native._reading_paused_ts or os.time()
        for page,values in pairs(native.page_stat or {}) do
            for _,value in ipairs(values) do
                local duration=value[2]
                if duration==0 and page==native.curr_page then
                    local elapsed=now-value[1]
                    if elapsed>=native.settings.min_sec then duration=math.min(elapsed,native.settings.max_sec) end
                end
                if duration>0 then rows[#rows+1]={page=page,start=value[1],duration=duration,total_pages=native.data.pages} end
            end
        end
        local _,unit=Pagination.selected(ui)
        if unit then rows=Stats.mapRows(rows,ui.document:getPageMap(),native.data.pages) end
        return {origin=origin,book_id=id,page_unit=unit or (ui.document.info.has_pages and 'page' or 'screen'),periods=Stats.periods(rows)}
    end)
    conn:close()
    assert(ok,result)
    return result
end

return Stats
