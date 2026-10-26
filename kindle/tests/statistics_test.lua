local Stats=dofile('kindle/todo.koplugin/statistics.lua')
local result=Stats.periods({
    {page=1,start=3590,duration=20,total_pages=100},
    {page=1,start=3620,duration=10,total_pages=100},
    {page=2,start=3630,duration=15,total_pages=100},
    {page=3,start=3640,duration=0,total_pages=100},
})
assert(#result==2 and result[1].start==0 and result[2].start==3600)
assert(result[1].seconds==10 and result[2].seconds==35,'Se reparten los segundos en los cambios de hora y año')
assert(result[1].pages==1 and result[2].pages==2,'Las relecturas en la misma hora no duplican páginas')
local Reading=dofile('kindle/todo.koplugin/reading.lua')
local queue=Reading.new({},'kindle-prueba',function(n) return 'prueba-estadisticas-'..n end)
local snapshot={document_id=string.rep('a',32),title='Prueba',author='Autora',observed_at=100,
    progress=.1,page='1',position='/p[1]',quotes={},statistics={origin='historial-prueba',book_id=1,periods=result}}
assert(queue:capture(snapshot))
local first=queue:next()
snapshot.statistics.periods[1].seconds=30
assert(queue:capture(snapshot),'Un cambio solo en el tiempo también genera un envío')
assert(first.statistics.periods[1].seconds==10 and queue:next()==first,'El reintento conserva los contadores originales')
assert(queue:receive(200,{savedLocally=true,request_id=first.request_id,library_item_id='prueba'}))
assert(queue:next().statistics.periods[1].seconds==30)
print('Estadísticas: horas, límites de fecha, páginas y reintentos persistentes verificados')
