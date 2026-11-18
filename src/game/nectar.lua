-- Nectar: the beads kills drop, the ground pickups elites drop, and the run's nectar balance.
--
-- Every kill spills nectar beads worth the enemy's `xp` (gilded elites add a bead worth their
-- bonusXP). Beads lie on the floor; inside the player's Pickup Range they drift in, faster and
-- faster, and touching one gives its value as skill XP (World:grantXP) and as nectar
-- (World:addNectar). When a wave is cleared every bead on the ground is magneted in, with a
-- chime that climbs with each bead. Beads that land close together merge into one bigger bead,
-- and all of them are drawn with one SpriteBatch, so a few hundred cost next to nothing.
--
-- Beads are not items: nothing that goes in the bag ever lies on the ground.
--
-- Ground pickups (content/pickups): a rare magnet from any kill, frost (freeze the swarm) and
-- royal jelly (fill the frenzy meter) from elites. They lie around for a while, drift in like
-- beads, and act the moment they're touched.
--
-- Currency API (on World, used by the shop, shrines and map gambles):
--   world.nectar                     the run's balance (a number; saved with the run)
--   world.nectarEarned / nectarSpent run totals
--   World:addNectar(n, x, y)         add (x, y optional: floats "+N nectar" there when n > 1)
--   World:spendNectar(n) -> bool     pay; false and nothing changes when short
--   World:canAffordNectar(n) -> bool
--   both emit "nectar_changed"(newTotal, delta)
--   World:dropNectar(x, y, value)    spill beads on the ground
--   World:magnetNectar()             pull every bead and pickup to the player
--   World:dropPickup(id, x, y)       place a ground pickup (content/pickups id)
--   World:freezeEnemies(seconds)     the frost pickup's effect
-- Numbers: src/config/nectar.lua (a mode may override with `nectar = { ... }`).
local Content = require("src.content")
local Settings = require("src.core.settings")
local Audio = require("src.core.audio")
local Iso = require("src.core.iso")
local util = require("src.core.util")

local Nectar = {}
Nectar.__index = Nectar

function Nectar.config(modeDef)
    local base = require("src.config.nectar")
    local over = modeDef and modeDef.nectar
    if not over then return base end
    local out = {}
    for k, v in pairs(base) do out[k] = v end
    for k, v in pairs(over) do out[k] = v end
    return out
end

----------------------------------------------------------------------------------------------
-- The bead sheet: built once, a few pixels per bead size, plus a shadow.

local sheet
-- tiers by value: small (1-2), medium (3-9), large (10-29), royal (30+)
local TIERS = {
    { r = 2.1, min = 0,  body = { 0.98, 0.72, 0.18 }, rim = { 0.72, 0.42, 0.08 } },
    { r = 2.8, min = 3,  body = { 1.00, 0.78, 0.22 }, rim = { 0.75, 0.45, 0.08 } },
    { r = 3.6, min = 10, body = { 1.00, 0.86, 0.36 }, rim = { 0.80, 0.52, 0.12 } },
    { r = 4.5, min = 30, body = { 1.00, 0.70, 0.55 }, rim = { 0.80, 0.36, 0.30 } },
}

