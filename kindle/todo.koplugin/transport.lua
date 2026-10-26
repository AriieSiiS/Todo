-- HTTPS con el certificado exacto aprovisionado por USB, antes de enviar el token.
local socket = require('socket')
local ssl = require('ssl')
local http = require('socket.http')
local ltn12 = require('ltn12')
local json = require('json')
local Transport = {}

local function normalize(value) return (value or ''):lower():gsub(':', '') end

function Transport.request(config, method, path, body, deadline)
    assert(type(config.token) == 'string' and config.token:match('^[A-Za-z0-9_%-]+$'),
        'La credencial no es válida. Vuelve a preparar la conexión por USB.')
    assert(type(config.fingerprint) == 'string' and #normalize(config.fingerprint) == 64,
        'Falta el certificado del PC.')
    assert(path:match('^/v1/kindle/[%w_/?=%.%-]+$'), 'La dirección no es válida.')
    -- LuaJSON necesita marcar explícitamente las listas vacías tras recargarlas.
    if body and body.quotes and json.util then json.util.InitArray(body.quotes) end
    if body and body.statistics and json.util then json.util.InitArray(body.statistics.periods) end
    local encoded = body and json.encode(body) or ''
    local last_error = 'El PC no está disponible en esta red.'
    local addresses = {}
    if Transport.last_address then table.insert(addresses, Transport.last_address) end
    for _, address in ipairs(config.addresses or {}) do
        if address ~= Transport.last_address then table.insert(addresses, address) end
    end
    for _, address in ipairs(addresses) do
        assert(type(address) == 'string' and address:match('^%d+%.%d+%.%d+%.%d+$'),
            'La dirección del PC no es válida.')
        local connection
        local function timeout()
            local remaining=deadline and deadline-socket.gettime() or 3
            assert(remaining>0,'Se agotó el tiempo de envío; se conserva la lectura.')
            return math.min(3,remaining)
        end
        local chunks, length = {}, 0
        local ok, code, result = pcall(function()
            local function create()
                local conn = {}
                connection = conn
                function conn:settimeout()
                    if self.sock then return self.sock:settimeout(timeout()) end
                    return 1
                end
                function conn:connect()
                    self.sock = assert(socket.tcp())
                    self.sock:settimeout(timeout())
                    assert(self.sock:connect(address, config.port or 47832))
                    -- La confianza es la huella exacta, no las CA globales del Kindle.
                    self.sock = assert(ssl.wrap(self.sock, {mode='client', protocol='tlsv1_2', verify='none'}))
                    self.sock:settimeout(timeout())
                    assert(self.sock:dohandshake())
                    local certificate = assert(self.sock:getpeercertificate())
                    assert(normalize(certificate:digest('sha256')) == normalize(config.fingerprint),
                        'El certificado del PC no coincide. No se ha enviado la credencial.')
                    return 1
                end
                function conn:send(...) self.sock:settimeout(timeout()); return self.sock:send(...) end
                function conn:receive(...) self.sock:settimeout(timeout()); return self.sock:receive(...) end
                function conn:getfd(...) return self.sock:getfd(...) end
                function conn:dirty(...) return self.sock:dirty(...) end
                function conn:close() if self.sock then self.sock:close() end end
                return conn
            end
            -- LuaSocket gestiona HTTP dentro del socket TLS creado arriba.
            local sent, status = http.request{
                url='http://' .. address .. ':' .. (config.port or 47832) .. path,
                method=method, create=create, redirect=false,
                headers={['Authorization']='Bearer ' .. config.token,
                    ['Content-Type']='application/json', ['Content-Length']=tostring(#encoded),
                    ['Connection']='close'},
                source=body and ltn12.source.string(encoded) or nil,
                sink=function(chunk)
                    if chunk then
                        length = length + #chunk
                        assert(length <= 2 * 1024 * 1024, 'La agenda es demasiado grande.')
                        chunks[#chunks+1] = chunk
                    end
                    return 1
                end,
            }
            assert(sent and tonumber(status), 'No se ha recibido confirmación del PC.')
            return tonumber(status), json.decode(table.concat(chunks))
        end)
        if connection then connection:close() end
        if ok then Transport.last_address=address; return code, result end
        if tostring(code):find('certificado') then error(code) end
        if deadline and socket.gettime()>=deadline then break end
        last_error = 'Sin conexión con el PC. Se conservan la agenda y las marcas pendientes.'
    end
    error(last_error)
end

function Transport.deadline(seconds) return socket.gettime()+seconds end

return Transport
