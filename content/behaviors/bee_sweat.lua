-- Sweat bee: tiny metallic bees that drink sweat. They ignore you while you stand still, but
-- start running and they home in, land on you and drink. While they're on you your dash
-- recharges slower (more bees, slower). Dash to fling them off, or stand still and they get
-- bored and leave.
-- params: drain (dash recharge lost per bee, x per second, 0.45), bored (seconds standing still
--         before they leave, 0.8), sip (seconds between little bites, 1.2), hold (max on you, 6)
local AI = require("src.game.ai")

return {
    name = "Sweat drinker",
    init = function(e)
        e.st.mode, e.st.t, e.st.ang = "idle", 0, love.math.random() * 6.28
    end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        e.biteCd = 1
        if st.mode == "idle" then
            -- drifting about, waiting for you to work up a sweat
            AI.hover(e, world, dt, 8)
            st.ang = st.ang + dt * (love.math.random() - 0.5) * 6
            local pull = p.moving and 1 or (d > 110 and 0.6 or -0.2)
            e.mx = (math.cos(st.ang) * 0.6 + dx / d * pull) * e.speed
            e.my = (math.sin(st.ang) * 0.6 + dy / d * pull) * e.speed
            if p.moving and d < p.radius + e.radius + 2 and p.dashT <= 0 and not p.dead then
                st.mode, st.t, st.sip = "drink", params.hold or 6, 0.5
                st.off = math.atan2(e.y - p.y, e.x - p.x)
                if not world.flags.sweatHint then
                    world.flags.sweatHint = true
                    world:floatText(p.x, p.y, "Sweat bees slow your dash! Stand still", { 1, 0.85, 0.4 }, false)
                end
            end
        elseif st.mode == "drink" then
            local r = p.radius + 1
            e.x, e.y, e.mx, e.my, e.kvx, e.kvy = p.x + math.cos(st.off) * r, p.y + math.sin(st.off) * r, 0, 0, 0, 0
            e.z = 3
            require("src.game.stamina").sap(p, dt, params.drain or 0.45)
            st.sip = st.sip - dt
            if st.sip <= 0 then st.sip = params.sip or 1.2 AI.sting(e, world, 1) end
            st.still = p.moving and 0 or (st.still or 0) + dt
            st.t = st.t - dt
            if p.dashT > 0 or p.dead or st.t <= 0 or st.still > (params.bored or 0.8) then
                st.mode, st.t = "leave", 1.2
                e.kvx, e.kvy = math.cos(st.off) * 150, math.sin(st.off) * 150
            end
        else
            AI.hover(e, world, dt, 9)
            e.mx, e.my = -dx / d * e.speed, -dy / d * e.speed
            st.t = st.t - dt
            if st.t <= 0 then st.mode = "idle" end
        end
    end,
}
