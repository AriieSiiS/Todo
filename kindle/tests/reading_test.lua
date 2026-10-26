local Reading=dofile('kindle/todo.koplugin/reading.lua')
local counter=0
local function id() counter=counter+1; return 'lectura-prueba-'..counter end
local function snapshot(progress,note)
    return {document_id=string.rep('a',32),title='Circe',author='Madeline Miller',
        observed_at=100,progress=progress,page='42',position='/p[42]',
        quotes={{anchor='/p[5]',text='Una cita',note=note or '',page='5',chapter='Uno',created_at='2026-10-24'}}}
end
local state={}
local queue=Reading.new(state,'kindle-prueba',id)
assert(queue:capture(snapshot(.14)))
local first=queue:next()
assert(first.progress==.14 and #first.quotes==1)
queue:capture(snapshot(.2,'Nota nueva'))
assert(queue:next()==first,'No modificar un envío pendiente de confirmación')
queue=Reading.new(state,'kindle-prueba',id)
assert(queue:next().request_id==first.request_id,'Reutilizar el envío tras reiniciar')
assert(not queue:receive(200,{savedLocally=false}))
assert(queue:receive(200,{savedLocally=true,request_id=first.request_id,library_item_id='circe'}))
local second=queue:next()
assert(second.progress==.2 and second.quotes[1].note=='Nota nueva' and second.sequence>first.sequence)
assert(queue:receive(200,{savedLocally=true,request_id=second.request_id,library_item_id='circe'}))
assert(queue:next()==nil)
assert(not queue:capture(snapshot(.2,'Nota nueva')),'Abrir otra vez no cambia la fecha de lectura')
queue:capture(snapshot(.3,'Nota nueva'))
local blocked=queue:next()
queue:receive(200,{status='needs_link',books={{id='circe',title='Circe'}}})
assert(queue:next()==nil)
queue:link(string.rep('a',32),'circe')
assert(queue:next().request_id~=blocked.request_id)
assert(queue:next().library_item_id=='circe')
local many=snapshot(.4)
many.quotes={}
for i=1,45 do many.quotes[i]={anchor='/p['..i..']',text='Texto '..i,note='',page=tostring(i),chapter='',created_at=''} end
local q=Reading.new({},'kindle-prueba',id)
q:capture(many)
local count=0
while q:next() do
    local body=q:next(); assert(#body.quotes<=20)
    count=count+#body.quotes
    assert(q:receive(200,{savedLocally=true,request_id=body.request_id,library_item_id='circe'}))
end
assert(count==45)
print('Lectura: cola, reintentos, cambios durante envío, vínculos y lotes correctos')
