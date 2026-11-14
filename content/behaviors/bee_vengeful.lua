-- Africanized bee: the same bee, a much shorter temper. Every bee that dies near it makes it
-- angrier: faster and biting more often, up to six stacks, cooling off slowly. Killing the
-- swarm one by one makes what's left of it worse, so kill them in big sweeps.
-- params: notice (radius in which deaths count, 140), maxAnger (6), perStack (speed per stack,
--         0.14), cool (stacks lost per second, 0.2), height (7)
local AI = require("src.game.ai")
local Content = require("src.content")
local Iso = require("src.core.iso")

return {
    name = "Vengeful swarm",
    init = function(e) e.st.anger, e.st.ph = 0, love.math.random() * 6.28 end,
    update = function(e, world, dt, params)
        local st = e.st
        local dx, dy, d = AI.toPlayer(e, world)
        local deaths, r2 = world.recentDeaths, (params.notice or 140) ^ 2
        for i = 1, deaths.n do
            local k = deaths[i]
            local kd = Content.enemies:get(k.id)
            if kd and kd.family == "bee" and (k.x - e.x) ^ 2 + (k.y - e.y) ^ 2 < r2 then
                st.anger = math.min(params.maxAnger or 6, st.anger + 1)
            end
        end
        st.anger = math.max(0, st.anger - dt * (params.cool or 0.2))
        local sp = e.speed * (1 + st.anger * (params.perStack or 0.14))
        st.ph = st.ph + dt * (6 + st.anger)
        local nx, ny = dx / d + math.cos(st.ph) * 0.5, dy / d + math.sin(st.ph * 1.4) * 0.5
        local l = math.sqrt(nx * nx + ny * ny) + 0.0001
        e.mx, e.my = nx / l * sp, ny / l * sp
        AI.hover(e, world, dt, d < 22 and 1 or (params.height or 7))
        -- angrier bees bite faster
        if e.biteCd > 0 then e.biteCd = e.biteCd - dt * st.anger * 0.15 end
    end,
    -- a red glint that grows with its anger
    draw = function(e)
        local a = e.st.anger
        if a < 1 then return end
        local x, y = Iso.toScreen(e.x, e.y, e.z)
        love.graphics.setColor(1, 0.2, 0.15, 0.12 + a * 0.08)
        love.graphics.circle("fill", x, y, 2 + a * 0.6)
    end,
}
