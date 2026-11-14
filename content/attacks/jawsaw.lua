-- Jaw saw (camel spider): the two huge jaws work like a pair of shears, chomping left and right
-- in quick turns, and every third beat the long palps sweep out and rake a wide arc.
-- params: damage, cooldown, sweepEvery (rake every Nth beat, 3), reach (jaws, 30), sweep (palp rake radius, 46), sweepMult (1.4),
--         bleed ({ dps, time } on jaw bites), knockback, color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")
local Iso = require("src.core.iso")
local util = require("src.core.util")

-- a pair of jaw blades closing on a point: drawn as two curved fangs that snap shut
local function drawJaws(fx, k, fade)
    local lg = love.graphics
    local shut = math.min(1, k / 0.3)
    local c = fx.color
    for sg = -1, 1, 2 do
        local open = (1 - shut) * 0.9
        local a = fx.a + sg * (0.25 + open)
        local bx, by = fx.x - math.cos(fx.a) * 4 + math.cos(fx.a + sg * 1.57) * 4, fx.y - math.sin(fx.a) * 4 + math.sin(fx.a + sg * 1.57) * 4
        local pts = {}
        for i = 0, 4 do
            local t = i / 4
            local bend = a - sg * t * (0.9 + open * 0.4)
            local r = fx.r * t
            local x, y = Iso.toScreen(bx + math.cos(bend) * r, by + math.sin(bend) * r, 4)
            pts[#pts + 1], pts[#pts + 2] = x, y
        end
        lg.setColor(c[1], c[2], c[3], 0.5 * fade)
        lg.setLineWidth(3)
        lg.line(pts)
        lg.setColor(1, 1, 1, 0.9 * fade)
        lg.setLineWidth(1)
        lg.line(pts)
    end
end

return {
    name = "Jaw Saw",
    range = function(params, player) return (params.sweep or 46) * (1 + player.stats:get("area") / 100) end,
    fire = function(player, world, ax, ay, params)
        local area = 1 + player.stats:get("area") / 100
        local atk = player.attack
        local every = params.sweepEvery or 3
        atk.combo = (atk.combo or 0) % every + 1
        local ang = math.atan2(ay, ax)
        if atk.combo < every then
            local reach = (params.reach or 30) * area
            local side = atk.combo == 1 and -0.3 or 0.3
            local hits = Combat.collect(world, player.x, player.y, reach, function(e, dx, dy)
                return math.abs(util.angleDiff(ang + side, math.atan2(dy, dx))) <= 0.7 end)
            for _, e in ipairs(hits) do
                Combat.damage(world, e, params.damage, { knockback = params.knockback or 50, kbx = ax, kby = ay, poison = params.bleed })
                world.particles:burst(e.x, e.y, 3, { { 0.55, 0.75, 0.3 } }, 40, 30, { stain = true, grav = 200 })
            end
            world:addFx({ draw = drawJaws, x = player.x + ax * 6, y = player.y + ay * 6, a = ang + side, r = reach * 0.8, life = 0.14,
                color = params.color or { 1, 0.9, 0.7 } })
            Audio.play("hit", { pitch = atk.combo == 1 and 1.5 or 1.7, volume = 0.6 })
        else
            -- the palp rake: a wide, sweeping slash that drags ants in close
            local r = (params.sweep or 46) * area
            for _, e in ipairs(Combat.collect(world, player.x, player.y, r, function(e, dx, dy)
                return math.abs(util.angleDiff(ang, math.atan2(dy, dx))) <= 1.3 end)) do
                local nx, ny = util.normalize(player.x - e.x, player.y - e.y)
                Combat.damage(world, e, params.damage * (params.sweepMult or 1.4), { knockback = 70, kbx = nx * 0.6 + ax * 0.4, kby = ny * 0.6 + ay * 0.4 })
            end
            world:addFx({ kind = "arc", x = player.x, y = player.y, r = r, a = ang, arc = 2.6, life = 0.16, dir = (atk.flip and -1 or 1),
                color = params.color or { 1, 0.9, 0.7 } })
            atk.flip = not atk.flip
            Audio.play("dash", { pitch = 1.3 })
        end
    end,
}
