-- Loads, saves and validates settings described by src/config/settings_schema.lua.
local util = require("src.core.util")
local schema = require("src.config.settings_schema")

local Settings = { schema = schema, byKey = {}, values = {}, listeners = {} }
local FILE = "settings.lua"
-- Bump when a default changes and old saves should pick up the new one. Keys listed under a
-- version are reset to their default when loading a save older than that version.
local VERSION = 2
local RESET_AT = {
    [2] = { "levelUpWhen" },   -- 2026-11-26: level-up cards wait for the wave's end by default
}

for _, s in ipairs(schema) do Settings.byKey[s.key] = s end

local function valid(s, v)
    if s.type == "toggle" then return type(v) == "boolean" end
    if s.type == "slider" then return type(v) == "number" end
    if s.type == "choice" then
        for _, o in ipairs(s.options) do if o.value == v then return true end end
        return false
    end
    return true
end

function Settings.defaults()
    local t = { binds = {}, version = VERSION }
    for k, s in pairs(Settings.byKey) do t[k] = util.deepcopy(s.default) end
    return t
end

function Settings.load()
    Settings.values = Settings.defaults()
    if not love.filesystem.getInfo(FILE) then return end
    local ok, chunk = pcall(love.filesystem.load, FILE)
    if not ok or not chunk then return end
    local ok2, data = pcall(chunk)
    if not ok2 or type(data) ~= "table" then return end
    local old = tonumber(data.version) or 1
    for ver = old + 1, VERSION do
        for _, k in ipairs(RESET_AT[ver] or {}) do data[k] = nil end
    end
    for k, v in pairs(data) do
        local s = Settings.byKey[k]
        if s and valid(s, v) then
            if s.type == "slider" then v = util.clamp(v, s.min, s.max) end
            Settings.values[k] = v
        elseif k == "binds" and type(v) == "table" then
            Settings.values.binds = v
        end
    end
end

function Settings.save()
    love.filesystem.write(FILE, "return " .. util.serialize(Settings.values) .. "\n")
end

function Settings.get(key) return Settings.values[key] end

function Settings.set(key, value)
    if Settings.values[key] == value then return end
    Settings.values[key] = value
    for _, fn in ipairs(Settings.listeners) do fn(key, value) end
end

function Settings.onChange(fn) Settings.listeners[#Settings.listeners + 1] = fn end

function Settings.resetCategory(category)
    for k, s in pairs(Settings.byKey) do
        if s.category == category then Settings.set(k, util.deepcopy(s.default)) end
    end
    if category == "Controls" then
        Settings.values.binds = {}
        for _, fn in ipairs(Settings.listeners) do fn("binds", Settings.values.binds) end
    end
end

-- Display string for a setting's current value.
function Settings.display(key)
    local s, v = Settings.byKey[key], Settings.values[key]
    if s.type == "toggle" then return v and "On" or "Off" end
    if s.type == "slider" then return s.format and s.format(v) or tostring(v) end
    if s.type == "choice" then
        for _, o in ipairs(s.options) do if o.value == v then return o.label end end
    end
    return tostring(v)
end

return Settings
