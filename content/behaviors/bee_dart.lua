-- Fire bee (Oxytrigona): flies in sharp, straight darts with tiny pauses, like a spark jumping.
-- Its bite burns (the enemy's `venom`), and when it dies it bursts into a puddle of caustic
-- acid (the enemy's onDeath), so don't kill them on top of yourself.
-- params: hop (seconds per dart, 0.22), pause (0.12), dart (speed x while darting, 2.2), height (6)
local AI = require("src.game.ai")

return {
    name = "Darting",
    init = function(e) e.st.mode, e.st.t = "pause", love.math.random() * 0.3 end,
    update = function(e, world, dt, params)
        local st = e.st
        local dx, dy, d = AI.toPlayer(e, world)
        AI.hover(e, world, dt, d < 24 and 1 or (params.height or 6))
        st.t = st.t - dt
        if st.mode == "pause" then
            e.mx, e.my = e.mx * 0.5, e.my * 0.5
            if st.t <= 0 then
                -- dart off at an angle across the line to you
                local a = math.atan2(dy, dx) + (love.math.random() - 0.5) * (d < 50 and 0.6 or 1.6)
                st.dx, st.dy = math.cos(a), math.sin(a)
                st.mode, st.t = "dart", params.hop or 0.22
            end
        else
            local s = e.speed * (params.dart or 2.2)
            e.mx, e.my = st.dx * s, st.dy * s
            if st.t <= 0 then st.mode, st.t = "pause", (params.pause or 0.12) * (0.5 + love.math.random()) end
        end
    end,
}
