
--
-- lua-Spore : <http://fperrad.github.com/lua-Spore/>
--

local assert = assert
local error = error
local require = require
local setmetatable = setmetatable
local tonumber = tonumber
local type = type
local tconcat = require 'table'.concat
local ltn12 = require 'ltn12'
local Request = require 'Spore.Request'


module 'Spore.Core'

local protocol = {
    http    = require 'socket.http',
    https   = require 'ssl.https',
}

function enable (self, mw, args)
    local checktype = require 'Spore'.checktype
    checktype('enable', 2, mw, 'string')
    args = args or {}
    checktype('enable', 3, args, 'table')
    if not mw:match'^Spore%.Middleware%.' then
        mw = 'Spore.Middleware.' .. mw
    end
    local m = require(mw)
    assert(type(m.call) == 'function', mw .. " without a function call")
    local f = function (req)
        return m.call(args, req)
    end
    local t = self.middlewares; t[#t+1] = f
end

function reset_middlewares (self)
    self.middlewares = {}
end

function raises (response, reason)
    error(setmetatable({ response = response, reason = reason },
        { __tostring = function (self) return self.reason end }))
end

function http_request (self, env)
    local req = Request.new(env)
    local callbacks = {}
    local response
    local middlewares = self.middlewares
    for i = 1, #middlewares do
        local mw = middlewares[i]
        local res = mw(req)
        if type(res) == 'function' then
            callbacks[#callbacks+1] = res
        elseif res then
            if res.status == 599 then
                return res
            end
            response = res
            break
        end
    end

    if response == nil then
        req:finalize()
        response = request(req)
    end

    for i = #callbacks, 1, -1 do
        local cb = callbacks[i]
        response = cb(response)
    end
    return response
end

function request (req)
    local t = {}
    req.sink = ltn12.sink.table(t)
    local spore = req.env.spore
    local payload = spore.payload
    if payload then
        req.source = ltn12.source.string(payload)
        req.headers['content-length'] = payload:len()
        req.headers['content-type'] = 'application/x-www-form-urlencoded'
    end
    local prot = protocol[spore.url_scheme]
    if spore.debug then
        spore.debug:write(req.method, " ", req.url, "\n")
    end
    local r, status, headers, line = prot.request(req)
    if spore.debug then
        spore.debug:write(line or status, "\n")
    end
    local res = {
        status = status,
        headers = headers,
        body = tconcat(t),
    }
    local expected = spore.expected
    if expected then
        local found = false
        for i = 1, #expected do
            if status == tonumber(expected[i]) then
                found = true
                break
            end
        end
        if not found then
            if spore.errors then
                spore.errors:write(req.method, " ", req.url, "\n")
                spore.errors:write(line or status, "\n")
            end
            raises(res, status .. ' not expected')
        end
    end
    return res
end

--
-- Copyright (c) 2010 Francois Perrad
--
-- This library is licensed under the terms of the MIT/X11 license,
-- like Lua itself.
--
