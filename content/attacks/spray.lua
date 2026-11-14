-- Bombardier spray: a boiling chemical jet, a cone of scalding droplets that pierce through ants.
-- params: damage, cooldown, range (how far the jet reaches, 90), drops (per burst, 7),
--         spread (radians, 0.6), pierce (extra ants per drop, 2), color
local Audio = require("src.core.audio")

return {
    name = "Boiling Spray",
    range = function(params, player) return (params.range or 90) * (1 + player.stats:get("area") / 100) end,
    fire = function(player, world, ax, ay, params)
        local range = (params.range or 90) * (1 + player.stats:get("area") / 100)
        local n, spread = params.drops or 7, params.spread or 0.6
        local base = math.atan2(ay, ax)
        local speed = 260
        local c = params.color or { 1, 0.92, 0.6 }
        for i = 1, n do
            local a = base + ((i - 1) / math.max(1, n - 1) - 0.5) * spread + (love.math.random() - 0.5) * 0.08
            local sp = speed * (0.85 + love.math.random() * 0.3)
            world.hazards:friendlyShot({ x = player.x + ax * 6, y = player.y + ay * 6, z = 5, vx = math.cos(a) * sp, vy = math.sin(a) * sp,
                r = 3, damage = params.damage, life = range / sp, color = c, pierce = params.pierce or 2, knockback = 40 })
        end
        -- the pop and the puff of steam
        world.particles:burst(player.x + ax * 8, player.y + ay * 8, 6, { { 1, 1, 0.9 }, { 0.9, 0.85, 0.75 } }, 60, 30, { glow = true, grav = -30 })
        Audio.play("dash", { pitch = 1.9 })
    end,
}
