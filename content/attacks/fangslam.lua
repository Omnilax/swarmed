-- Fang slam (tarantula): rears up on its back legs, fangs raised, then crashes down on the ants
-- in front. Everything under it is stunned for a moment and flung back, and a ring of shed
-- hairs drifts out over the crowd.
-- params: damage, cooldown, radius (40), offset (18), windup (0.28 s), stun (seconds, 1.2),
--         knockback, color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

return {
    name = "Fang Slam",
    range = function(params) return (params.radius or 40) + (params.offset or 18) end,
    fire = function(player, world, ax, ay, params)
        local wind = params.windup or 0.28
        player.rear = { t = 0, time = wind }
        Audio.play("dash", { pitch = 0.5 })
        player:after(wind, function(p, w)
            local area = 1 + p.stats:get("area") / 100
            local r = (params.radius or 40) * area
            local cx, cy = p.x + p.aimX * (params.offset or 18), p.y + p.aimY * (params.offset or 18)
            local stun = { 0.05, params.stun or 1.2 }
            local hits = Combat.area(w, cx, cy, r, params.damage, { knockback = params.knockback or 200, slow = stun })
            w:addFx({ kind = "ring", x = cx, y = cy, r = r, life = 0.22, color = params.color })
            w:addFx({ kind = "ring", x = cx, y = cy, r = r * 0.55, life = 0.16, color = { 1, 1, 1 } })
            w.particles:burst(cx, cy, 14, { { 0.7, 0.62, 0.52 }, { 0.5, 0.42, 0.36 } }, 80, 40, { grav = 220 })
            -- urticating hairs drift outward
            for i = 1, 10 do
                local a = i / 10 * math.pi * 2
                w.particles:spawn(cx, cy, 4, math.cos(a) * 60, math.sin(a) * 60, 6, 0.8, { 1, 0.6, 0.3 }, 1, { grav = -5 })
            end
            w.camera:shake(0.1 + hits * 0.004)
            p.rear = nil
            Audio.play("hit", { pitch = 0.5 })
        end)
    end,
    update = function(player, world, dt)
        local r = player.rear
        if r then r.t = r.t + dt end
    end,
}
