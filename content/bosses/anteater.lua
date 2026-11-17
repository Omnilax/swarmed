-- The Giant Anteater: a stage hazard, not a fight (see src/game/director.lua, def.hazard).
-- Something this big doesn't fight a bug, it feeds: it lies at the edge of the arena with its
-- head and forelegs reaching in, and works the colony over for the rest of the boss wave. Its
-- tongue and claws kill ants and hurt you alike; you can't hurt it.
--
--   flicks   three quick licks down red lanes, each aimed where you are; whatever's in the
--            lane is eaten, you are hurt and dragged toward the snout
--   sweep    the tongue lies out long and sweeps across a whole fan of the arena
--   rake     a foreleg reaches in and drags its great claws back through the ground: three
--            gouges that rip up everything in them
--   shuffle  it moves along the edge after you, or pulls out and comes in at another side
-- It gets quicker the longer the wave goes on. When the wave is cleared it wanders off.
local Env = require("src.game.envfx")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")
local Beasts = require("src.gfx.beasts")

local K = 1.05               -- world units per picture pixel
local TIP_U = 182            -- the snout tip in the picture
local REST_OUT, LEAN_OUT, GONE_OUT = 70, 36, 420

local P = {
    idle = { 0.9, 1.5 },
    flickWarn = 0.85, flickWidth = 10, flickReach = 400, flickDamage = 13,
    sweepWarn = 1.3, sweepTime = 1.0, sweepSpan = 0.8, sweepReach = 330, sweepWidth = 9, sweepDamage = 14,
    rakeWarn = 1.0, rakeReach = 270, rakeDamage = 18, rakeLen = 95, rakeGap = 14,
}

local function tempo(h) return 1 + math.min(0.6, h.t / 55) end
local function wrap(a) return (a + math.pi) % (math.pi * 2) - math.pi end

local function setMode(h, mode, label, danger)
    h.st.mode, h.st.t = mode, 0
    h.label, h.danger = label, danger
end

-- Where its shoulders sit: `out` units outside the arena edge at the edge point (ex, ey).
local function body(st)
    return st.ex - st.nx * st.out, st.ey - st.ny * st.out
end

local function snoutTip(st)
    local bx, by = body(st)
    return Beasts.point(bx, by, st.face, K, TIP_U, 0)
end

-- The edge of the arena nearest (x, y), and the point on it.
local function nearestEdge(world, x, y)
    local S, m = world.size, 150
    local cx, cy = math.max(m, math.min(S - m, x)), math.max(m, math.min(S - m, y))
    -- { edge x, edge y, inward normal x, y, distance }
    local opts = { { cx, 0, 0, 1, y }, { cx, S, 0, -1, S - y }, { 0, cy, 1, 0, x }, { S, cy, -1, 0, S - x } }
    local best, bi = nil, 1
    for i, o in ipairs(opts) do
        if not best or o[5] < best[5] then best, bi = o, i end
    end
    return best[1], best[2], best[3], best[4], bi
end

-- Turn the head toward a point, but never far from straight into the arena.
local function lookAt(st, x, y, dt, rate)
    local bx, by = body(st)
    local base = math.atan2(st.ny, st.nx)
    local want = wrap(math.atan2(y - by, x - bx) - base)
    want = math.max(-0.8, math.min(0.8, want))
    local cur = wrap(st.face - base)
    cur = cur + (want - cur) * math.min(1, dt * (rate or 3))
    st.face = base + cur
end

-- The arena-clipped end of a tongue from (x, y) along angle a.
local function tongueEnd(world, x, y, a, reach)
    local S = world.size
    local dx, dy = math.cos(a), math.sin(a)
    local t = reach
    if dx > 0 then t = math.min(t, (S - x) / dx) elseif dx < 0 then t = math.min(t, -x / dx) end
    if dy > 0 then t = math.min(t, (S - y) / dy) elseif dy < 0 then t = math.min(t, -y / dy) end
    t = math.max(40, t)
    return x + dx * t, y + dy * t
end

