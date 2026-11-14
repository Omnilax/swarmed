-- Dragline yank (jumping spider): fires a silk dragline at an ant where you point and yanks it
-- in, bowling over everything between you, then sinks its fangs in as it arrives.
-- params: damage (the bite), cooldown, range (140), poison ({dps, seconds}), color
local Combat = require("src.game.combat")
local Grab = require("src.game.grab")
local Audio = require("src.core.audio")
local util = require("src.core.util")

return {
    name = "Dragline Yank",
    range = function(params) return params.range or 140 end,
    fire = function(player, world, ax, ay, params, px, py)
        local range = params.range or 140
        local tx, ty = px or player.x + ax * 60, py or player.y + ay * 60
        -- the ant nearest the pointer, within range of you
        local best, bd
        for _, e in ipairs(Combat.collect(world, player.x, player.y, range)) do
            if not e.held and not e.def.boss then
                local d = (e.x - tx) ^ 2 + (e.y - ty) ^ 2
                if not bd or d < bd then best, bd = e, d end
            end
        end
        if not best then
            world:addFx({ kind = "stab", x = player.x, y = player.y, x2 = player.x + ax * range * 0.6, y2 = player.y + ay * range * 0.6, life = 0.1, color = { 1, 1, 0.95 } })
            return
        end
        player.carry = { kind = "yank", h = Grab.hold(best), t = 0, hit = { [best] = true } }
        Audio.play("dash", { pitch = 2.3 })
    end,
    update = function(player, world, dt, params)
        local c = player.carry
        if not c or c.kind ~= "yank" then return end
        if not Grab.valid(c.h) then player.carry = nil return end
        local e = c.h.e
        c.t = c.t + dt
        local dx, dy, d = util.normalize(player.x - e.x, player.y - e.y)
        local step = math.min(d, 520 * dt)
        local nx, ny = e.x + dx * step, e.y + dy * step
        Grab.place(c.h, nx, ny, 3, math.atan2(-dy, -dx))
        for _, o in ipairs(Combat.collect(world, nx, ny, e.radius + 3)) do
            if not c.hit[o] then
                c.hit[o] = true
                local sx, sy = -dy, dx
                if (o.x - nx) * sx + (o.y - ny) * sy < 0 then sx, sy = -sx, -sy end
                Combat.damage(world, o, params.damage * 0.4, { knockback = 160, kbx = sx, kby = sy })
            end
        end
        player.wangle = math.atan2(-dy, -dx)
        if d > player.radius + e.radius + 2 and c.t < 0.5 then return end
        -- arrived: the bite
        Grab.release(c.h)
        player.lungeT = 0.18
        Combat.damage(world, e, params.damage, { knockback = 140, kbx = -dx, kby = -dy, poison = params.poison })
        world.particles:burst(e.x, e.y, 5, { { 0.6, 1, 0.9 } }, 50, 30, { glow = true })
        Audio.play("hit", { pitch = 1.4 })
        player.carry = nil
    end,
    draw = function(player, world)
        local c = player.carry
        if not c or c.kind ~= "yank" or not Grab.valid(c.h) then return end
        local Iso = require("src.core.iso")
        local x1, y1 = Iso.toScreen(player.x, player.y, 4)
        local x2, y2 = Iso.toScreen(c.h.e.x, c.h.e.y, 3)
        love.graphics.setColor(1, 1, 0.95, 0.85)
        love.graphics.line(x1, y1, x2, y2)
    end,
}
