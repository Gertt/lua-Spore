
--
-- lua-Spore : <http://fperrad.github.com/lua-Spore>
--

local assert = assert
local pairs = pairs
local setmetatable = setmetatable
local tostring = tostring
local type = type
local io = require 'io'
local json = require 'json.decode'
local url = require 'socket.url'
local core = require 'Spore.Core'


module 'Spore'

local version = '0.0.1'

local function wrap (self, name, method, args)
    local params = {}
    for k, v in pairs(args) do
        v = tostring(v)
        if type(k) == 'number' then
            params[v] = v
        else
            params[tostring(k)] = v
        end
    end
    local payload = params.spore_payload or params.payload
    params.spore_payload = nil
    params.payload = nil
    local required = method.required or {}
    for i = 1, #required do
        local v = required[i]
        assert(params[v], v .. " is required for method " .. name)
    end

    local authentication = method.authentication or self.authentication
    local format = method.format or self.api_format
    local api_base_url = url.parse(method.base_url or self.api_base_url)
    local script = api_base_url.path
    if script == '/' then
        script = nil
    end

    local env = {
        REQUEST_METHOD  = method.method,
        SERVER_NAME     = api_base_url.host,
        SERVER_PORT     = api_base_url.port,
        SCRIPT_NAME     = script,
        PATH_INFO       = method.path,
        REQUEST_URI     = '',
        QUERY_STRING    = '',
        HTTP_USER_AGENT = 'lua-Spore v' .. version,
        spore = {
            expected        = method.expected or {},
            authentication  = authentication,
            params          = params,
            payload         = payload,
            errors          = io.stderr,
            url_scheme      = api_base_url.scheme or 'http',
            format          = format,
        },
    }
    return self:http_request(env)
end

function new_from_string (str, args)
    local args = args or {}
    local spec = json.decode(str)

    args.api_base_url = args.api_base_url or spec.api_base_url
    assert(args.api_base_url, "api_base_url is missing!")
    if spec.api_format then
        args.api_format = spec.api_format
    end
    if spec.authentication then
        args.authentication = spec.authentication
    end

    local obj = {
        middlewares = {}
    }
    for k, v in pairs(args) do
        obj[k] = v
    end
    assert(spec.methods, "no method in spec")
    for k, v in pairs(spec.methods) do
        assert(not obj[k], "Duplicated method " .. k)
        assert(v.method, k .. " without field method")
        assert(v.path, k .. " without field path")
        obj[k] =  function (self, args)
                      return wrap(self, k, v, args)
                  end
    end
    return setmetatable(obj, {
        __index = core,
    })
end

function new_from_spec (fname, args)
    local f, msg = io.open(fname)
    assert(f, msg)
    local content = f:read '*a'
    f:close()
    return new_from_string(content, args)
end

_VERSION = version
_DESCRIPTION = "lua-Spore : a generic ReST client"
_COPYRIGHT = "Copyright (c) 2010 Francois Perrad"
--
-- This library is licensed under the terms of the MIT/X11 license,
-- like Lua itself.
--