local function lick(world, x1, y1, x2, y2, w, dmg)
    local n = Env.strikeLane(world, x1, y1, x2, y2, w, 999, { force = 0, bossMul = 0.15 })
    if n >= 5 then world:floatText(x2, y2, n .. " LICKED UP", { 1, 0.6, 0.6 }, true) end
    if Env.playerInLane(world, x1, y1, x2, y2, w) then
        local p = world.player
        if Env.hurtPlayer(world, dmg, p.x, p.y, { name = "anteater" }) then p:knock(x1 - p.x, y1 - p.y, 190) end
        return true
    end
end

-- Shoulder joint of the left (-1) or right (+1) foreleg.
local function joint(st, s)
    local bx, by = body(st)
    return Beasts.point(bx, by, st.face, K, 16, s * 36)
end

local function aimFlick(world, h)
    local st, p = h.st, world.player
    local x1, y1 = snoutTip(st)
    local a = math.atan2(p.y + (p.vy or 0) * 0.2 - y1, p.x + (p.vx or 0) * 0.2 - x1)
    st.x1, st.y1 = x1, y1
    st.x2, st.y2 = tongueEnd(world, x1, y1, a, P.flickReach)
    setMode(h, "flickWarn", "TONGUE!", true)
    Audio.play("rumble", { pitch = 1.7, volume = 0.5 })
end

local function aimSweep(world, h)
    local st, p = h.st, world.player
    local x1, y1 = snoutTip(st)
    local a = math.atan2(p.y - y1, p.x - x1)
    local s = love.math.random() < 0.5 and -1 or 1
    st.x1, st.y1 = x1, y1
    st.a0, st.a1 = a - s * P.sweepSpan, a + s * P.sweepSpan
    st.sweepHit = false
    setMode(h, "sweepWarn", "TONGUE SWEEP!", true)
    Audio.play("rumble", { pitch = 1.2, volume = 0.7 })
end

local function aimRake(world, h)
    local st, p = h.st, world.player
    local bx, by = body(st)
    -- the foreleg on the player's side (the picture's +v side is its right when facing +u)
    local c, s = math.cos(st.face), math.sin(st.face)
    local side = (-(p.x - bx) * s + (p.y - by) * c) >= 0 and 1 or -1
    local jx, jy = joint(st, side)
    local tx, ty = p.x + (p.vx or 0) * 0.3, p.y + (p.vy or 0) * 0.3
    local dx, dy = tx - jx, ty - jy
    local d = math.sqrt(dx * dx + dy * dy) + 0.0001
    local reach = math.max(90, math.min(P.rakeReach, d + 30))
    st.side = side
    -- claws come down at the far end and drag back toward the beast
    st.rx1, st.ry1 = jx + dx / d * reach, jy + dy / d * reach
    st.rx2, st.ry2 = jx + dx / d * math.max(60, reach - P.rakeLen), jy + dy / d * math.max(60, reach - P.rakeLen)
    st.rdx, st.rdy = dx / d, dy / d
    setMode(h, "rakeWarn", "CLAWS!", true)
    Audio.play("rumble", { pitch = 0.9, volume = 0.7 })
end

