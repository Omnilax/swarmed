-- Shared helpers for things in the arena that are not the player's doing: mid-wave events
-- (content/events), boss encounters (content/bosses), stage mechanics (content/mechanics) and
-- props (content/props). Raw damage to ants and to the player (no player stats, crits or
-- procs), area and lane strikes, and the isometric shapes they draw with.
--
-- Ants killed this way still count as KOs and give XP: luring the colony under a boot or in
-- front of a lawnmower is part of the fun.
local Iso = require("src.core.iso")
local Combat = require("src.game.combat")

local Env = {}

-- What is hurting the player right now (an event / encounter id), for run stats; the director
-- sets it around each event's update, behaviours pass opts.name.
Env.current = nil

local sqrt = math.sqrt

-- Hurt one ant. Encounter bosses (def.encounter) shrug it off, queens take `bossMul` (0.2) of
-- it, burrowed / falling / carried ants are out of reach. Returns true if it died.
-- opts: kx, ky (direction), force (knockback), air (also hits ants high in the air), bossMul
function Env.hurtAnt(world, e, dmg, opts)
    if e.dead or e.hidden or e.dropH or e.held then return false end
    local def = e.def
    if def.encounter then return false end
    opts = opts or {}
    if (e.z or 0) > 6 and not opts.air then return false end
    if def.boss then dmg = dmg * (opts.bossMul or 0.2) end
    e.hp = e.hp - dmg
    e.flash, e.hurtTimer = 0.09, 2
    if opts.force and (opts.kx or opts.ky) then
        local l = sqrt((opts.kx or 0) ^ 2 + (opts.ky or 0) ^ 2) + 0.0001
        e.kvx = e.kvx + (opts.kx or 0) / l * opts.force / e.mass
        e.kvy = e.kvy + (opts.ky or 0) / l * opts.force / e.mass
    end
    if e.hp <= 0 then
        world:killEnemy(e)
        return true
    end
    return false
end

-- Hurt the player (dashing, dodging and blocks work as usual). opts: force (shove away from
-- x, y), slow = { mul, time }, stun (seconds). Returns true if it landed.
function Env.hurtPlayer(world, dmg, x, y, opts)
    local p = world.player
    if p.dead then return false end
    opts = opts or {}
    local hp0 = p.hp
    -- hazards are sized for a 100 HP bug: frail ones (jumping spider) take a smaller share
    dmg = dmg * math.max(0.45, math.min(1, p.stats:get("maxHp") / 100))
    p:hurt(dmg, { x = x or p.x, y = y or p.y, kvx = 0, kvy = 0, hazard = opts.name or Env.current or "hazard" })
    -- (god mode: nothing is taken, but the shove still shows where it would have hit)
    local landed = p.hp < hp0 or (world.flags.god and p.iframes <= 0 and p.dashT <= 0 and not p.blocking)
    if landed and opts.force and opts.force > 0 then
        local dx, dy = p.x - (x or p.x), p.y - (y or p.y)
        if dx * dx + dy * dy < 0.01 then dx, dy = love.math.random() - 0.5, love.math.random() - 0.5 end
        p:knock(dx, dy, opts.force)
    end
    if landed and opts.slow then p:slow(opts.slow[1], opts.slow[2]) end
    if landed and opts.stun and p.stun then p:stun(opts.stun) end
    return landed
end

-- Squared distance from (px, py) to the segment (x1, y1)-(x2, y2), and how far along it (0..1).
function Env.segDist2(px, py, x1, y1, x2, y2)
    local vx, vy = x2 - x1, y2 - y1
    local len2 = vx * vx + vy * vy + 0.0001
    local t = math.max(0, math.min(1, ((px - x1) * vx + (py - y1) * vy) / len2))
    local dx, dy = x1 + vx * t - px, y1 + vy * t - py
    return dx * dx + dy * dy, t
end

function Env.playerIn(world, x, y, r)
    local p = world.player
    if p.dead then return false end
    local dx, dy = p.x - x, p.y - y
    local rr = r + p.radius
    return dx * dx + dy * dy <= rr * rr
end

function Env.playerInLane(world, x1, y1, x2, y2, w)
    local p = world.player
    if p.dead then return false end
    local d2 = Env.segDist2(p.x, p.y, x1, y1, x2, y2)
    local r = w + p.radius
    return d2 <= r * r
end

-- Every ant in a circle takes `dmg` (opts as hurtAnt; force shoves away from the middle).
-- Returns the number killed.
function Env.strikeCircle(world, x, y, r, dmg, opts)
    local kills = 0
    opts = opts or {}
    for _, e in ipairs(Combat.collect(world, x, y, r)) do
        local o = { force = opts.force, kx = e.x - x, ky = e.y - y, air = opts.air, bossMul = opts.bossMul }
        if Env.hurtAnt(world, e, dmg, o) then kills = kills + 1 end
    end
    return kills
end

-- Every ant along a lane (half-width w) takes `dmg`; force shoves it along (kx, ky).
function Env.strikeLane(world, x1, y1, x2, y2, w, dmg, opts)
    local kills = 0
    opts = opts or {}
    for _, e in ipairs(Combat.collectLine(world, x1, y1, x2, y2, w)) do
        local o = { force = opts.force, kx = opts.kx or (x2 - x1), ky = opts.ky or (y2 - y1), air = opts.air, bossMul = opts.bossMul }
        if Env.hurtAnt(world, e, dmg, o) then kills = kills + 1 end
    end
    return kills
end

