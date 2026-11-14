-- Wide melee sweep in the aim direction. Great for mowing down a line of ants.
-- params: damage, cooldown, radius, arc (radians), knockback, color
local Combat = require("src.game.combat")
local util = require("src.core.util")

return {
    name = "Sweep",
    range = function(params, player) return params.radius * (1 + player.stats:get("area") / 100) end,
    fire = function(player, world, ax, ay, params)
        local radius = params.radius * (1 + player.stats:get("area") / 100)
        local half = (params.arc or 2.4) / 2
        local ang = math.atan2(ay, ax)
        local targets = Combat.collect(world, player.x, player.y, radius, function(e, dx, dy)
            return math.abs(util.angleDiff(ang, math.atan2(dy, dx))) <= half
        end)
        for _, e in ipairs(targets) do
            local nx, ny = util.normalize(e.x - player.x, e.y - player.y)
            Combat.damage(world, e, params.damage, { knockback = params.knockback, kbx = nx, kby = ny })
        end
        -- swat incoming acid and pebbles back the way they came
        world.hazards:deflect(player.x, player.y, radius, ang, half)
        -- swings alternate left-to-right and right-to-left
        player.swingDir = -(player.swingDir or 1)
        world:addFx({ kind = "arc", x = player.x, y = player.y, r = radius, a = ang, arc = half * 2, dir = player.swingDir, life = 0.16, color = params.color })
        if #targets >= 5 then world.camera:shake(0.06 + #targets * 0.005) end
    end,
}
