
--
-- lua-Spore : <http://fperrad.github.com/lua-Spore>
--

local assert = assert
local error = error
local pairs = pairs
local setmetatable = setmetatable
local tostring = tostring
local type = type
local unpack = require 'table'.unpack or unpack
local io = require 'io'
local json = require 'json.decode'
local url = require 'socket.url'
local core = require 'Spore.Core'
local slurp = require 'Spore.Protocols'.slurp


module 'Spore'

local version = '0.0.1'

function raises (response, reason)
    local ex = { response = response, reason = reason }
    local mt = { __tostring = function (self) return self.reason end }
    error(setmetatable(ex, mt))
end

function checktype (caller, narg, arg, tname)
    assert(type(arg) == tname, "bad argument #" .. tostring(narg) .. " to "
          .. caller .. " (" .. tname .. " expected, got " .. type(arg) .. ")")
end

local function wrap (self, name, method, args)
    args = args or {}
    checktype(name, 2, args, 'table')
    local params = {}
    for k, v in pairs(args) do
        if type(k) == 'number' then
            v = tostring(v)
            params[v] = v
        else
            params[tostring(k)] = v
        end
    end
    local payload = params.spore_payload or params.payload
    params.spore_payload = nil
    params.payload = nil
    if method.required_payload then
        assert(payload, "payload is required for method " .. name)
    end
    if payload then
        assert(method.required_payload or method.optional_payload, "payload is not expected for method " .. name)
    end

    local required_params = method.required_params or {}
    for i = 1, #required_params do
        local v = required_params[i]
        assert(params[v], v .. " is required for method " .. name)
    end

    if not method.unattended_params then
        local optional_params = method.optional_params or {}
        for param in pairs(params) do
            local found = false
            for i = 1, #required_params do
                if param == required_params[i] then
                    found = true
                    break
                end
            end
            if not found then
                for i = 1, #optional_params do
                    if param == optional_params[i] then
                        found = true
                        break
                    end
                end
            end
            assert(found, param .. " is not expected for method " .. name)
        end
    end

    local base_url = url.parse(method.base_url)
    local script = base_url.path
    if script == '/' then
        script = nil
    end

    local env = {
        REQUEST_METHOD  = method.method,
        SERVER_NAME     = base_url.host,
        SERVER_PORT     = base_url.port,
        SCRIPT_NAME     = script,
        PATH_INFO       = method.path,
        REQUEST_URI     = '',
        QUERY_STRING    = '',
        HTTP_USER_AGENT = 'lua-Spore v' .. version,
        spore = {
            caller          = name,
            expected        = method.expected_status,
            authentication  = method.authentication,
            params          = params,
            form_data       = method['form-data'],
            headers         = method.headers,
            payload         = payload,
            errors          = errors or io.stderr,
            debug           = debug,
            url_scheme      = base_url.scheme,
            format          = method.formats,
        },
        sporex = {},
    }
    if method.deprecated and debug then
        debug:write(name, " is deprecated\n")
    end
    return self:http_request(env)
end

local function new ()
    local obj = {
        middlewares = {}
    }
    local mt = {
        __index = core,
    }
    return setmetatable(obj, mt)
end

function new_from_string (...)
    local args = {...}
    local opts = {}
    local nb
    for i = 1, #args do
        local arg = args[i]
        if i > 1 and type(arg) == 'table' then
            opts = arg
            break
        end
        checktype('new_from_string', i, arg, 'string')
        nb = i
    end

    local obj = new()
    for i = 1, nb do
        local spec = json.decode(args[i])

        assert(spec.methods, "no method in spec")
        for k, v in pairs(spec.methods) do
            if type(methname_modifier) == 'function' then
                k = methname_modifier(k)
            end
            v.authentication = opts.authentication or v.authentication or spec.authentication
            v.base_url = opts.base_url or v.base_url or spec.base_url
            v.expected_status = opts.expected_status or v.expected_status or spec.expected_status
            v.formats = opts.formats or v.formats or spec.formats
            v.unattended_params = opts.unattended_params or v.unattended_params or spec.unattended_params
            assert(obj[k] == nil, k .. " duplicated")
            assert(v.method, k .. " without field method")
            assert(v.path, k .. " without field path")
            assert(type(v.expected_status or {}) == 'table', "expected_status of " .. k .. " is not an array")
            assert(type(v.required_params or {}) == 'table', "required_params of " .. k .. " is not an array")
            assert(type(v.optional_params or {}) == 'table', "optional_params of " .. k .. " is not an array")
            assert(type(v['form-data'] or {}) == 'table', "form-data of " .. k .. " is not an hash")
            assert(type(v.headers or {}) == 'table', "headers of " .. k .. " is not an hash")
            assert(v.base_url, k .. ": base_url is missing")
            local uri = url.parse(v.base_url)
            assert(uri.host, k .. ": base_url without host")
            assert(uri.scheme, k .. ": base_url without scheme")
            if v.required_payload or v.optional_payload then
                assert(not v['form-data'], "payload and form-data are exclusive")
            end
            obj[k] =  function (self, args)
                          return wrap(self, k, v, args)
                      end
        end
    end

    return obj
end

function new_from_spec (...)
    local args = {...}
    local opts = {}
    local t = {}
    for i = 1, #args do
        local arg = args[i]
        if i > 1 and type(arg) == 'table' then
            opts = arg
            break
        end
        checktype('new_from_spec', i, arg, 'string')
        t[#t+1] = slurp(arg)
    end
    t[#t+1] = opts
    return new_from_string(unpack(t))
end

_VERSION = version
_DESCRIPTION = "lua-Spore : a generic ReST client"
_COPYRIGHT = "Copyright (c) 2010 Francois Perrad"
--
-- This library is licensed under the terms of the MIT/X11 license,
-- like Lua itself.
--
