-- Lobster claw slam: a heavy crusher claw smashes the ground ahead; a shockwave throws ants away.
-- params: damage, cooldown, radius (blast, 34), offset (how far ahead, 30), knockback, color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

return {
    name = "Claw Slam",
    range = function(params, player)
        return ((params.offset or 30) + (params.radius or 34)) * (1 + player.stats:get("area") / 100)
    end,
    fire = function(player, world, ax, ay, params)
        local area = 1 + player.stats:get("area") / 100
        local r = (params.radius or 34) * area
        local x, y = player.x + ax * (params.offset or 30) * area, player.y + ay * (params.offset or 30) * area
        local hits = Combat.area(world, x, y, r, params.damage, { knockback = params.knockback or 220 })
        world:addFx({ kind = "ring", x = x, y = y, r = r, life = 0.25, color = params.color })
        world.particles:burst(x, y, 10, { { 0.6, 0.55, 0.5 }, { 0.75, 0.7, 0.62 } }, 90, 70, { grav = 300 })
        world.camera:shake(0.15 + math.min(0.3, hits * 0.01))
        Audio.play("boom", { pitch = 1.3 })
    end,
}
