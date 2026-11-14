-- Small math and table helpers shared everywhere.
local util = {}

function util.clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

function util.lerp(a, b, t) return a + (b - a) * t end

function util.round(v) return math.floor(v + 0.5) end

function util.len(x, y) return math.sqrt(x * x + y * y) end

function util.normalize(x, y)
    local l = math.sqrt(x * x + y * y)
    if l == 0 then return 0, 0, 0 end
    return x / l, y / l, l
end

-- Frame-rate independent exponential smoothing factor.
function util.damp(rate, dt) return 1 - math.exp(-rate * dt) end

function util.angleDiff(a, b)
    local d = (b - a) % (math.pi * 2)
    if d > math.pi then d = d - math.pi * 2 end
    return d
end

function util.deepcopy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = util.deepcopy(x) end
    return t
end

-- Fill missing keys of `t` from `defaults`, recursing into nested plain tables.
function util.applyDefaults(t, defaults)
    for k, dv in pairs(defaults) do
        local v = t[k]
        if v == nil then
            t[k] = util.deepcopy(dv)
        elseif type(v) == "table" and type(dv) == "table" and getmetatable(v) == nil and #dv == 0 then
            util.applyDefaults(v, dv)
        end
    end
    return t
end

function util.contains(list, value)
    for i = 1, #list do if list[i] == value then return true end end
    return false
end

function util.indexOf(list, value)
    for i = 1, #list do if list[i] == value then return i end end
    return nil
end

-- Pick from `list` using weightFn(item) -> number.
function util.weightedPick(list, weightFn)
    local total = 0
    for i = 1, #list do total = total + math.max(0, weightFn(list[i])) end
    if total <= 0 then return nil end
    local r = love.math.random() * total
    for i = 1, #list do
        r = r - math.max(0, weightFn(list[i]))
        if r <= 0 then return list[i] end
    end
    return list[#list]
end

function util.hex(s, alpha)
    s = s:gsub("#", "")
    local r = tonumber(s:sub(1, 2), 16) / 255
    local g = tonumber(s:sub(3, 4), 16) / 255
    local b = tonumber(s:sub(5, 6), 16) / 255
    local a = alpha or 1
    if #s >= 8 then a = tonumber(s:sub(7, 8), 16) / 255 end
    return { r, g, b, a }
end

local function serializeValue(v, indent)
    local t = type(v)
    if t == "string" then return string.format("%q", v) end
    if t == "number" or t == "boolean" or t == "nil" then return tostring(v) end
    if t ~= "table" then error("cannot serialize " .. t) end
    local pad = string.rep("    ", indent + 1)
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local out = { "{\n" }
    for _, k in ipairs(keys) do
        local key = type(k) == "string" and string.format("[%q]", k) or "[" .. tostring(k) .. "]"
        out[#out + 1] = pad .. key .. " = " .. serializeValue(v[k], indent + 1) .. ",\n"
    end
    out[#out + 1] = string.rep("    ", indent) .. "}"
    return table.concat(out)
end

function util.serialize(v) return serializeValue(v, 0) end

function util.split(s, sep)
    local out = {}
    for part in s:gmatch("[^" .. (sep or "%s") .. "]+") do out[#out + 1] = part end
    return out
end

return util
