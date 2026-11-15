-- Map gambles: risky spots that pop up on the map during a wave (world.gambles). Each is a prop
-- (content/props) with a `gamble = { weight, minWave, allowed }` field, so a new one is just a
-- new prop file:
--
--   * dewdrop_shrine: stand in its ring while ants pour in; when the dew is gathered, walk into
--     one of three blessings (a permanent stat boost).
--   * challenge_bell: ring it and a tough pack answers. Kill them all in time for XP, frenzy and
--     a rarer best card in the next item choice.
--   * gamble_flower: pay nectar to spin it. Items, blessings, nectar back... or ants and curses.
--
-- One may be placed at the start of each wave from wave 2 (Settings "Map Gambles"). Anything
-- left unused goes when the next wave starts. Blessings and curses last the whole run (they are
-- kept in run saves) and show in the pause screen's stat list like any other bonus.
--
-- Numbers: src/config/gambles.lua (a mode can override them with `gambles = { ... }`).
local Content = require("src.content")
local Settings = require("src.core.settings")
local Audio = require("src.core.audio")
local util = require("src.core.util")
local Env = require("src.game.envfx")

local Gambles = {}
Gambles.__index = Gambles

Gambles.SOURCE = "blessing"     -- the stat modifier source for blessings and curses

local function merged(base, over)
    local out = {}
    for k, v in pairs(base) do out[k] = v end
    for k, v in pairs(over or {}) do
        if type(v) == "table" and type(out[k]) == "table" and #v == 0 then
            local t = {}
            for k2, v2 in pairs(out[k]) do t[k2] = v2 end
            for k2, v2 in pairs(v) do t[k2] = v2 end
            out[k] = t
        else
            out[k] = v
        end
    end
    return out
end

function Gambles.new(world)
    local mode = world.modeDef or {}
    local self = setmetatable({ world = world, schedule = {}, placed = 0 }, Gambles)
    self.cfg = merged(require("src.config.gambles"), type(mode.gambles) == "table" and mode.gambles or nil)
    -- blessings / curses taken this run: { stat, add, from }
    world.blessings = world.blessings or {}
    return self
end

function Gambles:on()
    local w = self.world
    if w.mode ~= "run" or w.flags.demo then return false end
    if w.modeDef and w.modeDef.gambles == false then return false end
    return Settings.get("mapGambles") ~= "off"
end

-- Is the wave on? (shrines only fill and bells only ring while it is)
function Gambles.live(world)
    return world.spawner and world.spawner.phase == "wave"
end

