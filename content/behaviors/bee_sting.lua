-- Honey bee: a buzzing cloud that drifts at you and stings. The barbed stinger tears out and
-- stays in you, still pumping venom, and the bee dies doing it. Each sting also releases alarm
-- pheromone: every honey bee close by gets faster for a few seconds.
-- params: jitter (buzzing wobble, 0.8), venom ({dps, time}, {2, 3}), alarm (radius, 110),
--         alarmTime (3), alarmSpeed (1.7), height (8)
local AI = require("src.game.ai")
local Audio = require("src.core.audio")

return {
    name = "Barbed sting",
    init = function(e) e.st.alarm, e.st.ph = 0, love.math.random() * 6.28 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        st.ph = st.ph + dt * 7
        if st.alarm > 0 then st.alarm = st.alarm - dt end
        local sp = e.speed * (st.alarm > 0 and (params.alarmSpeed or 1.7) or 1)
        local j = params.jitter or 0.8
        local nx, ny = dx / d + math.cos(st.ph) * j, dy / d + math.sin(st.ph * 1.3) * j
        local l = math.sqrt(nx * nx + ny * ny) + 0.0001
        e.mx, e.my = nx / l * sp, ny / l * sp
        AI.hover(e, world, dt, d < 22 and 1 or (params.height or 8))
        e.biteCd = 1        -- it stings once, below, instead of biting
        if d < p.radius + e.radius + 1.5 and e.z < 3 and p.dashT <= 0 and not p.dead then
            AI.sting(e, world, 1)
            local v = params.venom or { 2, 3 }
            p:poison(v[1] * e.damage / math.max(0.1, e.def.damage), v[2])
            -- alarm pheromone: the rest of the cloud goes wild
            local list, n = world:queryEnemies(e.x, e.y, params.alarm or 110)
            for i = 1, n do
                local o = list[i]
                if o.def == e.def then o.st.alarm = params.alarmTime or 3 end
            end
            if not world.flags.beeHint then
                world.flags.beeHint = true
                world:floatText(p.x, p.y, "Stingers keep pumping venom!", { 1, 0.85, 0.4 }, false)
            end
            Audio.play("hit", { pitch = 1.9 })
            st.exploded = true          -- the stinger tears out: no death effects of its own
            world:killEnemy(e)
        end
    end,
    draw = function(e)
        if e.st.alarm <= 0 then return end
        local Iso = require("src.core.iso")
        local x, y = Iso.toScreen(e.x, e.y, e.z)
        love.graphics.setColor(1, 0.85, 0.3, 0.5)
        love.graphics.rectangle("fill", math.floor(x), math.floor(y) - 5, 1, 1)
    end,
}
