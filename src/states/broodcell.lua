-- The brood cell chest fanfare (content/props/brood_cell.lua): the cell shakes, bursts, and a
-- counter rolls through 1, 3 and 5 before it lands on how many level-up cards are inside. Those
-- go to the level-up card picks (src/game/levelups.lua, Levelups.grant with now = true), which
-- show straight after this. Without that system, each card is XP instead (cfg.fallbackXP).
-- The game is paused while this is open. Any confirm / click skips the roll, and once it has
-- landed another closes it (or it closes itself after a few seconds).
local State = require("src.core.state")
local Input = require("src.core.input")
local Audio = require("src.core.audio")
local Theme = require("src.ui.theme")
local Config = require("src.config.molting")
local util = require("src.core.util")

local Chest = { transparent = true }
Chest.__index = Chest

local lg = love.graphics

Chest.SHAKE = 0.7       -- seconds of shaking before it bursts
Chest.ROLL = 1.5        -- seconds the counter rolls
Chest.AUTO = 3.2        -- closes by itself this long after landing

-- How many cards: weighted by the chest kind's odds, Luck moving weight toward 3 and 5.
function Chest.roll(world, kind)
    local cfg = Config.chest
    local k = cfg[kind] or cfg.queen
    local luck = math.max(0, world.player.stats:get("luck") / 100)
    local sh = cfg.luckShift * luck
    local w = { k.odds[1] * math.max(0.25, 1 - sh), k.odds[2] * (1 + sh), k.odds[3] * (1 + sh) }
    local total = w[1] + w[2] + w[3]
    local r = love.math.random() * total
    for i = 1, 3 do
        r = r - w[i]
        if r <= 0 then return cfg.counts[i], i end
    end
    return cfg.counts[3], 3
end

-- c = { kind = "queen" | "treasure", x, y } (World:openChest)
function Chest.new(game, c)
    local self = setmetatable({ game = game, world = game.world, t = 0, kind = c.kind or "queen", x = c.x, y = c.y }, Chest)
    self.count, self.slot = Chest.roll(self.world, self.kind)
    self.sparks = {}
    self.rollShown = 1
    self.tick = 0
    return self
end

function Chest:enter()
    love.mouse.setVisible(true)
    Audio.play("pickup", { pitch = 0.6 })
end

function Chest:landed() return self.t >= Chest.SHAKE + Chest.ROLL end

-- Give the cards and close.
function Chest:close()
    if self.closed then return end
    self.closed = true
    State.pop()
    local w, n = self.world, self.count
    local cfg = Config.chest
    local ok, Levelups = pcall(require, "src.game.levelups")
    local given = false
    if ok and type(Levelups) == "table" and Levelups.grant and w.levelups then
        local kcfg = cfg[self.kind] or {}
        given = (Levelups.grant(w, n, { source = self.kind == "queen" and "Royal brood cell" or "Brood cell",
            minRarity = kcfg.minRarity, now = true }) or 0) > 0
    end
    if not given then
        local p = w.player
        w:grantXP(n * cfg.fallbackXP, p.x, p.y)
    end
    w.chestsOpened = (w.chestsOpened or 0) + 1
    w.events:emit("chest_opened", self.kind, n)
end

function Chest:skip()
    if self:landed() then self:close() return end
    if self.t >= 0.25 then self.t = Chest.SHAKE + Chest.ROLL end
end

