-- Wood ant: races around to get behind the player (relative to where you face), then rushes in
-- for a few seconds before circling again.
-- params: behind (distance behind the player to aim for, 40), rush (seconds, 1.6)
local AI = require("src.game.ai")

return {
    name = "Flanker",
    init = function(e) e.st.mode, e.st.dir = "flank", love.math.random() < 0.5 and -1 or 1 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        if st.mode == "rush" then
            e.mx, e.my = dx / d * e.speed, dy / d * e.speed
            st.t = st.t - dt
            if st.t <= 0 then st.mode = "flank" end
            return
        end
        local fx, fy = p.aimX or 1, p.aimY or 0
        local bx, by = p.x - fx * (params.behind or 40), p.y - fy * (params.behind or 40)
        -- in front of the player? swing around the side instead of straight through
        local front = (-dx * fx - dy * fy) / d
        if front > -0.3 and d < 160 then
            local r = math.max(50, d)
            local a = math.atan2(-dy, -dx) + st.dir * 1.2
            AI.goTo(e, p.x + math.cos(a) * r, p.y + math.sin(a) * r, e.speed)
        else
            local left = AI.goTo(e, bx, by, e.speed)
            if left < 14 then st.mode, st.t = "rush", params.rush or 1.6 end
        end
    end,
}
