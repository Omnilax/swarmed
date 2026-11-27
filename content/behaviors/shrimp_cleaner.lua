-- Cleaner shrimp: stays out of the fight and picks over the wounded. It swims to the most hurt
-- bug nearby and cleans it, mending it while it stays close; when you come near it flicks away.
-- params: heal (hp per second it mends, 4), search (radius it looks for patients in, 170),
--         keep (distance it keeps from you when idle, 120), shy (flicks away when you are this
--         close, 46), flick (tail-flip push, 240)
local AI = require("src.game.ai")
local util = require("src.core.util")

local SPARK = { { 1, 1, 1 }, { 0.7, 0.95, 1 } }

return {
    name = "Cleaner",
    init = function(e) e.st.look, e.st.cd = 0, 0 end,
    update = function(e, world, dt, params)
        local st = e.st
        local dx, dy, d = AI.toPlayer(e, world)
        if st.cd > 0 then st.cd = st.cd - dt end
        -- too close: snap away backwards
        if d < (params.shy or 46) and st.cd <= 0 then
            local push = (params.flick or 240) / math.max(0.4, e.mass)
            e.kvx, e.kvy = e.kvx - dx / d * push, e.kvy - dy / d * push
            st.cd, e.squash = 1.4, 0.14
        end
        -- who needs cleaning (re-checked a few times a second)
        st.look = st.look - dt
        if st.look <= 0 then
            st.look = 0.35
            st.patient = nil
            local worst = 0.95
            local list, n = world:queryEnemies(e.x, e.y, params.search or 170)
            for i = 1, n do
                local o = list[i]
                if o ~= e and not o.dead and not o.def.boss and o.maxHp > 0 and o.hp / o.maxHp < worst then
                    worst, st.patient = o.hp / o.maxHp, o
                end
            end
        end
        local o = st.patient
        if o and not o.dead then
            local ox, oy = o.x - e.x, o.y - e.y
            local od = math.sqrt(ox * ox + oy * oy) + 0.0001
            local reach = o.radius + e.radius + 4
            if od > reach then
                e.mx, e.my = ox / od * e.speed, oy / od * e.speed
            else
                -- cleaning: face it, mend it, a sparkle now and then
                e.mx, e.my = ox / od * 2, oy / od * 2
                o.hp = math.min(o.maxHp, o.hp + (params.heal or 4) * dt)
                if love.math.random() < dt * 6 then
                    world.particles:spawn(o.x + (love.math.random() - 0.5) * 6, o.y + (love.math.random() - 0.5) * 6, 4,
                        0, 0, 12, 0.4, SPARK[love.math.random(2)], 1, { glow = true, grav = 0 })
                end
                if o.hp >= o.maxHp then st.patient, st.look = nil, 0 end
            end
        else
            -- nobody to clean: hang back at a distance, drifting sideways
            local keep = params.keep or 120
            local want = util.clamp((d - keep) / 30, -1, 1)
            local side = math.sin(world.time * 0.8 + e.uid) * 0.6
            e.mx = (dx / d * want - dy / d * side) * e.speed
            e.my = (dy / d * want + dx / d * side) * e.speed
        end
    end,
}
