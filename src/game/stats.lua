-- Stat block: base values plus modifiers from named sources (an item, a buff, a level-up).
-- final = (base + sum(add)) * (1 + sum(mult)), clamped to the stat's min/max.
local defs = require("src.config.stats")
local util = require("src.core.util")

local Stats = { defs = defs, byId = {} }
Stats.__index = Stats
for _, d in ipairs(defs) do Stats.byId[d.id] = d end

function Stats.new(overrides)
    local self = setmetatable({ base = {}, mods = {}, values = {}, dirty = true }, Stats)
    for _, d in ipairs(defs) do self.base[d.id] = d.default end
    for id, v in pairs(overrides or {}) do
        if not Stats.byId[id] then error("unknown stat '" .. id .. "'") end
        self.base[id] = v
    end
    return self
end

function Stats:addModifier(source, stat, add, mult)
    if not Stats.byId[stat] then error("unknown stat '" .. tostring(stat) .. "'") end
    self.mods[#self.mods + 1] = { source = source, stat = stat, add = add or 0, mult = mult or 0 }
    self.dirty = true
end

function Stats:removeSource(source)
    for i = #self.mods, 1, -1 do
        if self.mods[i].source == source then table.remove(self.mods, i) end
    end
    self.dirty = true
end

function Stats:setBase(stat, v)
    self.base[stat] = v
    self.dirty = true
end

function Stats:recompute()
    local add, mult = {}, {}
    for _, m in ipairs(self.mods) do
        add[m.stat] = (add[m.stat] or 0) + m.add
        mult[m.stat] = (mult[m.stat] or 0) + m.mult
    end
    for _, d in ipairs(defs) do
        local v = (self.base[d.id] + (add[d.id] or 0)) * (1 + (mult[d.id] or 0))
        self.values[d.id] = util.clamp(v, d.min or -math.huge, d.max or math.huge)
    end
    self.dirty = false
end

function Stats:get(stat)
    if self.dirty then self:recompute() end
    return self.values[stat]
end

function Stats.format(stat, v)
    local d = Stats.byId[stat]
    local s = (math.floor(v * 10 + 0.5) / 10)
    if s == math.floor(s) then s = math.floor(s) end
    return tostring(s) .. (d.percent and "%" or "")
end

return Stats
