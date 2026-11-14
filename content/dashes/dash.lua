-- The standard dash, tunable: distance, speed (x normal), hop (height of a jump, px),
-- charges (uses before it needs to recharge), ram (damage to ants you pass through), knockback.
local Combat = require("src.game.combat")
local util = require("src.core.util")

return {
    name = "Dash",
    description = "A quick burst of speed. You can't be hurt while dashing.",
    start = function(player, world, dx, dy, params)
        player:lunge(dx, dy, params.distance or 67, params.speed or 1)
        player.dashHop = params.hop or 0
        player.dashHit = params.ram and {} or nil
    end,
    update = function(player, world, dt, params)
        if not player.dashHit or not params.ram then return end
        for _, e in ipairs(Combat.collect(world, player.x, player.y, player.radius + 4)) do
            if not player.dashHit[e] then
                player.dashHit[e] = true
                local nx, ny = util.normalize(e.x - player.x, e.y - player.y)
                Combat.damage(world, e, params.ram, { knockback = params.knockback or 150, kbx = nx, kby = ny })
            end
        end
    end,
}
