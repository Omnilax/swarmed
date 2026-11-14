-- Cuckoo bee: sneaks into other bees' nests to lay its eggs. Almost invisible: it drifts in the
-- crowd as a faint shimmer, and only shows itself (a glint) a moment before it stings hard.
-- Hitting it while it's sneaking exposes it for a while.
-- params: strike (distance it attacks from, 34), reveal (glint time, 0.3), dash (speed x, 3.2),
--         mult (sting x damage, 2), recloak (seconds before it fades again, 2.5), faint (0.12)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")

return {
    name = "Sneak sting",
    init = function(e) e.st.mode, e.st.t, e.st.side = "sneak", 0, love.math.random() < 0.5 and -1 or 1 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        local faint = params.faint or 0.12
        e.biteCd = 1
        if st.mode == "sneak" then
            AI.hover(e, world, dt, 6)
            e.alpha = math.max(faint, (e.alpha or 1) - dt * 2)
            local side = st.side * (d < 60 and 0.8 or 0.2)
            e.mx, e.my = (dx / d - dy / d * side) * e.speed, (dy / d + dx / d * side) * e.speed
            if d < (params.strike or 34) then st.mode, st.t = "reveal", params.reveal or 0.3 end
        elseif st.mode == "reveal" then
            e.mx, e.my = 0, 0
            e.alpha = 1
            st.t = st.t - dt
            if st.t <= 0 then st.mode, st.t, st.dx, st.dy = "strike", 0.3, dx / d, dy / d end
        elseif st.mode == "strike" then
            AI.hover(e, world, dt, 1)
            local s = e.speed * (params.dash or 3.2)
            e.mx, e.my = st.dx * s, st.dy * s
            st.t = st.t - dt
            if d < p.radius + e.radius + 2 and not p.dead then
                AI.sting(e, world, params.mult or 2)
                Audio.play("hit", { pitch = 1.5 })
                st.t = 0
            end
            if st.t <= 0 then st.mode, st.t = "flee", params.recloak or 2.5 end
        else -- flee and fade back into the crowd
            AI.hover(e, world, dt, 8)
            e.mx, e.my = -dx / d * e.speed, -dy / d * e.speed
            st.t = st.t - dt
            if st.t <= 0 then st.mode, st.side = "sneak", -st.side end
        end
    end,
    onHit = function(e)
        if e.st.mode == "sneak" then e.st.mode, e.st.t, e.alpha = "flee", 1.5, 1 end
        return 1
    end,
    draw = function(e)
        if e.st.mode ~= "reveal" then return end
        local x, y = Iso.toScreen(e.x, e.y, e.z)
        love.graphics.setColor(1, 1, 0.8, 0.9)
        love.graphics.rectangle("fill", math.floor(x) - 3, math.floor(y) - 6, 7, 1)
        love.graphics.rectangle("fill", math.floor(x), math.floor(y) - 9, 1, 7)
    end,
}
