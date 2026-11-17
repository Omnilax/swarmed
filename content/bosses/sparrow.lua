-- The Sparrow: a stage hazard, not a fight (see src/game/director.lua, def.hazard). A bird
-- the size of the sky hunts over the arena for the rest of the boss wave. It eats ants and
-- you alike, and you can't hurt it: dodge, and steer the colony into its path.
--
--   circle   it soars high overhead; only its shadow sweeps the ground
--   swoop    a lane across the whole arena lights up, then it dives down it, snatching
--            everything (later on it comes straight back for a second pass)
--   land     it drops onto a marked spot, crushing what's under its feet
--   peck     it hops after you, stabbing at marked spots with its beak
--   gust     it takes off with a wing beat that blasts everything away from it
-- It gets quicker the longer the wave goes on. When the wave is cleared it flies off.
local Env = require("src.game.envfx")
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")
local Beasts = require("src.gfx.beasts")

local K = 0.8            -- world units per picture pixel
local HIGH = 150         -- soaring height
local PK = K * 1.3       -- standing, it is drawn a bit bigger: a chunky perched bird
local REACH = 48         -- how far ahead of its body the beak strikes
local FLAP = { "sparrow_up", "sparrow_glide", "sparrow_down", "sparrow_tuck", "sparrow_down", "sparrow_glide" }

local P = {
    circle = { 2.4, 3.4 },  -- seconds soaring between attacks
    swoopWarn = 1.25, swoopSpeed = 640, swoopWidth = 24, swoopDamage = 15,
    landWarn = 1.1, landR = 34, landDamage = 10,
    pecks = 5, peckWarn = 0.6, peckR = 17, peckDamage = 11,
    gustWarn = 0.7, gustR = 135,
}

local function tempo(h) return 1 + math.min(0.6, h.t / 55) end

local function setMode(h, mode, label, danger)
    local st = h.st
    st.mode, st.t = mode, 0
    h.label, h.danger = label, danger
end

local function circle(h)
    local st = h.st
    st.circleFor = (P.circle[1] + love.math.random() * (P.circle[2] - P.circle[1])) / tempo(h)
    setMode(h, "circle", "CIRCLING OVERHEAD", false)
end

local function pickAttack(world, h)
    local st = h.st
    local opts = { { "swoop", 3 }, { "land", st.last == "land" and 0.5 or 2.2 } }
    local total = 0
    for _, o in ipairs(opts) do total = total + o[2] end
    local r = love.math.random() * total
    for _, o in ipairs(opts) do
        r = r - o[2]
        if r <= 0 then return o[1] end
    end
    return "swoop"
end

-- A dive across the whole arena through (near) the player, starting well outside it.
local function aimSwoop(world, h, back)
    local st, p = h.st, world.player
    local x1, y1, x2, y2
    if back and st.x1 then
        -- come straight back across, bent toward wherever the player went
        local dx, dy = p.x - st.x2, p.y - st.y2
        local l = math.sqrt(dx * dx + dy * dy) + 0.0001
        local S = world.size
        local t = S * 1.6
        x1, y1 = st.x2, st.y2
        x2, y2 = x1 + dx / l * t, y1 + dy / l * t
    else
        x1, y1, x2, y2 = Env.crossing(world, p.x, p.y, 50)
        local dx, dy = x2 - x1, y2 - y1
        local l = math.sqrt(dx * dx + dy * dy) + 0.0001
        x1, y1 = x1 - dx / l * 170, y1 - dy / l * 170
        x2, y2 = x2 + dx / l * 170, y2 + dy / l * 170
    end
    st.x1, st.y1, st.x2, st.y2 = x1, y1, x2, y2
    st.face = math.atan2(y2 - y1, x2 - x1)
    st.hit, st.hitPlayer = {}, false
    setMode(h, "swoopWarn", back and "IT'S COMING BACK!" or "SWOOP INCOMING!", true)
    Audio.play("queen", { pitch = 1.9, volume = 0.6 })
end

local function aimLanding(world, h)
    local st, p = h.st, world.player
    -- lands a little way off, facing you, then hops in
    local x, y = Env.pointNear(world, p.x, p.y, 120, 70)
    local dx, dy = x - p.x, y - p.y
    if dx * dx + dy * dy < 70 * 70 then
        local a = love.math.random() * math.pi * 2
        x, y = Env.pointNear(world, p.x + math.cos(a) * 110, p.y + math.sin(a) * 110, 10, 70)
    end
    st.lx, st.ly, st.fromX, st.fromY, st.fromZ = x, y, st.x, st.y, st.z
    setMode(h, "landWarn", "IT'S LANDING!", true)
    Audio.play("dash", { pitch = 0.45, volume = 0.6 })
