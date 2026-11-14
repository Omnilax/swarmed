-- Bulldog ant: huge eyes, excellent vision. Keeps its distance and watches you, and the moment
-- you turn your back (aim away from it) it rushes in to sting. Hit it mid-rush to stagger it.
-- params: keep (watching distance, 80), watch (seconds your back must be turned, 0.3),
--         rush (speed x, 2.7), rushTime (0.9), cooldown (1.3), stagger (0.9)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local Combat = require("src.game.combat")
local util = require("src.core.util")

return {
    name = "Stalker",
    init = function(e)
        e.st.mode, e.st.seen, e.st.cd, e.st.t = "watch", 0, 1, 0
        e.st.dir = love.math.random() < 0.5 and -1 or 1
    end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        if st.mode == "watch" then
            local keep = params.keep or 80
            local want = util.clamp((d - keep) / 20, -1, 1)
            local side = st.dir * 0.6
            e.mx = (dx / d * want - dy / d * side) * e.speed
            e.my = (dy / d * want + dx / d * side) * e.speed
            -- is the player facing away from me?
            local facing = -(p.aimX * dx + p.aimY * dy) / d
            if facing < -0.1 then st.seen = st.seen + dt else st.seen = math.max(0, st.seen - dt * 2) end
            st.cd = st.cd - dt
            if st.cd <= 0 and (st.seen > (params.watch or 0.3) or d < keep * 0.45) then
                st.mode, st.t, e.hitPad = "rush", params.rushTime or 0.9, 4
            end
        elseif st.mode == "rush" then
            local s = e.speed * (params.rush or 2.7)
            e.mx, e.my = dx / d * s, dy / d * s
            st.t = st.t - dt
            if st.t <= 0 or d < p.radius + e.radius + 1 then st.mode, st.t, e.hitPad = "retreat", 0.5, 0 end
        elseif st.mode == "retreat" then
            e.mx, e.my = -dx / d * e.speed * 1.4, -dy / d * e.speed * 1.4
            st.t = st.t - dt
            if st.t <= 0 then st.mode, st.seen, st.cd = "watch", 0, params.cooldown or 1.3 end
        else -- stagger
            e.mx, e.my = 0, 0
            st.t = st.t - dt
            if st.t <= 0 then st.mode, st.seen, st.cd = "watch", 0, params.cooldown or 1.3 end
        end
    end,
    onHit = function(e, world, opts)
        if e.st.mode ~= "rush" then return 1 end
        Combat.stagger(world, e, e.params.stagger or 0.9, opts)
        return 1.5
    end,
    -- its eyes glint while it sizes you up
    draw = function(e)
        local st = e.st
        if st.mode == "stagger" then Combat.drawDazed(e) return end
        if st.mode ~= "watch" or st.seen <= 0 then return end
        local x, y = Iso.toScreen(e.x, e.y)
        love.graphics.setColor(1, 0.3, 0.2, math.min(1, st.seen * 3))
        love.graphics.rectangle("fill", math.floor(x) - 2, math.floor(y) - 6, 1, 1)
        love.graphics.rectangle("fill", math.floor(x) + 1, math.floor(y) - 6, 1, 1)
    end,
}
