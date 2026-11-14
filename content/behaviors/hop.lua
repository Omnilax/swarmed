-- Jumping ant: never walks. Crouches, then leaps toward the player in big arcs.
-- params: distance (max per hop, 55), airtime (0.38), rest ({min, max}, {0.25, 0.55}), height (14)
local AI = require("src.game.ai")

return {
    name = "Hopper",
    init = function(e) e.st.mode, e.st.t = "rest", love.math.random() * 0.5 end,
    update = function(e, world, dt, params)
        local st = e.st
        if st.mode == "rest" then
            local dx, dy, d = AI.toPlayer(e, world)
            e.mx, e.my = dx / d * 1.2, dy / d * 1.2
            st.t = st.t - dt
            e.squash = st.t < 0.12 and 0.1 or 0      -- crouch before take-off
            if st.t <= 0 then
                local hopLen = math.min(d, params.distance or 55)
                local a = math.atan2(dy, dx) + (love.math.random() - 0.5) * 0.5
                AI.startJump(e, e.x + math.cos(a) * hopLen, e.y + math.sin(a) * hopLen, params.airtime or 0.38, params.height or 14)
                st.mode = "air"
            end
        else
            if AI.updateJump(e, dt) then
                local r = params.rest or { 0.25, 0.55 }
                st.mode, st.t = "rest", r[1] + love.math.random() * (r[2] - r[1])
                world.particles:burst(e.x, e.y, 3, { { 0.55, 0.5, 0.42 } }, 30, 20)
            end
        end
    end,
}
