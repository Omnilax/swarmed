-- Swing & hurl (stag beetle): clamps the biggest ant in reach in its antler-jaws, lifts it and
-- swings it round in a full circle, clubbing every ant around with it, then hurls it where you
-- point. The thrown ant bowls through the crowd and crashes down with a thud.
-- params: damage (thrown ant's impact; the swing does 60%), cooldown, reach (grab, 36),
--         swing (seconds for the turn, 0.45), arm (swing radius, 22), distance (throw, 130),
--         radius (landing area, 34)
local Combat = require("src.game.combat")
local Grab = require("src.game.grab")
local Audio = require("src.core.audio")
local util = require("src.core.util")

return {
    name = "Swing & Hurl",
    range = function(params) return params.reach or 36 end,
    fire = function(player, world, ax, ay, params)
        -- the biggest ant within reach in front (it makes the best club)
        local best, bestR
        for _, e in ipairs(Combat.collect(world, player.x + ax * 12, player.y + ay * 12, params.reach or 36)) do
            if not e.held and not e.def.boss and (not bestR or e.radius > bestR) then best, bestR = e, e.radius end
        end
        if not best then
            Combat.area(world, player.x + ax * 16, player.y + ay * 16, 18, params.damage * 0.5, { knockback = 150 })
            world:addFx({ kind = "arc", x = player.x, y = player.y, r = 22, a = math.atan2(ay, ax), arc = 1.2, life = 0.12, color = { 1, 0.8, 0.55 } })
            return
        end
        player.carry = { kind = "swing", h = Grab.hold(best), t = 0, a0 = math.atan2(best.y - player.y, best.x - player.x), hit = { [best] = true } }
        Audio.play("hit", { pitch = 0.6 })
    end,
    update = function(player, world, dt, params, down, px, py)
        local c = player.carry
        if not c or c.kind ~= "swing" then return end
        if not Grab.valid(c.h) then player.carry = nil return end
        c.t = c.t + dt
        local dur = params.swing or 0.45
        local k = math.min(1, c.t / dur)
        -- winds up slowly, then whips round fast
        local a = c.a0 + (k * k) * math.pi * 2
        local arm = params.arm or 22
        local vx, vy = player.x + math.cos(a) * arm, player.y + math.sin(a) * arm
        Grab.place(c.h, vx, vy, 4 + k * 6, a * 1.3)
        player.wangle = a
        local e = c.h.e
        for _, o in ipairs(Combat.collect(world, vx, vy, e.radius + 4)) do
            if not c.hit[o] then
                c.hit[o] = true
                local tx, ty = -math.sin(a), math.cos(a)
                Combat.damage(world, o, params.damage * 0.6, { knockback = 200, kbx = tx, kby = ty })
            end
        end
        if k < 1 then return end
        -- let fly toward the pointer
        local dx, dy, d = util.normalize(px - player.x, py - player.y)
        if d < 1 then dx, dy = player.aimX, player.aimY end
        local dist = math.min(math.max(d, 50), params.distance or 130)
        local speed = 420
        Grab.fling(world, c.h, dx * speed, dy * speed, dist / speed, { damage = params.damage * 0.6, landDamage = params.damage,
            selfDamage = params.damage * 1.5, radius = params.radius or 34, height = 16, spin = 18, knockback = 200 })
        player.wangle = math.atan2(dy, dx)
        player.lungeT = 0.18
        player.carry = nil
        world.camera:shake(0.05)
    end,
}
