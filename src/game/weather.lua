-- Weather: random passing spells of rain, fog, wind, pollen and so on, defined in
-- content/weather (see _template.lua). A spell's `effects` (wind pushing, rain slowing, a
-- heatwave speeding things up) are applied by src/game/director.lua.
--
-- A spell lasts `duration` seconds, fading in and out over a few seconds, then a new one is
-- picked by weight. A stage can change the odds with `weather = { rain = 0, dust = 30 }`.
-- Particles live in projected (screen-space) world coordinates and wrap around the view,
-- so they stay put on the ground as the camera moves and never run out at the edges.
local Content = require("src.content")
local Settings = require("src.core.settings")
local Sprites = require("src.gfx.sprites")
local util = require("src.core.util")

local Weather = {}
Weather.__index = Weather

local FADE = 4           -- seconds to fade a spell in or out
local REF_AREA = 960 * 540

function Weather.new(world)
    local self = setmetatable({ world = world, k = 0, t = 0, flash = 0, parts = {}, splashes = {}, blobs = {} }, Weather)
    self:pick(true)
    return self
end

local function weightOf(def, stage, world)
    local w = def.weight
    if stage.weather and stage.weather[def.id] ~= nil then w = stage.weather[def.id]
    elseif def.stages then
        w = 0
        for _, s in ipairs(def.stages) do if s == stage.id then w = def.weight end end
    end
    if def.night and world:daylight() > 0.5 then w = 0 end
    return w
end

-- Choose the next spell (never the same one twice in a row unless it is the only option).
function Weather:pick(first)
    local stage = self.world.stage
    local defs = Content.weather:all()
    local cur = self.def
    local def = util.weightedPick(defs, function(d)
        if cur and d == cur and #defs > 1 then return 0 end
        -- runs start calm more often than not
        if first and d.id ~= "clear" then return weightOf(d, stage, self.world) * 0.5 end
        return weightOf(d, stage, self.world)
    end)
    self:set(def or Content.weather:get("clear"))
end

-- Switch straight to a spell (dev console `weather <id>`); fades in from nothing.
function Weather:set(def, duration)
    self.def, self.t, self.k = def, 0, 0
    local d = def.duration or { 60, 120 }
    self.length = duration or love.math.random(d[1], d[2])
    self.parts, self.splashes, self.blobs = {}, {}, {}
    self.flashCd = def.lightning and love.math.random(6, 14) or nil
end

function Weather:name() return self.def.name end

-- 0..1 strength of the current spell (fading in and out).
function Weather:strength()
    if Settings.get("weather") == "off" then return 0 end
    return self.k
end

function Weather:update(dt)
    local def = self.def
    self.t = self.t + dt
    if Settings.get("weather") == "off" then self.k = 0 return end
    self.k = util.clamp(math.min(self.t, self.length - self.t) / FADE, 0, 1)
    if self.t >= self.length then self:pick() return end

    -- thunder: a bright flicker every so often
    self.flash = math.max(0, self.flash - dt * 3)
    if self.flashCd then
        self.flashCd = self.flashCd - dt
        if self.flashCd <= 0 then
            self.flashCd = love.math.random(5, 16)
            if self.k > 0.6 and not Settings.get("reduceFlashing") then self.flash = 1 end
        end
    end

    local wind = def.wind or { 0, 0 }
    for _, p in ipairs(self.parts) do
        p.t = p.t + dt
        local sway = p.sway and math.sin(self.world.time * p.sway + p.seed) * 12 or 0
        p.x = p.x + (p.vx + wind[1] + sway + (self.world.windGust or 0) * 25) * dt
        p.y = p.y + (p.vy + wind[2]) * dt
        if p.spin then p.a = p.a + p.spin * dt end
    end
    for i = #self.splashes, 1, -1 do
        local s = self.splashes[i]
        s.t = s.t + dt
        if s.t > 0.25 then table.remove(self.splashes, i) end
    end
    for _, b in ipairs(self.blobs) do
        b.x, b.y = b.x + (wind[1] * 0.3 + b.vx) * dt, b.y + (wind[2] * 0.3 + b.vy) * dt
    end
end

-- How much the spell dims daylight (rain clouds), as a multiplier on the ambient colour.
function Weather:ambientMul()
    local dim = self.def.dim
    if not dim then return 1 end
    return 1 - (1 - dim) * self:strength()
end

local function rand(r) return type(r) == "table" and util.lerp(r[1], r[2], love.math.random()) or r end

