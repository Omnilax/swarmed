-- Hover wasp (Stenogastrinae): hangs perfectly still in the air, then darts. It watches your
-- rhythm: just before your attack lands it flicks sideways out of the way. It can only do
-- that every so often, so hit it right after it dodges, or with something wide.
-- params: keep (hover distance, 46), dodge (sidestep distance, 26), dodgeCd (1.4),
--         dart (speed x, 3), cooldown (2.2)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")

return {
    name = "Hover and dodge",
    init = function(e)
        e.st.mode, e.st.cd, e.st.dodgeCd, e.st.ang = "hover", 1.5, 0, love.math.random() * 6.28
    end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        e.biteCd = 1
        st.dodgeCd = st.dodgeCd - dt
        -- your swing is about to come: flick aside
        if st.dodgeCd <= 0 and st.mode ~= "dart" and p.attack.timer < 0.06 and d < p:attackRange() + 14 and not p.dead then
            local side = love.math.random() < 0.5 and -1 or 1
            local step = params.dodge or 26
            local nx, ny = -dy / d * side, dx / d * side
            st.gx, st.gy, st.gt = e.x, e.y, 0.25
            e.x, e.y = e.x + nx * step * 0.7, e.y + ny * step * 0.7
            e.kvx, e.kvy = nx * step * 4, ny * step * 4
            st.dodgeCd = params.dodgeCd or 1.4
            st.ang = math.atan2(e.y - p.y, e.x - p.x)
            world:floatText(e.x, e.y, "dodge", { 0.75, 0.85, 1 }, false)
        end
        if st.gt then
            st.gt = st.gt - dt
            if st.gt <= 0 then st.gt = nil end
        end
        if st.mode == "hover" then
            -- dead still in the air, just drifting round you very slowly
            AI.hover(e, world, dt, 7)
            st.ang = st.ang + dt * 0.25
            local keep = params.keep or 46
            AI.goTo(e, p.x + math.cos(st.ang) * keep, p.y + math.sin(st.ang) * keep, e.speed)
            st.cd = st.cd - dt
            if st.cd <= 0 then st.mode, st.t, st.dx, st.dy = "dart", 0.35, dx / d, dy / d end
        elseif st.mode == "dart" then
            AI.hover(e, world, dt, 1)
            local s = e.speed * (params.dart or 3)
            e.mx, e.my = st.dx * s, st.dy * s
            st.t = st.t - dt
            if d < p.radius + e.radius + 2 and not p.dead then
                AI.sting(e, world, 1)
                Audio.play("hit", { pitch = 1.6 })
                st.t = 0
            end
            if st.t <= 0 then st.mode, st.cd = "hover", params.cooldown or 2.2 st.ang = math.atan2(e.y - p.y, e.x - p.x) end
        end
    end,
    -- an afterimage where it was before the dodge
    draw = function(e)
        local st = e.st
        if not st.gt then return end
        local x, y = Iso.toScreen(st.gx, st.gy, e.z)
        love.graphics.setColor(0.7, 0.85, 1, st.gt * 2)
        love.graphics.circle("line", x, y, 3)
    end,
}
