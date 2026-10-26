-- Exporta contadores acumulados sin modificar las estadísticas nativas.
local Stats={}

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
            local page=row.page..':'..row.total_pages
            if not bucket.seen[page] then bucket.seen[page]=true; bucket.pages=bucket.pages+1 end
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
        return {origin=origin,book_id=id,periods=Stats.periods(rows)}
    end)
    conn:close()
    assert(ok,result)
    return result
end

return Stats
