-- Worm bite (velvet worm): a quick, simple bite with the little jaws hidden in its mouth. The
-- head darts forward and bites whatever is just in front.
-- params: damage, cooldown, reach (18), radius (bite size, 12), knockback (40), poison
--         ({ dps, time }, optional), color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

return {
    name = "Bite",
    range = function(params, player) return (params.reach or 18) * (1 + player.stats:get("area") / 100) + 6 end,
    fire = function(player, world, ax, ay, params)
        local area = 1 + player.stats:get("area") / 100
        local reach, r = (params.reach or 18) * area, (params.radius or 12) * area
        local hx, hy = player.x + ax * reach, player.y + ay * reach
        for _, e in ipairs(Combat.collect(world, hx, hy, r)) do
            Combat.damage(world, e, params.damage, { knockback = params.knockback or 40, kbx = ax, kby = ay, poison = params.poison })
        end
        world:addFx({ kind = "ring", x = hx, y = hy, r = r * 0.8, life = 0.1, color = params.color or { 1, 0.75, 0.6 } })
        Audio.play("hit", { pitch = 1.8, volume = 0.35 })
    end,
}
