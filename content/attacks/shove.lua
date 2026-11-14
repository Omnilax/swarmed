-- Shove (assassin bug): a sharp shoulder-check that throws every ant in front of you back and
-- staggers them, to make room. Hits much harder from stealth (player.stealthMul).
-- params: damage (4), cooldown, radius (40), arc (cone width in radians, 1.7), knockback (380),
--         stun (seconds, 0.3), color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

return {
    name = "Shove",
    range = function(params, player) return (params.radius or 40) * (1 + player.stats:get("area") / 100) end,
    fire = function(player, world, ax, ay, params)
        local r = (params.radius or 40) * (1 + player.stats:get("area") / 100)
        local half = (params.arc or 1.7) / 2
        local cosHalf = math.cos(half)
        local mul = player.cloakT and player.stealthMul or 1
        local n = 0
        for _, e in ipairs(Combat.collect(world, player.x, player.y, r)) do
            local dx, dy = e.x - player.x, e.y - player.y
            local l = math.sqrt(dx * dx + dy * dy)
            if l < 6 or (dx * ax + dy * ay) / l >= cosHalf then
                n = n + 1
                Combat.damage(world, e, (params.damage or 4) * mul, { knockback = (params.knockback or 380) * (0.6 + 0.4 * mul),
                    kbx = dx / (l + 0.001) + ax, kby = dy / (l + 0.001) + ay, stun = params.stun or 0.3 })
            end
        end
        world:addFx({ kind = "arc", x = player.x, y = player.y, a = math.atan2(ay, ax), arc = half * 2, r = r, life = 0.16,
            color = params.color or { 1, 0.75, 0.6 } })
        world.particles:burst(player.x + ax * 10, player.y + ay * 10, 8, { { 0.85, 0.8, 0.7 } }, 120, 30, { grav = 120 })
        if n > 0 then world.camera:shake(0.05) end
        Audio.play("dash", { pitch = 0.8, volume = 0.7 })
    end,
}
