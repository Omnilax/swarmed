-- Krill: a school that swims at you as one, every krill weaving a little. A lantern krill glows,
-- and krill near its light swim faster (lit) while they stay close to it.
-- params: wobble (radians, 0.6), wobbleSpeed (5), lantern (radius of its light, nil = not a
--         lantern), litSpeed (speed x for krill in a lantern's light, 1.35)
local AI = require("src.game.ai")

return {
    name = "Krill school",
    init = function(e) e.st.wt, e.st.lit, e.st.ping = love.math.random() * 6.28, 0, love.math.random() * 0.4 end,
    update = function(e, world, dt, params)
        local st = e.st
        local dx, dy, d = AI.toPlayer(e, world)
        st.wt = st.wt + dt * (params.wobbleSpeed or 5)
        local a = math.atan2(dy, dx) + math.sin(st.wt) * (params.wobble or 0.6)
        if st.lit > 0 then st.lit = st.lit - dt end
        local sp = e.speed * (st.lit > 0 and (params.litSpeed or 1.35) or 1)
        e.mx, e.my = math.cos(a) * sp, math.sin(a) * sp
        -- a lantern lights up the school around it
        if params.lantern then
            st.ping = st.ping - dt
            if st.ping <= 0 then
                st.ping = 0.4
                local list, n = world:queryEnemies(e.x, e.y, params.lantern)
                for i = 1, n do
                    local o = list[i]
                    if o.behavior == e.behavior and o.st.lit then o.st.lit = 0.6 end
                end
            end
        end
    end,
}
