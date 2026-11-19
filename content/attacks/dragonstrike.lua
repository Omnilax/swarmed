-- Dragonfly strikes. On the ground it sweeps: the wings and spiny legs scythe a wide arc around
-- the front, hurting and pushing back every ant in it (and batting spit away). In the air it
-- lunges: a fast, untouchable dive forward that rakes every ant along the way.
-- params: damage, cooldown, gust (sweep reach, 46), arc (sweep width, 3.4), gustMult (sweep
--         damage x, 0.9), reach (air lunge distance, 70), lungeSpeed (x dash speed, 1.7),
--         knockback, color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")
local util = require("src.core.util")

return {
    name = "Sweep / Dive Lunge",
    range = function(params, player)
        local area = 1 + player.stats:get("area") / 100
        return (player.airborne and (params.reach or 70) or (params.gust or 46)) * area
    end,
    fire = function(player, world, ax, ay, params)
        local area = 1 + player.stats:get("area") / 100
        local ang = math.atan2(ay, ax)
        if player.airborne then
            -- the dive: untouchable from start to finish, raking whatever it passes. It goes where
            -- you steer (when you are steering), so attacking never yanks the dragonfly off course.
            local reach = (params.reach or 70) * area
            local mx, my = player.moveDirX or 0, player.moveDirY or 0
            if params.steerDive ~= false and (mx ~= 0 or my ~= 0) then ax, ay = util.normalize(mx, my) end
            player:lunge(ax, ay, reach, params.lungeSpeed or 1.7)
            player.iframes = math.max(player.iframes, player.dashT + 0.08)
            player.dfLunge = { hit = {}, x = player.x, y = player.y }
            world:addFx({ kind = "streak", x = player.x, y = player.y, x2 = player.x + ax * reach, y2 = player.y + ay * reach,
                life = 0.16, w = 3, color = params.color or { 0.5, 0.85, 1 } })
            Audio.play("dash", { pitch = 1.8, volume = 0.7 })
        else
            local r = (params.gust or 46) * area
            local half = (params.arc or 3.4) / 2
            for _, e in ipairs(Combat.collect(world, player.x, player.y, r, function(e, dx, dy)
                return math.abs(util.angleDiff(ang, math.atan2(dy, dx))) <= half end)) do
                local nx, ny = util.normalize(e.x - player.x, e.y - player.y)
                Combat.damage(world, e, params.damage * (params.gustMult or 0.9), { knockback = (params.knockback or 90) * 1.6, kbx = nx, kby = ny })
            end
            world.hazards:deflect(player.x, player.y, r, ang, half)
            player.swingDir = -(player.swingDir or 1)
            world:addFx({ kind = "arc", x = player.x, y = player.y, r = r, a = ang, arc = half * 2, dir = player.swingDir, life = 0.2, color = { 0.8, 0.95, 1 } })
            for _ = 1, 8 do
                local a = ang + (love.math.random() - 0.5) * half * 2
                world.particles:spawn(player.x + math.cos(a) * 8, player.y + math.sin(a) * 8, 3, math.cos(a) * 160, math.sin(a) * 160, 10, 0.3,
                    { 0.75, 0.7, 0.6 }, 1, { grav = 0 })
            end
            Audio.play("dash", { pitch = 1.3, volume = 0.5 })
        end
    end,
    update = function(player, world, dt, params)
        local l = player.dfLunge
        if not l then return end
        if player.dashT <= 0 or player.dead then player.dfLunge = nil return end
        for _, e in ipairs(Combat.collect(world, player.x, player.y, player.radius + 8)) do
            if not l.hit[e] then
                l.hit[e] = true
                local nx, ny = util.normalize(e.x - player.x, e.y - player.y)
                Combat.damage(world, e, params.damage, { knockback = params.knockback or 90, kbx = nx + player.dashX * 0.5, kby = ny + player.dashY * 0.5 })
                world.particles:burst(e.x, e.y, 3, { params.color or { 0.5, 0.85, 1 } }, 60, 10, { glow = true })
            end
        end
    end,
}
