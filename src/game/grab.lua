-- Grabbing and throwing ants (stag beetle, mantis, jumping spider). A held ant stops thinking
-- and moving on its own (World:updateEnemies skips it); whoever holds it sets its position.
-- A thrown ant flies along an arc, bowling over every ant it passes, and crashes down at the end.
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

local Grab = {}

-- Take hold of an ant. Returns a handle (ants are pooled, so the uid tells if it is still the same one).
function Grab.hold(e)
    e.held = true
    e.kvx, e.kvy, e.mx, e.my = 0, 0, 0, 0
    return { e = e, uid = e.uid }
end

function Grab.valid(h) return h and not h.e.dead and h.e.uid == h.uid end

function Grab.release(h)
    if Grab.valid(h) then h.e.held, h.e.z = nil, 0 end
end

-- Move a held ant (and keep it facing a way).
function Grab.place(h, x, y, z, angle)
    if not Grab.valid(h) then return end
    local e = h.e
    e.x, e.y, e.z = x, y, z or 0
    if angle then e.angle = angle end
end

-- Hurl a held ant along (vx, vy) for `time` seconds. opts: damage (to ants it hits on the way),
-- landDamage (area at the end), radius (landing area), knockback, height (arc, px), spin,
-- color, onLand(world, x, y)
function Grab.fling(world, h, vx, vy, time, opts)
    if not Grab.valid(h) then return end
    local sk = world.player and world.player.skills
    if sk then opts = sk:throwOpts(opts or {}) end   -- skill nodes: bigger landings
    world.thrown[#world.thrown + 1] = { h = h, vx = vx, vy = vy, t = 0, time = math.max(0.05, time), hit = { [h.e] = true },
        opts = opts or {}, z0 = h.e.z or 0 }
    Audio.play("dash", { pitch = 0.6 + love.math.random() * 0.2 })
end

function Grab.update(world, dt)
    local list = world.thrown
    for i = #list, 1, -1 do
        local f = list[i]
        local h, o = f.h, f.opts
        f.t = f.t + dt
        if not Grab.valid(h) then
            table.remove(list, i)
        else
            local e = h.e
            local k = math.min(1, f.t / f.time)
            local S = world.size
            e.x = math.max(e.radius, math.min(S - e.radius, e.x + f.vx * dt))
            e.y = math.max(e.radius, math.min(S - e.radius, e.y + f.vy * dt))
            e.z = f.z0 * (1 - k) + math.sin(k * math.pi) * (o.height or 14)
            e.angle = e.angle + (o.spin or 14) * dt
            -- bowling: everything in the way gets bowled over
            local l = math.sqrt(f.vx * f.vx + f.vy * f.vy) + 0.001
            for _, other in ipairs(Combat.collect(world, e.x, e.y, e.radius + 3)) do
                if not f.hit[other] then
                    f.hit[other] = true
                    local sx, sy = -f.vy / l, f.vx / l
                    if (other.x - e.x) * sx + (other.y - e.y) * sy < 0 then sx, sy = -sx, -sy end
                    Combat.damage(world, other, o.damage or 8, { knockback = o.knockback or 160,
                        kbx = sx * 0.7 + f.vx / l * 0.5, kby = sy * 0.7 + f.vy / l * 0.5 })
                end
            end
            if world.time % 0.05 < dt then
                world.particles:spawn(e.x, e.y, e.z + 2, 0, 0, 10, 0.3, o.color or { 0.9, 0.8, 0.6 }, 1, { grav = 0 })
            end
            if k >= 1 then
                table.remove(list, i)
                e.held, e.z = nil, 0
                local r = (o.radius or 26) * (1 + world.player.stats:get("area") / 100)
                if (o.landDamage or 0) > 0 then
                    Combat.explode(world, e.x, e.y, r, o.landDamage, { knockback = 170, color = o.color or { 0.9, 0.75, 0.55 } })
                end
                if not e.dead then Combat.damage(world, e, (o.selfDamage or o.landDamage or 10), { knockback = 40, kbx = f.vx / l, kby = f.vy / l }) end
                world.camera:shake(0.08)
                if o.onLand then o.onLand(world, e.x, e.y) end
            end
        end
    end
end

return Grab