end

local function aimPeck(world, h)
    local st, p = h.st, world.player
    -- lead the player a little
    local tx = p.x + (p.vx or 0) * 0.25 + (love.math.random() - 0.5) * 16
    local ty = p.y + (p.vy or 0) * 0.25 + (love.math.random() - 0.5) * 16
    local S = world.size
    tx, ty = math.max(15, math.min(S - 15, tx)), math.max(15, math.min(S - 15, ty))
    st.tx, st.ty = tx, ty
    local dx, dy = tx - st.x, ty - st.y
    local d = math.sqrt(dx * dx + dy * dy) + 0.0001
    st.face = math.atan2(dy, dx)
    -- hop to where the beak reaches the spot
    st.hx0, st.hy0 = st.x, st.y
    st.hx1, st.hy1 = tx - dx / d * REACH, ty - dy / d * REACH
    setMode(h, "peckWarn", "PECKING!", true)
end

local function strike(world, h, x, y, r, dmg, force, label)
    local n = Env.strikeCircle(world, x, y, r, 999, { force = 120, bossMul = 0.25 })
    if Env.playerIn(world, x, y, r) then Env.hurtPlayer(world, dmg, x, y, { force = force, name = "sparrow" }) end
    if n >= 6 and label then world:floatText(x, y, n .. " " .. label, { 1, 0.75, 0.55 }, true) end
    return n
end

local function dust(world, x, y, n, speed)
    world.particles:burst(x, y, n, { { 0.55, 0.45, 0.32 }, { 0.4, 0.32, 0.22 }, { 0.68, 0.6, 0.48 } }, speed, 50, { grav = 220 })
end

local function feathers(world, x, y, n)
    world.particles:burst(x, y, n, { { 0.42, 0.29, 0.18 }, { 0.62, 0.45, 0.28 }, { 0.9, 0.86, 0.78 } }, 70, 90, { grav = 60 })
end

