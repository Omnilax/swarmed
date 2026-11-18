-- Things enemies leave or throw: ground zones (honey puddles) and projectiles (acid spit).
--   zone:       { kind, x, y, r, life, heal (hp/s to enemies inside), slow (player speed x), color,
--                 damage (hp/s to the player inside), pull (drags the player toward the middle, units/s),
--                 update = function(world, z, dt, inside) (custom per-frame logic; inside = player in it),
--                 draw = function(z, sx, sy, fade) (custom look instead of a puddle; sx, sy on screen) }
--   projectile: { x, y, z, vx, vy, vz, r, damage, life, color, splat, turn (curves, radians/s),
--                 onHitPlayer = function(world, s, player) (extra effect when it hits you),
--                 grav (default 120), lob = { x, y, r, slow, slowTime } (lands on a marked spot
--                 and hits everything in r there instead of on contact), pebble (drawn as a stone) }
-- The player's attacks can bat projectiles back (Hazards:deflect); returned shots hurt ants.
-- Both are plain lists on the world, updated and drawn here.
local Iso = require("src.core.iso")
local util = require("src.core.util")
local Sprites = require("src.gfx.sprites")
local Audio = require("src.core.audio")
local Combat = require("src.game.combat")
local RunStats = require("src.game.runstats")
local Palette = require("src.ui.palette")

local Hazards = {}
Hazards.__index = Hazards

function Hazards.new(world)
    return setmetatable({ world = world, zones = {}, shots = {}, walls = {} }, Hazards)
end

