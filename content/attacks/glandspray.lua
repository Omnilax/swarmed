-- Gland spray (millipede): it doesn't bite, it defends. Rows of stink glands along every ring
-- of its body puff out a burning toxin, so every ant pressed against any part of the long body
-- gets a dose, and the head butts whatever is in front.
-- params: damage, cooldown, radius (around each gland, 11), every (glands on every Nth ring, 2),
--         poison ({ dps, time }), reach (head butt, 18), color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

return {
    name = "Gland Spray",
    range = function(params, player) return (params.reach or 18) + 10 end,
    fire = function(player, world, ax, ay, params)
        local area = 1 + player.stats:get("area") / 100
        local r = (params.radius or 11) * area
        local c = params.color or { 0.95, 0.85, 0.35 }
        local hit = {}
        local chain = player.chain or {}
        local atk = player.attack
        atk.flip = not atk.flip
        local start = atk.flip and 1 or 2
        for i = start, #chain, params.every or 2 do
            local s = chain[i]
            for _, e in ipairs(Combat.collect(world, s.x, s.y, r)) do
                if not hit[e] then
                    hit[e] = true
                    local nx, ny = e.x - s.x, e.y - s.y
                    Combat.damage(world, e, params.damage, { knockback = 50, kbx = nx, kby = ny, poison = params.poison or { 4, 3 } })
                end
            end
            -- a puff from each side of the ring
            for side = -1, 1, 2 do
                world.particles:spawn(s.x + (love.math.random() - 0.5) * 4, s.y + (love.math.random() - 0.5) * 4, 3,
                    side * (love.math.random() * 30 + 10), (love.math.random() - 0.5) * 30, 14, 0.4, c, 1, { glow = true, grav = -10 })
            end
        end
        -- the head butts what's in front
        local reach = (params.reach or 18) * area
        local hx, hy = player.x + ax * reach * 0.6, player.y + ay * reach * 0.6
        for _, e in ipairs(Combat.collect(world, hx, hy, reach * 0.5)) do
            if not hit[e] then Combat.damage(world, e, params.damage * 1.5, { knockback = 120, kbx = ax, kby = ay }) end
        end
        world:addFx({ kind = "ring", x = hx, y = hy, r = reach * 0.5, life = 0.12, color = c })
        Audio.play("dash", { pitch = 2.4, volume = 0.3 })
    end,
}
