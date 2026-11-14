-- Jumping spider pounce: leaps onto the target and lands with a splash of damage.
-- params: damage, cooldown, distance (max leap, 80), radius (landing hit, 26), knockback, color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

return {
    name = "Pounce",
    range = function(params, player) return (params.distance or 80) end,
    fire = function(player, world, ax, ay, params)
        local target = world:nearestEnemy(player.x + ax * 30, player.y + ay * 30, params.distance or 80)
        local dist = params.distance or 80
        if target then
            local dx, dy = target.x - player.x, target.y - player.y
            dist = math.max(4, math.sqrt(dx * dx + dy * dy) - 4)
            ax, ay = dx / (dist + 4), dy / (dist + 4)
        else
            dist = dist * 0.5
        end
        player:lunge(ax, ay, dist, 1.4)
        Audio.play("dash", { pitch = 1.6 })
        player:after(player.dashT, function(p, w)
            local r = (params.radius or 26) * (1 + p.stats:get("area") / 100)
            local hits = Combat.area(w, p.x, p.y, r, params.damage, { knockback = params.knockback or 120 })
            w:addFx({ kind = "ring", x = p.x, y = p.y, r = r, life = 0.18, color = params.color })
            w.particles:burst(p.x, p.y, 5, { { 0.7, 0.66, 0.58 } }, 50, 30, { grav = 200 })
            if hits >= 4 then w.camera:shake(0.06 + hits * 0.005) end
        end)
    end,
}
