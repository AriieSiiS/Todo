local writes = 0
local peer = string.rep('a', 64)
local connected = false
package.loaded.socket = {tcp=function() return {
    settimeout=function() return 1 end, connect=function() connected=true; return 1 end, close=function() end,
} end}
package.loaded.ssl = {wrap=function()
    return {settimeout=function() return 1 end, sni=function() end, dohandshake=function() return 1 end,
        getpeercertificate=function() return {digest=function() return peer end} end,
        send=function() writes=writes+1; return 1 end, close=function() end}
end}
package.loaded['socket.http'] = {request=function(args)
    local conn = args.create()
    assert(conn:settimeout(3), 'LuaSocket exige confirmar el tiempo de espera antes de conectar')
    conn:connect('192.168.1.10', 47832)
    assert(conn:settimeout(3), 'El tiempo de espera debe propagarse al socket TLS conectado')
    conn:send('Authorization: Bearer privada')
    args.sink('{}')
    return 1, 200
end}
package.loaded.ltn12 = {source={string=function(value) return value end}}
package.loaded.json = {encode=function() return '{}' end, decode=function() return {} end}
local Transport = dofile('kindle/todo.koplugin/transport.lua')
local config = {addresses={'192.168.1.10'}, port=47832, token='privada', fingerprint=string.rep('b',64)}
local ok = pcall(Transport.request, config, 'GET', '/v1/kindle/agenda')
assert(not ok and writes == 0 and connected, 'No enviar la credencial si el certificado no coincide')
config.fingerprint = peer
local status = Transport.request(config, 'GET', '/v1/kindle/agenda')
assert(status == 200 and writes == 1, 'Enviar solamente después de validar el certificado')
package.loaded.json.util={InitArray=function(value) value.es_lista=true end}
package.loaded.json.encode=function(body)
    assert(body.quotes.es_lista and body.statistics.periods.es_lista,
        'Los envíos sin citas ni tiempos deben conservar listas JSON vacías tras recargar la cola')
    return '{}'
end
assert(Transport.request(config,'POST','/v1/kindle/reading',{quotes={},statistics={periods={}}})==200)
package.loaded.json.encode=function() return '{}' end
local now,attempts=100,0
package.loaded.socket.gettime=function() return now end
assert(Transport.deadline(1)==101)
package.loaded.socket.tcp=function() return {
    settimeout=function(_,value) assert(value<=1); return 1 end,
    connect=function() attempts=attempts+1; now=101; return 1 end,
    close=function() end,
} end
config.addresses={'192.168.1.10','192.168.1.11'}
local before=writes
assert(not pcall(Transport.request,config,'POST','/v1/kindle/reading',{},101))
assert(attempts==1 and writes==before,'El presupuesto total detiene el envío antes de probar otra dirección')
print('Certificado: pruebas superadas')
