-- Horn charge (rhino beetle): head down, a straight charge that scoops the first ants it meets
-- up onto the horn and carries them along, then heaves them into the air at the end of the run
-- so they crash down on the crowd ahead. Ants it barges past on the way are knocked aside.
-- params: distance (75), speed (x normal dash speed, 1), carry (ants it can scoop, 3),
--         ram (damage to ants barged past, 10), knockback (220), toss (thrown distance, 70),
--         tossDamage (landing damage, 12), radius (landing area, 22)
local Combat = require("src.game.combat")
local Grab = require("src.game.grab")
local Audio = require("src.core.audio")
local util = require("src.core.util")

local function heave(player, world, params)
    local c = player.carry
    if not c or c.kind ~= "horn" then return end
    player.carry = nil
    local fx, fy = player.aimX, player.aimY
    if math.abs(player.dashX) + math.abs(player.dashY) > 0.01 then fx, fy = util.normalize(player.dashX, player.dashY) end
    local dist = params.toss or 70
    for i, h in ipairs(c.list) do
        if Grab.valid(h) then
            local spread = (i - (#c.list + 1) / 2) * 0.35
            local cs, sn = math.cos(spread), math.sin(spread)
            local vx, vy = fx * cs - fy * sn, fx * sn + fy * cs
            Grab.fling(world, h, vx * dist / 0.45, vy * dist / 0.45, 0.45,
                { damage = 6, landDamage = params.tossDamage or 12, radius = params.radius or 22, height = 22, color = { 0.6, 0.95, 1 } })
        end
    end
    world.camera:shake(0.08)
end

return {
    name = "Horn Charge",
    description = "Charge head down: the first ants you hit are scooped onto your horn, carried along and heaved onto the crowd ahead. Others are barged aside.",
    start = function(player, world, dx, dy, params)
        if player.carry and player.carry.kind == "horn" then heave(player, world, params) end
        player:lunge(dx, dy, params.distance or 75, params.speed or 1)
        player.dashHit = {}
        player.carry = { kind = "horn", list = {} }
    end,
    update = function(player, world, dt, params)
        local c, hit = player.carry, player.dashHit
        if not c or c.kind ~= "horn" or not hit then return end
        local fx, fy = util.normalize(player.dashX, player.dashY)
        local hx, hy = player.x + fx * (player.radius + 5), player.y + fy * (player.radius + 5)
        for _, e in ipairs(Grab.collect(world, hx, hy, 6)) do
            if not hit[e] and not e.held then
                hit[e] = true
                if #c.list < (params.carry or 3) and not e.def.boss and (e.mass or 1) <= 4 then
                    c.list[#c.list + 1] = Grab.hold(e)
                    Audio.play("hit", { pitch = 0.8 })
                else
                    local sx, sy = -fy, fx
                    if (e.x - player.x) * sx + (e.y - player.y) * sy < 0 then sx, sy = -sx, -sy end
                    Combat.damage(world, e, params.ram or 10, { knockback = params.knockback or 220, kbx = sx + fx * 0.5, kby = sy + fy * 0.5 })
                end
            end
        end
        -- the scooped ants ride on the horn, stacked up
        for i, h in ipairs(c.list) do
            Grab.place(h, hx + fx * i * 2, hy + fy * i * 2, 6 + i * 4, math.atan2(fy, fx))
        end
    end,
    tick = function(player, world, dt, params)
        local c = player.carry
        if c and c.kind == "horn" and player.dashT <= 0 then heave(player, world, params) end
    end,
}
