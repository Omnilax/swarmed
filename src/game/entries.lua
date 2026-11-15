-- Ways into the arena. Most groups still march in from the edge, but some take another way:
--   burrow: the soil heaves up somewhere near the player, then the group bursts out of it.
--   drop:   flyers come down from the sky; a shadow grows on the ground where they will land.
--   nest:   on some waves a few nest holes open in the floor and the wave's groups pour out of
--           them as well as the edge. The holes close again when the wave is cleared.
--   ring:   a pack of small burrows heaves up in a wide circle around the player all at once
--           (later waves, instead of some of the stray packs).
-- Every way but the edge is telegraphed (`warn` seconds of mound / shadow / opening hole) and
-- never opens close to the player, and a hole waits while the player stands on top of it.
--
-- Data: an enemy's spawn.entries = { "edge", "burrow", ... } lists the ways it may use (first =
-- the most likely); without it, "flying" ants drop in, "burrower" ones dig up, the rest walk or
-- dig, and queens always walk in from the edge. The stage / mode spawn config's `entries`
-- table below tunes when each way starts and how often (set entryStyles = false: edge only).
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")
local Sprites = require("src.gfx.sprites")
local Palette = require("src.ui.palette")

local Entries = {}

Entries.DEFAULTS = {
    burrow = { minWave = 3, chance = 0.22, warn = 1.4, near = { 95, 165 } },
    drop = { minWave = 2, chance = 0.6, warn = 1.0, near = { 90, 160 }, height = 70 },
    nest = { minWave = 4, chance = 0.45, holes = { 1, 3 }, warn = 1.8, away = 170, use = 0.5 },
    ring = { minWave = 6, chance = 0.25, warn = 1.6, radius = { 120, 150 }, spots = { 5, 8 }, each = { 2, 3 } },
}

local SOIL = { { 0.36, 0.26, 0.17 }, { 0.5, 0.38, 0.24 }, { 0.24, 0.17, 0.11 } }

-- The tuning for one way (stage / mode `entryStyles` overrides on top of the defaults), or nil
-- when it is switched off.
function Entries.cfg(spawner, kind)
    local over = spawner.cfg.entryStyles
    if over == false then return nil end
    local base = Entries.DEFAULTS[kind]
    local o = over and over[kind]
    if o == false then return nil end
    if not o then return base end
    local c = {}
    for k, v in pairs(base) do c[k] = v end
    for k, v in pairs(o) do c[k] = v end
    return c
end

local function hasTag(def, tag)
    for _, t in ipairs(def.tags or {}) do if t == tag then return true end end
    return false
end

-- The ways this species may come in, most likely first.
function Entries.waysFor(def)
    if def.spawn.entries then return def.spawn.entries end
    if def.boss then return { "edge" } end
    if hasTag(def, "flying") then return { "drop", "edge" } end
    if hasTag(def, "burrower") then return { "burrow", "edge" } end
    return { "edge", "burrow" }
end

local function allowed(spawner, kind, wave)
    local c = Entries.cfg(spawner, kind)
    return c and wave >= (c.minWave or 1) and c
end

-- How a group of `def` arrives this wave: "edge", "burrow" or "drop".
function Entries.pick(spawner, def)
    local wave = math.max(1, spawner.wave)
    local ways = Entries.waysFor(def)
    for i, kind in ipairs(ways) do
        if kind ~= "edge" then
            local c = allowed(spawner, kind, wave)
            -- the species' own way (listed first) is used more often
            local chance = c and (c.chance or 0) * (i == 1 and 1.4 or 1)
            if c and love.math.random() < chance then return kind end
        end
    end
    return "edge"
end

-- A spot `near` world units from the player (a ring around them), inside the arena.
function Entries.nearPoint(spawner, near)
    local world, p = spawner.world, spawner.world.player
    local S, m = world.size, 24
    local lo, hi = near[1], near[2]
    for _ = 1, 12 do
        local a = love.math.random() * math.pi * 2
        local r = lo + love.math.random() * (hi - lo)
        local x, y = p.x + math.cos(a) * r, p.y + math.sin(a) * r
        if x > m and x < S - m and y > m and y < S - m then return x, y end
    end
    -- hemmed into a corner: the far side of the arena centre is always roomy
    local cx, cy = S / 2 + (S / 2 - p.x) * 0.5, S / 2 + (S / 2 - p.y) * 0.5
    return cx, cy
end

