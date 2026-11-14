-- Hermit pinches (hermit crab): two quick snips of the little claw, then the big claw comes
-- down in a crushing pinch that hits a wider patch and knocks ants reeling. Works from inside
-- the shell too.
-- params: damage, cooldown, radius (small claw, 16), bigRadius (24), bigMult (2.4), offset (20), color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

return {
    name = "Hermit Pinches",
    range = function(params, player) return ((params.offset or 20) + (params.bigRadius or 24)) * (1 + player.stats:get("area") / 100) end,
    fire = function(player, world, ax, ay, params)
        local area = 1 + player.stats:get("area") / 100
        local atk = player.attack
        atk.combo = (atk.combo or 0) % 3 + 1
        local big = atk.combo == 3
        -- the big claw is on the left, the small one on the right
        local side = big and -6 or 6
        local off = (params.offset or 20) * area
        local cx, cy = player.x + ax * off - ay * side, player.y + ay * off + ax * side
        local r = (big and (params.bigRadius or 24) or (params.radius or 16)) * area
        local dmg = params.damage * (big and (params.bigMult or 2.4) or 1)
        for _, e in ipairs(Combat.collect(world, cx, cy, r)) do
            Combat.damage(world, e, dmg, { knockback = big and 200 or 50, kbx = ax, kby = ay })
        end
        local a = math.atan2(ay, ax)
        world:addFx({ kind = "arc", x = cx, y = cy, r = r, a = a, arc = big and 2.8 or 2, dir = big and -1 or 1, life = big and 0.18 or 0.1, color = params.color })
        if big then
            world.particles:burst(cx, cy, 6, { { 0.75, 0.68, 0.55 } }, 60, 30, { grav = 260 })
            world.camera:shake(0.05)
            Audio.play("hit", { pitch = 0.7 })
        else
            Audio.play("hit", { pitch = 1.7, volume = 0.6 })
        end
    end,
}
