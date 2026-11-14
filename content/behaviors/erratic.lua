-- Crazy ant: darts in random directions every split second, only loosely toward the player.
-- params: jitter (max angle off the player direction, 2.2), switch ({min, max} seconds, {0.08, 0.25})
return {
    name = "Erratic",
    init = function(e) e.st.t, e.st.dir = 0, love.math.random() * math.pi * 2 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        st.t = st.t - dt
        if st.t <= 0 then
            local sw = params.switch or { 0.08, 0.25 }
            st.t = sw[1] + love.math.random() * (sw[2] - sw[1])
            local j = params.jitter or 2.2
            st.dir = math.atan2(p.y - e.y, p.x - e.x) + (love.math.random() * 2 - 1) * j
            st.burst = 0.6 + love.math.random() * 0.7
        end
        e.mx, e.my = math.cos(st.dir) * e.speed * st.burst, math.sin(st.dir) * e.speed * st.burst
    end,
}
