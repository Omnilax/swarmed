-- Acid bomb (vinegaroon): the heavy palps clamp onto the nearest ant in front. Hold right
-- click and the tail drenches it in vinegar (it burns, and you're shielded by it); let go and
-- it's hurled where you point, bursting into a pool of acid that burns and corrodes every ant
-- that crosses it. The longer it soaked, the bigger the pool. A tap grabs and throws at once.
-- params: damage, cooldown, reach (40), soak (max hold, 1.5), distance (throw, 120),
--         pool (radius at full soak, 40), poolLife (4), corrode ({ mul, time }), color
local Combat = require("src.game.combat")
local Grab = require("src.game.grab")
local Audio = require("src.core.audio")
local util = require("src.core.util")

local GREEN = { 0.8, 1, 0.45 }

local function pool(world, x, y, r, params)
    world.hazards:addZone({ kind = "acidpool", x = x, y = y, r = r, life = params.poolLife or 4,
        update = function(w, z, dt)
            z.tick = (z.tick or 0) + dt
            if z.tick < 0.3 then return end
            z.tick = 0
            for _, e in ipairs(Combat.collect(w, z.x, z.y, z.r * math.min(1, z.t / 0.3))) do
                Combat.damage(w, e, params.damage * 0.25, { noCrit = true, dot = true, corrode = params.corrode or { 1.4, 3 } })
            end
            if love.math.random() < 0.6 then
                local a, d = love.math.random() * 6.28, love.math.random() * z.r * 0.8
                w.particles:spawn(z.x + math.cos(a) * d, z.y + math.sin(a) * d, 1, 0, 0, 12, 0.5, GREEN, 1, { glow = true, grav = -20 })
            end
        end,
        draw = function(z, sx, sy, fade)
            local lg = love.graphics
            local r = z.r * math.min(1, z.t / 0.3)
            lg.setColor(0.45, 0.65, 0.15, 0.35 * fade)
            lg.ellipse("fill", sx, sy, r, r * 0.5)
            lg.setColor(0.8, 1, 0.45, 0.5 * fade)
            lg.ellipse("line", sx, sy, r, r * 0.5)
            -- bubbles popping
            for k = 0, 3 do
                local a = k * 1.7 + z.t * 2
                local bk = (z.t * 1.5 + k * 0.25) % 1
                lg.setColor(0.85, 1, 0.55, 0.6 * (1 - bk) * fade)
                lg.circle("line", sx + math.cos(a) * r * 0.5, sy + math.sin(a) * r * 0.25, 0.5 + bk * 1.5)
            end
        end })
end

return {
    name = "Acid Bomb",
    range = function(params) return params.reach or 40 end,
    fire = function(player, world, ax, ay, params)
        local reach = (params.reach or 40) * (1 + player.stats:get("area") / 100)
        local ang = math.atan2(ay, ax)
        local best, bd = nil, math.huge
        for _, e in ipairs(Grab.collect(world, player.x, player.y, reach, function(e, dx, dy)
            return not e.held and not e.def.boss and math.abs(util.angleDiff(ang, math.atan2(dy, dx))) < 0.9 end)) do
            local d = (e.x - player.x) ^ 2 + (e.y - player.y) ^ 2
            if d < bd then best, bd = e, d end
        end
        world:addFx({ kind = "stab", x = player.x, y = player.y, x2 = player.x + ax * reach, y2 = player.y + ay * reach, life = 0.1, color = { 1, 0.6, 0.45 } })
        if not best then Audio.play("dash", { pitch = 1.5 }) return end
        player.carry = { kind = "acidbomb", h = Grab.hold(best), t = 0, tick = 0 }
        Audio.play("hit", { pitch = 0.9 })
    end,
    update = function(player, world, dt, params, down, px, py)
        local c = player.carry
        if not c or c.kind ~= "acidbomb" then return end
        if not Grab.valid(c.h) then player.carry = nil return end
        c.t = c.t + dt
        local fx, fy = math.cos(player.wangle), math.sin(player.wangle)
        -- held up in the palps; it shields you from the ants in front
        Grab.place(c.h, player.x + fx * 12, player.y + fy * 12, 5 + math.sin(c.t * 24), player.wangle + math.sin(c.t * 30) * 0.3)
        local soak = math.min(1, c.t / (params.soak or 1.5))
        if down and c.t < (params.soak or 1.5) then
            c.tick = c.tick - dt
            if c.tick <= 0 then
                c.tick = 0.25
                Combat.damage(world, c.h.e, params.damage * 0.3, { knockback = 0, noCrit = true, dot = true, corrode = params.corrode or { 1.4, 3 } })
                world.particles:burst(c.h.e.x, c.h.e.y, 3, { GREEN }, 30, 20, { glow = true, grav = 120 })
                Audio.play("hit", { pitch = 1.8, volume = 0.3 })
            end
            return
        end
        -- hurl it
        local dx, dy, d = util.normalize(px - player.x, py - player.y)
        if d < 1 then dx, dy = player.aimX, player.aimY end
        local dist = math.min(params.distance or 120, math.max(30, d))
        local speed = 340
        local r = (params.pool or 40) * (0.55 + 0.45 * soak)
        Grab.fling(world, c.h, dx * speed, dy * speed, dist / speed, { damage = params.damage * 0.5, landDamage = params.damage * (1 + soak),
            selfDamage = params.damage * 2, radius = r * 0.7, height = 16, spin = 16, color = GREEN,
            onLand = function(w, x, y) pool(w, x, y, r * (1 + w.player.stats:get("area") / 100), params) end })
        player.wangle = math.atan2(dy, dx)
        player.lungeT = 0.18
        player.carry = nil
    end,
}
