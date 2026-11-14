-- Mantis: two lightning-fast scything slashes, left then right.
-- params: damage, cooldown, radius (42), arc (1.8), gap (seconds between slashes, 0.09), knockback, color
local Combat = require("src.game.combat")
local util = require("src.core.util")
local Audio = require("src.core.audio")

local function slash(player, world, ang, side, params)
    local radius = (params.radius or 42) * (1 + player.stats:get("area") / 100)
    local half = (params.arc or 1.8) / 2
    local a = ang + side
    local hits = Combat.collect(world, player.x, player.y, radius, function(e, dx, dy)
        return math.abs(util.angleDiff(a, math.atan2(dy, dx))) <= half end)
    for _, e in ipairs(hits) do
        local nx, ny = util.normalize(e.x - player.x, e.y - player.y)
        Combat.damage(world, e, params.damage, { knockback = params.knockback or 70, kbx = nx, kby = ny, crit = player.swayPrimed ~= nil })
    end
    world.hazards:deflect(player.x, player.y, radius, a, half)
    world:addFx({ kind = "arc", x = player.x, y = player.y, r = radius, a = a, arc = half * 2, dir = side < 0 and 1 or -1, life = 0.14, color = params.color })
    Audio.play("dash", { pitch = 2.4 })
end

return {
    name = "Twin Scythes",
    range = function(params, player) return (params.radius or 42) * (1 + player.stats:get("area") / 100) end,
    fire = function(player, world, ax, ay, params)
        local ang = math.atan2(ay, ax)
        slash(player, world, ang, -0.4, params)
        player:after(params.gap or 0.09, function(p, w)
            slash(p, w, math.atan2(p.aimY, p.aimX), 0.4, params)
            p.lungeT = 0.18
            p.swayPrimed = nil -- Leaf Sway's sure crits last for one strike (both slashes)
        end)
    end,
}
