-- Treasure ant: never fights. It keeps away from the player, swerving off the arena walls so it
-- can't be cornered for free, and dives back into the ground after `escape` seconds.
-- params: escape (s, 14), panic (speed x when the player is close, 1.35), near (90), jink (s between swerves, 0.6)
local AI = require("src.game.ai")

return {
    name = "Treasure runner",
    init = function(e) e.st.t, e.st.jink, e.st.side = 0, 0, 1 end,
    update = function(e, world, dt, params)
        local st = e.st
        st.t = st.t + dt
        if st.t >= (params.escape or 14) then
            world:escapeEnemy(e, "GOT AWAY!")
            return
        end
        local dx, dy, d = AI.toPlayer(e, world)
        local ax, ay = -dx / d, -dy / d                 -- straight away from the player
        st.jink = st.jink - dt
        if st.jink <= 0 then st.jink, st.side = (params.jink or 0.6) * (0.6 + love.math.random() * 0.8), -st.side end
        -- sideways swerve, and steer back toward the middle near a wall
        ax, ay = ax - ay * 0.45 * st.side, ay + ax * 0.45 * st.side
        local S, m = world.size, 70
        local cx, cy = S / 2 - e.x, S / 2 - e.y
        local edge = math.max(0, m - math.min(e.x, e.y, S - e.x, S - e.y)) / m
        if edge > 0 then
            local cl = math.sqrt(cx * cx + cy * cy) + 0.001
            -- slide along the wall: away from the player but bent toward the centre
            ax, ay = ax * (1 - edge) + cx / cl * edge * 1.4, ay * (1 - edge) + cy / cl * edge * 1.4
        end
        local l = math.sqrt(ax * ax + ay * ay) + 0.0001
        local s = e.speed * (d < (params.near or 90) and (params.panic or 1.35) or 1)
        e.mx, e.my = ax / l * s, ay / l * s
        if love.math.random() < dt * 10 then
            world.particles:spawn(e.x, e.y, 2, 0, 0, 12, 0.5, { 1, 0.9, 0.4 }, 1, { glow = true, grav = 10 })
        end
    end,
    -- the last few seconds: a countdown ring so the chase has a clock
    drawUnder = function(e, world)
        local left = (e.params.escape or 14) - (e.st.t or 0)
        if left > 4 then return end
        local Iso = require("src.core.iso")
        local x, y = Iso.toScreen(e.x, e.y)
        love.graphics.setColor(1, 0.85, 0.3, 0.5 + 0.4 * math.sin(world.time * 14))
        love.graphics.ellipse("line", x, y + 1, 7 + left, (7 + left) * 0.5)
        love.graphics.setColor(1, 1, 1, 1)
    end,
}