-- A fresh particle somewhere in the view (projected coords).
local function newPart(spec, ox, oy, vw, vh)
    local p = {
        x = ox + love.math.random() * vw, y = oy + love.math.random() * vh, t = 0,
        life = rand(spec.life or { 0.4, 0.8 }), seed = love.math.random() * 100,
        vx = rand(spec.vx or 0), vy = rand(spec.vy or 0), size = rand(spec.size or 1),
        sway = spec.sway, spin = spec.spin and rand(spec.spin), a = love.math.random() * 6.28,
    }
    p.c = spec._c[love.math.random(#spec._c)]
    return p
end

local function prepare(spec)
    if spec._c then return end
    spec._c = {}
    for i, h in ipairs(spec.colors or { spec.color or "#ffffff" }) do spec._c[i] = util.hex(h) end
end

-- Drawn into the world (camera transform applied) just before lighting, so night darkens it.
function Weather:draw(ox, oy, vw, vh)
    local k = self:strength()
    if k <= 0 then return end
    local def = self.def
    local lg = love.graphics

    -- fog banks: big soft blobs drifting over the floor
    if def.fog then
        local f = def.fog
        if not f._c then f._c = util.hex(f.color) end
        while #self.blobs < (f.count or 8) do
            self.blobs[#self.blobs + 1] = { x = ox + love.math.random() * vw, y = oy + love.math.random() * vh,
                r = love.math.random(f.size and f.size[1] or 90, f.size and f.size[2] or 180),
                vx = (love.math.random() - 0.5) * 6, vy = (love.math.random() - 0.5) * 3 }
        end
        for _, b in ipairs(self.blobs) do
            local x = ox + (b.x - ox) % (vw + 2 * b.r) - b.r
            local y = oy + (b.y - oy) % (vh + 2 * b.r) - b.r
            lg.setColor(f._c[1], f._c[2], f._c[3], (f.alpha or 0.3) * k)
            lg.draw(Sprites.light, x, y, 0, b.r / 64, b.r / 110, 64, 64)
        end
    end

    -- rain is drawn after lighting (drawGlow) so it still shows at night
    if def.particles and (def.particles.kind or "mote") ~= "rain" then self:drawParticles(ox, oy, vw, vh, k, 1) end
    lg.setColor(1, 1, 1, 1)
end

function Weather:drawParticles(ox, oy, vw, vh, k, alphaMul)
    local def = self.def
    local spec = def.particles
    local lg = love.graphics
    local atlas, px = Sprites.atlas, Sprites.pixel
    local night = def.night and util.clamp((0.6 - self.world:daylight()) / 0.4, 0, 1) or 1
    if spec and Settings.get("particles") > 0 then
        prepare(spec)
        local want = math.floor(math.min(spec.max or 700, (spec.count or 100) * vw * vh / REF_AREA)
            * (0.4 + 0.2 * Settings.get("particles")) * k * night)
        k = k * alphaMul
        local parts = self.parts
        while #parts < want do parts[#parts + 1] = newPart(spec, ox, oy, vw, vh) end
        for i = #parts, want + 1, -1 do parts[i] = nil end
        local kind = spec.kind or "mote"
        local len = spec.length or 6
        for i = 1, #parts do
            local p = parts[i]
            if p.t >= p.life then
                if kind == "rain" and #self.splashes < 120 then
                    self.splashes[#self.splashes + 1] = { x = p.x, y = p.y, t = 0 }
                end
                local q = newPart(spec, ox, oy, vw, vh)
                parts[i] = q
                p = q
            end
            local x = ox + (p.x - ox) % vw
            local y = oy + (p.y - oy) % vh
            local fade = math.min(1, p.t / 0.15, (p.life - p.t) / 0.25)
            local c = p.c
            if kind == "rain" then
                -- a falling streak along its velocity
                local sp = math.max(1, math.sqrt(p.vx * p.vx + p.vy * p.vy))
                lg.setColor(c[1], c[2], c[3], (spec.alpha or 0.5) * k)
                lg.setLineWidth(1)
                lg.line(x, y, x - p.vx / sp * len, y - p.vy / sp * len)
            elseif kind == "leaf" then
                lg.setColor(c[1], c[2], c[3], (spec.alpha or 0.9) * k * fade)
                local s = p.size
                lg.draw(atlas, px, x, y, p.a, s * 1.6, s * (0.5 + 0.5 * math.abs(math.sin(p.a * 2))), 0.5, 0.5)
            else
                -- motes: pollen, dust, fireflies (flicker)
                local a = (spec.alpha or 0.8) * k * fade
                if spec.flicker then a = a * (0.5 + 0.5 * math.sin(self.world.time * spec.flicker + p.seed)) end
                lg.setColor(c[1], c[2], c[3], a)
                lg.draw(atlas, px, x, y, 0, p.size, p.size, 0.5, 0.5)
            end
        end
        if #self.splashes > 0 then
            prepare(spec)
            local c = spec._c[1]
            for _, s in ipairs(self.splashes) do
                local x = ox + (s.x - ox) % vw
                local y = oy + (s.y - oy) % vh
                local f = s.t / 0.25
                lg.setColor(c[1], c[2], c[3], (spec.alpha or 0.5) * k * (1 - f))
                lg.ellipse("line", x, y, 1 + f * 3, 0.5 + f * 1.5)
            end
        end
    end
    lg.setColor(1, 1, 1, 1)
end

-- After lighting: rain (dimmed a little at night, but never lost in the dark), glowing motes
-- (fireflies) and the thunder flash.
function Weather:drawGlow(ox, oy, vw, vh)
    local k = self:strength()
    local glare = require("src.gfx.lighting").glareMul()
    if k <= 0 then return end
    local spec = self.def.particles
    local lg = love.graphics
    if spec and spec.kind == "rain" then
        self:drawParticles(ox, oy, vw, vh, k, 0.45 + 0.55 * self.world:daylight() + self.flash * 0.5)
    end
    if spec and spec.glow and #self.parts > 0 then
        lg.setBlendMode("add")
        for _, p in ipairs(self.parts) do
            local x = ox + (p.x - ox) % vw
            local y = oy + (p.y - oy) % vh
            local a = 0.35 * k * glare * (spec.flicker and (0.5 + 0.5 * math.sin(self.world.time * spec.flicker + p.seed)) or 1)
            lg.setColor(p.c[1], p.c[2], p.c[3], a)
            lg.draw(Sprites.light, x, y, 0, spec.glow / 64, spec.glow / 64, 64, 64)
        end
        lg.setBlendMode("alpha")
    end
    if self.flash > 0 then
        lg.setBlendMode("add")
        lg.setColor(0.75, 0.8, 1, 0.22 * self.flash * k * glare * glare)
        lg.rectangle("fill", ox, oy, vw, vh)
        lg.setBlendMode("alpha")
    end
    lg.setColor(1, 1, 1, 1)
end

return Weather