return {
    name = "Shadow From Above",
    title = "Sparrow",
    description = "A sparrow hunts the arena. You can't fight it: dodge its swoops and pecks, and feed it ants.",
    hazard = true,
    pictures = Beasts.SPARROW,
    weight = 10, minWave = 5,
    xp = 30,
    survived = "THE SPARROW FLIES OFF",
    color = { 1, 0.6, 0.35 },
    leaveTime = 3,
    entry = function(world) return Env.pointAway(world, 300, 0) end,

    start = function(world, h)
        local st, p = h.st, world.player
        -- glides in from far outside the arena
        local a = love.math.random() * math.pi * 2
        st.x, st.y, st.z = p.x + math.cos(a) * 700, p.y + math.sin(a) * 700, HIGH
        st.orbit = a
        st.face = a + math.pi
        st.flap, st.pecks = 0, 0
        circle(h)
    end,

    update = function(world, h, dt)
        local st, p = h.st, world.player
        local tp = tempo(h)
        st.t = st.t + dt
        st.flap = st.flap + dt
        if st.peckT then st.peckT = math.max(0, st.peckT - dt) end
        local m = st.mode
        if m == "circle" then
            st.flapping = (st.flap % 3) < 1.1
            st.orbit = st.orbit + dt * 0.55
            local tx, ty = p.x + math.cos(st.orbit) * 210, p.y + math.sin(st.orbit) * 210
            local dx, dy = tx - st.x, ty - st.y
            local d = math.sqrt(dx * dx + dy * dy) + 0.0001
            local sp = math.min(330, d * 1.6)
            st.x, st.y = st.x + dx / d * sp * dt, st.y + dy / d * sp * dt
            if d > 8 then
                local want = math.atan2(dy, dx)
                local diff = (want - st.face + math.pi) % (math.pi * 2) - math.pi
                st.face = st.face + diff * math.min(1, dt * 3)
            end
            st.z = st.z + (HIGH - st.z) * math.min(1, dt * 2)
            if st.t >= st.circleFor and not p.dead then
                local a = pickAttack(world, h)
                st.last = a
                if a == "swoop" then aimSwoop(world, h) else aimLanding(world, h) end
            end
        elseif m == "swoopWarn" then
            -- out of sight, banking round to the start of its run
            st.flapping = false
            local k = math.min(1, st.t / (P.swoopWarn / tp))
            st.x = st.x + (st.x1 - st.x) * math.min(1, dt * 4)
            st.y = st.y + (st.y1 - st.y) * math.min(1, dt * 4)
            st.z = HIGH + 60 * k
            if st.t >= P.swoopWarn / tp then
                st.x, st.y, st.z = st.x1, st.y1, 60
                setMode(h, "swoop", "SWOOP!", true)
                Audio.play("dash", { pitch = 0.35, volume = 0.9 })
            end
        elseif m == "swoop" then
            st.flapping = false
            local dx, dy = st.x2 - st.x1, st.y2 - st.y1
            local L = math.sqrt(dx * dx + dy * dy) + 0.0001
            local sp = P.swoopSpeed * (0.9 + 0.2 * tp)
            st.x, st.y = st.x + dx / L * sp * dt, st.y + dy / L * sp * dt
            local f = math.max(0, math.min(1, ((st.x - st.x1) * dx + (st.y - st.y1) * dy) / (L * L)))
            st.z = 6 + 70 * ((f - 0.5) * 2) ^ 2
            if st.z < 40 then
                local w = P.swoopWidth
                local n = 0
                for _, o in ipairs(Combat.collect(world, st.x, st.y, w)) do
                    if not st.hit[o.uid] then
                        st.hit[o.uid] = true
                        if Env.hurtAnt(world, o, 999, { air = true, bossMul = 0.25, force = 160, kx = dx, ky = dy }) then n = n + 1 end
                    end
                end
                st.snatched = (st.snatched or 0) + n
                if not st.hitPlayer and Env.playerIn(world, st.x, st.y, w - 4) then
                    st.hitPlayer = true
                    Env.hurtPlayer(world, P.swoopDamage, st.x - dy / L * 10, st.y + dx / L * 10, { force = 260, name = "sparrow" })
                end
                -- the wash off its wings throws the crowd aside
                if love.math.random() < dt * 20 then Env.pushCircle(world, st.x, st.y, w + 40, 140) end
                if love.math.random() < dt * 12 then feathers(world, st.x, st.y, 1) end
            end
            if f >= 1 then
                if (st.snatched or 0) >= 6 then
                    world:floatText(p.x, p.y - 20, st.snatched .. " SNATCHED", { 1, 0.75, 0.55 }, true)
                end
                st.snatched = 0
                world.camera:shake(0.15)
                if tp > 1.25 and not st.wentBack and love.math.random() < 0.6 then
                    st.wentBack = true
                    aimSwoop(world, h, true)
                else
                    st.wentBack = false
                    st.orbit = math.atan2(st.y - p.y, st.x - p.x)
                    circle(h)
                end
            end
        elseif m == "landWarn" then
            -- drops out of the sky onto the marked spot
            st.flapping = true
            local k = math.min(1, st.t / (P.landWarn / tp))
            local e = k * k
            st.x = st.fromX + (st.lx - st.fromX) * (1 - (1 - k) ^ 2)
            st.y = st.fromY + (st.ly - st.fromY) * (1 - (1 - k) ^ 2)
            st.z = st.fromZ * (1 - e)
            st.face = math.atan2(p.y - st.y, p.x - st.x)
            if k >= 1 then
                st.x, st.y, st.z = st.lx, st.ly, 0
                local n = strike(world, h, st.x, st.y, P.landR, P.landDamage, 220, "CRUSHED")
                Env.pushCircle(world, st.x, st.y, P.landR + 50, 150)
                dust(world, st.x, st.y, 26, 120)
                world.camera:shake(0.35)
                Audio.play("boom", { pitch = 0.5 })
                st.pecks = 0
                setMode(h, "perch", "PECKING!", true)
                st.perchFor = 0.35
            end
        elseif m == "perch" then
            st.flapping = false
            if st.t >= st.perchFor then aimPeck(world, h) end
        elseif m == "peckWarn" then
            -- hop into reach, then hold still as the head draws back
            local hop = math.min(1, st.t / 0.22)
            st.x = st.hx0 + (st.hx1 - st.hx0) * hop
            st.y = st.hy0 + (st.hy1 - st.hy0) * hop
            st.z = math.sin(hop * math.pi) * 10
            if hop >= 1 and not st.hopped then
                st.hopped = true
                Env.pushCircle(world, st.x, st.y, 34, 90)
                dust(world, st.x, st.y, 6, 60)
            end
            if st.t >= P.peckWarn / tp then
                st.hopped = false
                st.peckT = 0.18
                st.pecks = st.pecks + 1
                strike(world, h, st.tx, st.ty, P.peckR, P.peckDamage, 120, "PECKED UP")
                dust(world, st.tx, st.ty, 8, 70)
                world.camera:shake(0.12)
                Audio.play("hit", { pitch = 0.45, volume = 0.9 })
                if st.pecks >= P.pecks + math.floor((tp - 1) * 4) then
                    setMode(h, "gustWarn", "WINGS SPREADING!", true)
                    Audio.play("rumble", { pitch = 1.5, volume = 0.6 })
                else
                    setMode(h, "perch", "PECKING!", true)
                    st.perchFor = 0.12
                end
            end
        elseif m == "gustWarn" then
            st.flapping = st.t > 0.3
            if st.t >= P.gustWarn / tp then
                -- one huge wing beat: everything near is blasted away
                local n = Env.pushCircle(world, st.x, st.y, P.gustR, 420)
                Env.strikeCircle(world, st.x, st.y, 30, 999, { bossMul = 0.25 })
                if Env.playerIn(world, st.x, st.y, P.gustR) then
                    local dx, dy = p.x - st.x, p.y - st.y
                    p:knock(dx, dy, 300)
                end
                dust(world, st.x, st.y, 40, 220)
                feathers(world, st.x, st.y, 6)
                world.camera:shake(0.3)
                Audio.play("dash", { pitch = 0.3, volume = 1 })
                st.fromZ = 0
                setMode(h, "rise", "TAKING OFF", false)
            end
        elseif m == "rise" then
            st.flapping = true
            st.z = math.min(HIGH, st.z + dt * 140)
            st.x, st.y = st.x + math.cos(st.face) * 90 * dt, st.y + math.sin(st.face) * 90 * dt
            if st.z >= HIGH * 0.8 then
                st.orbit = math.atan2(st.y - p.y, st.x - p.x)
                circle(h)
            end
        end
    end,

    leave = function(world, h, dt)
        local st = h.st
        st.flapping = true
        st.flap = st.flap + dt
        st.mode = "leave"
        st.z = math.min(HIGH * 2, st.z + dt * 120)
        st.x, st.y = st.x + math.cos(st.face) * 260 * dt, st.y + math.sin(st.face) * 260 * dt
    end,

    drawGround = function(world, h)
        local st = h.st
        local m = st.mode
        local tp = tempo(h)
        -- its shadow: the bird's own silhouette on the ground, sharper the lower it flies
        local z = st.z or HIGH
        local lo = 1 - math.min(1, z / (HIGH * 1.4))
        local pic = (m == "perch" or m == "peckWarn") and "sparrow_perched" or "sparrow_glide"
        if m ~= "perch" and m ~= "peckWarn" then
            Beasts.drawFlat(pic, st.x + z * 0.25, st.y + z * 0.25, 0, st.face, K * (1.1 - 0.15 * lo), 0.16 + 0.3 * lo, true)
        end
        if m == "swoopWarn" then
            Env.warnLane(st.x1, st.y1, st.x2, st.y2, P.swoopWidth, st.t / (P.swoopWarn / tp), world.time)
        elseif m == "landWarn" then
            Env.warnCircle(st.lx, st.ly, P.landR, st.t / (P.landWarn / tp), world.time)
        elseif m == "peckWarn" then
            Env.warnCircle(st.tx, st.ty, P.peckR, st.t / (P.peckWarn / tp), world.time)
        elseif m == "gustWarn" then
            Env.warnCircle(st.x, st.y, P.gustR, st.t / (P.gustWarn / tp), world.time, { 1, 0.85, 0.5 })
        end
    end,

    drawAir = function(world, h)
        local st = h.st
        local m = st.mode
        if m == "swoopWarn" then return end          -- out of sight, lining up its run
        local z = st.z or HIGH
        if m == "perch" or m == "peckWarn" then
            -- standing: folded wings, the head darting forward to peck
            Beasts.drawUp("sparrow_perched", st.x, st.y, z, st.face, PK)
            local out = 30
            if m == "peckWarn" then out = 30 - 8 * math.min(1, st.t / 0.4) end      -- draws back
            if (st.peckT or 0) > 0 then out = 30 + 14 * (st.peckT / 0.18) end      -- stabs
            local hx, hy = Beasts.point(st.x, st.y, st.face, PK, out, 0)
            Beasts.drawUp("sparrow_head", hx, hy, z + 4, st.face, PK)
            return
        end
        local pic = "sparrow_glide"
        if st.flapping then
            pic = FLAP[math.floor(st.flap * 14) % #FLAP + 1]
        elseif m == "swoop" then
            pic = "sparrow_down"
        elseif m == "gustWarn" then
            pic = "sparrow_up"
        end
        Beasts.drawFlat(pic, st.x, st.y, z, st.face, K)
    end,
}
