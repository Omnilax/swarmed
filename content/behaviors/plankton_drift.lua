-- Plankton: drifts on a slow, swirling current that carries it toward you, with a sharp kick
-- now and then (a copepod's jump). Tiny and weak, but they come in clouds.
-- params: drift (speed x while drifting, 0.4), kick (speed x at the start of a kick, 3),
--         every ({min, max} seconds between kicks, {0.5, 1.2}), swirl (radians off course, 1.1)
local AI = require("src.game.ai")

return {
    name = "Plankton drift",
    init = function(e) e.st.t, e.st.v, e.st.ph = love.math.random(), 0.4, love.math.random() * 6.28 end,
    update = function(e, world, dt, params)
        local st = e.st
        local dx, dy = AI.toPlayer(e, world)
        local drift = params.drift or 0.4
        st.v = math.max(drift, st.v - dt * 6)
        st.t = st.t - dt
        if st.t <= 0 then
            local r = params.every or { 0.5, 1.2 }
            st.t = r[1] + love.math.random() * (r[2] - r[1])
            st.v = params.kick or 3
            e.squash = 0.08
        end
        -- the current: everyone nearby swirls the same way (it follows the world clock and place)
        local swirl = math.sin(world.time * 0.6 + e.x * 0.012 + st.ph * 0.3) * (params.swirl or 1.1)
        local a = math.atan2(dy, dx) + swirl * (st.v > drift + 0.2 and 0.3 or 1)
        local sp = e.speed * st.v
        e.mx, e.my = math.cos(a) * sp, math.sin(a) * sp
    end,
}
