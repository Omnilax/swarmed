-- Spiderling swarm (wolf spider): wolf spider mothers carry their young on their backs. A shake
-- sends them all scurrying out; each runs down an ant, bites it full of venom and hunts the next
-- until it has bitten `bites` times or `life` runs out.
-- params: damage (per bite), cooldown, count (8), bites (3), speed (170), life (4 s), poison, color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")
local util = require("src.core.util")

return {
    name = "Spiderling Swarm",
    range = function() return 90 end,
    fire = function(player, world, ax, ay, params)
        player.brood = player.brood or {}
        local n = params.count or 8
        for i = 1, n do
            local a = i / n * math.pi * 2 + love.math.random() * 0.4
            player.brood[#player.brood + 1] = { x = player.x, y = player.y, vx = math.cos(a) * 90, vy = math.sin(a) * 90,
                t = 0, bites = params.bites or 3, look = 0, z = 6 }
        end
        world.particles:burst(player.x, player.y, 6, { { 0.45, 0.38, 0.3 } }, 60, 20)
        Audio.play("dash", { pitch = 1.9 })
    end,
    update = function(player, world, dt, params)
        local brood = player.brood
        if not brood then return end
        local speed = params.speed or 170
        for i = #brood, 1, -1 do
            local s = brood[i]
            s.t = s.t + dt
            s.z = math.max(0, s.z - dt * 30)
            -- pick a target now and then
            s.look = s.look - dt
            if s.look <= 0 or (s.target and (s.target.dead or s.target.uid ~= s.uid)) then
                s.look = 0.3
                s.target = world:nearestEnemy(s.x, s.y, 120)
                s.uid = s.target and s.target.uid
            end
            local e = s.target
            if e and not e.dead and e.uid == s.uid then
                local dx, dy, d = util.normalize(e.x - s.x, e.y - s.y)
                s.vx, s.vy = s.vx + (dx * speed - s.vx) * math.min(1, dt * 8), s.vy + (dy * speed - s.vy) * math.min(1, dt * 8)
                if d < e.radius + 2 then
                    Combat.damage(world, e, params.damage or 4, { knockback = 20, kbx = dx, kby = dy, poison = params.poison or { 4, 3 }, noCrit = true })
                    s.bites = s.bites - 1
                    s.target, s.look = nil, 0.15
                    s.vx, s.vy = -dx * 80, -dy * 80
                end
            else
                -- nothing to hunt: scurry back around mother
                local dx, dy = util.normalize(player.x - s.x, player.y - s.y)
                s.vx, s.vy = s.vx + (dx * speed * 0.6 - s.vx) * dt * 3, s.vy + (dy * speed * 0.6 - s.vy) * dt * 3
            end
            s.x, s.y = s.x + s.vx * dt, s.y + s.vy * dt
            if s.bites <= 0 or s.t > (params.life or 4) then table.remove(brood, i) end
        end
        if #brood == 0 then player.brood = nil end
    end,
    draw = function(player, world)
        local brood = player.brood
        if not brood then return end
        local Iso = require("src.core.iso")
        local lg = love.graphics
        for _, s in ipairs(brood) do
            local x, y = Iso.toScreen(s.x, s.y, s.z)
            x, y = math.floor(x), math.floor(y)
            local leg = math.floor(s.t * 20) % 2
            lg.setColor(0.18, 0.14, 0.11, 1)
            lg.rectangle("fill", x - 2, y - leg, 1, 1)
            lg.rectangle("fill", x + 2, y - 1 + leg, 1, 1)
            lg.setColor(0.42, 0.34, 0.26, 1)
            lg.rectangle("fill", x - 1, y - 1, 2, 2)
        end
    end,
}
