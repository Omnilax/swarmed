-- Run stats: what happened in this run, for the HUD, the death recap and the run summary.
--
-- Every World has one (world.stats_ / RunStats.of(world)). It tracks:
--   dealt[label]      damage the player dealt, by source (an item, an attack, a dash...)
--   kills[enemyId]    kills by species
--   waves[n]          { dealt, taken, kills, time } per wave
--   hits              the last RunStats.HITS hits the player took ({ name, amount, wave, time })
--   killer            the hit that finished the player (same shape), once they fall
--   seen[enemyId]     species met this run (for the first-meeting popup)
--
-- Damage sources: Combat.damage asks RunStats.label(world) who is hitting. That is, in order,
-- opts.source, world.dmgSrc (set while an item proc, a held attack, a dash or something they
-- left behind runs), the move the player is firing right now (player.curMove), else "Other".
-- Things that hurt later (projectiles, pools, thrown ants, poison) remember the label they
-- were made under: RunStats.tag(world, obj) when made, RunStats.enter(world, obj) / leave when
-- they hit. Content can name its own source with `source = "..."` in Combat opts.
local util = require("src.core.util")

local RunStats = {}
RunStats.__index = RunStats

RunStats.HITS = 5

-- How plain-string hurt sources read in the recap (Player:hurt(amount, "acid") etc).
RunStats.SOURCE_NAMES = {
    acid = "Acid spit", pebble = "Thrown pebble", zone = "Puddle", venom = "Venom",
    test = "Test", sandbox = "Sandbox",
}

function RunStats.new(world)
    local self = setmetatable({ world = world, dealt = {}, kills = {}, waves = {}, hits = {},
        seen = {}, totalDealt = 0, totalTaken = 0 }, RunStats)
    local ev = world.events
    ev:on("enemy_died", function(e)
        local id = e.def.id
        self.kills[id] = (self.kills[id] or 0) + 1
        local w = self:wave()
        if w then w.kills = w.kills + 1 end
    end)
    ev:on("player_hurt", function(ctx) self:hurt(ctx) end)
    ev:on("player_died", function(ctx) self.killer = self.hits[#self.hits] end)
    ev:on("wave_cleared", function(n)
        local w = self.waves[n]
        if w then w.time = world.time - (w.start or world.time) end
    end)
    return self
end

-- The entry for the wave going on (nil before wave 1).
function RunStats:wave()
    local sp = self.world.spawner
    local n = sp and sp.wave or 0
    if n <= 0 then return nil end
    local w = self.waves[n]
    if not w then
        w = { dealt = 0, taken = 0, kills = 0, start = self.world.time }
        self.waves[n] = w
    end
    return w
end

-- Display name of an enemy ("Aggressive Green Ant", "Crowned Fire Ant Queen").
function RunStats.enemyName(e)
    if type(e) ~= "table" or not e.def then return nil end
    if e.title then return e.title end
    if e.elite then return e.elite.name .. " " .. e.def.name end
    return e.def.name
end

-- Who hurt the player, as text. Hazards set world.hitBy to the enemy that made them.
function RunStats.hurtName(world, source, p)
    local n = RunStats.enemyName(source)
    if n then return n end
    local by = world.hitBy
    if source == "venom" then by = p and p.venomBy or by end
    local base = type(source) == "string" and (RunStats.SOURCE_NAMES[source] or util.titleCase and util.titleCase(source) or source) or "Something"
    if by then return base .. " (" .. by .. ")" end
    return base
end

function RunStats:hurt(ctx)
    local world = self.world
    local d = ctx.damage or 0
    -- a killing blow counts only the health that was left (not 99999)
    if ctx.player then d = math.min(d, math.max(0, ctx.player.hp + d)) end
    self.totalTaken = self.totalTaken + d
    local w = self:wave()
    if w then w.taken = w.taken + d end
    local name = RunStats.hurtName(world, ctx.source, ctx.player)
    world.hitBy = nil
    -- bites from the same kind of ant in quick succession fold into one line ("x4")
    local last = self.hits[#self.hits]
    if last and last.name == name and world.time - last.time < 0.6 then
        last.amount, last.count, last.time = last.amount + d, last.count + 1, world.time
    else
        self.hits[#self.hits + 1] = { name = name, amount = d, count = 1, time = world.time, wave = world.spawner and world.spawner.wave or 0 }
        if #self.hits > RunStats.HITS then table.remove(self.hits, 1) end
    end
    self.hits[#self.hits].hp = ctx.player and math.max(0, ctx.player.hp) or 0
end

-- Display names of the player's own moves (attack, special, dash), cached per player.
local function moveName(p, move)
    if move == "attack" then return p.attack and p.attack.type.name or "Attack" end
    if move == "secondary" then return p.secondary and p.secondary.type.name or "Special" end
    if move == "dash" then return p.dashDef and p.dashDef.name or "Dash" end
end
RunStats.moveName = moveName

-- Who is dealing damage right now (see the top of this file).
function RunStats.label(world, opts)
    if opts and opts.source then return opts.source end
    if world.dmgSrc then return world.dmgSrc end
    local p = world.player
    if p and p.curMove then return moveName(p, p.curMove) end
    return "Other"
end

-- Remember the current label on something that will deal damage later.
function RunStats.tag(world, obj)
    if obj and obj._src == nil then obj._src = RunStats.label(world) end
    return obj
end

-- Run with obj's label; returns the previous one for RunStats.leave.
function RunStats.enter(world, obj)
    local prev = world.dmgSrc
    if obj and obj._src then world.dmgSrc = obj._src end
    return prev
end
function RunStats.leave(world, prev) world.dmgSrc = prev end

-- Set a label by name (items, moves); returns the previous one.
function RunStats.push(world, label)
    local prev = world.dmgSrc
    world.dmgSrc = label
    return prev
end

-- Combat.damage reports every hit here (`amount` is what it took off the enemy).
function RunStats:dealtHit(amount, label)
    if amount <= 0 then return end
    self.dealt[label] = (self.dealt[label] or 0) + amount
    self.totalDealt = self.totalDealt + amount
    local w = self:wave()
    if w then w.dealt = w.dealt + amount end
end

-- Sorted { {label, value}, ... } of a table, biggest first, at most n.
function RunStats.sorted(t, n)
    local out = {}
    for k, v in pairs(t) do out[#out + 1] = { k, v } end
    table.sort(out, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end return tostring(a[1]) < tostring(b[1]) end)
    if n then while #out > n do table.remove(out) end end
    return out
end

function RunStats.of(world)
    if not world.runStats then world.runStats = RunStats.new(world) end
    return world.runStats
end

return RunStats
