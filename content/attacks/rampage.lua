-- Rampage (tiger beetle): three sprint strikes in a row, each to the next nearest ant.
-- params: damage, cooldown, strikes (3), distance (max per strike, 80), width (8), color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

local function strike(player, world, params, left, ax, ay)
    local target = world:nearestEnemy(player.x + ax * 30, player.y + ay * 30, params.distance or 80)
    local dist = params.distance or 80
    if target then
        local dx, dy = target.x - player.x, target.y - player.y
        local d = math.sqrt(dx * dx + dy * dy) + 0.001
        ax, ay, dist = dx / d, dy / d, math.min(dist, d + 14)
    end
    local x2, y2 = player.x + ax * dist, player.y + ay * dist
    for _, e in ipairs(Combat.collectLine(world, player.x, player.y, x2, y2, params.width or 8)) do
        Combat.damage(world, e, params.damage, { knockback = 120, kbx = -ay, kby = ax })
    end
    world:addFx({ kind = "streak", x = player.x, y = player.y, x2 = x2, y2 = y2, w = 5, life = 0.18, color = params.color })
    player:lunge(ax, ay, dist, 1.6)
    Audio.play("dash", { pitch = 1.2 + left * 0.15 })
    if left > 1 then
        player:after(player.dashT + 0.04, function(p, w) strike(p, w, params, left - 1, p.aimX, p.aimY) end)
    end
end

return {
    name = "Rampage",
    range = function(params) return params.distance or 80 end,
    fire = function(player, world, ax, ay, params)
        strike(player, world, params, params.strikes or 3, ax, ay)
    end,
}
