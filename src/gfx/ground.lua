-- Pre-renders a stage's isometric floor into a canvas once, so the floor costs one draw call.
-- Also owns the decal canvas that bug splats are painted onto.
local util = require("src.core.util")
local Iso = require("src.core.iso")

local Ground = {}
Ground.__index = Ground

local MARGIN = 64

function Ground.new(stage)
    local self = setmetatable({}, Ground)
    local S = stage.size
    self.size = S
    self.w, self.h = S * 2 + MARGIN * 2, S + MARGIN * 2
    -- Projected position of the canvas' top-left corner.
    self.x, self.y = -S - MARGIN, -MARGIN
    self.canvas = love.graphics.newCanvas(self.w, self.h)
    self.decals = love.graphics.newCanvas(self.w, self.h)
    self.decals:renderTo(function() love.graphics.clear(0, 0, 0, 0) end)
    self:render(stage)
    return self
end

-- Per-pixel ground texture, Noita style: every pixel is generated from world position, so the
-- floor has fine speckle and grain instead of flat tiles. Runs once per stage load.
--
-- Layout: a concrete patio in the middle (speckled aggregate, expansion joints, cracks, stains)
-- surrounded by lawn, with tall grass blades along the back edges and a soil cross-section
-- under the front edges.
function Ground:render(stage)
    local S = stage.size
    local pal = {}
    for k, v in pairs(stage.palette) do pal[k] = util.hex(v) end
    local seed = (stage.seed or 1) * 17.31
    local rng = love.math.newRandomGenerator(stage.seed or 1)
    local noise = love.math.noise
    local floor, random = math.floor, love.math.random
    love.math.setRandomSeed(stage.seed or 1)

    local p0, p1 = S * (stage.patioInset or 0.2), S * (1 - (stage.patioInset or 0.2))
    local joint = stage.jointSpacing or 120
    local depth = stage.cliffDepth or 22
    local ox, oy = self.x, self.y

    local function mix(a, b, t) return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t end
    local grass = { pal.grass1, pal.grass2, pal.grass3, pal.grass4 }
    local soil = { pal.soil1, pal.soil2, pal.soil3 }

    local data = love.image.newImageData(self.w, self.h)
    data:mapPixel(function(px, py)
        local sx, sy = px + ox, py + oy
        local wx, wy = Iso.toWorld(sx, sy)
        if wx < 0 or wy < 0 or wx > S or wy > S then
            -- Soil cross-section under the front edges.
            -- Height below the plateau edge directly above this pixel.
            local ex, ey = Iso.toWorld(sx, sy - depth)
            if ex >= 0 and ey >= 0 and ex <= S + 0.5 and ey <= S + 0.5 and (wx > S or wy > S) then
                local band = floor((sy + noise(sx * 0.05, seed) * 4) / 5) % 3 + 1
                local r, g, b = soil[band][1], soil[band][2], soil[band][3]
                local shade = (wx > S) and 0.85 or 1
                local n = (random() - 0.5) * 0.06
                if random() < 0.015 then r, g, b = pal.pebble[1], pal.pebble[2], pal.pebble[3] end
                return (r + n) * shade, (g + n) * shade, (b + n) * shade, 1
            end
            return 0, 0, 0, 0
        end

        local edgeN = noise(wx * 0.03 + seed, wy * 0.03) * 10 - 5
        local inPatio = wx > p0 + edgeN and wx < p1 - edgeN and wy > p0 - edgeN and wy < p1 + edgeN
        if inPatio then
            local r, g, b = pal.concrete[1], pal.concrete[2], pal.concrete[3]
            -- large stains and damp patches
            local stain = noise(wx * 0.012 + seed, wy * 0.012 - seed)
            local t = math.max(0, stain - 0.55) * 0.9
            r, g, b = r - t * 0.12, g - t * 0.12, b - t * 0.1
            -- aggregate speckle
            local q = random()
            if q < 0.08 then r, g, b = mix({ r, g, b }, pal.concreteDark, 0.6)
            elseif q < 0.12 then r, g, b = mix({ r, g, b }, pal.concreteLight, 0.7)
            end
            local n = (random() - 0.5) * 0.035
            r, g, b = r + n, g + n, b + n
            -- expansion joints
            local jx = (wx - p0) % joint
            local jy = (wy - p0) % joint
            if jx < 1.1 or jy < 1.1 then r, g, b = pal.joint[1], pal.joint[2], pal.joint[3] end
            -- soft shadow inside the patio edge
            local edge = math.min(wx - p0 - edgeN, p1 - edgeN - wx, wy - p0 + edgeN, p1 + edgeN - wy)
            if edge < 6 then
                local k = (1 - edge / 6) * 0.25
                r, g, b = r * (1 - k), g * (1 - k), b * (1 - k)
            end
            return r, g, b, 1
        end

        -- Lawn: streaky blade texture stretched vertically on screen.
        local streak = noise(sx * 0.45 + seed, sy * 0.09)
        local patch = noise(wx * 0.02 - seed, wy * 0.02 + seed)
        local v = streak * 0.7 + patch * 0.3 + (random() - 0.5) * 0.25
        local idx = v < 0.35 and 1 or v < 0.5 and 2 or v < 0.68 and 3 or 4
        local c = grass[idx]
        local r, g, b = c[1], c[2], c[3]
        if random() < 0.006 then r, g, b = pal.flower[1], pal.flower[2], pal.flower[3] end
        return r, g, b, 1
    end)

    -- Cracks: short random walks across the concrete.
    for _ = 1, stage.cracks or 26 do
        local wx, wy = p0 + rng:random() * (p1 - p0), p0 + rng:random() * (p1 - p0)
        local a = rng:random() * math.pi * 2
        for _ = 1, rng:random(15, 60) do
            a = a + (rng:random() - 0.5) * 0.9
            wx, wy = wx + math.cos(a) * 1.5, wy + math.sin(a) * 1.5
            if wx < p0 or wx > p1 or wy < p0 or wy > p1 then break end
            local sx, sy = Iso.toScreen(wx, wy)
            local px, py = floor(sx - ox), floor(sy - oy)
            if px >= 0 and py >= 0 and px < self.w and py < self.h then
                data:setPixel(px, py, pal.crack[1], pal.crack[2], pal.crack[3], 1)
                if py + 1 < self.h then
                    local r, g, b = data:getPixel(px, py + 1)
                    data:setPixel(px, py + 1, r * 1.08, g * 1.08, b * 1.08, 1)
                end
            end
        end
    end

    local img = love.graphics.newImage(data)
    love.graphics.push("all")
    love.graphics.setCanvas(self.canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, 0, 0)
    love.graphics.translate(-ox, -oy)

    -- Blades of grass: tall along the back edges, short along the patio rim.
    local blades = { pal.blade1, pal.blade2, pal.blade3, pal.grass4 }
    local function blade(wx, wy, h)
        local sx, sy = Iso.toScreen(wx, wy)
        sx, sy = floor(sx), floor(sy)
        local lean = (rng:random() - 0.5) * h * 0.5
        local c = blades[rng:random(1, #blades)]
        love.graphics.setColor(c)
        love.graphics.line(sx + 0.5, sy, sx + 0.5 + lean, sy - h)
        love.graphics.setColor(pal.bladeTip)
        love.graphics.points(floor(sx + lean) + 0.5, sy - h + 0.5)
    end
    love.graphics.setLineStyle("rough")
    love.graphics.setLineWidth(1)
    for i = 0, S, 1.3 do
        for _ = 1, 2 do
            blade(i, rng:random() * 6, 6 + rng:random() * (stage.edgeGrass or 18))
            blade(rng:random() * 6, i, 6 + rng:random() * (stage.edgeGrass or 18))
        end
    end
    for i = p0, p1, 2.5 do
        blade(i, p0 - 3 - rng:random() * 3, 2 + rng:random() * 5)
        blade(p0 - 3 - rng:random() * 3, i, 2 + rng:random() * 5)
    end
    -- A few fallen leaves and pebbles on the patio.
    for _ = 1, (stage.leaves or 40) do
        local sx, sy = Iso.toScreen(p0 + rng:random() * (p1 - p0), p0 + rng:random() * (p1 - p0))
        sx, sy = floor(sx), floor(sy)
        love.graphics.setColor(rng:random() < 0.5 and pal.leafA or pal.leafB)
        love.graphics.rectangle("fill", sx, sy, 3, 2)
        love.graphics.rectangle("fill", sx + 1, sy - 1, 2, 1)
        love.graphics.setColor(pal.leafVein)
        love.graphics.rectangle("fill", sx + 1, sy, 2, 1)
    end
    love.graphics.pop()
end

-- Decals. These paint onto the persistent decal canvas; call them with that canvas bound
-- (World:flushDecals does this). Everything a fight leaves behind accumulates here for free.

-- A directional splat: a wet core plus a streak sprayed along (dx, dy).
function Ground:splat(x, y, color, size, dx, dy)
    local Sprites = require("src.gfx.sprites")
    local r = size or 4
    dx, dy = dx or 0, dy or 0
    local lg = love.graphics
    local atlas, blobs, pix = Sprites.atlas, Sprites.blobs, Sprites.pixel
    local cr, cg, cb = color[1], color[2], color[3]
    -- wet pool: 2-4 lumpy blobs from the atlas, trailing along the blow
    local k = r / 7
    lg.setColor(cr, cg, cb, 1)
    for b = 0, love.math.random(1, 3) do
        local side = (love.math.random() - 0.5) * r * 0.9
        local px, py = Iso.toScreen(x + dx * r * 0.5 * b - dy * side, y + dy * r * 0.5 * b + dx * side)
        local s = k * (1 - b * 0.18) * (0.7 + love.math.random() * 0.5)
        lg.draw(atlas, blobs[love.math.random(#blobs)], math.floor(px - self.x), math.floor(py - self.y),
            0, s * (love.math.random() < 0.5 and -1 or 1), s, 9, 5)
    end
    -- spray streaks flung along the blow
    for _ = 1, r * 3 do
        local t = r + love.math.random() ^ 1.4 * r * 4
        local side = (love.math.random() - 0.5) * r * (0.4 + t / r * 0.25)
        local px, py = Iso.toScreen(x + dx * t - dy * side, y + dy * t + dx * side)
        lg.setColor(cr * 0.8, cg * 0.8, cb * 0.8, 0.75 * (1 - t / (r * 5.2)))
        lg.draw(atlas, pix, math.floor(px - self.x), math.floor(py - self.y))
    end
    lg.setColor(1, 1, 1, 1)
end

-- A single droplet or bit of debris where a particle landed.
function Ground:drop(x, y, color, size)
    local px, py = Iso.toScreen(x, y)
    love.graphics.setColor(color[1] * 0.85, color[2] * 0.85, color[3] * 0.85, 0.75)
    local Sprites = require("src.gfx.sprites")
    love.graphics.draw(Sprites.atlas, Sprites.pixel, math.floor(px - self.x), math.floor(py - self.y), 0, size or 1, 1)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Remains: a dead bug stays where it came to rest, darkened.
function Ground:stamp(sprite, x, y, angle, scale, tint)
    local Sprites = require("src.gfx.sprites")
    local px, py = Iso.toScreen(x, y)
    tint = tint or { 0.3, 0.27, 0.25, 0.6 }
    love.graphics.setColor(tint)
    Sprites.draw(sprite, 1, px - self.x, py - self.y, angle, false, scale or 1)
    love.graphics.setColor(1, 1, 1, 1)
end

function Ground:clearDecals()
    self.decals:renderTo(function() love.graphics.clear(0, 0, 0, 0) end)
end

function Ground:draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.canvas, self.x, self.y)
    love.graphics.draw(self.decals, self.x, self.y)
end

-- World position -> pixel on the floor canvas (for content/decor painting onto it).
function Ground:toCanvas(wx, wy)
    local sx, sy = Iso.toScreen(wx, wy)
    return sx - self.x, sy - self.y
end

-- ...and the projected position of that pixel (for decor lights).
function Ground:toProjected(cx, cy) return cx + self.x, cy + self.y end

return Ground
