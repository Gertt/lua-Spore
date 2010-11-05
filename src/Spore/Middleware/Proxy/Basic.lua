--
-- lua-Spore : <http://fperrad.github.com/lua-Spore/>
--

local assert = assert
local os = require 'os'
local mime = require 'mime'
local url = require 'socket.url'


module 'Spore.Middleware.Proxy.Basic'

local function _env_proxy (scheme)
    local name = scheme:upper() .. '_PROXY'
    local v = os.getenv(name)
    assert(v, "no " .. name)
    local proxy = url.parse(v)
    return {
        proxy = url.build{
            scheme  = proxy.scheme,
            host    = proxy.host,
            port    = proxy.port,
        },
        userinfo    = proxy.userinfo,
    }
end

local cache = {}
local function env_proxy (scheme)
    local r = cache[scheme]
    if r then
        return r
    end
    r = _env_proxy(scheme)
    cache[scheme] = r
    return r
end

function call (self, req)
    local env = req.env
    if not self.proxy then
        self = env_proxy(env.spore.url_scheme)
    end
    req.headers['host'] = env.SERVER_NAME

    local proxy = url.parse(self.proxy)
    env.SERVER_NAME = proxy.host
    env.SERVER_PORT = proxy.port

    local userinfo
    if self.userinfo then
        userinfo = self.userinfo
    elseif self.username and self.password then
        userinfo = self.username .. ':' .. self.password
    end
    if userinfo then
        req.headers['proxy-authorization'] = 'Basic ' .. mime.b64(userinfo)
    end
end

--
-- Copyright (c) 2010 Francois Perrad
--
-- This library is licensed under the terms of the MIT/X11 license,
-- like Lua itself.
--
