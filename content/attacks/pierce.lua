-- Horn pierce (rhino beetle): a long, heavy thrust that skewers every ant in a line and shoves
-- them all straight back.
-- params: damage, cooldown, range (95), width (7), knockback (240), color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

return {
    name = "Horn Pierce",
    range = function(params, player) return (params.range or 95) * (1 + player.stats:get("area") / 100) end,
    fire = function(player, world, ax, ay, params)
        local reach = (params.range or 95) * (1 + player.stats:get("area") / 100)
        local x2, y2 = player.x + ax * reach, player.y + ay * reach
        local hits = Combat.collectLine(world, player.x, player.y, x2, y2, params.width or 7)
        for _, e in ipairs(hits) do
            Combat.damage(world, e, params.damage, { knockback = params.knockback or 240, kbx = ax, kby = ay })
        end
        world:addFx({ kind = "stab", x = player.x, y = player.y, x2 = x2, y2 = y2, w = 4, life = 0.18, color = params.color })
        world:addFx({ kind = "arc", x = player.x, y = player.y, r = reach * 0.5, a = math.atan2(ay, ax), arc = 0.5, life = 0.12, color = params.color })
        player.kvx, player.kvy = player.kvx + ax * 90, player.kvy + ay * 90
        world.camera:shake(0.1 + math.min(0.3, #hits * 0.01))
        Audio.play("boom", { pitch = 1.6 })
    end,
}
