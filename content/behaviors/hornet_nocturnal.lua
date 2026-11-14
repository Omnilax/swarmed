-- European hornet: one of the few wasps that hunts at night, drawn to lights. In daylight it
-- is sluggish and hangs back. After dark it spirals in toward your light like a moth, tighter
-- and tighter, then strikes straight through you and swings out to spiral in again.
-- (Set by the Time of Day setting: see the day/night cycle.)
-- params: night (daylight level below which it hunts, 0.45), spiral (seconds to close in, 1.8),
--         strike (speed x, 3.2), dayKeep (130)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local util = require("src.core.util")

return {
    name = "Night hunter",
    init = function(e) e.st.mode, e.st.ang, e.st.t = "spiral", love.math.random() * 6.28, 0 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        local night = world:daylight() < (params.night or 0.45)
        st.night = night
        if not night then
            -- by day: slow, keeps away, only bites if you walk into it
            AI.hover(e, world, dt, 6)
            local keep = params.dayKeep or 130
            local want = util.clamp((d - keep) / 30, -1, 1)
            e.mx, e.my = (dx / d * want - dy / d * 0.3) * e.speed * 0.55, (dy / d * want + dx / d * 0.3) * e.speed * 0.55
            st.mode, st.t = "spiral", 0
            return
        end
        e.biteCd = 1
        if st.mode == "spiral" then
            -- moth to a flame: circling in on your light
            st.t = st.t + dt
            local k = math.min(1, st.t / (params.spiral or 1.8))
            st.ang = st.ang + dt * (1.5 + k * 3)
            local r = 85 - 60 * k
            AI.hover(e, world, dt, 6)
            AI.goTo(e, p.x + math.cos(st.ang) * r, p.y + math.sin(st.ang) * r, e.speed * 2.2)
            if k >= 1 then st.mode, st.t, st.dx, st.dy = "strike", 0.45, dx / d, dy / d end
        else
            AI.hover(e, world, dt, 1)
            local s = e.speed * (params.strike or 3.2)
            e.mx, e.my = st.dx * s, st.dy * s
            st.t = st.t - dt
            if not st.stung and d < p.radius + e.radius + 2 and not p.dead then
                st.stung = true
                AI.sting(e, world, 1)
            end
            if st.t <= 0 then st.mode, st.t, st.stung, st.ang = "spiral", 0, nil, math.atan2(e.y - p.y, e.x - p.x) end
        end
    end,
    -- eyes catching your light at night
    draw = function(e)
        if not e.st.night then return end
        local x, y = Iso.toScreen(e.x, e.y, e.z)
        love.graphics.setColor(1, 0.85, 0.5, 0.8)
        love.graphics.rectangle("fill", math.floor(x) - 1, math.floor(y) - 1, 1, 1)
        love.graphics.rectangle("fill", math.floor(x) + 1, math.floor(y) - 1, 1, 1)
    end,
}
