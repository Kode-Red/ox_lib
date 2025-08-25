--[[
    https://github.com/communityox/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 KodeRed <https://github.com/Kode-Red>
]]

--- @alias SwitchMatch any|fun(val:any):boolean|"default"|any[]
--- @alias BreakFn     fun():nil
--- @class SwitchCase
--- @field match  SwitchMatch
--- @field action fun(breakFn:BreakFn, ...:any):any
--- @alias SwitchCases SwitchCase[]

local _cache = setmetatable({}, { __mode = "k" })
local t_unpack = table.unpack

--- compile once per cases to a fast dispatcher (kept local; not exported)
--- @param cases SwitchCases
--- @return fun(value:any, fallthrough:boolean|nil, ...:any):any
local function compile(cases)
    local map, preds, defaultIndex = {}, {}, nil
    local n = #cases

    for i = 1, n do
        local m = cases[i].match
        local mt = type(m)
        if m == "default" then
            defaultIndex = i
        elseif mt == "function" then
            preds[#preds + 1] = i
        elseif mt == "table" then
            for j = 1, #m do
                local v = m[j]
                if map[v] == nil then map[v] = i end
            end
        else
            if map[m] == nil then map[m] = i end
        end
    end

    return function(value, fallthrough, ...)
        local stop, res
        local function breakFn() stop = true end

        local i = map[value]
        if i == nil then
            for k = 1, #preds do
                local pi = preds[k]
                if cases[pi].match(value) then
                    i = pi; break
                end
            end
            if i == nil then i = defaultIndex end
        end
        if i == nil then return nil end

        if fallthrough then
            while i <= n do
                res = cases[i].action(breakFn, ...)
                if stop then break end
                i = i + 1
            end
            return res
        else
            return cases[i].action(breakFn, ...)
        end
    end
end

--- Switch API (value first, cases third).
--- Call as:
---   lib.switch(value, fallthrough, cases, ...)
---   lib.switch({ value, ... }, fallthrough, cases)
--- @generic R
--- @param valueOrArgs any|any[]          -- single value OR { value, arg1, arg2, ... }
--- @param fallthrough boolean|nil         -- true = allow fallthrough; false/nil = stop at first
--- @param cases SwitchCases
--- @param ... any
--- @return R|any
function lib.switch(valueOrArgs, fallthrough, cases, ...)
    local dispatch = _cache[cases]
    if not dispatch then
        dispatch = compile(cases)
        _cache[cases] = dispatch
    end

    if type(valueOrArgs) == "table" then
        local value = valueOrArgs[1]
        local argc = #valueOrArgs
        if argc > 1 then
            local packed, p = {}, 0
            for i = 2, argc do
                p = p + 1; packed[p] = valueOrArgs[i]
            end
            local extra = { ... }
            for i = 1, #extra do
                p = p + 1; packed[p] = extra[i]
            end
            return dispatch(value, fallthrough, t_unpack(packed))
        else
            return dispatch(value, fallthrough, ...)
        end
    else
        return dispatch(valueOrArgs, fallthrough, ...)
    end
end

return lib.switch
