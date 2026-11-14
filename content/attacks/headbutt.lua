-- Headbutt (hissing roach): rams the domed pronotum into the ants in front, bowling them back.
-- Every few butts it puts its whole weight in: a shove that sends the front row flying.
-- params: damage, cooldown, reach (28), arc (1.6), knockback (180), heavyEvery (4), color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")
local util = require("src.core.util")

return {
    name = "Headbutt",
    range = function(params, player) return (params.reach or 28) * (1 + player.stats:get("area") / 100) end,
    fire = function(player, world, ax, ay, params)
        local atk = player.attack
        atk.count = (atk.count or 0) + 1
        local heavy = atk.count % (params.heavyEvery or 4) == 0
        local reach = (params.reach or 28) * (1 + player.stats:get("area") / 100) * (heavy and 1.35 or 1)
        local ang = math.atan2(ay, ax)
        local half = (params.arc or 1.6) / 2
        for _, e in ipairs(Combat.collect(world, player.x, player.y, reach, function(e, dx, dy)
            return math.abs(util.angleDiff(ang, math.atan2(dy, dx))) <= half end)) do
            local nx, ny = util.normalize(e.x - player.x, e.y - player.y)
            Combat.damage(world, e, params.damage * (heavy and 2 or 1), { knockback = (params.knockback or 180) * (heavy and 1.8 or 1),
                kbx = nx * 0.5 + ax * 0.5, kby = ny * 0.5 + ay * 0.5 })
        end
        world:addFx({ kind = "arc", x = player.x, y = player.y, r = reach, a = ang, arc = half * 2, life = heavy and 0.2 or 0.12,
            color = params.color or { 1, 0.75, 0.45 } })
        if heavy then
            player:lunge(ax, ay, 14, 1.2)
            world:addFx({ kind = "ring", x = player.x + ax * reach * 0.6, y = player.y + ay * reach * 0.6, r = reach * 0.6, life = 0.2, color = { 1, 0.8, 0.5 } })
            world.camera:shake(0.06)
            Audio.play("hit", { pitch = 0.6 })
        else
            Audio.play("hit", { pitch = 1.1, volume = 0.6 })
        end
    end,
}