-- A point on the arena edge and the opposite one, for things that cross the whole arena
-- through (or near) a target point.
function Env.crossing(world, tx, ty, spread)
    local S = world.size
    local a = love.math.random() * math.pi * 2
    local dx, dy = math.cos(a), math.sin(a)
    tx = tx + (love.math.random() - 0.5) * (spread or 0)
    ty = ty + (love.math.random() - 0.5) * (spread or 0)
    -- walk back and forward from the target to the edges
    local function toEdge(sx, sy)
        local t = math.huge
        if sx > 0 then t = math.min(t, (S - tx) / sx) elseif sx < 0 then t = math.min(t, -tx / sx) end
        if sy > 0 then t = math.min(t, (S - ty) / sy) elseif sy < 0 then t = math.min(t, -ty / sy) end
        return tx + sx * t, ty + sy * t
    end
    local x1, y1 = toEdge(-dx, -dy)
    local x2, y2 = toEdge(dx, dy)
    return x1, y1, x2, y2
end

-- A random point at least `away` from the player (and `margin` in from the walls).
function Env.pointAway(world, away, margin)
    local S, p = world.size, world.player
    margin = margin or 40
    local x, y
    for _ = 1, 12 do
        x = margin + love.math.random() * (S - margin * 2)
        y = margin + love.math.random() * (S - margin * 2)
        if (x - p.x) ^ 2 + (y - p.y) ^ 2 >= away * away then return x, y end
    end
    return x, y
end

-- A random point within `r` of (x, y), inside the arena.
function Env.pointNear(world, x, y, r, margin)
    local S = world.size
    margin = margin or 20
    local a, d = love.math.random() * math.pi * 2, sqrt(love.math.random()) * r
    return math.max(margin, math.min(S - margin, x + math.cos(a) * d)), math.max(margin, math.min(S - margin, y + math.sin(a) * d))
end

----------------------------------------------------------------------------------------------
-- Drawing (inside the world's camera transform, projected coordinates)

-- A world-space circle on the ground: an ellipse twice as wide as it is tall.
function Env.ellipse(mode, x, y, r, z)
    local sx, sy = Iso.toScreen(x, y, z)
    love.graphics.ellipse(mode, sx, sy, r * 1.414, r * 0.707, math.max(12, math.min(48, math.floor(r / 2))))
end

-- A world-space lane (segment with half-width w) on the ground, as a polygon.
function Env.lane(mode, x1, y1, x2, y2, w)
    local dx, dy = x2 - x1, y2 - y1
    local l = sqrt(dx * dx + dy * dy) + 0.0001
    local nx, ny = -dy / l * w, dx / l * w
    local ax, ay = Iso.toScreen(x1 + nx, y1 + ny)
    local bx, by = Iso.toScreen(x2 + nx, y2 + ny)
    local cx, cy = Iso.toScreen(x2 - nx, y2 - ny)
    local ex, ey = Iso.toScreen(x1 - nx, y1 - ny)
    love.graphics.polygon(mode, ax, ay, bx, by, cx, cy, ex, ey)
end

-- Warning stripes along a lane: a pulsing red band (telegraph), k = 0..1 how close it is.
function Env.warnLane(x1, y1, x2, y2, w, k, t, color)
    local lg = love.graphics
    local c = color or { 1, 0.25, 0.15 }
    lg.setColor(c[1], c[2], c[3], 0.12 + 0.18 * k + 0.08 * math.sin(t * (8 + k * 14)))
    Env.lane("fill", x1, y1, x2, y2, w)
    lg.setColor(c[1], c[2], c[3], 0.5 + 0.4 * k)
    Env.lane("line", x1, y1, x2, y2, w)
end

-- Warning ring for a circle about to be hit: an outline, filling in as k goes 0..1.
function Env.warnCircle(x, y, r, k, t, color)
    local lg = love.graphics
    local c = color or { 1, 0.25, 0.15 }
    lg.setColor(c[1], c[2], c[3], 0.5 + 0.3 * math.sin(t * 12))
    Env.ellipse("line", x, y, r)
    lg.setColor(c[1], c[2], c[3], 0.08 + 0.22 * k)
    Env.ellipse("fill", x, y, r * math.max(0.05, k))
end

-- A soft dark shadow on the ground (things overhead: a boot, an acorn, a bird).
function Env.shadow(x, y, r, alpha)
    local lg = love.graphics
    lg.setColor(0.05, 0.03, 0.04, alpha * 0.55)
    Env.ellipse("fill", x, y, r)
    lg.setColor(0.05, 0.03, 0.04, alpha * 0.35)
    Env.ellipse("fill", x, y, r * 0.7)
end

-- An anteater's tongue from (x1, y1) reaching `k` (0..1) of the way to (x2, y2).
function Env.tongue(x1, y1, x2, y2, k, width)
    local lg = love.graphics
    local tx, ty = x1 + (x2 - x1) * k, y1 + (y2 - y1) * k
    local ax, ay = Iso.toScreen(x1, y1, 2)
    local bx, by = Iso.toScreen(tx, ty, 2)
    lg.setLineWidth(width or 3)
    lg.setColor(0.55, 0.16, 0.22, 1)
    lg.line(ax, ay, bx, by)
    lg.setLineWidth(math.max(1, (width or 3) - 2))
    lg.setColor(0.92, 0.45, 0.5, 1)
    lg.line(ax, ay - 1, bx, by - 1)
    lg.setLineWidth(1)
    lg.setColor(0.95, 0.55, 0.6, 1)
    lg.circle("fill", bx, by, (width or 3) * 0.7)
end

-- Draw a filled polygon of world points (flat list x1, y1, x2, y2, ...) on the ground.
function Env.poly(mode, pts)
    local out = {}
    for i = 1, #pts, 2 do
        local sx, sy = Iso.toScreen(pts[i], pts[i + 1])
        out[#out + 1], out[#out + 2] = sx, sy
    end
    if #out >= 6 then love.graphics.polygon(mode, out) end
end

return Env
