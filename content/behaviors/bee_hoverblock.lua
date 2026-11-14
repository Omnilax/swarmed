-- Carpenter bee: the males can't sting, so they guard by getting in your face. It hovers right
-- in front of you wherever you're heading, solid as a wall, and now and then head-butts you.
-- Swat it out of the way or dash past.
-- params: gap (how far in front of you, 22), headbutt (seconds between butts, 2.6),
--         windup (0.35), knock (200)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local util = require("src.core.util")

return {
    name = "In your face",
    init = function(e) e.st.mode, e.st.cd = "block", 1 + love.math.random() end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        e.biteCd = 1
        AI.hover(e, world, dt, 3)
        if st.mode == "block" then
            -- block the way you're going (or the way you face when standing still)
            local fx, fy = util.normalize(p.vx or 0, p.vy or 0)
            if not p.moving then fx, fy = p.aimX, p.aimY end
            local gap = params.gap or 22
            AI.goTo(e, p.x + fx * gap, p.y + fy * gap, e.speed * (d > 60 and 1 or 1.8))
            st.cd = st.cd - dt
            if st.cd <= 0 and d < 40 then st.mode, st.t = "windup", params.windup or 0.35 end
        elseif st.mode == "windup" then
            e.mx, e.my = -dx / d * 20, -dy / d * 20     -- rears back
            st.t = st.t - dt
            if st.t <= 0 then st.mode, st.t, st.dx, st.dy = "butt", 0.18, dx / d, dy / d end
        else
            e.mx, e.my = st.dx * 260, st.dy * 260
            st.t = st.t - dt
            if d < p.radius + e.radius + 2 then
                AI.sting(e, world, 1)
                p:knock(st.dx, st.dy, params.knock or 200)
                world.camera:shake(0.15)
                st.t = 0
            end
            if st.t <= 0 then st.mode, st.cd = "block", params.headbutt or 2.6 end
        end
    end,
    draw = function(e)
        if e.st.mode ~= "windup" then return end
        local x, y = Iso.toScreen(e.x, e.y, e.z)
        love.graphics.setColor(1, 0.8, 0.3, 0.5 + 0.4 * math.sin(e.st.t * 50))
        love.graphics.circle("line", x, y, 6)
    end,
}
