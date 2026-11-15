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

-- Soft caps (a stat def's `soft = { knee, cap }`): up to the knee a point is a point; past it
-- each point counts for less and the value creeps toward the cap without reaching it
-- (hyperbolic stacking, so piling Dodge stays worth a bit without making you untouchable).
function Stats.soften(d, v)
    local s = d.soft
    if not s or v <= s[1] then return v end
    local room = s[2] - s[1]
    local over = v - s[1]
    return s[1] + room * over / (over + room)
end

-- The value a stat would have before its soft cap (for tooltips): base + adds, times mults.
function Stats:raw(stat)
    local add, mult = 0, 0
    for _, m in ipairs(self.mods) do
        if m.stat == stat then add, mult = add + m.add, mult + m.mult end
    end
    return (self.base[stat] + add) * (1 + mult)
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
        self.values[d.id] = Stats.soften(d, util.clamp(v, d.min or -math.huge, d.max or math.huge))
    end
    self.dirty = false
end

-- The values this block would have with extra modifiers on top ({ [stat] = add }, { [stat] = mult }),
-- without changing anything (item choice previews).
function Stats:peek(extraAdd, extraMult)
    local add, mult = {}, {}
    for _, m in ipairs(self.mods) do
        add[m.stat] = (add[m.stat] or 0) + m.add
        mult[m.stat] = (mult[m.stat] or 0) + m.mult
    end
    for id, v in pairs(extraAdd or {}) do add[id] = (add[id] or 0) + v end
    for id, v in pairs(extraMult or {}) do mult[id] = (mult[id] or 0) + v end
    local out = {}
    for _, d in ipairs(defs) do
        local v = (self.base[d.id] + (add[d.id] or 0)) * (1 + (mult[d.id] or 0))
        out[d.id] = Stats.soften(d, util.clamp(v, d.min or -math.huge, d.max or math.huge))
    end
    return out
end

-- What a stat's value means in plain numbers ("Takes 25% less damage from every hit"), from the
-- stat's `info` in src/config/stats.lua. Empty string if it has none.
function Stats.explain(stat, v)
    local d = Stats.byId[stat]
    if not d or not d.info then return "" end
    return d.info(v)
end

function Stats:get(stat)
    if self.dirty then self:recompute() end
    return self.values[stat]
end

function Stats.format(stat, v)
    local d = Stats.byId[stat]
    local s = (math.floor(v * 10 + 0.5) / 10)
    if s == math.floor(s) then s = math.floor(s) end
    return tostring(s) .. (d.percent and "%" or d.suffix or "")
end

return Stats
