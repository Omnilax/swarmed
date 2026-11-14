-- Crushing claws (emperor scorpion): slow, heavy pincer crushes, left claw then right claw.
-- Each one clamps down on a patch of ground beside the head and crushes every ant in it;
-- ants already hurt are crushed outright more often (bonus damage below half health).
-- params: damage, cooldown, radius (claw area, 20), offset (how far out the claws reach, 26),
--         spread (sideways, 9), execute (damage x on ants under half health, 1.6), knockback,
--         both (true: both claws crush at once), color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

return {
    name = "Crushing Claws",
    range = function(params, player) return ((params.offset or 26) + (params.radius or 20)) * (1 + player.stats:get("area") / 100) end,
    fire = function(player, world, ax, ay, params)
        local area = 1 + player.stats:get("area") / 100
        local atk = player.attack
        atk.claw = -(atk.claw or 1)
        for pass = 1, params.both and 2 or 1 do
            if pass == 2 then atk.claw = -atk.claw end
            local side = atk.claw * (params.spread or 9)
            local off = (params.offset or 26) * area
            local cx, cy = player.x + ax * off - ay * side, player.y + ay * off + ax * side
            local r = (params.radius or 20) * area
            local n = 0
            for _, e in ipairs(Combat.collect(world, cx, cy, r)) do
                local mult = e.hp < e.maxHp * 0.5 and (params.execute or 1.6) or 1
                Combat.damage(world, e, params.damage * mult, { knockback = params.knockback or 120, kbx = ax, kby = ay, poison = params.poison })
                n = n + 1
            end
            world:addFx({ kind = "arc", x = cx, y = cy, r = r, a = math.atan2(ay, ax) + atk.claw * 1.4, arc = 2.6, dir = -atk.claw, life = 0.16, color = params.color })
            world.particles:burst(cx, cy, 5, { { 0.6, 0.55, 0.5 }, { 0.4, 0.38, 0.35 } }, 50, 30, { grav = 300 })
            Audio.play("hit", { pitch = 0.65 })
            if n >= 3 then world.camera:shake(0.06) end
        end
    end,
}
