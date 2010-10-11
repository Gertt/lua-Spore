--
-- lua-Spore : <http://fperrad.github.com/lua-Spore/>
--

local pcall = pcall
local raises = require 'Spore.Core'.raises
require 'yaml'
local yaml = yaml


module 'Spore.Middleware.Format.YAML'

function call (self, req)
    local spore = req.env.spore
    if spore.payload then
        spore.payload = yaml.dump(spore.payload)
        req.headers['content-type'] = 'text/x-yaml' 
    end
    req.headers['accept'] = 'text/x-yaml'
    return  function (res)
                if res.body then
                    local r, msg = pcall(function ()
                        res.body = yaml.load(res.body)
                    end)
                    if not r then
                        if spore.errors then
                            spore.errors:write(msg)
                            spore.errors:write(res.body, "\n")
                        end
                        raises(res, msg)
                    end
                end
                return res
            end
end

--
-- Copyright (c) 2010 Francois Perrad
--
-- This library is licensed under the terms of the MIT/X11 license,
-- like Lua itself.
--