local function buildSheet()
    if sheet then return sheet end
    local cellW, H = 12, 12
    local W = cellW * (#TIERS + 1)
    local data = love.image.newImageData(W, H)
    for ti, tier in ipairs(TIERS) do
        local ox = (ti - 1) * cellW
        local c = (cellW - 1) / 2
        for y = 0, H - 1 do
            for x = 0, cellW - 1 do
                local dx, dy = x - c, y - c
                local d = math.sqrt(dx * dx + dy * dy)
                if d <= tier.r then
                    local col = tier.body
                    if d > tier.r - 0.9 then col = tier.rim end
                    -- a shine in the top left
                    local hx, hy = dx + tier.r * 0.4, dy + tier.r * 0.4
                    if hx * hx + hy * hy < (tier.r * 0.35) ^ 2 + 0.3 then col = { 1, 0.98, 0.85 } end
                    data:setPixel(ox + x, y, col[1], col[2], col[3], 1)
                elseif d <= tier.r + 1.2 then
                    -- soft halo
                    data:setPixel(ox + x, y, 1, 0.8, 0.3, 0.28 * (1 - (d - tier.r) / 1.2))
                end
            end
        end
    end
    -- shadow: a flat dark oval in the last cell
    local ox = #TIERS * cellW
    for y = 0, H - 1 do
        for x = 0, cellW - 1 do
            local dx, dy = (x - 5.5) / 4, (y - 5.5) / 1.6
            if dx * dx + dy * dy <= 1 then data:setPixel(ox + x, y, 0.05, 0.03, 0.02, 0.35) end
        end
    end
    local img = love.graphics.newImage(data)
    img:setFilter("nearest", "nearest")
    sheet = { image = img, quads = {}, half = cellW / 2 }
    for ti = 1, #TIERS do sheet.quads[ti] = love.graphics.newQuad((ti - 1) * cellW, 0, cellW, H, W, H) end
    sheet.shadow = love.graphics.newQuad(ox, 0, cellW, H, W, H)
    return sheet
end

local function tierOf(v)
    for i = #TIERS, 1, -1 do if v >= TIERS[i].min then return i end end
    return 1
end

----------------------------------------------------------------------------------------------

function Nectar.new(world)
    local self = setmetatable({}, Nectar)
    self.world = world
    self.cfg = Nectar.config(world.modeDef)
    self.beads, self.n = {}, 0
    self.grid = {}                  -- merge cells -> the bead resting there
    self.pickups = {}
    self.chain, self.chainT = 0, 0
    self.magnetGlow = 0
    return self
end

local function cellKey(cfg, x, y)
    local s = cfg.mergeCell
    return math.floor(x / s) * 65536 + math.floor(y / s)
end

-- Spill `value` worth of beads at (x, y). Returns the bead it went into.
function Nectar:drop(x, y, value)
    if not value or value <= 0 then return nil end
    local cfg = self.cfg
    local key = cellKey(cfg, x, y)
    local b = self.grid[key]
    if b and not b.pull then
        b.v = b.v + value
        b.pop = 0.18
        return b
    end
    if self.n >= cfg.maxBeads then
        -- full floor: add it to some bead already lying there
        local other = self.beads[love.math.random(self.n)]
        other.v = other.v + value
        other.pop = 0.18
        return other
    end
    local a = love.math.random() * math.pi * 2
    local s = cfg.spill * (0.4 + love.math.random() * 0.6)
    b = { x = x, y = y, z = 2, vz = 50 + love.math.random() * 30, vx = math.cos(a) * s, vy = math.sin(a) * s,
        v = value, key = key, phase = love.math.random() * 6.28, pop = 0, air = true, speed = 0 }
    self.n = self.n + 1
    self.beads[self.n] = b
    self.grid[key] = b
    return b
end

-- Total value still on the ground (and in the air).
function Nectar:pending()
    local t = 0
    for i = 1, self.n do t = t + self.beads[i].v end
    return t
end

function Nectar:startPull(b, magnet)
    if self.grid[b.key] == b then self.grid[b.key] = nil end
    local cfg = self.cfg
    if not b.pull then b.speed = magnet and cfg.magnetSpeed or cfg.driftSpeed end
    if magnet and b.pull ~= "magnet" then b.speed = math.max(b.speed, cfg.magnetSpeed) end
    b.pull = magnet and "magnet" or (b.pull or "drift")
end

-- Every bead and pickup on the ground flies to the player.
function Nectar:magnet()
    for i = 1, self.n do self:startPull(self.beads[i], true) end
    for _, pk in ipairs(self.pickups) do pk.pull, pk.speed = "magnet", math.max(pk.speed, self.cfg.magnetSpeed) end
    if self.n > 0 then self.magnetGlow = 1 end
    self.world.events:emit("nectar_magnet", self.n)
end

-- Grant everything still on the ground at once (saving the run, the run ending).
function Nectar:collectAll()
    local v = self:pending()
    self.beads, self.n, self.grid = {}, 0, {}
    if v > 0 then self:give(v, true) end
    return v
end

-- `count`: how many beads that was (each one queues a note of the chime)
function Nectar:give(v, quiet, count)
    local w = self.world
    local p = w.player
    w:grantXP(v, p.x, p.y, true)
    w:addNectar(v * self.cfg.perXP)
    if quiet then return end
    self.chimeQ = math.min(self.cfg.chimeQueue, (self.chimeQ or 0) + (count or 1))
end

-- A little chime that climbs note by note while you sweep up a trail; the wave-end magnet
-- brings in a whole floor at once, so its notes are queued and played as a rising run.
function Nectar:updateChime(dt)
    local cfg = self.cfg
    self.chimeT = (self.chimeT or 0) - dt
    if (self.chimeQ or 0) > 0 then
        if self.chimeT <= 0 then
            self.chimeQ = self.chimeQ - 1
            self.chimeT = cfg.chimeStep
            self.chain = math.min(cfg.chainSteps, self.chain + 1)
            self.chainT = cfg.chainGap
            local k = self.chain - 1
            local semis = ({ 0, 2, 4, 7, 9 })[k % 5 + 1] + math.floor(k / 5) * 12
            Audio.play("nectar", { pitch = 2 ^ (math.min(semis, 31) / 12) })
        end
    elseif self.chainT > 0 then
        self.chainT = self.chainT - dt
        if self.chainT <= 0 then self.chain = 0 end
    end
end

-- Pickups

function Nectar:dropPickup(def, x, y)
    if type(def) == "string" then def = Content.pickups:get(def) end
    if not def or #self.pickups >= self.cfg.pickupMax then return nil end
    local S = self.world.size
    local pk = { def = def, x = util.clamp(x, 8, S - 8), y = util.clamp(y, 8, S - 8), z = 2, vz = 70, t = 0, speed = 0,
        color = util.hex(def.color) }
    self.pickups[#self.pickups + 1] = pk
    self.world.particles:burst(pk.x, pk.y, 8, { pk.color, { 1, 1, 1 } }, 60, 50, { glow = true, grav = 100 })
    self.world.events:emit("pickup_dropped", def, pk)
    return pk
end

function Nectar:rollPickup(source)
    local w = self.world
    local wave = w.spawner and math.max(1, w.spawner.wave) or 1
    return Content.pickups:pickWeighted(function(d) return d.weight end,
        function(d) return d.source == source and d.minWave <= wave and (not d.allowed or d.allowed(w)) end)
end

-- A kill: its beads, and maybe a pickup.
function Nectar:onKill(e)
    local def = e.def
    local value = def.xp or 1
    if e.elite and e.elite.bonusXP then value = value + e.elite.bonusXP end
    -- `beadValue` items (Pollen Basket) make every kill's beads worth more; the fraction rolls
    local inv = self.world.player and self.world.player.inventory
    local more = inv and inv:sum("beadValue") or 0
    if more > 0 then
        local v = value * (1 + more)
        value = math.floor(v) + (love.math.random() < v - math.floor(v) and 1 or 0)
    end
    self:drop(e.x, e.y, value)
    local cfg = self.cfg
    local w = self.world
    local wave = w.spawner and w.spawner.wave or 1
    local pick
    if e.elite and love.math.random() < cfg.eliteChance then
        pick = self:rollPickup("elite")
    elseif wave >= cfg.killFromWave and love.math.random() < cfg.killChance then
        pick = self:rollPickup("kill")
    end
    if pick then self:dropPickup(pick, e.x, e.y) end
end

----------------------------------------------------------------------------------------------

-- moves (x, y) toward the player; true when it arrived
local function home(o, p, dt, accel, max, reach)
    o.speed = math.min(max, o.speed + accel * dt)
    local dx, dy = p.x - o.x, p.y - o.y
    local d = math.sqrt(dx * dx + dy * dy)
    local step = o.speed * dt
    if d <= reach + step then return true end
    o.x, o.y = o.x + dx / d * step, o.y + dy / d * step
    o.z = o.z + (5 - o.z) * math.min(1, dt * 8)
    return false
end

function Nectar:update(dt)
    local w, cfg = self.world, self.cfg
    local p = w.player
    local alive = not p.dead
    local range = p.stats:get("pickupRange")
    local r2 = range * range
    local auto = Settings.get("autoCollect")
    local touch = p.radius + cfg.collectPad
    local gained, count = 0, 0
    local beads = self.beads
    local i = 1
    while i <= self.n do
        local b = beads[i]
        local got = false
        if b.pop > 0 then b.pop = b.pop - dt end
        if b.air then
            b.x, b.y = b.x + b.vx * dt, b.y + b.vy * dt
            b.vz = b.vz - 320 * dt
            b.z = b.z + b.vz * dt
            if b.z <= 0 then b.z, b.air = 0, nil end
        end
        if alive then
            if b.pull then
                local magnet = b.pull == "magnet"
                got = home(b, p, dt, magnet and cfg.magnetAccel or cfg.driftAccel, magnet and cfg.magnetMax or cfg.driftMax, touch)
            elseif not b.air then
                local dx, dy = p.x - b.x, p.y - b.y
                local d2 = dx * dx + dy * dy
                if d2 < touch * touch then got = true
                elseif auto or d2 < r2 then self:startPull(b, false) end
            end
        end
        if got then
            gained, count = gained + b.v, count + 1
            if self.grid[b.key] == b then self.grid[b.key] = nil end
            beads[i] = beads[self.n]
            beads[self.n] = nil
            self.n = self.n - 1
        else
            i = i + 1
        end
    end
    if gained > 0 then self:give(gained, false, count) end
    self:updateChime(dt)
    if self.magnetGlow > 0 then self.magnetGlow = math.max(0, self.magnetGlow - dt * 1.5) end

    -- pickups
    local list = self.pickups
    for k = #list, 1, -1 do
        local pk = list[k]
        pk.t = pk.t + dt
        if pk.z > 0 or pk.vz > 0 then
            pk.vz = pk.vz - 300 * dt
            pk.z = math.max(0, pk.z + pk.vz * dt)
            if pk.z == 0 then pk.vz = 0 end
        end
        local got = false
        if alive then
            if pk.pull then
                local magnet = pk.pull == "magnet"
                got = home(pk, p, dt, magnet and cfg.magnetAccel or cfg.driftAccel, magnet and cfg.magnetMax or cfg.driftMax, touch + 2)
            else
                local dx, dy = p.x - pk.x, p.y - pk.y
                local d2 = dx * dx + dy * dy
                if d2 < (touch + 2) ^ 2 then got = true
                elseif d2 < r2 or auto then pk.pull, pk.speed = "drift", cfg.driftSpeed end
            end
        end
        if got then
            table.remove(list, k)
            Audio.play("pickup", { pitch = 1.2 })
            w.particles:burst(p.x, p.y, 14, { pk.color, { 1, 1, 1 } }, 90, 60, { glow = true, grav = 60 })
            pk.def.collect(w, p, pk)
            w.events:emit("pickup_collected", pk.def, pk)
        elseif pk.t >= cfg.pickupLife and not pk.pull then
            table.remove(list, k)
            w.particles:burst(pk.x, pk.y, 6, { pk.color }, 30, 30, { glow = true, grav = 0 })
        end
    end
end

----------------------------------------------------------------------------------------------
-- Drawing (projected pixels, inside the world's camera transform)

local function drawIcon(icon, x, y, t)
    local lg = love.graphics
    lg.setLineWidth(1)
    if icon == "magnet" then
        lg.setColor(0.9, 0.15, 0.12, 1)
        lg.arc("line", "open", x, y + 0.5, 3, 0, math.pi, 8)
        lg.line(x - 3, y + 0.5, x - 3, y - 2.5)
        lg.line(x + 3, y + 0.5, x + 3, y - 2.5)
        lg.setColor(0.95, 0.95, 1, 1)
        lg.points(x - 3 + 0.5, y - 2.5, x + 3 + 0.5, y - 2.5)
    elseif icon == "freeze" then
        lg.setColor(1, 1, 1, 1)
        for k = 0, 2 do
            local a = k * math.pi / 3 + t * 0.6
            local c, s = math.cos(a) * 3.2, math.sin(a) * 3.2
            lg.line(x - c, y - s, x + c, y + s)
        end
    elseif icon == "frenzy" then
        lg.setColor(1, 1, 0.85, 1)
        lg.line(x + 1, y - 3.5, x - 1.5, y + 0.2, x + 1.5, y - 0.2, x - 1, y + 3.5)
    else
        lg.setColor(1, 1, 1, 1)
        lg.circle("fill", x, y, 1.5, 6)
    end
end

function Nectar:draw(cx0, cy0, cx1, cy1)
    local lg = love.graphics
    local t = self.world.time
    if self.n > 0 then
        local sh = buildSheet()
        local batch = self.batch
        if not batch then
            batch = lg.newSpriteBatch(sh.image, self.cfg.maxBeads * 2 + 16, "stream")
            self.batch = batch
        end
        batch:clear()
        local half = sh.half
        local beads = self.beads
        local count = 0
        -- shadows first, then the beads (one draw call for all of them)
        for i = 1, self.n do
            local b = beads[i]
            local sx, sy = b.x - b.y, (b.x + b.y) * 0.5
            if sx > cx0 and sx < cx1 and sy > cy0 and sy < cy1 then
                count = count + 1
                if not b.pull then batch:add(sh.shadow, math.floor(sx - half), math.floor(sy - half + 1)) end
            end
        end
        if count > 0 then
            for i = 1, self.n do
                local b = beads[i]
                local sx, sy = b.x - b.y, (b.x + b.y) * 0.5
                if sx > cx0 and sx < cx1 and sy > cy0 and sy < cy1 then
                    local z = b.z
                    if not b.pull and not b.air then z = 1.5 + math.sin(t * 4 + b.phase) * 0.8 end
                    local tier = tierOf(b.v)
                    local s = b.pop > 0 and 1.35 or 1
                    batch:add(sh.quads[tier], math.floor(sx), math.floor(sy - z), 0, s, s, half, half)
                end
            end
            lg.setColor(1, 1, 1, 1)
            lg.draw(batch)
        end
    end

    -- pickups: a glowing token with a symbol, bobbing over a shadow
    for _, pk in ipairs(self.pickups) do
        local sx, sy = Iso.toScreen(pk.x, pk.y)
        if sx > cx0 and sx < cx1 and sy > cy0 and sy < cy1 then
            local left = self.cfg.pickupLife - pk.t
            if pk.pull or left > 5 or math.floor(pk.t * 8) % 2 == 0 then
                local bob = pk.pull and pk.z or (3 + math.sin(t * 3 + pk.x) * 1.5 + pk.z)
                local c = pk.color
                lg.setColor(0, 0, 0, 0.3)
                lg.ellipse("fill", sx, sy + 1, 5, 2)
                lg.setColor(c[1], c[2], c[3], 0.35 + 0.15 * math.sin(t * 6))
                lg.circle("fill", sx, sy - bob, 7.5, 16)
                lg.setColor(c[1] * 0.5, c[2] * 0.5, c[3] * 0.5, 1)
                lg.circle("fill", sx, sy - bob, 5.5, 14)
                lg.setColor(c[1], c[2], c[3], 1)
                lg.circle("line", sx, sy - bob, 5.5, 14)
                drawIcon(pk.def.icon, math.floor(sx) + 0.5, math.floor(sy - bob) + 0.5, t)
            end
        end
    end
    lg.setColor(1, 1, 1, 1)
end

return Nectar
