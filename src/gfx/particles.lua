-- Pooled pixel particles with height and bounce, drawn from the atlas so they batch with sprites.
-- Glowing particles also get a soft additive halo, Noita style.
local Settings = require("src.core.settings")
local Iso = require("src.core.iso")
local Sprites = require("src.gfx.sprites")

local Particles = { load = 0 }
Particles.__index = Particles

local DENSITY = { [0] = 0, [1] = 0.3, [2] = 0.65, [3] = 1 }

function Particles.new(max)
    local self = setmetatable({ list = {}, n = 0, max = max or 3000, landed = {} }, Particles)
    for i = 1, self.max do
        self.list[i] = { x = 0, y = 0, z = 0, vx = 0, vy = 0, vz = 0, life = 0, maxLife = 1, r = 1, g = 1, b = 1, size = 1, glow = false, grav = 300, drag = 0, stain = false }
    end
    return self
end

-- Scales a requested particle count by the user's particle setting, and down further when the
-- pool is getting full, so huge multi-kills stay smooth instead of spawning thousands of bits.
function Particles.count(n)
    local d = (DENSITY[Settings.get("particles")] or 1) * math.max(0.12, 1 - Particles.load * 1.3)
    local c = n * d
    local whole = math.floor(c)
    if love.math.random() < c - whole then whole = whole + 1 end
    return whole
end

-- opts (optional): glow (bool), grav (default 300), drag (velocity lost per second, 0..),
--   stain (bool): when it hits the ground it is removed and reported in self.landed, so the
--   world can paint it onto the floor (droplets and bits that stay where they fall).
function Particles:spawn(x, y, z, vx, vy, vz, life, color, size, opts)
    if self.n >= self.max then return end
    self.n = self.n + 1
    local p = self.list[self.n]
    p.x, p.y, p.z, p.vx, p.vy, p.vz = x, y, z, vx, vy, vz
    p.life, p.maxLife = life, life
    p.r, p.g, p.b = color[1], color[2], color[3]
    p.size = size or 1
    p.glow = opts and opts.glow or false
    p.grav = opts and opts.grav or 300
    p.drag = opts and opts.drag or 0
    p.stain = opts and opts.stain or false
end

-- Radial burst of debris, e.g. when a bug pops.
function Particles:burst(x, y, n, colors, speed, up, opts)
    for _ = 1, Particles.count(n) do
        local a = love.math.random() * math.pi * 2
        local s = (0.3 + love.math.random() * 0.7) * (speed or 60)
        local c = colors[love.math.random(#colors)]
        self:spawn(x, y, 4, math.cos(a) * s, math.sin(a) * s, (up or 60) * (0.5 + love.math.random()),
            0.4 + love.math.random() * 0.5, c, love.math.random() < 0.3 and 2 or 1, opts)
    end
end

-- Fast glowing sparks flying mostly along (dx, dy), for hits.
function Particles:sparks(x, y, n, color, dx, dy, spread, speed)
    local base = math.atan2(dy or 0, dx or 1)
    for _ = 1, Particles.count(n) do
        local a = base + (love.math.random() - 0.5) * (spread or 1.5)
        local s = (0.5 + love.math.random() * 0.8) * (speed or 160)
        self:spawn(x, y, 5, math.cos(a) * s, math.sin(a) * s, 20 + love.math.random() * 40,
            0.12 + love.math.random() * 0.15, color, 1, { glow = true, grav = 150, drag = 6 })
    end
end

function Particles:update(dt)
    Particles.load = self.n / self.max
    local list = self.list
    local i = 1
    while i <= self.n do
        local p = list[i]
        p.life = p.life - dt
        if p.life <= 0 then
            list[i], list[self.n] = list[self.n], p
            self.n = self.n - 1
        else
            if p.drag > 0 then
                local k = math.max(0, 1 - p.drag * dt)
                p.vx, p.vy = p.vx * k, p.vy * k
            end
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.vz = p.vz - p.grav * dt
            p.z = p.z + p.vz * dt
            if p.z < 0 and p.stain then
                local l = self.landed
                l[#l + 1] = { p.x, p.y, { p.r, p.g, p.b }, p.size }
                list[i], list[self.n] = list[self.n], p
                self.n = self.n - 1
            else
                if p.z < 0 then
                    p.z = 0
                    p.vz = -p.vz * 0.35
                    p.vx, p.vy = p.vx * 0.5, p.vy * 0.5
                end
                i = i + 1
            end
        end
    end
end

function Particles:draw()
    local atlas, q = Sprites.atlas, Sprites.pixel
    local list = self.list
    for i = 1, self.n do
        local p = list[i]
        local sx, sy = Iso.toScreen(p.x, p.y, p.z)
        love.graphics.setColor(p.r, p.g, p.b, math.min(1, p.life / p.maxLife * 2))
        love.graphics.draw(atlas, q, math.floor(sx), math.floor(sy), 0, p.size, p.size)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Additive halos for glowing particles. Call inside an additive blend section.
function Particles:drawGlow()
    local atlas, q = Sprites.atlas, Sprites.glow
    local list = self.list
    for i = 1, self.n do
        local p = list[i]
        if p.glow then
            local sx, sy = Iso.toScreen(p.x, p.y, p.z)
            local a = math.min(1, p.life / p.maxLife * 2) * 0.55
            love.graphics.setColor(p.r, p.g, p.b, a)
            love.graphics.draw(atlas, q, sx, sy, 0, 0.5 * p.size, 0.5 * p.size, 8, 8)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Particles:clear() self.n = 0 end

return Particles
