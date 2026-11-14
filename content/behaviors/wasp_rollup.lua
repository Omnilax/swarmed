-- Cuckoo wasp: jewel-bright and armoured like a little tank. Hit it and it curls up into a
-- ball (its real defence): the first hit lands, then it's almost immune while it rolls away,
-- bouncing, and it bowls you over if it rolls into you. Catch it when it uncurls.
-- params: ball (seconds curled, 1.6), armor (damage taken while curled, 0.1), roll (speed, 170),
--         height (6)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local util = require("src.core.util")
local Audio = require("src.core.audio")

return {
    name = "Roll up",
    init = function(e) e.st.mode, e.st.ph = "fly", love.math.random() * 6.28 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        if st.mode == "fly" then
            e.scale = e.baseScale
            st.ph = st.ph + dt * 5
            local nx, ny = dx / d + math.cos(st.ph) * 0.3, dy / d + math.sin(st.ph) * 0.3
            local l = math.sqrt(nx * nx + ny * ny) + 0.0001
            e.mx, e.my = nx / l * e.speed, ny / l * e.speed
            AI.hover(e, world, dt, d < 22 and 1 or (params.height or 6))
        else
            -- a curled-up ball rolling and bouncing off the arena edge
            e.biteCd = 1
            e.scale = e.baseScale * 0.75
            e.z = math.max(0, e.z - dt * 40)
            e.mx, e.my = st.vx, st.vy
            local k = 1 - util.damp(1.2, dt)
            st.vx, st.vy = st.vx * k, st.vy * k
            local S = world.size
            if (e.x < e.radius + 2 and st.vx < 0) or (e.x > S - e.radius - 2 and st.vx > 0) then st.vx = -st.vx end
            if (e.y < e.radius + 2 and st.vy < 0) or (e.y > S - e.radius - 2 and st.vy > 0) then st.vy = -st.vy end
            st.cd = (st.cd or 0) - dt
            if st.cd <= 0 and d < p.radius + e.radius + 1 and (st.vx * st.vx + st.vy * st.vy) > 3600 and not p.dead then
                st.cd = 0.5
                AI.sting(e, world, 1)
                p:knock(st.vx, st.vy, 180)
                st.vx, st.vy = -st.vx * 0.6, -st.vy * 0.6
                Audio.play("hit", { pitch = 1.2 })
            end
            st.t = st.t - dt
            if st.t <= 0 then st.mode = "fly" end
        end
    end,
    onHit = function(e, world, opts)
        local st = e.st
        if st.mode == "ball" then
            world.particles:sparks(e.x, e.y, 3, { 0.6, 1, 0.9 }, opts.kbx or 0, opts.kby or 0, 1.2, 100)
            return e.params.armor or 0.1
        end
        -- curl up and roll away along the blow
        local kx, ky = opts.kbx, opts.kby
        if not kx or (kx == 0 and ky == 0) then kx, ky = util.normalize(e.x - world.player.x, e.y - world.player.y) end
        local sp = e.params.roll or 170
        st.mode, st.t, st.vx, st.vy = "ball", e.params.ball or 1.6, kx * sp, ky * sp
        world:floatText(e.x, e.y, "CURLED UP", { 0.55, 1, 0.85 }, false)
        return 1
    end,
    -- a hard shine on the ball
    draw = function(e)
        if e.st.mode ~= "ball" then return end
        local x, y = Iso.toScreen(e.x, e.y, e.z)
        love.graphics.setColor(0.7, 1, 0.95, 0.6)
        love.graphics.circle("line", x, y, 4)
    end,
}