function Chest:update(dt)
    local before = self.t
    self.t = self.t + dt
    local S, R = Chest.SHAKE, Chest.ROLL
    if before < S and self.t >= S then
        Audio.play("boom", { pitch = 1.3 })
        for _ = 1, 40 do
            local a = love.math.random() * math.pi * 2
            local s = 120 + love.math.random() * 260
            self.sparks[#self.sparks + 1] = { x = 0, y = 0, vx = math.cos(a) * s, vy = math.sin(a) * s - 80, t = 0,
                life = 0.7 + love.math.random() * 0.6, c = love.math.random() < 0.5 and { 1, 0.85, 0.35 } or { 1, 1, 0.8 } }
        end
    end
    -- the counter: ticks through 1 / 3 / 5, slowing down, then lands
    if self.t >= S and not self:landed() then
        local k = (self.t - S) / R
        local period = 0.05 + 0.25 * k * k
        self.tick = self.tick - dt
        if self.tick <= 0 then
            self.tick = period
            self.rollShown = self.rollShown % 3 + 1
            Audio.play("ui_move", { pitch = 0.9 + self.rollShown * 0.15 })
        end
    end
    if before < S + R and self:landed() then
        self.rollShown = self.slot
        Audio.play("wave_clear")
        Audio.play("ui_confirm", { pitch = 0.8 + self.slot * 0.2 })
        if self.slot == 3 then self.world.camera:shake(0.3) end
        for _ = 1, 20 + self.slot * 15 do
            local a = love.math.random() * math.pi * 2
            local s = 80 + love.math.random() * 240
            self.sparks[#self.sparks + 1] = { x = 0, y = 0, vx = math.cos(a) * s, vy = math.sin(a) * s - 120, t = 0,
                life = 0.9 + love.math.random() * 0.8, c = ({ { 0.5, 1, 0.85 }, { 1, 0.85, 0.35 }, { 1, 0.55, 0.9 } })[love.math.random(3)] }
        end
    end
    for i = #self.sparks, 1, -1 do
        local s = self.sparks[i]
        s.t = s.t + dt
        s.x, s.y = s.x + s.vx * dt, s.y + s.vy * dt
        s.vy = s.vy + 300 * dt
        if s.t >= s.life then table.remove(self.sparks, i) end
    end
    if Input.pressed("ui_confirm") or Input.pressed("ui_back") or Input.pressed("attack") then self:skip() end
    if self:landed() and self.t >= S + R + Chest.AUTO then self:close() end
end

function Chest:mousepressed() self:skip() end
function Chest:touchpressed() self:skip() end