-- The three gouge lanes of a rake.
local function gouges(st)
    local px, py = -st.rdy * P.rakeGap, st.rdx * P.rakeGap
    local out = {}
    for i = -1, 1 do
        out[#out + 1] = { st.rx1 + px * i, st.ry1 + py * i, st.rx2 + px * i, st.ry2 + py * i }
    end
    return out
end

local function idle(h)
    local st = h.st
    st.idleFor = (P.idle[1] + love.math.random() * (P.idle[2] - P.idle[1])) / tempo(h)
    setMode(h, "idle", "SNIFFING FOR ANTS", false)
end

local function pickAttack(world, h)
    local st, p = h.st, world.player
    -- follow the player when they've wandered off along the edge or across the arena
    local ex, ey, nx, ny, edge = nearestEdge(world, p.x, p.y)
    local along = math.abs((ex - st.ex) * st.ny - (ey - st.ey) * st.nx)
    local bx, by = body(st)
    local far = (p.x - bx) ^ 2 + (p.y - by) ^ 2 > 470 * 470
    if (edge ~= st.edge and far) or (st.attacks or 0) >= 4 and edge ~= st.edge then
        st.attacks = 0
        st.nextEdge = { ex, ey, nx, ny, edge }
        setMode(h, "withdraw", "MOVING AROUND", false)
        return
    end
    if along > 140 and edge == st.edge then
        st.sx0, st.sy0, st.sx1, st.sy1 = st.ex, st.ey, ex, ey
        setMode(h, "shuffle", "SHUFFLING ALONG", false)
        return
    end
    st.attacks = (st.attacks or 0) + 1
    local jx, jy = joint(st, 1)
    local close = (p.x - jx) ^ 2 + (p.y - jy) ^ 2 < 300 * 300
    local list = { { "flicks", 3 }, { "sweep", st.last == "sweep" and 0.6 or 2 } }
    if close then list[#list + 1] = { "rake", st.last == "rake" and 0.8 or 2.4 } end
    local total = 0
    for _, o in ipairs(list) do total = total + o[2] end
    local r, pick = love.math.random() * total, "flicks"
    for _, o in ipairs(list) do
        r = r - o[2]
        if r <= 0 then pick = o[1] break end
    end
    st.last = pick
    if pick == "flicks" then
        st.flicks = 2 + math.floor(tempo(h) * 1.5)
        aimFlick(world, h)
    elseif pick == "sweep" then
        aimSweep(world, h)
    else
        aimRake(world, h)
    end
end

local function placeAt(st, ex, ey, nx, ny, edge)
    st.ex, st.ey, st.nx, st.ny, st.edge = ex, ey, nx, ny, edge
    st.face = math.atan2(ny, nx)
end

return {
    name = "The Anteater",
    title = "Giant Anteater",
    description = "A giant anteater feeds at the edge. You can't fight it: dodge its tongue and claws, and lead the ants in.",
    hazard = true,
    pictures = Beasts.ANTEATER,
    weight = 10, minWave = 5,
    xp = 30,
    survived = "THE ANTEATER WANDERS OFF",
    color = { 1, 0.5, 0.4 },
    leaveTime = 2.5,

    start = function(world, h)
        local st, p = h.st, world.player
        local ex, ey, nx, ny, edge = nearestEdge(world, p.x, p.y)
        placeAt(st, ex, ey, nx, ny, edge)
        st.out, st.attacks = GONE_OUT, 0
        setMode(h, "enter", "IT'S COMING IN", false)
        Audio.play("rumble", { pitch = 0.6, volume = 0.8 })
    end,

    update = function(world, h, dt)
        local st, p = h.st, world.player
        local tp = tempo(h)
        st.t = st.t + dt
        local m = st.mode
        -- the shoulders lean in while it works, sit back while it sniffs
        local wantOut = (m == "idle" or m == "shuffle") and REST_OUT or LEAN_OUT
        if m ~= "enter" and m ~= "withdraw" then st.out = st.out + (wantOut - st.out) * math.min(1, dt * 4) end
        if m == "enter" then
            st.out = st.out + (REST_OUT - st.out) * math.min(1, dt * 2.2)
            lookAt(st, p.x, p.y, dt, 1.5)
            if st.out - REST_OUT < 4 then
                world.camera:shake(0.25)
                idle(h)
            end
        elseif m == "idle" then
            -- nose about, swinging toward the player
            local sway = math.sin(world.time * 2.3) * 40
            lookAt(st, p.x + sway, p.y - sway, dt, 2)
            if st.t >= st.idleFor and not p.dead then pickAttack(world, h) end
        elseif m == "shuffle" then
            local k = math.min(1, st.t / 1.2)
            local e = k * k * (3 - 2 * k)
            st.ex, st.ey = st.sx0 + (st.sx1 - st.sx0) * e, st.sy0 + (st.sy1 - st.sy0) * e
            lookAt(st, p.x, p.y, dt, 2)
            if k >= 1 then idle(h) end
        elseif m == "withdraw" then
            st.out = st.out + dt * 260
            if st.out >= GONE_OUT then
                local n = st.nextEdge
                placeAt(st, n[1], n[2], n[3], n[4], n[5])
                setMode(h, "enter", "IT'S COMING IN", false)
                Audio.play("rumble", { pitch = 0.6, volume = 0.8 })
            end
        elseif m == "flickWarn" then
            lookAt(st, st.x2, st.y2, dt, 8)
            st.x1, st.y1 = snoutTip(st)
            if st.t >= P.flickWarn / tp then
                setMode(h, "flick", "TONGUE!", true)
                Audio.play("dash", { pitch = 0.5 })
            end
        elseif m == "flick" then
            if not st.struck and st.t >= 0.12 then
                st.struck = true
                lick(world, st.x1, st.y1, st.x2, st.y2, P.flickWidth, P.flickDamage)
                world.camera:shake(0.12)
            end
            if st.t >= 0.5 then
                st.struck = false
                st.flicks = st.flicks - 1
                if st.flicks > 0 then aimFlick(world, h) else idle(h) end
            end
        elseif m == "sweepWarn" then
            lookAt(st, st.x1 + math.cos(st.a0) * 100, st.y1 + math.sin(st.a0) * 100, dt, 6)
            if st.t >= P.sweepWarn / tp then
                setMode(h, "sweep", "TONGUE SWEEP!", true)
                Audio.play("dash", { pitch = 0.35, volume = 0.9 })
            end
        elseif m == "sweep" then
            local k = math.min(1, st.t / (P.sweepTime / tp))
            local a = st.a0 + (st.a1 - st.a0) * k
            st.sa = a
            lookAt(st, st.x1 + math.cos(a) * 100, st.y1 + math.sin(a) * 100, dt, 10)
            local x2, y2 = tongueEnd(world, st.x1, st.y1, a, P.sweepReach)
            st.sx2, st.sy2 = x2, y2
            local n = Env.strikeLane(world, st.x1, st.y1, x2, y2, P.sweepWidth, 999, { force = 0, bossMul = 0.15 })
            st.swept = (st.swept or 0) + n
            if not st.sweepHit and Env.playerInLane(world, st.x1, st.y1, x2, y2, P.sweepWidth) then
                st.sweepHit = true
                if Env.hurtPlayer(world, P.sweepDamage, p.x, p.y, { name = "anteater" }) then
                    p:knock(math.cos(st.a1) - math.cos(st.a0), math.sin(st.a1) - math.sin(st.a0), 240)
                end
            end
            if k >= 1 then
                if (st.swept or 0) >= 5 then world:floatText(x2, y2, st.swept .. " LICKED UP", { 1, 0.6, 0.6 }, true) end
                st.swept = 0
                setMode(h, "sweepBack", nil, false)
            end
        elseif m == "sweepBack" then
            if st.t >= 0.35 then idle(h) end
        elseif m == "rakeWarn" then
            lookAt(st, st.rx1, st.ry1, dt, 4)
            if st.t >= P.rakeWarn / tp then
                setMode(h, "rake", "CLAWS!", true)
                st.raked = false
            end
        elseif m == "rake" then
            if not st.raked and st.t >= 0.08 then
                st.raked = true
                local n = 0
                for _, g in ipairs(gouges(st)) do
                    n = n + Env.strikeLane(world, g[1], g[2], g[3], g[4], 6, 999, { force = 180, kx = -st.rdx, ky = -st.rdy, bossMul = 0.3 })
                    -- torn-up soil sprayed along each gouge (leaves stains)
                    for i = 0, 5 do
                        local t = i / 5
                        world.particles:burst(g[1] + (g[3] - g[1]) * t, g[2] + (g[4] - g[2]) * t, 3,
                            { { 0.32, 0.23, 0.15 }, { 0.22, 0.16, 0.1 }, { 0.45, 0.35, 0.24 } }, 70, 70, { grav = 300, stain = true })
                    end
                end
                if n >= 5 then world:floatText(st.rx2, st.ry2, n .. " RIPPED UP", { 1, 0.7, 0.5 }, true) end
                for _, g in ipairs(gouges(st)) do
                    if Env.playerInLane(world, g[1], g[2], g[3], g[4], 6) then
                        if Env.hurtPlayer(world, P.rakeDamage, p.x + st.rdx, p.y + st.rdy, { name = "anteater" }) then
                            p:knock(-st.rdx, -st.rdy, 200)
                        end
                        break
                    end
                end
                world.camera:shake(0.4)
                Audio.play("boom", { pitch = 0.6 })
            end
            if st.t >= 0.75 then idle(h) end
        end
    end,

    leave = function(world, h, dt)
        local st = h.st
        st.mode = "leave"
        st.out = st.out + dt * 150
    end,

    drawGround = function(world, h)
        local st = h.st
        local m = st.mode
        local tp = tempo(h)
        if m == "flickWarn" then
            Env.warnLane(st.x1, st.y1, st.x2, st.y2, P.flickWidth, st.t / (P.flickWarn / tp), world.time)
        elseif m == "sweepWarn" then
            -- the whole fan it is about to sweep, with the start edge marked
            local k = st.t / (P.sweepWarn / tp)
            local pts = { st.x1, st.y1 }
            for i = 0, 12 do
                local a = st.a0 + (st.a1 - st.a0) * i / 12
                local x, y = tongueEnd(world, st.x1, st.y1, a, P.sweepReach)
                pts[#pts + 1], pts[#pts + 2] = x, y
            end
            local lg = love.graphics
            lg.setColor(1, 0.25, 0.15, 0.1 + 0.16 * k + 0.06 * math.sin(world.time * (8 + k * 14)))
            Env.poly("fill", pts)
            lg.setColor(1, 0.25, 0.15, 0.5 + 0.4 * k)
            Env.poly("line", pts)
            local x2, y2 = tongueEnd(world, st.x1, st.y1, st.a0, P.sweepReach)
            Env.warnLane(st.x1, st.y1, x2, y2, P.sweepWidth, k, world.time)
        elseif m == "rakeWarn" then
            for _, g in ipairs(gouges(st)) do
                Env.warnLane(g[1], g[2], g[3], g[4], 6, st.t / (P.rakeWarn / tp), world.time)
            end
        end
        -- a big soft shadow under it
        local bx, by = body(st)
        local sx, sy = Beasts.point(bx, by, st.face, K, -40, 0)
        Env.shadow(sx + 6, sy + 6, 95, 0.5)
        local hx, hy = Beasts.point(bx, by, st.face, K, 90, 0)
        Env.shadow(hx + 4, hy + 4, 28, 0.4)
    end,

    drawAir = function(world, h)
        local st = h.st
        local m = st.mode
        local bx, by = body(st)
        -- forelegs first (the shoulders lie over them): planted either side of the head, or
        -- the raking one reaching out
        for s = -1, 1, 2 do
            local jx, jy = joint(st, s)
            local cx, cy, z = nil, nil, 0
            if st.side == s and (m == "rakeWarn" or m == "rake") then
                if m == "rakeWarn" then
                    local k = math.min(1, st.t / 0.35)
                    cx, cy = Beasts.point(bx, by, st.face, K, 110, s * 50)
                    cx, cy = cx + (st.rx1 - cx) * k, cy + (st.ry1 - cy) * k
                    z = 26 * k
                else
                    local k = math.min(1, st.t / 0.25)
                    cx, cy = st.rx1 + (st.rx2 - st.rx1) * k, st.ry1 + (st.ry2 - st.ry1) * k
                    z = 0
                    if st.t > 0.45 then
                        local b = math.min(1, (st.t - 0.45) / 0.3)
                        local rx, ry = Beasts.point(bx, by, st.face, K, 110, s * 50)
                        cx, cy = cx + (rx - cx) * b, cy + (ry - cy) * b
                    end
                end
            else
                cx, cy = Beasts.point(bx, by, st.face, K, 110, s * 50)
            end
            local dx, dy = cx - jx, cy - jy
            local d = math.sqrt(dx * dx + dy * dy) + 0.0001
            local kArm = math.max(0.6, math.min(2.4, d / 136))
            local a = math.atan2(dy, dx)
            -- stretch along the arm only: draw at kArm along, K across
            Beasts.drawUp("anteater_paw", jx, jy, z, a, K, 1, kArm)
        end
        Beasts.drawUp("anteater", bx, by, 0, st.face, K)
        -- the tongue
        if m == "flick" then
            local t = st.t
            local k = t < 0.12 and t / 0.12 or (t < 0.25 and 1 or math.max(0, 1 - (t - 0.25) / 0.25))
            Env.tongue(st.x1, st.y1, st.x2, st.y2, k, 5)
        elseif m == "sweep" and st.sx2 then
            Env.tongue(st.x1, st.y1, st.sx2, st.sy2, 1, 5)
        elseif m == "sweepBack" and st.sx2 then
            Env.tongue(st.x1, st.y1, st.sx2, st.sy2, math.max(0, 1 - st.t / 0.35), 5)
        end
    end,
}
