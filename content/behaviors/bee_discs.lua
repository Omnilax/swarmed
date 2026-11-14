-- Leafcutter bee: snips perfect discs out of leaves. Circles at a distance and flings two
-- spinning leaf discs that curve in from both sides like a pincer. Step forward or back out of
-- the crossing point; a swing bats them back.
-- params: keep (orbit distance, 110), cooldown (2.8), windup (0.4), speed (120), curve (1.5),
--         spread (0.75), shotDamage (5), life (2)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")

local LEAF = { 0.42, 0.82, 0.3 }

return {
    name = "Leaf discs",
    init = function(e)
        e.st.mode, e.st.cd, e.st.dir = "orbit", 1 + love.math.random() * 2, love.math.random() < 0.5 and -1 or 1
        e.st.ang = love.math.random() * 6.28
    end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        AI.hover(e, world, dt, 9)
        if st.mode == "orbit" then
            st.ang = st.ang + st.dir * dt * 0.7
            local keep = params.keep or 110
            AI.goTo(e, p.x + math.cos(st.ang) * keep, p.y + math.sin(st.ang) * keep, e.speed)
            st.cd = st.cd - dt
            if st.cd <= 0 and d < keep * 1.6 then st.mode, st.t = "windup", params.windup or 0.4 end
        else
            e.mx, e.my = dx / d, dy / d
            st.t = st.t - dt
            if st.t <= 0 then
                local base, sp, turn = math.atan2(dy, dx), params.speed or 120, params.curve or 1.5
                local spread = params.spread or 0.75
                for side = -1, 1, 2 do
                    local a = base + side * spread
                    world.hazards:shoot({ x = e.x, y = e.y, z = e.z, vz = 0, grav = 0, vx = math.cos(a) * sp, vy = math.sin(a) * sp,
                        turn = -side * turn, r = 3, damage = (params.shotDamage or 5) * e.damage / math.max(0.1, e.def.damage),
                        life = params.life or 2, color = LEAF })
                end
                Audio.play("dash", { pitch = 2.1 })
                st.mode, st.cd = "orbit", params.cooldown or 2.8
            end
        end
    end,
    draw = function(e)
        if e.st.mode ~= "windup" then return end
        local x, y = Iso.toScreen(e.x, e.y, e.z)
        love.graphics.setColor(LEAF[1], LEAF[2], LEAF[3], 0.4 + 0.3 * math.sin(e.st.t * 40))
        love.graphics.circle("fill", x, y, 4)
    end,
}
