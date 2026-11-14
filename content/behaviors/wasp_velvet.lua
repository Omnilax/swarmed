-- Velvet ant: not an ant at all but a wingless wasp, with one of the most painful stings
-- there is and a body so hard that other insects can't sting through it. Runs fast on a
-- jittery zigzag. Weak hits just glance off (CLINK): it only takes real damage from hits of at
-- least `threshold`. When struck it squeaks (stridulates) and panics, running faster.
-- params: threshold (8), glance (damage taken from weak hits, 0.15), zig (seconds per leg, 0.3),
--         turn (zigzag angle, 0.9)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")

return {
    name = "Armoured runner",
    init = function(e) e.st.t, e.st.a, e.st.panic, e.st.squeak = 0, 0, 0, 0 end,
    update = function(e, world, dt, params)
        local st = e.st
        local dx, dy, d = AI.toPlayer(e, world)
        st.t = st.t - dt
        st.panic = math.max(0, st.panic - dt)
        st.squeak = math.max(0, st.squeak - dt)
        if st.t <= 0 then
            st.t = (params.zig or 0.3) * (0.6 + love.math.random() * 0.8)
            local turn = params.turn or 0.9
            st.a = (d < 30 and 0.2 or turn) * (love.math.random() < 0.5 and -1 or 1)
        end
        local base = math.atan2(dy, dx) + st.a
        local sp = e.speed * (st.panic > 0 and 1.6 or 1)
        e.mx, e.my = math.cos(base) * sp, math.sin(base) * sp
    end,
    onHit = function(e, world, opts, dmg)
        local st = e.st
        st.panic = 0.8
        if st.squeak <= 0 then
            st.squeak = 0.5
            world:addFx({ kind = "ring", x = e.x, y = e.y, r = 12, life = 0.25, color = { 1, 0.5, 0.45 } })
        end
        if dmg < (e.params.threshold or 8) then
            world.particles:sparks(e.x, e.y, 4, { 0.9, 0.9, 1 }, opts.kbx or 0, opts.kby or 0, 1.4, 120)
            if (st.clinkT or 0) < world.time then
                st.clinkT = world.time + 0.4
                world:floatText(e.x, e.y, "CLINK", { 0.8, 0.85, 0.95 }, false)
            end
            Audio.play("hit", { pitch = 2.2 })
            return e.params.glance or 0.15
        end
        return 1
    end,
    draw = function(e)
        if e.st.squeak <= 0.3 then return end
        -- squeak lines
        local x, y = Iso.toScreen(e.x, e.y)
        x, y = math.floor(x), math.floor(y)
        love.graphics.setColor(1, 0.6, 0.5, 0.8)
        love.graphics.rectangle("fill", x + 4, y - 8, 1, 1)
        love.graphics.rectangle("fill", x + 5, y - 9, 1, 1)
        love.graphics.rectangle("fill", x + 6, y - 8, 1, 1)
        love.graphics.rectangle("fill", x + 7, y - 9, 1, 1)
    end,
}