-- Open a telegraphed way in: a portal that becomes a stream when its warning runs out.
function Entries.open(spawner, kind, def, count, x, y, opts)
    local c = Entries.cfg(spawner, kind == "ringspot" and "ring" or kind) or {}
    local pt = { kind = kind, def = def, count = count, x = x, y = y, t = 0, warn = c.warn or 1.2,
        opts = opts, height = c.height, seed = love.math.random() * 10 }
    spawner.portals[#spawner.portals + 1] = pt
    if kind == "burrow" or kind == "ringspot" then Audio.play("rumble", { volume = kind == "ringspot" and 0.5 or 1 }) end
    return pt
end

-- Send a group the way it wants to come. Edge groups start streaming right away.
function Entries.send(spawner, def, count, x, y, opts)
    local kind = Entries.pick(spawner, def)
    if kind == "edge" then return spawner:spawnGroup(def, count, x, y, opts) end
    local c = Entries.cfg(spawner, kind)
    local px, py = Entries.nearPoint(spawner, c.near)
    Entries.open(spawner, kind, def, count, px, py, opts)
end

-- A ring of small burrows around the player (instead of a stray pack). Returns true if sent.
function Entries.ring(spawner, def)
    local c = allowed(spawner, "ring", math.max(1, spawner.wave))
    if not c or def.boss or love.math.random() >= c.chance then return false end
    local ways = Entries.waysFor(def)
    local digs = false
    for _, k in ipairs(ways) do if k == "burrow" then digs = true end end
    if not digs then return false end
    local p, S = spawner.world.player, spawner.world.size
    local n = love.math.random(c.spots[1], c.spots[2])
    local r = c.radius[1] + love.math.random() * (c.radius[2] - c.radius[1])
    local a0 = love.math.random() * math.pi * 2
    for i = 1, n do
        local a = a0 + (i - 1) / n * math.pi * 2
        local x = math.max(20, math.min(S - 20, p.x + math.cos(a) * r))
        local y = math.max(20, math.min(S - 20, p.y + math.sin(a) * r))
        Entries.open(spawner, "ringspot", def, love.math.random(c.each[1], c.each[2]), x, y)
    end
    return true
end

-- Nest holes for this wave (maybe none): they open at the start and replace some entries.
function Entries.openNests(spawner)
    spawner.holes = {}
    local c = allowed(spawner, "nest", spawner.wave)
    if not c or love.math.random() >= c.chance then return end
    local world, p = spawner.world, spawner.world.player
    local S = world.size
    local n = love.math.random(c.holes[1], c.holes[2])
    for _ = 1, n do
        for _ = 1, 10 do
            local x, y = 50 + love.math.random() * (S - 100), 50 + love.math.random() * (S - 100)
            local ok = (x - p.x) ^ 2 + (y - p.y) ^ 2 > c.away * c.away
            for _, h in ipairs(spawner.holes) do
                if (x - h.x) ^ 2 + (y - h.y) ^ 2 < 120 * 120 then ok = false end
            end
            if ok then
                spawner.holes[#spawner.holes + 1] = { x = x, y = y, t = 0, warn = c.warn, open = false, puff = 0,
                    seed = love.math.random() * 10 }
                break
            end
        end
    end
    if #spawner.holes > 0 then Audio.play("rumble") end
end

-- Which of this wave's groups come out of a hole instead of their edge entry.
function Entries.holeFor(spawner)
    local holes = spawner.holes
    if not holes or #holes == 0 then return nil end
    local c = Entries.cfg(spawner, "nest")
    if not c or love.math.random() >= (c.use or 0.5) then return nil end
    return holes[love.math.random(#holes)]
end

-- Burst particles for one ant arriving by the way its stream came.
function Entries.arrive(world, e, style, st)
    if style == "burrow" or style == "nest" then
        e.squash = 0.2
        if love.math.random() < 0.6 then
            world.particles:burst(e.x, e.y, 4, SOIL, 55, 70, { grav = 300, stain = true })
        end
    elseif style == "drop" then
        e.dropH = (st.height or 70) * (0.85 + love.math.random() * 0.3)
    end
end

local function tooClose(world, x, y, r)
    local p = world.player
    return not p.dead and (p.x - x) ^ 2 + (p.y - y) ^ 2 < r * r
end

function Entries.update(spawner, dt)
    local world = spawner.world
    local portals = spawner.portals
    for i = #portals, 1, -1 do
        local pt = portals[i]
        pt.t = pt.t + dt
        if pt.kind ~= "drop" and love.math.random() < dt * 14 then
            world.particles:spawn(pt.x + (love.math.random() - 0.5) * 8, pt.y + (love.math.random() - 0.5) * 8, 1,
                (love.math.random() - 0.5) * 20, (love.math.random() - 0.5) * 20, 30 + 40 * pt.t / pt.warn, 0.4,
                SOIL[love.math.random(3)], 1, { grav = 300 })
        end
        -- never right on top of the player: a mound waits (a little) while they stand on it
        local ready = pt.t >= pt.warn and (not tooClose(world, pt.x, pt.y, 30) or pt.t > pt.warn + 1.2)
        if ready then
            table.remove(portals, i)
            local style = pt.kind == "ringspot" and "burrow" or pt.kind
            local st = spawner:spawnGroup(pt.def, pt.count, pt.x, pt.y, pt.opts)
            if st then st.style, st.height = style, pt.height end
            if style == "burrow" then
                world.particles:burst(pt.x, pt.y, 12, SOIL, 80, 90, { grav = 300, stain = true })
                if world.camera and world.camera.shake then world.camera:shake(0.12) end
            end
        end
    end
    -- nest holes: open up, then stay open for the wave; close (and vanish) after it
    local holes = spawner.holes or {}
    for i = #holes, 1, -1 do
        local h = holes[i]
        h.t = h.t + dt
        if not h.open and h.t >= h.warn then
            h.open = true
            world.particles:burst(h.x, h.y, 14, SOIL, 70, 80, { grav = 300, stain = true })
        end
        h.puff = math.max(0, h.puff - dt)
        if h.closing then
            h.closing = h.closing - dt
            if h.closing <= 0 then table.remove(holes, i) end
        end
    end
end

-- A group due out of a hole: false while it is still opening or the player stands on it.
function Entries.holeReady(spawner, h, waited)
    if h.closing then return true end
    if not h.open then return false end
    return not tooClose(spawner.world, h.x, h.y, 34) or waited > 1.5
end

function Entries.closeNests(spawner)
    for _, h in ipairs(spawner.holes or {}) do
        if not h.closing then h.closing = 0.8 end
    end
end

-- Groups still waiting in portals (for "ants left" counts and the end of the wave).
function Entries.pending(spawner)
    local n = 0
    for _, pt in ipairs(spawner.portals) do n = n + pt.count end
    return n
end

function Entries.clear(spawner)
    spawner.portals, spawner.holes = {}, {}
end

-- Drawn on the ground under everything (World:draw, right after hazards).
function Entries.drawGround(spawner, time)
    local lg = love.graphics
    local atlas, glow, px = Sprites.atlas, Sprites.glow, Sprites.pixel
    for _, h in ipairs(spawner.holes or {}) do
        local x, y = Iso.toScreen(h.x, h.y)
        local k = math.min(1, h.t / h.warn)
        if h.closing then k = math.max(0, h.closing / 0.8) end
        local w = 5 + 10 * k
        -- a ring of churned soil, then the dark mouth of the nest
        lg.setColor(0.42, 0.31, 0.2, 0.9)
        lg.ellipse("fill", x, y + 1, w + 3, (w + 3) * 0.5)
        lg.setColor(0.07, 0.04, 0.03, 0.95)
        lg.ellipse("fill", x, y + 1, w, w * 0.5)
        for s = 0, 7 do
            local a = s / 8 * math.pi * 2 + h.seed
            local j = h.puff > 0 and (love.math.random() - 0.5) * 1.5 or 0
            lg.setColor(SOIL[s % 3 + 1][1], SOIL[s % 3 + 1][2], SOIL[s % 3 + 1][3], 1)
            lg.draw(atlas, px, math.floor(x + math.cos(a) * (w + 2.5) + j), math.floor(y + 1 + math.sin(a) * (w + 2.5) * 0.5), 0, 2, 1)
        end
        if not h.open then
            -- still opening: a pulsing warning rim
            local a = 0.55 + 0.35 * math.sin(time * 14)
            Palette.ring(x, y + 1, w + 5, (w + 5) * 0.5, { 1, 0.55, 0.25 }, a)
            local r = 34 - 26 * k
            Palette.ring(x, y + 1, w + r, (w + r) * 0.5, { 1, 0.55, 0.25 }, a)
        end
    end
    for _, pt in ipairs(spawner.portals) do
        local x, y = Iso.toScreen(pt.x, pt.y)
        local k = math.min(1, pt.t / pt.warn)
        local pulse = 0.5 + 0.5 * math.sin(time * (8 + 10 * k))
        if pt.kind == "drop" then
            -- a shadow growing as they come down, and a ring marking where
            local hc = Palette.contrast()
            lg.setColor(0, 0, 0, (hc and 0.45 or 0.15) + (hc and 0.4 or 0.3) * k)
            lg.draw(atlas, glow, x, y + 1, 0, 0.6 + 1.6 * k, (0.6 + 1.6 * k) * 0.5, 8, 8)
            local r = 30 - 18 * k
            Palette.ring(x, y + 1, r, r * 0.5, { 1, 0.85, 0.4 }, 0.45 + 0.4 * pulse)
            Palette.ring(x, y + 1, 12, 6, { 1, 0.85, 0.4 }, 0.45 + 0.4 * pulse)
        else
            -- heaving soil: a mound that grows and cracks, with a warning rim
            local big = pt.kind == "ringspot" and 0.7 or 1
            local w = (5 + 7 * k) * big
            local sh = k > 0.7 and (love.math.random() - 0.5) * 1.2 or 0
            lg.setColor(0.24, 0.17, 0.11, 0.8)
            lg.ellipse("fill", x + sh, y + 1, w + 1.5, (w + 1.5) * 0.5)
            lg.setColor(0.45, 0.33, 0.21, 0.95)
            lg.ellipse("fill", x + sh, y - k * 1.5, w, w * 0.45)
            lg.setColor(0.12, 0.08, 0.05, 0.9)
            for s = 0, 2 do
                local a = s * 2.1 + pt.seed
                lg.line(x + sh, y - k, x + sh + math.cos(a) * w * k, y - k + math.sin(a) * w * 0.45 * k)
            end
            -- a warning ring closing in on the mound
            local r = w + (30 - 24 * k) * big
            Palette.ring(x, y + 1, r, r * 0.5, { 1, 0.45, 0.2 }, 0.45 + 0.4 * pulse)
        end
    end
    lg.setColor(1, 1, 1, 1)
end

return Entries
