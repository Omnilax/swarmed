-- Ball bash (dung beetle): shoves the dung ball forward into the ants in front and pulls it
-- back. The bigger the ball, the harder and wider it hits; every ant it squashes sticks to it
-- and makes it grow.
-- A heavy ball is slow to swing: bigger balls add up to sizeSlow x the cooldown.
-- params: damage (at the smallest ball), cooldown, perSize (extra damage x per unit of ball
--         radius over the smallest, 0.18), killGrow (radius gained per kill, 0.35), knockback,
--         sizeSlow (extra cooldown x at the biggest ball, 1)
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")
local util = require("src.core.util")
local Dung = require("content.attacks._dungball")

return {
    name = "Ball Bash",
    range = function(params, player)
        local d = player.dung
        return player.radius + (d and d.r or 5) * 2 + 18
    end,
    fire = function(player, world, ax, ay, params)
        local d = Dung.get(player, params)
        d.push = 0.001
        local bx, by = Dung.pos(player, d)
        local hx, hy = bx + ax * 16, by + ay * 16
        local r = d.r + 6
        local k = 1 + (d.r - Dung.MIN) * (params.perSize or 0.18)
        local kills = 0
        -- the whole swing counts, from the beetle's face out to the ball's furthest reach, so ants
        -- hugging the beetle get squashed too
        for _, e in ipairs(Combat.collectLine(world, player.x, player.y, hx, hy, r)) do
            local nx, ny = util.normalize(e.x - player.x + ax * 8, e.y - player.y + ay * 8)
            Combat.damage(world, e, params.damage * k, { knockback = (params.knockback or 140) * (0.7 + d.r / 12), kbx = nx, kby = ny })
            if e.dead then kills = kills + 1 end
        end
        if kills > 0 then Dung.grow(player, d, kills * (params.killGrow or 0.35), player.secondary and player.secondary.params) end
        d.bashSlow = params.cooldown * Dung.weight(d) * (params.sizeSlow or 1)
        world:addFx({ kind = "ring", x = hx, y = hy, r = r, life = 0.15, color = { 0.8, 0.6, 0.35 } })
        world.particles:burst(hx, hy, 4 + kills, { { 0.4, 0.28, 0.14 }, { 0.6, 0.45, 0.25 } }, 60, 40, { grav = 300 })
        world.hazards:deflect(hx, hy, r, math.atan2(ay, ax), 1.2)
        Audio.play("hit", { pitch = 0.9 - d.r * 0.02 })
        if d.r >= 9 then world.camera:shake(0.04) end
    end,
}
