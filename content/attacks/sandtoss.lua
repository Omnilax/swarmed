-- Sand toss (mole cricket): the shovel forelegs fling a spray of grit like a shotgun. Each grain
-- does little, but they fan out far, and the closer the ants are the harder the grains hit
-- (the shot weakens as it flies, see `falloff` in Hazards:friendlyShot). Up close most of the
-- spray lands on the same few ants, so a point-blank toss hits very hard.
-- params: damage (per grain at point blank, 3), grains (14), spread (radians, 0.9),
--         range (160), speed (300), falloff (share lost by the end of the range, 0.8),
--         knockback (per grain, 30), slow ({ mul, seconds }, optional), color
local Audio = require("src.core.audio")

local GRIT = { { 0.78, 0.68, 0.5 }, { 0.6, 0.5, 0.36 }, { 0.9, 0.82, 0.64 } }

return {
    name = "Sand Toss",
    range = function(params, player) return (params.range or 160) * 0.6 * (1 + player.stats:get("area") / 100) end,
    fire = function(player, world, ax, ay, params)
        local range = (params.range or 160) * (1 + player.stats:get("area") / 100)
        local n = params.grains or 14
        local spread = params.spread or 0.9
        local base = math.atan2(ay, ax)
        for i = 1, n do
            -- evenly fanned, with a little scatter so no two tosses look the same
            local a = base + ((i - 0.5) / n - 0.5) * spread + (love.math.random() - 0.5) * spread / n
            local sp = (params.speed or 300) * (0.8 + love.math.random() * 0.4)
            world.hazards:friendlyShot({ x = player.x + ax * 6, y = player.y + ay * 6, z = 3, vz = 30 + love.math.random() * 30, grav = 90,
                vx = math.cos(a) * sp, vy = math.sin(a) * sp, r = 1.5, damage = params.damage or 3, life = range / sp,
                falloff = params.falloff or 0.8, color = params.color or GRIT[1 + (i % 3)], pierce = params.pierce or 0,
                knockback = params.knockback or 30, slow = params.slow })
        end
        -- a puff of dust thrown off the claws
        world.particles:burst(player.x + ax * 8, player.y + ay * 8, 10, GRIT, 120, 40, { grav = 260 })
        world.camera:shake(0.04)
        Audio.play("dash", { pitch = 1.6, volume = 0.5 })
    end,
}
