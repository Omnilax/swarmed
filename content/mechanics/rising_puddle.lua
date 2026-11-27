-- A puddle that rises: bigger every wave, and it creeps outward while a wave goes on, then sinks
-- back a little in the breaks. In the water you wade (x0.75), ants struggle (x0.5) and the small
-- ones drown. Flying things don't care.
-- params: x, y (centre as a share of the arena), base (radius at wave 1), perWave, rise (extra
-- over a wave), riseTime (seconds to reach it), max
local Env = require("src.game.envfx")

local function inside(m, x, y)
    local st = m.st
    return (x - st.x) ^ 2 + (y - st.y) ^ 2 < st.r * st.r
end

return {
    name = "Rising Puddle",
    description = "A puddle grows through each wave. Water slows everything and drowns small ants.",
    start = function(world, m)
        local P, S = m.params, world.size
        m.st.x, m.st.y = (P.x or 0.5) * S, (P.y or 0.5) * S
        m.st.r, m.st.tick = P.base or 40, 0
    end,
    update = function(world, m, dt)
        local P, st, sp = m.params, m.st, world.spawner
        local wave = math.max(1, sp.wave)
        local base = math.min(P.max or 170, (P.base or 40) + (wave - 1) * (P.perWave or 10))
        local want = base
        if sp.phase == "wave" then want = math.min(P.max or 170, base + (P.rise or 45) * math.min(1, sp.waveTime / (P.riseTime or 40))) end
        st.r = st.r + (want - st.r) * math.min(1, dt * 0.8)
        st.tick = st.tick + dt
        if st.tick >= 0.5 then
            st.tick = 0
            local list, n = world:queryEnemies(st.x, st.y, st.r)
            for i = 1, n do
                local e = list[i]
                if not e.dead and (e.z or 0) < 4 and e.radius <= 4.5 and not e.def.boss and not e.def.encounter and not e.def.aquatic and inside(m, e.x, e.y) then
                    Env.hurtAnt(world, e, 2 + wave * 0.25)
                end
            end
        end
    end,
    field = function(world, m, x, y, who)
        if not inside(m, x, y) then return 1 end
        if who == "player" then return (world.player.z or 0) > 4 and 1 or 0.75 end
        if (who.z or 0) > 4 or who.def.encounter then return 1 end
        if who.def.aquatic then return 1.12 end   -- shrimp, krill, plankton
        return 0.5
    end,
    drawGround = function(world, m)
        local lg, st = love.graphics, m.st
        lg.setColor(0.22, 0.38, 0.6, 0.55)
        Env.ellipse("fill", st.x, st.y, st.r)
        lg.setColor(0.35, 0.55, 0.8, 0.4)
        Env.ellipse("fill", st.x - st.r * 0.15, st.y - st.r * 0.15, st.r * 0.6)
        lg.setColor(0.75, 0.88, 1, 0.7)
        lg.setLineWidth(2)
        Env.ellipse("line", st.x, st.y, st.r + math.sin(world.time * 2) * 1.5)
        lg.setLineWidth(1)
        lg.setColor(0.8, 0.92, 1, 0.3)
        for i = 1, 5 do
            local a = i * 1.3
            local rr = st.r * (0.2 + (i % 3) * 0.2)
            Env.ellipse("line", st.x + math.cos(a) * rr, st.y + math.sin(a) * rr, 4 + (world.time * 5 + i * 2) % 7)
        end
    end,
}