local function hexPts(cx, cy, r, sq)
    local pts = {}
    for i = 0, 5 do
        local a = i / 6 * math.pi * 2 + math.pi / 6
        pts[#pts + 1] = cx + math.cos(a) * r
        pts[#pts + 1] = cy + math.sin(a) * r * sq
    end
    return pts
end

function Chest:draw()
    local w, h = lg.getDimensions()
    local u = Theme.u
    local S, R = Chest.SHAKE, Chest.ROLL
    local fade = math.min(1, self.t / 0.2)
    lg.setColor(0.02, 0.015, 0.02, 0.7 * fade)
    lg.rectangle("fill", 0, 0, w, h)
    local cx, cy = w / 2, h * 0.4
    local royal = self.kind == "queen"
    lg.setFont(Theme.font(20, "bold"))
    Theme.printShadow(royal and "ROYAL BROOD CELL" or "BROOD CELL", 0, cy - u(150), { 1, 0.88, 0.45, fade }, "center", w)

    -- light rays behind it once it bursts
    if self.t >= S then
        local k = math.min(1, (self.t - S) / 0.4)
        lg.setColor(1, 0.85, 0.4, 0.12 * k)
        for i = 0, 11 do
            local a = i / 12 * math.pi * 2 + self.t * 0.4
            local r = u(260)
            lg.polygon("fill", cx, cy, cx + math.cos(a - 0.08) * r, cy + math.sin(a - 0.08) * r, cx + math.cos(a + 0.08) * r, cy + math.sin(a + 0.08) * r)
        end
    end
    -- the cell: shakes harder and harder, then splits in two halves that fly apart
    local r = u(64)
    if self.t < S then
        local k = self.t / S
        local j = (love.math.random() - 0.5) * u(10) * k
        local jy = (love.math.random() - 0.5) * u(6) * k
        lg.setColor(0.55, 0.36, 0.1, 1)
        lg.polygon("fill", hexPts(cx + j, cy + jy + r * 0.25, r, 0.75))
        lg.setColor(0.88, 0.62, 0.2, 1)
        lg.polygon("fill", hexPts(cx + j, cy + jy, r, 0.75))
        lg.setColor(1, 0.9, 0.55, 1)
        lg.polygon("fill", hexPts(cx + j, cy + jy - u(4), r * 0.72, 0.75))
        lg.setColor(0.42, 0.26, 0.08, 1)
        lg.setLineWidth(u(2))
        for i = 1, math.floor(k * 5) do
            local a = i * 1.7
            lg.line(cx + j, cy + jy, cx + j + math.cos(a) * r * 0.7, cy + jy + math.sin(a) * r * 0.5)
        end
        lg.setLineWidth(1)
    else
        local k = math.min(1, (self.t - S) / 0.5)
        local off = k * u(120)
        local a = 1 - k
        for side = -1, 1, 2 do
            lg.setColor(0.88, 0.62, 0.2, a)
            local pts = hexPts(cx + side * off, cy + k * u(60), r * (1 - k * 0.3), 0.75)
            lg.polygon("fill", pts)
        end
    end
    -- sparks
    for _, s in ipairs(self.sparks) do
        local a = 1 - s.t / s.life
        lg.setColor(s.c[1], s.c[2], s.c[3], a)
        lg.rectangle("fill", cx + s.x - u(2), cy + s.y - u(2), u(4), u(4))
    end
    -- the counter: three medallions 1 / 3 / 5, the lit one rolling
    if self.t >= S then
        local counts = Config.chest.counts
        local mw = u(84)
        local gap = u(22)
        local x0 = cx - (3 * mw + 2 * gap) / 2
        local my = cy + u(110)
        for i = 1, 3 do
            local on = i == self.rollShown
            local land = self:landed() and on
            local mx = x0 + (i - 1) * (mw + gap)
            local pop = land and (1 + 0.12 * math.max(0, 1 - (self.t - S - R) * 3)) or 1
            local ww, hh = mw * pop, mw * pop
            local bx, by = mx + (mw - ww) / 2, my + (mw - hh) / 2
            lg.setColor(on and { 0.3, 0.2, 0.08, 1 } or { 0.1, 0.08, 0.07, 0.92 })
            lg.rectangle("fill", bx, by, ww, hh, u(8))
            local c = ({ { 0.85, 0.85, 0.8 }, { 1, 0.85, 0.35 }, { 1, 0.55, 0.9 } })[i]
            lg.setColor(c[1], c[2], c[3], on and 1 or 0.3)
            lg.setLineWidth(on and u(3) or u(1))
            lg.rectangle("line", bx, by, ww, hh, u(8))
            lg.setLineWidth(1)
            lg.setFont(Theme.font(40, "bold"))
            Theme.printShadow(tostring(counts[i]), bx, by + hh / 2 - u(26), { c[1], c[2], c[3], on and 1 or 0.35 }, "center", ww)
        end
        if self:landed() then
            local n = self.count
            local ok, Levelups = pcall(require, "src.game.levelups")
            local cards = ok and type(Levelups) == "table" and Levelups.grant and self.world.levelups
            local text = cards and (n == 1 and "1 LEVEL-UP CARD" or (n .. " LEVEL-UP CARDS"))
                or ("+" .. n * Config.chest.fallbackXP .. " XP")
            local k = math.min(1, (self.t - S - R) * 4)
            lg.setFont(Theme.font(self.slot == 3 and 38 or 32, "bold"))
            local col = ({ { 0.95, 0.92, 0.85 }, { 1, 0.85, 0.35 }, { 1, 0.6, 0.92 } })[self.slot]
            Theme.printShadow((self.slot == 3 and "JACKPOT!  " or "") .. text, 0, my + mw + u(26) - (1 - k) * u(12), { col[1], col[2], col[3], k }, "center", w)
            lg.setFont(Theme.font(14))
            lg.setColor(Theme.colors.dim[1], Theme.colors.dim[2], Theme.colors.dim[3], k * 0.9)
            local hint = Input.lastDevice == "gamepad" and "A to continue" or Input.lastDevice == "touch" and "Tap to continue" or "Click or press Enter to continue"
            lg.printf(hint, 0, my + mw + u(80), w, "center")
        end
    end
    lg.setColor(1, 1, 1, 1)
end

return Chest
