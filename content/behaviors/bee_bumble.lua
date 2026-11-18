-- Bumblebee: big, furry and clumsy. Bumbles along a wobbly path and body-slams you, bouncing
-- you away like a pinball (and bouncing off itself). Being knocked into the swarm is the danger.
-- params: knock (shove on the player, 260), bounce (its own rebound, 170), cooldown (0.9),
--         wobble (1.0), height (4)
local AI = require("src.game.ai")
local Audio = require("src.core.audio")

-- particle colours and options, made once (not a new table every frame)
local PFX_1 = { 1, 0.85, 0.35 }
local PFX_2 = { grav = 120 }
local PFX_LIST_1 = { PFX_1 }

return {
    name = "Bumper",
    init = function(e) e.st.cd, e.st.ph = 0, love.math.random() * 6.28 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        st.ph = st.ph + dt * 2.2
        st.cd = st.cd - dt
        local a = math.sin(st.ph) * (params.wobble or 1.0)
        local c, s = math.cos(a), math.sin(a)
        local nx, ny = dx / d, dy / d
        e.mx, e.my = (nx * c - ny * s) * e.speed, (nx * s + ny * c) * e.speed
        -- a heavy, lolloping flight: bounces up and down
        e.z = 1 + math.abs(math.sin(st.ph * 2.5)) * (params.height or 4)
        e.biteCd = 1
        if st.cd <= 0 and d < p.radius + e.radius + 2 and not p.dead then
            st.cd = params.cooldown or 0.9
            AI.sting(e, world, 1)
            p:knock(dx, dy, params.knock or 260)
            local b = (params.bounce or 170) / e.mass ^ 0.3
            e.kvx, e.kvy = -nx * b, -ny * b
            world.camera:shake(0.15)
            world.particles:burst(e.x, e.y, 5, PFX_LIST_1, 60, 30, PFX_2)
            Audio.play("hit", { pitch = 0.55 })
        end
    end,
}
