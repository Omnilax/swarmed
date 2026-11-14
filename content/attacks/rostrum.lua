-- Rostrum stab (assassin bug): a lightning-fast thrust of the curved beak that skewers the
-- first ants in line and sucks a little life out of each one it pierces. From stealth
-- (player.stealthMul, content/dashes/stealth.lua) it hits far harder.
-- params: damage, cooldown, reach (44), width (4), pierce (ants skewered, 2),
--         leech (share of damage dealt that heals you, 0.3), poison ({ dps, time }, optional), color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

return {
    name = "Rostrum Stab",
    range = function(params, player) return (params.reach or 44) * (1 + player.stats:get("area") / 100) end,
    fire = function(player, world, ax, ay, params)
        local reach = (params.reach or 44) * (1 + player.stats:get("area") / 100)
        local x2, y2 = player.x + ax * reach, player.y + ay * reach
        local list = Combat.collectLine(world, player.x, player.y, x2, y2, params.width or 4)
        table.sort(list, function(a, b)
            return (a.x - player.x) ^ 2 + (a.y - player.y) ^ 2 < (b.x - player.x) ^ 2 + (b.y - player.y) ^ 2
        end)
        local mul = player.cloakT and player.stealthMul or 1
        local drained = 0
        for i = 1, math.min(#list, params.pierce or 2) do
            drained = drained + Combat.damage(world, list[i], params.damage * mul, { knockback = 40, kbx = ax, kby = ay, poison = params.poison })
            world.particles:spawn(list[i].x, list[i].y, 4, -ax * 30, -ay * 30, 30, 0.35, { 0.85, 0.15, 0.1 }, 1, { grav = 0 })
        end
        if drained > 0 then
            player:heal(drained * (params.leech or 0.3))
            world.particles:spawn(player.x, player.y, 6, 0, 0, 20, 0.5, { 1, 0.3, 0.3 }, 1, { glow = true, grav = -30 })
        end
        world:addFx({ kind = "stab", x = player.x, y = player.y, x2 = x2, y2 = y2, life = mul > 1 and 0.16 or 0.1, w = mul > 1 and 3 or 2,
            color = mul > 1 and { 0.75, 0.6, 1 } or params.color or { 1, 0.35, 0.3 } })
        Audio.play("hit", { pitch = 1.5, volume = 0.6 })
    end,
}