-- The props that can be placed as gambles, and how likely each is on wave n.
function Gambles:kinds()
    local out = {}
    for _, def in ipairs(Content.props:all()) do
        if def.gamble then out[#out + 1] = def end
    end
    return out
end

local function weight(self, def, n)
    local g = def.gamble
    if (g.minWave or 1) > n then return 0 end
    if g.allowed and not g.allowed(self.world) then return 0 end
    local w = g.weight or 10
    -- not the same kind twice in a row
    if self.last == def.id then w = w * 0.3 end
    return w
end

-- Line up this wave's gambles (called by the director when a wave starts).
function Gambles:onWaveStart(n)
    local world = self.world
    self.schedule = {}
    -- what was left unused last wave goes (a shrine you are standing in stays a little)
    for _, o in ipairs(world.props.list) do
        if o.def.gamble and not o.dead and not o.busy then
            if o.def.leave then o.def.leave(world, o) else o.dead = true end
        end
    end
    if not self:on() or n < self.cfg.from then return end
    local often = Settings.get("mapGambles") == "often"
    local count = 0
    if love.math.random() < (often and self.cfg.oftenChance or self.cfg.chance) then count = 1 end
    if often and count == 1 and love.math.random() < self.cfg.secondChance then count = 2 end
    local at = self.cfg.arriveAt
    for _ = 1, count do
        local def = util.weightedPick(self:kinds(), function(d) return weight(self, d, n) end)
        if def then
            self.last = def.id
            self.schedule[#self.schedule + 1] = { id = def.id, at = at[1] + love.math.random() * (at[2] - at[1]) }
        end
    end
end

function Gambles:update(dt)
    local world = self.world
    local sp = world.spawner
    if sp.phase ~= "wave" then return end
    for i = #self.schedule, 1, -1 do
        local s = self.schedule[i]
        if sp.waveTime >= s.at then
            table.remove(self.schedule, i)
            self:place(s.id)
        end
    end
end

function Gambles:count()
    local n = 0
    for _, o in ipairs(self.world.props.list) do if o.def.gamble and not o.dead then n = n + 1 end end
    return n
end

-- Put a gamble on the map now (somewhere away from the player, unless x, y are given).
function Gambles:place(id, x, y)
    local world = self.world
    local def = Content.props:require(id)
    if self:count() >= self.cfg.max then
        -- the oldest unused one makes way
        for _, o in ipairs(world.props.list) do
            if o.def.gamble and not o.dead and not o.busy then o.dead = true break end
        end
    end
    if not x then x, y = Env.pointAway(world, self.cfg.away, 70) end
    local o = world.props:spawn(id, x, y)
    self.placed = self.placed + 1
    world.particles:burst(x, y, 14, { { 0.75, 0.95, 1 }, { 1, 0.95, 0.7 } }, 70, 60, { grav = 120 })
    Audio.play("chime", { pitch = 1.2 })
    if def.gamble.banner ~= false then
        world.director:announce(def.name, def.gamble.text or def.description, def.gamble.color or { 0.7, 0.95, 1 })
    end
    world.events:emit("gamble_placed", id, o)
    return o
end

----------------------------------------------------------------------------------------------
-- Blessings and curses: permanent stat changes for the rest of the run

-- A blessing's size on this wave (blessings grow a little as the run goes on).
function Gambles:scaled(add)
    local wave = math.max(1, self.world.spawner.wave or 1)
    local v = add * (1 + (wave - 1) * self.cfg.shrine.grow)
    if math.abs(v) >= 3 then return math.floor(v + 0.5) end
    return math.floor(v * 100 + 0.5) / 100
end

-- `n` different blessings from the pool, already scaled: { { stat, add }, ... }
function Gambles:rollBlessings(n)
    local pool, out, used = self.cfg.shrine.pool, {}, {}
    for _ = 1, n do
        local pick = util.weightedPick(pool, function(b) return used[b.stat] and 0 or (b.weight or 10) end)
        if not pick then break end
        used[pick.stat] = true
        out[#out + 1] = { stat = pick.stat, add = self:scaled(pick.add) }
    end
    return out
end

-- "+7% Damage"
function Gambles.describe(stat, add)
    local Stats = require("src.game.stats")
    local d = Stats.byId[stat]
    return (add >= 0 and "+" or "") .. Stats.format(stat, add) .. " " .. (d and d.label or stat)
end

-- Apply one (quiet = no text, for restoring a save). Returns the text shown.
local function apply(world, stat, add)
    local p = world.player
    p.stats:addModifier(Gambles.SOURCE, stat, add, 0)
    if stat == "maxHp" then
        p.hp = math.max(1, math.min(p.stats:get("maxHp"), p.hp + math.max(0, add)))
    end
end

function Gambles:bless(stat, add, from)
    local world = self.world
    local list = world.blessings
    list[#list + 1] = { stat = stat, add = add, from = from }
    apply(world, stat, add)
    local p = world.player
    local good = add >= 0
    local d = require("src.game.stats").byId[stat]
    if d and d.lowerIsBetter then good = not good end
    world:floatText(p.x, p.y - 12, Gambles.describe(stat, add), good and { 0.6, 0.95, 1 } or { 0.8, 0.5, 1 }, true)
    world.events:emit(good and "blessing" or "curse", stat, add, from)
end

-- A curse from the flower: a random small minus.
function Gambles:curse(from)
    local list = self.cfg.flower.curses
    local c = list[love.math.random(#list)]
    self:bless(c.stat, self:scaled(c.add), from or "curse")
end

-- Run saves: put the blessings back on a fresh player.
function Gambles.restore(world, list)
    world.blessings = {}
    for _, b in ipairs(list or {}) do
        if require("src.game.stats").byId[b.stat] then
            world.blessings[#world.blessings + 1] = { stat = b.stat, add = b.add, from = b.from }
            apply(world, b.stat, b.add)
        end
    end
end

----------------------------------------------------------------------------------------------
-- Shared drawing helpers for the gamble props

-- A soft glowing ring on the ground (k = 0..1 fill).
function Gambles.ring(x, y, r, k, t, color)
    local lg = love.graphics
    local c = color
    lg.setColor(c[1], c[2], c[3], 0.08 + 0.12 * k)
    Env.ellipse("fill", x, y, r)
    lg.setColor(c[1], c[2], c[3], 0.35 + 0.15 * math.sin(t * 3))
    Env.ellipse("line", x, y, r)
    if k > 0 then
        lg.setColor(c[1], c[2], c[3], 0.25 + 0.3 * k)
        Env.ellipse("fill", x, y, r * k)
    end
end

return Gambles
