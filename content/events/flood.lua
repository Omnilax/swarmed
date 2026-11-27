-- Flood: the sprinkler's on. Water spreads in from one side of the arena, then drains away.
-- In the water everyone wades (you a little, ants a lot), the current pushes downstream and
-- small ants drown. Fight from the shallows and let the water do the work.
local Env = require("src.game.envfx")
local Audio = require("src.core.audio")

local RISE, HOLD, FALL = 8, 6, 6
local REACH = 0.45        -- share of the arena it covers at its highest

-- How far in from its side a point is (0 at the side's wall).
local function depthOf(world, st, x, y)
    local S = world.size
    if st.side == 1 then return x elseif st.side == 2 then return S - x elseif st.side == 3 then return y end
    return S - y
end

local function inWater(world, st, x, y) return depthOf(world, st, x, y) < st.level end

return {
    name = "Flood",
    description = "Water rushes in. Ants wade and small ones drown.",
    color = { 0.5, 0.75, 1 },
    kind = "hazard",
    weight = 7, minWave = 4,
    duration = RISE + HOLD + FALL,
    start = function(world, ev)
        local st = ev.st
        -- from the side furthest from the player, so it comes at you
        local p, S = world.player, world.size
        local d = { p.x, S - p.x, p.y, S - p.y }
        st.side = 1
        for i = 2, 4 do if d[i] > d[st.side] then st.side = i end end
        st.level, st.tick = 0, 0
        local push = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
        st.dx, st.dy = push[st.side][1], push[st.side][2]
        Audio.play("rumble", { pitch = 0.6 })
    end,
    update = function(world, ev, dt)
        local st, S = ev.st, world.size
        local t = ev.t
        local k
        if t < RISE then k = t / RISE elseif t < RISE + HOLD then k = 1 else k = math.max(0, 1 - (t - RISE - HOLD) / FALL) end
        st.level = S * REACH * (k * k * (3 - 2 * k))
        local p = world.player
        if not p.dead and inWater(world, st, p.x, p.y) and (p.z or 0) < 4 then
            p.x = math.max(p.radius, math.min(S - p.radius, p.x + st.dx * 22 * dt))
            p.y = math.max(p.radius, math.min(S - p.radius, p.y + st.dy * 22 * dt))
        end
        st.tick = st.tick + dt
        if st.tick >= 0.5 and st.level > 4 then
            st.tick = 0
            for i = 1, world.enemyCount do
                local e = world.enemies[i]
                if not e.dead and (e.z or 0) < 4 and not e.hidden and inWater(world, st, e.x, e.y) then
                    e.kvx, e.kvy = e.kvx + st.dx * 25 / e.mass, e.kvy + st.dy * 25 / e.mass
                    if e.radius <= 4.5 and not e.def.boss and not e.def.aquatic then
                        Env.hurtAnt(world, e, 2.5 + world.spawner.wave * 0.3)
                        if love.math.random() < 0.3 then world.particles:spawn(e.x, e.y, 2, 0, 0, 25, 0.4, { 0.7, 0.85, 1 }, 1, { grav = 80 }) end
                    end
                end
            end
        end
    end,
    field = function(world, ev, x, y, who)
        if not inWater(world, ev.st, x, y) then return 1 end
        if who == "player" then return world.player.z > 4 and 1 or 0.72 end
        if (who.z or 0) > 4 or who.def.encounter then return 1 end
        if who.def.aquatic then return 1.12 end   -- shrimp, krill, plankton
        return 0.5
    end,
    drawGround = function(world, ev)
        local st, S, lg = ev.st, world.size, love.graphics
        local L = st.level
        if L <= 1 then return end
        local pts
        if st.side == 1 then pts = { 0, 0, L, 0, L, S, 0, S }
        elseif st.side == 2 then pts = { S - L, 0, S, 0, S, S, S - L, S }
        elseif st.side == 3 then pts = { 0, 0, S, 0, S, L, 0, L }
        else pts = { 0, S - L, S, S - L, S, S, 0, S } end
        lg.setColor(0.25, 0.45, 0.75, 0.42)
        Env.poly("fill", pts)
        -- the shoreline: a bright wavy edge, and ripples on the water
        local n = 24
        local line = {}
        for i = 0, n do
            local u = i / n * S
            local wob = math.sin(u * 0.05 + world.time * 3) * 3
            local x, y
            if st.side == 1 then x, y = L + wob, u elseif st.side == 2 then x, y = S - L - wob, u
            elseif st.side == 3 then x, y = u, L + wob else x, y = u, S - L - wob end
            local Iso = require("src.core.iso")
            local sx, sy = Iso.toScreen(x, y)
            line[#line + 1], line[#line + 2] = sx, sy
        end
        lg.setColor(0.8, 0.92, 1, 0.75)
        lg.setLineWidth(2)
        lg.line(line)
        lg.setLineWidth(1)
        lg.setColor(0.75, 0.9, 1, 0.25)
        for i = 1, 10 do
            local u = (i * 97 + world.time * 30) % S
            local v = ((i * 53) % 100) / 100 * L
            local x, y
            if st.side == 1 then x, y = v, u elseif st.side == 2 then x, y = S - v, u elseif st.side == 3 then x, y = u, v else x, y = u, S - v end
            Env.ellipse("line", x, y, 6 + (world.time * 4 + i) % 6)
        end
    end,
}