-- Silk walls (orb weaver): a sticky strand between two points. Ants that touch it get stuck
-- fast for a while (and are stuck again if they are still on it), so it holds a crowd back like
-- a wall until it has caught `strength` ants or runs out of `life`.
--   { x1, y1, x2, y2, life, strength, hold (seconds stuck), damage (per catch), max (walls kept) }
function Hazards:addWall(w)
    RunStats.tag(self.world, w)
    w.t, w.maxLife, w.caught, w.wobble = 0, w.life, 0, 0
    self.walls[#self.walls + 1] = w
    while #self.walls > (w.max or 3) do table.remove(self.walls, 1) end
    return w
end

-- Who made it (for the death recap): the enemy acting right now, if any.
local function maker(world, h)
    if h.by == nil then h.by = RunStats.enemyName(world.actingEnemy) or false end
end

function Hazards:addZone(z)
    maker(self.world, z)
    z.t, z.maxLife = 0, z.life
    self.zones[#self.zones + 1] = z
    return z
end

function Hazards:shoot(s)
    if s.friendly then RunStats.tag(self.world, s) else maker(self.world, s) end
    s.z, s.vz, s.t = s.z or 6, s.vz or 40, 0
    self.shots[#self.shots + 1] = s
    return s
end

-- A player projectile (bombardier spray, web): flies like a shot but hits ants, up to `pierce`
-- extra ones. Optional onEnd(world, s) runs where it stops (the web spreads out there).
function Hazards:friendlyShot(s)
    s.friendly, s.hitSet, s.pierce = true, {}, s.pierce or 0
    s.grav = s.grav or 0
    s.vz = s.vz or 0
    return self:shoot(s)
end

function Hazards:clear() self.zones, self.shots, self.walls = {}, {}, {} end

function Hazards:updateWalls(dt)
    local world = self.world
    for i = #self.walls, 1, -1 do
        local w = self.walls[i]
        w.t = w.t + dt
        w.wobble = math.max(0, w.wobble - dt * 3)
        if w.t >= w.maxLife or w.caught >= (w.strength or 40) then
            table.remove(self.walls, i)
            world.particles:burst((w.x1 + w.x2) / 2, (w.y1 + w.y2) / 2, 8, { { 1, 1, 0.95 } }, 40, 20)
        else
            local vx, vy = w.x2 - w.x1, w.y2 - w.y1
            local len2 = vx * vx + vy * vy + 0.001
            for _, e in ipairs(Combat.collectLine(world, w.x1, w.y1, w.x2, w.y2, 2)) do
                if e.z < 6 then
                    -- held back: pushed to the side of the strand it came from
                    local t = math.max(0, math.min(1, ((e.x - w.x1) * vx + (e.y - w.y1) * vy) / len2))
                    local dx, dy = e.x - (w.x1 + vx * t), e.y - (w.y1 + vy * t)
                    local d = math.sqrt(dx * dx + dy * dy) + 0.001
                    local want = e.radius + 2
                    if d < want then e.x, e.y = e.x + dx / d * (want - d) * 0.5, e.y + dy / d * (want - d) * 0.5 end
                    if e.slowT <= 0.05 then
                        e.slowT, e.slowMul = w.hold or 2.5, 0
                        e.kvx, e.kvy = 0, 0
                        w.caught = w.caught + 1
                        w.wobble = 1
                        if (w.damage or 0) > 0 then Combat.damage(world, e, w.damage, { knockback = 0, noCrit = true, dot = true, source = w._src }) end
                    end
                end
            end
        end
    end
end

function Hazards:update(dt)
    local world, p = self.world, self.world.player
    self:updateWalls(dt)
    local slow = 1
    for i = #self.zones, 1, -1 do
        local z = self.zones[i]
        z.t = z.t + dt
        if z.t >= z.maxLife then
            table.remove(self.zones, i)
        else
            local grow = math.min(1, z.t / 0.3)
            local r = z.r * grow
            local dx, dy = p.x - z.x, p.y - z.y
            local inside = not p.dead and dx * dx + dy * dy < r * r
            if z.slow and inside then slow = math.min(slow, z.slow) end
            if inside and z.damage then
                -- hurts in quarter-second ticks so it doesn't spam tiny numbers
                z.tick = (z.tick or 0) + dt
                if z.tick >= 0.25 then
                    z.tick = z.tick - 0.25
                    world.hitBy = z.by or nil
                    p:hurt(z.damage * 0.25, "zone")
                    world.hitBy = nil
                end
            end
            if inside and z.pull and p.dashT <= 0 then
                local d = math.sqrt(dx * dx + dy * dy) + 0.001
                local k = math.min(d, z.pull * dt * (0.4 + 0.6 * d / r))
                p.x, p.y = p.x - dx / d * k, p.y - dy / d * k
            end
            if z.update then
                local prev = RunStats.enter(world, z)
                z.update(world, z, dt, inside)
                RunStats.leave(world, prev)
            end
            if z.enemySlow then
                -- webs: ants inside are slowed (and lightly hurt)
                local list, n = world:queryEnemies(z.x, z.y, r)
                for k = 1, n do
                    local e = list[k]
                    local ex, ey = e.x - z.x, e.y - z.y
                    if not e.dead and ex * ex + ey * ey < (r + e.radius) ^ 2 then
                        e.slowT, e.slowMul = math.max(e.slowT, 0.15), math.min(e.slowT > 0 and e.slowMul or 1, z.enemySlow)
                    end
                end
            end
            if z.heal then
                -- heal ants standing in it (a few per frame is plenty)
                local list, n = world:queryEnemies(z.x, z.y, r)
                for k = 1, n do
                    local e = list[k]
                    if not e.dead and e.hp < e.maxHp and not e.def.boss then
                        e.hp = math.min(e.maxHp, e.hp + z.heal * dt * world:hpScale())
                        if love.math.random() < dt * 2 then
                            world.particles:spawn(e.x, e.y, 6, 0, 0, 30, 0.5, { 1, 0.85, 0.35 }, 1, { glow = true, grav = 0 })
                        end
                    end
                end
            end
        end
    end
    if p.slowT > 0 then slow = math.min(slow, p.slowAmt) end
    slow = math.min(slow, world.frameSlow)
    world.frameSlow = 1
    p.slowMul = slow

    for i = #self.shots, 1, -1 do
        local s = self.shots[i]
        s.t = s.t + dt
        if s.turn then
            local c, sn = math.cos(s.turn * dt), math.sin(s.turn * dt)
            s.vx, s.vy = s.vx * c - s.vy * sn, s.vx * sn + s.vy * c
        end
        s.x, s.y = s.x + s.vx * dt, s.y + s.vy * dt
        s.vz = s.vz - (s.grav or 120) * dt
        s.z = math.max(1, s.z + s.vz * dt)
        local hit, done = false, false
        if s.bomb then
            -- a lobbed bomb: goes off where it lands (see onEnd)
            if s.vz < 0 and s.z <= 1.5 then done = true end
        elseif s.friendly then
            -- batted back: flies through ants, hurting a few of them
            local list, n = world:queryEnemies(s.x, s.y, s.r + 8)
            for k = 1, n do
                local e = list[k]
                local dx, dy = e.x - s.x, e.y - s.y
                local rr = e.radius + s.r + 2
                if not e.dead and not s.hitSet[e] and dx * dx + dy * dy < rr * rr then
                    s.hitSet[e] = true
                    local nx, ny = util.normalize(s.vx, s.vy)
                    Combat.damage(world, e, s.damage, { knockback = s.knockback or 70, kbx = nx, kby = ny, procDepth = s.procDepth or 1, slow = s.slow,
                        poison = s.poison, corrode = s.corrode, stun = s.stun, source = s._src, cstatus = s.cstatus, look = s.look })
                    s.pierce = s.pierce - 1
                    if s.pierce < 0 then done = true break end
                end
            end
        elseif s.lob then
            -- lobbed: only lands at the marked spot
            if s.vz < 0 and s.z <= 1.5 then
                done = true
                local L = s.lob
                local dx, dy = p.x - s.x, p.y - s.y
                if not p.dead and dx * dx + dy * dy < (L.r + p.radius) ^ 2 then
                    hit = true
                    world.hitBy = s.by or nil
                    p:hurt(s.damage, "pebble")
                    world.hitBy = nil
                    if L.slow then p:slow(L.slow, L.slowTime or 0.8) end
                end
                world:addFx({ kind = "ring", x = s.x, y = s.y, r = L.r, life = 0.18, color = { 0.8, 0.75, 0.65 } })
                world.particles:burst(s.x, s.y, 6, { { 0.55, 0.5, 0.45 }, { 0.7, 0.65, 0.58 } }, 50, 50, { grav = 300 })
            end
        else
            local dx, dy = p.x - s.x, p.y - s.y
            local rr = p.radius + s.r
            hit = not p.dead and dx * dx + dy * dy < rr * rr
            if hit then
                world.hitBy = s.by or nil
                p:hurt(s.damage, "acid")
                world.hitBy = s.by or nil
                if s.venom then p:poison(s.venom.dps, s.venom.time) end
                world.hitBy = nil
                if s.onHitPlayer then s.onHitPlayer(world, s, p) end
            end
        end
        if hit or done or s.t >= s.life or s.x < 0 or s.y < 0 or s.x > world.size or s.y > world.size then
            table.remove(self.shots, i)
            if s.onEnd then
                local prev = RunStats.enter(world, s)
                s.onEnd(world, s)
                RunStats.leave(world, prev)
            end
            if not s.pebble then
                world.particles:burst(s.x, s.y, 5, { s.color }, 50, 40, { stain = true, grav = 300 })
                if s.splat then world.pendingSplats[#world.pendingSplats + 1] = { kind = "splat", s.x, s.y, s.color, 3, s.vx / 200, s.vy / 200 } end
            end
            if hit then Audio.play("hit", { pitch = 0.6 }) end
        end
    end
end

-- Bat projectiles back: every hostile shot within `radius` of (x, y) (and, if `ang` is given,
-- within `half` radians of that direction) is sent flying away from the player, faster and
-- harder, to hurt ants instead. Returns how many were returned.
function Hazards:deflect(x, y, radius, ang, half)
    local world, n = self.world, 0
    for _, s in ipairs(self.shots) do
        if not s.friendly then
            local dx, dy = s.x - x, s.y - y
            local r = radius + s.r + 4
            if dx * dx + dy * dy < r * r and (not ang or math.abs(util.angleDiff(ang, math.atan2(dy, dx))) <= half + 0.3) then
                local nx, ny = util.normalize(dx, dy)
                if ang then nx, ny = util.normalize(nx + math.cos(ang), ny + math.sin(ang)) end
                local sp = math.max(170, math.sqrt(s.vx * s.vx + s.vy * s.vy)) * 1.6
                s.vx, s.vy = nx * sp, ny * sp
                s.vz, s.z, s.grav, s.lob, s.turn = 25, math.max(s.z, 5), 60, nil, nil
                s.friendly, s.hitSet, s.pierce = true, {}, 2
                s.damage = math.max(6, s.damage * 2.5)
                s.t, s.life = 0, 1.2
                s.color = { math.min(1, s.color[1] * 0.5 + 0.6), math.min(1, s.color[2] * 0.5 + 0.55), math.min(1, s.color[3] * 0.5 + 0.4) }
                world.particles:sparks(s.x, s.y, 5, { 1, 1, 0.8 }, nx, ny, 1.2, 120)
                n = n + 1
            end
        end
    end
    if n > 0 then
        Audio.play("zap", { pitch = 1.5 })
        world:floatText(x, y, n > 1 and ("RETURNED x" .. n) or "RETURNED", { 0.75, 1, 0.6 }, false)
        world.events:emit("shots_deflected", n)
    end
    return n
end

-- Puddles lie on the floor: drawn right after the ground.
-- A silk strand drawn a little above the ground, sagging between its two anchor blobs and
-- trembling when it catches something.
function Hazards.drawStrand(x1, y1, x2, y2, alpha, wobble, t)
    local lg = love.graphics
    local pts = {}
    for k = 0, 10 do
        local f = k / 10
        local sag = math.sin(f * math.pi)
        local wx, wy = x1 + (x2 - x1) * f, y1 + (y2 - y1) * f
        local sx, sy = Iso.toScreen(wx, wy, 4 - sag * 1.5 + math.sin(t * 30 + f * 12) * wobble * sag)
        pts[#pts + 1], pts[#pts + 2] = sx, sy
    end
    lg.setColor(0.55, 0.55, 0.5, alpha * 0.5)
    for k = 1, #pts, 2 do pts[k + 1] = pts[k + 1] + 1 end
    lg.line(pts)
    for k = 1, #pts, 2 do pts[k + 1] = pts[k + 1] - 1 end
    lg.setColor(1, 1, 0.95, alpha)
    lg.line(pts)
    -- dew drops of glue along the strand
    lg.setColor(1, 1, 1, alpha * 0.9)
    for k = 5, #pts - 4, 4 do lg.rectangle("fill", math.floor(pts[k]), math.floor(pts[k + 1]), 1, 1) end
    for _, e in ipairs({ { x1, y1 }, { x2, y2 } }) do
        local sx, sy = Iso.toScreen(e[1], e[2])
        lg.setColor(0.95, 0.95, 0.9, alpha * 0.7)
        lg.line(sx, sy, sx, sy - 4)
        lg.circle("fill", sx, sy, 1.5)
    end
end

function Hazards:drawGround()
    local lg = love.graphics
    for _, w in ipairs(self.walls) do
        local fade = math.min(1, (w.maxLife - w.t) / 1.2) * (1 - 0.4 * w.caught / (w.strength or 40))
        Hazards.drawStrand(w.x1, w.y1, w.x2, w.y2, fade, w.wobble * 2, w.t)
        -- a second, looser strand below so it reads as a fence of silk
        lg.setColor(1, 1, 0.95, fade * 0.45)
        local ax, ay = Iso.toScreen(w.x1, w.y1, 1.5)
        local bx, by = Iso.toScreen(w.x2, w.y2, 1.5)
        lg.line(ax, ay, bx, by)
    end
    local atlas, blobs = Sprites.atlas, Sprites.blobs
    for i, z in ipairs(self.zones) do
        local sx, sy = Iso.toScreen(z.x, z.y)
        local grow = math.min(1, z.t / 0.3)
        local fade = math.min(1, (z.maxLife - z.t) / 1.5)
        local c = Palette.zone(z)
        local k = z.r / 9 * grow
        if z.draw then
            z.draw(z, sx, sy, fade)
        elseif z.web then
            -- a spiderweb: radial threads and a spiral
            local a0 = fade * 0.8
            lg.setColor(0.95, 0.95, 0.9, a0 * 0.7)
            local r = z.r * grow
            for s = 0, 7 do
                local a = s / 8 * math.pi * 2
                local ex, ey = Iso.toScreen(z.x + math.cos(a) * r, z.y + math.sin(a) * r)
                lg.line(sx, sy, ex, ey)
            end
            for ring = 1, 3 do
                local rr = r * ring / 3.4
                local pts = {}
                for s = 0, 8 do
                    local a = s / 8 * math.pi * 2
                    local ex, ey = Iso.toScreen(z.x + math.cos(a) * rr, z.y + math.sin(a) * rr)
                    pts[#pts + 1], pts[#pts + 2] = ex, ey
                end
                lg.line(pts)
            end
        else -- (no goto: the web build runs plain Lua 5.1)
        lg.setColor(c[1] * 0.7, c[2] * 0.7, c[3] * 0.7, 0.75 * fade)
        lg.draw(atlas, blobs[(i % #blobs) + 1], sx, sy, 0, k * 1.1, k, 9, 5)
        lg.setColor(c[1], c[2], c[3], 0.85 * fade)
        lg.draw(atlas, blobs[((i + 3) % #blobs) + 1], sx - k, sy - k * 0.5, 0, k * 0.8, k * 0.7, 9, 5)
        -- glossy wet highlight that slowly drifts
        lg.setColor(1, 0.95, 0.75, 0.4 * fade)
        lg.draw(atlas, Sprites.pixel, sx - k * 3 + math.sin(z.t) * 2, sy - k * 1.5, 0, 3, 1)
        end
    end
    lg.setColor(1, 1, 1, 1)
end

-- Projectiles fly above the floor: shadow on the ground, glowing blob in the air.
function Hazards:drawAir()
    local lg = love.graphics
    local atlas, glow = Sprites.atlas, Sprites.glow
    for _, s in ipairs(self.shots) do
        local gx, gy = Iso.toScreen(s.x, s.y)
        local ax, ay = Iso.toScreen(s.x, s.y, s.z)
        if s.lob then
            -- landing marker: a ring on the ground that closes in as the stone falls
            local tx, ty = Iso.toScreen(s.lob.x, s.lob.y)
            local k = math.min(1, s.t / math.max(0.1, s.lob.flight or 0.9))
            Palette.ring(tx, ty, s.lob.r * (1.6 - 0.6 * k), s.lob.r * 0.5 * (1.6 - 0.6 * k), { 1, 0.8, 0.5 }, 0.25 + 0.45 * k)
        end
        if s.pebble and not s.friendly then
            -- enemy stone: has to read at night, so a firm shadow, a pale halo, a short dust
            -- trail and a dark-outlined 4px stone with a highlight
            local fall = 1 - math.min(1, (s.z or 0) / 40)
            lg.setColor(0, 0, 0, 0.35 + 0.25 * fall)
            lg.draw(atlas, glow, gx, gy, 0, 0.4 + 0.2 * fall, 0.2 + 0.1 * fall, 8, 8)
            for i = 1, 3 do
                local dt = i * 0.03
                local tx, ty = Iso.toScreen(s.x - s.vx * dt, s.y - s.vy * dt, s.z - (s.vz or 0) * dt)
                lg.setColor(0.85, 0.78, 0.66, 0.4 - i * 0.1)
                lg.draw(atlas, Sprites.pixel, math.floor(tx) - 1, math.floor(ty) - 1, 0, 2, 2)
            end
            lg.setColor(1, 0.92, 0.75, 0.45)
            lg.draw(atlas, glow, ax, ay, 0, 0.5, 0.5, 8, 8)
            local px, py = math.floor(ax) - 2, math.floor(ay) - 2
            lg.setColor(0.1, 0.08, 0.07, 1)
            lg.draw(atlas, Sprites.pixel, px - 1, py - 1, 0, 6, 6)
            lg.setColor(s.color[1], s.color[2], s.color[3], 1)
            lg.draw(atlas, Sprites.pixel, px, py, 0, 4, 4)
            lg.setColor(s.color[1] * 0.7, s.color[2] * 0.7, s.color[3] * 0.7, 1)
            lg.draw(atlas, Sprites.pixel, px + 1, py + 2, 0, 3, 2)
            lg.setColor(1, 0.97, 0.9, 1)
            lg.draw(atlas, Sprites.pixel, px + 1, py + 1, 0, 1, 1)
        else
            local sc = Palette.shot(s)
            lg.setColor(0, 0, 0, Palette.contrast() and not s.friendly and 0.6 or 0.3)
            lg.draw(atlas, glow, gx, gy, 0, 0.35, 0.18, 8, 8)
            lg.setColor(sc[1], sc[2], sc[3], 0.9)
            lg.draw(atlas, glow, ax, ay, 0, 0.45, 0.45, 8, 8)
            lg.setColor(1, 1, 0.8, 1)
            lg.draw(atlas, Sprites.pixel, math.floor(ax), math.floor(ay), 0, 2, 2)
        end
    end
    lg.setColor(1, 1, 1, 1)
end

function Hazards:lights(light)
    for _, s in ipairs(self.shots) do
        local x, y = Iso.toScreen(s.x, s.y, s.z)
        if not s.pebble or s.friendly then light(x, y, 30, s.color[1], s.color[2], s.color[3], 0.5)
        else
            -- enemy stones and their landing rings stay lit so they can be dodged in the dark
            light(x, y, 26, 1, 0.9, 0.75, 0.55)
            if s.lob then
                local tx, ty = Iso.toScreen(s.lob.x, s.lob.y)
                light(tx, ty, s.lob.r * 3, 1, 0.75, 0.5, 0.35)
            end
        end
    end
end

return Hazards
