-- Art and atmosphere touches (Visuals in the Lighting tab). Each has its own setting:
--   Wind Gusts: one shared wind (the weather's, plus gusts) that leaves, grass and weather follow.
--   Horde Tracks: ants leave faint tracks that fade after a few seconds.
--   Squash & Stretch: ants squash when hit and when they land.
--   Death Styles: bodies fall by family (ants curl up, termites flip, bees and wasps spiral).
--   Colour Grade: a gentle per-map or per-act colour grade (in src/core/screen.lua's post shader).
--   Heat Haze: a soft shimmer at desert noon and in heatwaves.
--   Falling Leaves: a few leaves (or dust motes in the desert) drift through the view.
--   Night Glow Decor: glowing mushrooms come out at night on the leafy maps.
local Settings = require("src.core.settings")
local Iso = require("src.core.iso")
local Sprites = require("src.gfx.sprites")

local Ambience = {}

local sin, cos, floor = math.sin, math.cos, math.floor

local DESERT = { dune_field = true, sandstone_wash = true }
local LEAFY = { forest_floor = true, rainforest_floor = true, rotting_log = true, dappled_garden = true, backyard = true, wildflower_meadow = true }

-- Per-map colour grades: tint r, g, b and saturation.
local GRADES = {
    backyard = { 1.0, 1.0, 0.98, 1.05 }, forest_floor = { 0.96, 1.02, 0.95, 1.08 },
    rainforest_floor = { 0.92, 1.03, 0.98, 1.12 }, dune_field = { 1.05, 0.99, 0.9, 1.04 },
    sandstone_wash = { 1.06, 0.98, 0.9, 1.0 }, mown_lawn = { 0.98, 1.03, 0.95, 1.06 },
    puddle_patio = { 0.95, 0.99, 1.04, 0.98 }, rotting_log = { 1.0, 0.97, 0.93, 1.02 },
    wildflower_meadow = { 1.03, 1.0, 0.97, 1.1 }, dappled_garden = { 0.98, 1.02, 0.96, 1.06 },
}
-- Per-act grades: lush, dry gold, dusky violet.
local ACT = { { 0.97, 1.03, 0.96, 1.1 }, { 1.05, 1.0, 0.9, 0.98 }, { 1.0, 0.94, 1.04, 0.95 } }

-- tint r, g, b, saturation for the post shader (1, 1, 1, 1 = untouched).
function Ambience.grade(world)
    local mode = Settings.get("colourGrade")
    if mode == "off" or not world then return 1, 1, 1, 1 end
    local g
    if mode == "act" then g = ACT[math.min(3, world.act or 1)]
    else g = GRADES[world.stage and world.stage.id or ""] end
    if not g then return 1, 1, 1, 1 end
    return g[1], g[2], g[3], g[4]
end

-- Heat haze amount 0..1.
function Ambience.haze(world)
    if not world or not Settings.get("heatHaze") or Settings.get("reduceFlashing") then return 0 end
    local w = world.weather
    local id = w and w.def and w.def.id
    if id == "heatwave" then return w:strength() end
    if DESERT[world.stage.id] then return math.max(0, (world:daylight() - 0.75) * 4) * 0.6 end
    return 0
end

function Ambience.update(world, dt)
    -- the shared wind: the weather's push plus slow gusts
    local w = world.weather
    local base = (w.def and w.def.wind and w.def.wind[1] or 0) / 60 * w:strength()
    local gust = 0
    if Settings.get("windGusts") then
        gust = (love.math.noise(world.time * 0.25, 7) - 0.5) * 1.2
        gust = gust * gust * (gust > 0 and 1 or -1) * 2
    end
    world.wind, world.windGust = base + gust, gust
    -- tracks
    if Settings.get("hordeTracks") then
        world.trackT = (world.trackT or 0) - dt
        if world.trackT <= 0 then
            world.trackT = 0.25
            local tracks = world.tracks or {}
            world.tracks = tracks
            local made = 0
            for i = 1, world.enemyCount do
                local e = world.enemies[i]
                if made >= 20 then break end
                if not e.hidden and (e.z or 0) < 2 and ((e.vx or 0) ~= 0 or (e.vy or 0) ~= 0) and (e.uid or i) % 3 == floor(world.time * 4) % 3 then
                    made = made + 1
                    if #tracks >= 360 then table.remove(tracks, 1) end
                    tracks[#tracks + 1] = { x = e.x, y = e.y, t = 0, r = (e.radius or 5) * 0.8 }
                end
            end
        end
    end
    local tracks = world.tracks
    if tracks then
        for i = #tracks, 1, -1 do
            local tr = tracks[i]
            tr.t = tr.t + dt
            if tr.t > 8 then table.remove(tracks, i) end
        end
    end
    -- leaves
    if Settings.get("fallingLeaves") then
        world.leaves = world.leaves or {}
        for _, l in ipairs(world.leaves) do
            l.y = l.y + l.vy * dt
            l.x = l.x + (l.vx + (world.wind or 0) * 18 + sin(world.time * l.f + l.seed) * 8) * dt
            l.a = l.a + l.spin * dt
            l.life = l.life - dt
        end
    end
end

-- Under everything on the ground (after the ground itself).
function Ambience.drawGround(world)
    local tracks = world.tracks
    if not tracks or not Settings.get("hordeTracks") then return end
    local lg = love.graphics
    local dark = DESERT[world.stage.id] and 0.18 or 0.12
    for _, tr in ipairs(tracks) do
        local sx, sy = Iso.toScreen(tr.x, tr.y)
        lg.setColor(0.08, 0.06, 0.04, dark * (1 - tr.t / 8))
        lg.draw(Sprites.atlas, Sprites.glow, sx, sy + 1, 0, tr.r / 16 * 1.4, tr.r / 16 * 0.7, 8, 8)
    end
    lg.setColor(1, 1, 1, 1)
end

-- Ground decor that only shows at night: glowing mushrooms in fixed spots on leafy maps.
local function mushroomSpots(world)
    if world._mush then return world._mush end
    local spots = {}
    local S = world.size or 900
    local rng = love.math.newRandomGenerator(#(world.stage.id or "x") * 977 + 13)
    for i = 1, 9 do
        spots[i] = { x = rng:random() * (S - 80) + 40, y = rng:random() * (S - 80) + 40, n = rng:random(2, 4), hue = rng:random(1, 3) }
    end
    world._mush = spots
    return spots
end
local HUES = { { 0.45, 1, 0.75 }, { 0.55, 0.8, 1 }, { 0.85, 0.6, 1 } }

local function nightK(world)
    if not Settings.get("glowDecor") or not LEAFY[world.stage.id] then return 0 end
    return math.max(0, (0.55 - world:daylight()) / 0.4)
end

function Ambience.drawDecor(world)
    local k = nightK(world)
    if k <= 0 then return end
    local lg = love.graphics
    for _, m in ipairs(mushroomSpots(world)) do
        local c = HUES[m.hue]
        for j = 1, m.n do
            local sx, sy = Iso.toScreen(m.x + j * 5 - 7, m.y + (j % 2) * 4)
            local s = 1.4 + (j % 3) * 0.6
            lg.setColor(0.85, 0.82, 0.75, k)
            lg.rectangle("fill", floor(sx), floor(sy - s * 2), 1, s * 2)
            lg.setColor(c[1], c[2], c[3], k)
            lg.ellipse("fill", sx + 0.5, sy - s * 2, s * 1.5, s * 0.8)
        end
    end
    lg.setColor(1, 1, 1, 1)
end

-- Light sources for the light pass: light(x, y, r, cr, cg, cb, a)
function Ambience.lights(world, light)
    local k = nightK(world)
    if k <= 0 then return end
    for _, m in ipairs(mushroomSpots(world)) do
        local c = HUES[m.hue]
        local sx, sy = Iso.toScreen(m.x, m.y)
        light(sx, sy, 50, c[1], c[2], c[3], 0.5 * k * (0.85 + 0.15 * sin(world.time * 1.7 + m.x)))
    end
end

-- Falling leaves: after the lighting (lit like the scene would be is not needed; they're tiny).
function Ambience.drawLeaves(world, ox, oy, vw, vh)
    if not Settings.get("fallingLeaves") then world.leaves = nil return end
    local leaves = world.leaves or {}
    world.leaves = leaves
    local desert = DESERT[world.stage.id]
    -- keep about a dozen in view
    for i = #leaves, 1, -1 do
        local l = leaves[i]
        if l.life <= 0 or l.y > oy + vh + 20 or l.x < ox - 60 or l.x > ox + vw + 60 then table.remove(leaves, i) end
    end
    while #leaves < (desert and 18 or 10) do
        leaves[#leaves + 1] = { x = ox + love.math.random() * vw, y = oy - 10 - love.math.random() * vh * 0.5,
            vx = (love.math.random() - 0.5) * 10, vy = desert and 6 or (14 + love.math.random() * 12),
            a = love.math.random() * 6, spin = (love.math.random() - 0.5) * 3, f = 1 + love.math.random(),
            seed = love.math.random() * 10, life = 18, c = love.math.random(1, 3) }
    end
    local lg = love.graphics
    local day = 0.35 + 0.65 * world:daylight()
    for _, l in ipairs(leaves) do
        if desert then
            lg.setColor(0.95 * day, 0.85 * day, 0.65 * day, 0.35)
            lg.rectangle("fill", floor(l.x), floor(l.y), 1, 1)
        else
            local c = l.c == 1 and { 0.55, 0.62, 0.25 } or l.c == 2 and { 0.75, 0.48, 0.2 } or { 0.62, 0.3, 0.18 }
            lg.setColor(c[1] * day, c[2] * day, c[3] * day, 0.85)
            local w = 2.2 * math.abs(cos(l.a)) + 0.6
            lg.ellipse("fill", l.x, l.y, w, 1.2)
        end
    end
    lg.setColor(1, 1, 1, 1)
end

-- Death Styles: how a falling body is drawn. Returns angle, scale x, scale y.
function Ambience.corpseStyle(c)
    if not c.style or not Settings.get("deathStyles") then return c.angle, c.scale, c.scale end
    local k = math.min(1, c.t / math.max(0.01, c.life))
    if c.style == "curl" then
        return c.angle, c.scale * (1 - 0.25 * k), c.scale * (1 - 0.35 * k)
    elseif c.style == "flip" then
        return c.angle, c.scale, c.scale * cos(k * math.pi)
    elseif c.style == "spiral" then
        return c.angle + k * 9, c.scale * (1 - 0.3 * k), c.scale * (1 - 0.3 * k)
    end
    return c.angle, c.scale, c.scale
end

function Ambience.styleOf(def)
    local f = def.family
    if f == "bee" or f == "wasp" or f == "hornet" then return "spiral" end
    if f == "termite" then return "flip" end
    return "curl"
end

return Ambience
