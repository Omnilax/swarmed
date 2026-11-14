-- Centipede venom: bites the nearest ant and the venom jumps from ant to ant.
-- params: damage, cooldown, range (bite reach, 40), jumps (6), jumpRange (40), color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

return {
    name = "Venom Chain",
    range = function(params, player) return (params.range or 40) * (1 + player.stats:get("area") / 100) end,
    fire = function(player, world, ax, ay, params)
        local area = 1 + player.stats:get("area") / 100
        local reach = (params.range or 40) * area
        local first = world:nearestEnemy(player.x + ax * reach * 0.4, player.y + ay * reach * 0.4, reach)
        if not first then return end
        local c = params.color or { 0.7, 1, 0.3 }
        Combat.damage(world, first, params.damage * 1.5, { knockback = 50, kbx = ax, kby = ay, slow = { 0.6, 1 } })
        world:addFx({ kind = "bolt", x = player.x, y = player.y, x2 = first.x, y2 = first.y, life = 0.12, color = c })
        Combat.chain(world, first, params.jumps or 6, (params.jumpRange or 40) * area, params.damage, { color = c, slow = { 0.6, 1 } })
        Audio.play("hit", { pitch = 1.7 })
    end,
}
