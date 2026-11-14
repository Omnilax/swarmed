-- Tumble (millipede): curls into a wheel and rolls, bowling over every ant in the way.
-- params: distance (110), speed (0.8), damage (per ant, 10), knockback (180)
local Combat = require("src.game.combat")
local util = require("src.core.util")

local function wheel(player)
    local spiral = require("content.attacks.coil").spiral
    spiral(player, -(player.rollT or 0) * 25)
end

return {
    name = "Tumble",
    description = "Curl into an armoured wheel and roll, bowling over every ant in your path.",
    start = function(player, world, dx, dy, params)
        player:lunge(dx, dy, params.distance or 110, params.speed or 0.8)
        player.dashHit = {}
        player.rollT = 0
        if player.chain then player.chainPose = wheel end
    end,
    update = function(player, world, dt, params)
        player.rollT = (player.rollT or 0) + dt
        for _, e in ipairs(Combat.collect(world, player.x, player.y, 10)) do
            if not player.dashHit[e] then
                player.dashHit[e] = true
                local nx, ny = util.normalize(e.x - player.x, e.y - player.y)
                Combat.damage(world, e, params.damage or 10, { knockback = params.knockback or 180, kbx = nx + player.dashX, kby = ny + player.dashY })
            end
        end
        if player.dashT <= dt and player.chainPose == wheel then player.chainPose = nil end
    end,
}
