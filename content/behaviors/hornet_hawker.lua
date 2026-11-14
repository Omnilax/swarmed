-- Asian hornet (Vespa velutina): hunts by "hawking", hovering in front of a hive and snatching
-- bees out of the air as they fly. This one hovers to your side and reads your dashes: dash
-- near it and it shoots to where your dash ends and is waiting there to sting. Walk away from
-- it, or dash when it's busy.
-- params: keep (55), read (seconds between interceptions, 2.5), strike (speed x, 4),
--         mult (sting x at an interception, 1.6), cooldown (between normal darts, 3.5)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")

return {
    name = "Hawker",
    init = function(e) e.st.mode, e.st.read, e.st.cd, e.st.side = "hover", 0, 2, love.math.random() < 0.5 and -1 or 1 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        e.biteCd = 1
        st.read = st.read - dt
        if st.mode ~= "intercept" and p.dashT > 0 and st.read <= 0 and d < 160 then
            -- where will the dash end?
            local Player = require("src.game.player")
            local tx = p.x + (p.dashX or 0) * Player.DASH_SPEED * p.dashT
            local ty = p.y + (p.dashY or 0) * Player.DASH_SPEED * p.dashT
            st.mode, st.tx, st.ty, st.t, st.read = "intercept", tx, ty, 0.5, params.read or 2.5
            world:floatText(e.x, e.y, "!", { 1, 0.6, 0.3 }, false)
        end
        if st.mode == "hover" then
            AI.hover(e, world, dt, 8)
            local keep = params.keep or 55
            local a = math.atan2(-dy, -dx) + st.side * 0.02
            AI.goTo(e, p.x + math.cos(a) * keep, p.y + math.sin(a) * keep, e.speed)
            -- strafe sideways round you
            e.mx, e.my = e.mx - dy / d * st.side * e.speed * 0.5, e.my + dx / d * st.side * e.speed * 0.5
            st.cd = st.cd - dt
            if st.cd <= 0 then st.mode, st.t, st.dx, st.dy = "dart", 0.35, dx / d, dy / d end
        elseif st.mode == "intercept" then
            AI.hover(e, world, dt, 2)
            local s = e.speed * (params.strike or 4)
            AI.goTo(e, st.tx, st.ty, s)
            st.t = st.t - dt
            if d < p.radius + e.radius + 3 and not p.dead then
                AI.sting(e, world, params.mult or 1.6)
                p:knock(dx, dy, 150)
                world:floatText(p.x, p.y, "INTERCEPTED", { 1, 0.6, 0.3 }, false)
                Audio.play("hit", { pitch = 0.9 })
                st.t = 0
            end
            if st.t <= 0 then st.mode, st.side = "hover", -st.side end
        else
            AI.hover(e, world, dt, 1)
            local s = e.speed * 2.6
            e.mx, e.my = st.dx * s, st.dy * s
            st.t = st.t - dt
            if d < p.radius + e.radius + 2 and not p.dead then AI.sting(e, world, 1) st.t = 0 end
            if st.t <= 0 then st.mode, st.cd = "hover", params.cooldown or 3.5 end
        end
    end,
    draw = function(e)
        local st = e.st
        if st.mode ~= "intercept" then return end
        local x, y = Iso.toScreen(st.tx, st.ty)
        love.graphics.setColor(1, 0.5, 0.25, 0.6)
        love.graphics.ellipse("line", x, y, 8, 4)
    end,
}
