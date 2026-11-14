-- Rapid jabs (centipede): its venom claws stab straight ahead over and over, very fast. Each jab
-- is weak but lands a little venom.
-- params: damage, cooldown (very short), reach (30), width (5), poison ({dps, seconds}), color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

return {
    name = "Venom Jabs",
    range = function(params, player)
        local tail = player.reversed and player.chain and #player.chain * player.model.spacing or 0
        return (params.reach or 30) * (1 + player.stats:get("area") / 100) + tail
    end,
    fire = function(player, world, ax, ay, params)
        local reach = (params.reach or 30) * (1 + player.stats:get("area") / 100)
        -- alternate claws: each jab is a little to one side
        player.attack.side = -(player.attack.side or 1)
        local sx, sy = -ay * 2.5 * player.attack.side, ax * 2.5 * player.attack.side
        -- reversed (holding the flip): the jabs come out of the tail end instead
        local ox, oy = player.x, player.y
        local ch = player.reversed and player.chain
        if ch then ox, oy = ch[#ch].x, ch[#ch].y end
        local x1, y1 = ox + sx, oy + sy
        local x2, y2 = x1 + ax * reach, y1 + ay * reach
        for _, e in ipairs(Combat.collectLine(world, x1, y1, x2, y2, params.width or 5)) do
            Combat.damage(world, e, params.damage, { knockback = 50, kbx = ax, kby = ay, poison = params.poison })
        end
        world:addFx({ kind = "stab", x = x1 + ax * 6, y = y1 + ay * 6, x2 = x2, y2 = y2, w = 1.5, life = 0.08, color = params.color })
        Audio.play("hit", { pitch = 2 + love.math.random() * 0.4 })
    end,
}
