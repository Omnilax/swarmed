-- Flurry (mantis shrimp): a boxer's barrage. Both clubs pump out a rapid string of jabs in
-- front, faster than the eye can follow; each pops a tiny bubble and the last one is an
-- uppercut that blasts the crowd back.
-- params: damage (per jab), cooldown, punches (10), time (0.7 s), reach (28), finisher (x damage, 3), color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")
local util = require("src.core.util")

return {
    name = "Flurry",
    range = function(params) return params.reach or 28 end,
    fire = function(player, world, ax, ay, params)
        local n = params.punches or 10
        local gap = (params.time or 0.7) / n
        for i = 1, n do
            player:after(gap * (i - 1), function(p, w)
                local ang = math.atan2(p.aimY, p.aimX)
                local last = i == n
                local side = (i % 2 == 0) and 1 or -1
                local reach = (params.reach or 28) * (1 + p.stats:get("area") / 100) * (last and 1.3 or 1)
                local a = ang + side * 0.25 + (love.math.random() - 0.5) * 0.3
                for _, e in ipairs(Combat.collect(w, p.x, p.y, reach, function(e, dx, dy)
                    return math.abs(util.angleDiff(a, math.atan2(dy, dx))) <= (last and 1 or 0.6) end)) do
                    Combat.damage(w, e, params.damage * (last and (params.finisher or 3) or 1),
                        { knockback = last and 260 or 30, kbx = p.aimX, kby = p.aimY, procDepth = last and 0 or 1 })
                end
                local sx, sy = p.x + math.cos(ang + side * 1.57) * 3, p.y + math.sin(ang + side * 1.57) * 3
                w:addFx({ kind = "stab", x = sx, y = sy, x2 = sx + math.cos(a) * reach, y2 = sy + math.sin(a) * reach, w = last and 4 or 2,
                    life = 0.08, color = params.color or { 1, 0.5, 0.4 } })
                w.particles:spawn(sx + math.cos(a) * reach, sy + math.sin(a) * reach, 5, 0, 0, 30, 0.15, { 0.85, 0.95, 1 }, 1, { glow = true, grav = 0 })
                p.lungeT = 0.18
                p.wangle = a
                if last then
                    w:addFx({ kind = "ring", x = p.x + p.aimX * reach * 0.7, y = p.y + p.aimY * reach * 0.7, r = reach * 0.8, life = 0.2, color = { 1, 0.7, 0.5 } })
                    w.camera:shake(0.12)
                    Audio.play("boom", { pitch = 1.4, volume = 0.6 })
                else
                    Audio.play("hit", { pitch = 1.3 + love.math.random() * 0.4, volume = 0.5 })
                end
            end)
        end
    end,
}
