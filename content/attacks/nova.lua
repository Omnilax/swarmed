-- Burst that hits everything around the player.
-- params: damage, cooldown, radius, knockback, color, slow ({mul, seconds}: e.g. irritating hairs)
local Combat = require("src.game.combat")

return {
    name = "Nova",
    range = function(params, player) return params.radius * (1 + player.stats:get("area") / 100) end,
    fire = function(player, world, ax, ay, params)
        local radius = params.radius * (1 + player.stats:get("area") / 100)
        local hits = Combat.area(world, player.x, player.y, radius, params.damage, { knockback = params.knockback, slow = params.slow })
        world.hazards:deflect(player.x, player.y, radius)
        world:addFx({ kind = "ring", x = player.x, y = player.y, r = radius, life = 0.22, color = params.color })
        if hits >= 5 then world.camera:shake(0.05 + hits * 0.005) end
    end,
}
