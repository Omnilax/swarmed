-- Claw snips (crab): quick alternating pinches, left claw then right, each snapping shut on
-- a small patch beside the face and yanking the ants it catches in towards the crab.
-- params: damage, cooldown, radius (16), offset (22), spread (8), color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

return {
    name = "Claw Snips",
    range = function(params, player) return ((params.offset or 22) + (params.radius or 16)) * (1 + player.stats:get("area") / 100) end,
    fire = function(player, world, ax, ay, params)
        local area = 1 + player.stats:get("area") / 100
        local atk = player.attack
        atk.claw = -(atk.claw or 1)
        local side = atk.claw * (params.spread or 8)
        local off = (params.offset or 22) * area
        local cx, cy = player.x + ax * off - ay * side, player.y + ay * off + ax * side
        local r = (params.radius or 16) * area
        for _, e in ipairs(Combat.collect(world, cx, cy, r)) do
            -- pinched and pulled in
            Combat.damage(world, e, params.damage, { knockback = 60, kbx = -ax, kby = -ay })
        end
        local a = math.atan2(ay, ax)
        world:addFx({ kind = "arc", x = cx, y = cy, r = r * 0.8, a = a + atk.claw * 0.8, arc = 2.2, dir = atk.claw, life = 0.1, color = params.color })
        world:addFx({ kind = "arc", x = cx, y = cy, r = r * 0.8, a = a - atk.claw * 0.8, arc = 2.2, dir = -atk.claw, life = 0.1, color = params.color })
        world.hazards:deflect(cx, cy, r, a, 1)
        Audio.play("hit", { pitch = 1.6, volume = 0.7 })
    end,
}
