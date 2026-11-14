-- Jaw pierce (camel spider): both huge jaws drive straight forward in a quick one-two, each
-- thrust skewering every ant in a line. Ants it pierces bleed.
-- params: damage (per thrust), cooldown, reach (38), width (6), thrusts (2), gap (0.08 s),
--         finalMult (extra damage x on the last thrust, 0), bleed ({ dps, time }), knockback, color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

local function thrust(player, world, ax, ay, params, i, n)
    local area = 1 + player.stats:get("area") / 100
    local reach = (params.reach or 38) * area
    -- the jaws alternate a hair to each side
    local side = (i % 2 == 1) and -2 or 2
    local x1, y1 = player.x - ay * side, player.y + ax * side
    local x2, y2 = x1 + ax * reach, y1 + ay * reach
    local dmg = params.damage * (i == n and 1 + (params.finalMult or 0) or 1)
    for _, e in ipairs(Combat.collectLine(world, x1, y1, x2, y2, (params.width or 6) * area)) do
        Combat.damage(world, e, dmg, { knockback = params.knockback or 40, kbx = ax, kby = ay, poison = params.bleed })
        world.particles:burst(e.x, e.y, 2, { { 0.55, 0.75, 0.3 } }, 40, 30, { stain = true, grav = 200 })
    end
    world:addFx({ kind = "stab", x = x1 + ax * 5, y = y1 + ay * 5, x2 = x2, y2 = y2, w = 2.5, life = 0.1, color = params.color or { 1, 0.9, 0.7 } })
    Audio.play("hit", { pitch = 1.4 + i * 0.15, volume = 0.6 })
end

return {
    name = "Jaw Pierce",
    range = function(params, player) return (params.reach or 38) * (1 + player.stats:get("area") / 100) end,
    fire = function(player, world, ax, ay, params)
        local n = params.thrusts or 2
        thrust(player, world, ax, ay, params, 1, n)
        for i = 2, n do
            player:after((params.gap or 0.08) * (i - 1), function(p, w) thrust(p, w, ax, ay, params, i, n) end)
        end
    end,
}
