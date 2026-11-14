-- Ball hurl (dung beetle): stands on its front legs and kicks the dung ball away with its
-- hind legs, toward where you point. It rolls through the swarm flattening ant after ant,
-- slowing a little with each one, and a big enough ball bursts where it stops. A new little
-- ball is started at once. Grow it big before you throw!
-- params: damage (at the smallest ball), cooldown, perSize (x per unit radius, 0.3),
--         speed (roll speed, 340), burstSize (radius that bursts at the end, 9), minSize (4),
--         maxSize (20), grow (radius per px rolled, 0.008), knockback, slowMax (walk speed lost
--         at the biggest ball, 0.45), sizeCooldown (extra seconds per unit of radius thrown, 0.12)
local Audio = require("src.core.audio")
local util = require("src.core.util")
local Dung = require("content.attacks._dungball")

return {
    name = "Ball Hurl",
    range = function() return 200 end,
    fire = function(player, world, ax, ay, params, px, py)
        local d = Dung.get(player, params)
        local bx, by = Dung.pos(player, d)
        local dx, dy, l = util.normalize((px or bx) - player.x, (py or by) - player.y)
        if l < 1 then dx, dy = ax, ay end
        local k = 1 + (d.r - Dung.MIN) * (params.perSize or 0.3)
        local speed = (params.speed or 340) * (0.8 + d.r / 20)
        d.thrown[#d.thrown + 1] = { x = bx, y = by, vx = dx * speed, vy = dy * speed, r = d.r, spin = d.spin, t = 0, hit = {},
            damage = params.damage * k, knockback = (params.knockback or 180) * (0.6 + d.r / 10), drag = 1.1 - d.r * 0.04,
            toll = 0.93 + d.r * 0.004 }
        -- the bigger the ball, the longer it takes to start the next one rolling
        d.throwSlow = (d.r - Dung.MIN) * (params.sizeCooldown or 0.12)
        d.r = params.minSize or Dung.MIN
        player.wangle = math.atan2(dy, dx)
        world.particles:burst(bx, by, 6, { { 0.5, 0.36, 0.2 } }, 60, 30, { grav = 200 })
        Audio.play("dash", { pitch = 0.7 })
    end,
    update = function(player, world, dt, params)
        Dung.update(player, world, dt, params)
    end,
    draw = function(player, world)
        Dung.draw(player, world)
    end,
}
