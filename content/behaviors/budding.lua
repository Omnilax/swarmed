-- Pharaoh ant: tiny ants in enormous numbers. Kill one and its neighbours scatter in every
-- direction, then regroup into new little swarms and come again (real pharaoh ant colonies
-- split up, "bud", when disturbed). Hard to sweep up in one go.
-- params: radius (how far a death is noticed, 45), scatter ({min, max} seconds, {0.5, 1.0}),
--         wobble (0.4)
local AI = require("src.game.ai")

return {
    name = "Scatter and regroup",
    init = function(e) e.st.mode, e.st.t, e.st.wt = "swarm", 0, love.math.random() * 6.28 end,
    update = function(e, world, dt, params)
        local st = e.st
        if st.mode == "swarm" then
            local deaths = world.recentDeaths
            local r2 = (params.radius or 45) ^ 2
            for i = 1, deaths.n do
                local k = deaths[i]
                if k.id == e.def.id then
                    local fx, fy = e.x - k.x, e.y - k.y
                    if fx * fx + fy * fy < r2 then
                        local l = math.sqrt(fx * fx + fy * fy) + 0.01
                        local a = math.atan2(fy, fx) + (love.math.random() - 0.5) * 1.2
                        local sc = params.scatter or { 0.5, 1.0 }
                        st.mode, st.t = "scatter", sc[1] + love.math.random() * (sc[2] - sc[1])
                        st.dx, st.dy = math.cos(a), math.sin(a)
                        break
                    end
                end
            end
            if st.mode == "swarm" then
                local dx, dy, d = AI.toPlayer(e, world)
                st.wt = st.wt + dt * 5
                local w = math.sin(st.wt) * (params.wobble or 0.4)
                e.mx, e.my = (dx / d - dy / d * w) * e.speed, (dy / d + dx / d * w) * e.speed
            end
        else
            local s = e.speed * 1.6
            e.mx, e.my = st.dx * s, st.dy * s
            st.t = st.t - dt
            if st.t <= 0 then st.mode = "swarm" end
        end
    end,
}
