-- Tiger beetle sprint: dashes forward through the crowd, cutting every ant along the path.
-- params: damage, cooldown, distance (60), width (8), knockback, color, poison ({dps, seconds})
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

return {
    name = "Sprint Strike",
    range = function(params, player) return (params.distance or 60) * (1 + player.stats:get("area") / 200) end,
    fire = function(player, world, ax, ay, params)
        local dist = (params.distance or 60) * (1 + player.stats:get("area") / 200)
        local x2, y2 = player.x + ax * dist, player.y + ay * dist
        local hits = Combat.collectLine(world, player.x, player.y, x2, y2, params.width or 8)
        for _, e in ipairs(hits) do
            -- knocked aside, away from the line
            local sx, sy = -ay, ax
            if (e.x - player.x) * sx + (e.y - player.y) * sy < 0 then sx, sy = -sx, -sy end
            Combat.damage(world, e, params.damage, { knockback = params.knockback or 90, kbx = sx, kby = sy, poison = params.poison })
        end
        world:addFx({ kind = "streak", x = player.x, y = player.y, x2 = x2, y2 = y2, w = 5, life = 0.18, color = params.color })
        player:lunge(ax, ay, dist, 1.2)
        Audio.play("dash", { pitch = 1.3 })
        if #hits >= 5 then world.camera:shake(0.05 + #hits * 0.005) end
    end,
}
