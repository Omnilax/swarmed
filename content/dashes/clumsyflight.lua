-- Clumsy flight (stag beetle): the wing cases pop open and the heavy beetle lumbers into the
-- air, drifting toward where you point while it's up (steer it), then crash-lands with a thud
-- that knocks the ants around it flat. Untouchable for nearly the whole flight.
-- params: distance (flight length, 95), speed (x normal dash speed, 0.5), hop (height, 14),
--         turn (steering, radians per second, 4), damage (landing, 8), radius (34),
--         knockback (240)
local Combat = require("src.game.combat")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")
local util = require("src.core.util")

return {
    name = "Clumsy Flight",
    description = "Lumber into the air and steer toward where you point, then crash down with a thud that knocks the ants around you flat.",
    jump = true,
    start = function(player, world, dx, dy, params)
        player:lunge(dx, dy, params.distance or 95, params.speed or 0.5)
        player.dashHop = params.hop or 14
        player.flyT = player.dashT
        world.particles:burst(player.x, player.y, 6, { { 0.7, 0.6, 0.45 } }, 50, 10, { grav = 200 })
        Audio.play("dash", { pitch = 0.5, volume = 0.7 })
    end,
    update = function(player, world, dt, params)
        if not player.flyT then return end
        -- steer the flight toward the pointer, keeping the speed
        local px, py = player:pointer()
        local sp = math.sqrt(player.dashX * player.dashX + player.dashY * player.dashY)
        local tx, ty, l = util.normalize(px - player.x, py - player.y)
        if l > 10 and sp > 0 then
            local a = math.atan2(player.dashY, player.dashX)
            local da = util.angleDiff(a, math.atan2(ty, tx))
            local step = (params.turn or 4) * dt
            a = a + math.max(-step, math.min(step, da))
            player.dashX, player.dashY = math.cos(a) * sp, math.sin(a) * sp
        end
        if player.dashT > dt then return end
        player.flyT = nil
        local r = (params.radius or 34) * (1 + player.stats:get("area") / 100)
        Combat.area(world, player.x, player.y, r, params.damage or 8, { knockback = params.knockback or 240 })
        world:addFx({ kind = "ring", x = player.x, y = player.y, r = r, life = 0.22, color = { 1, 0.8, 0.55 } })
        world.particles:burst(player.x, player.y, 12, { { 0.7, 0.6, 0.45 }, { 0.5, 0.42, 0.32 } }, 90, 30, { grav = 260 })
        world.camera:shake(0.12)
        Audio.play("hit", { pitch = 0.5 })
        player.iframes = math.max(player.iframes, 0.12)
    end,
    -- buzzing hind wings while airborne
    draw = function(player, world, params)
        if not player.flyT or player.dashT <= 0 or player.dead then return end
        local lg = love.graphics
        local c, s = math.cos(player.wangle), math.sin(player.wangle)
        local flap = math.sin(world.time * 70) * 0.5 + 0.5
        lg.setColor(0.85, 0.85, 0.75, 0.35 + flap * 0.25)
        for side = -1, 1, 2 do
            local bx, by = player.x - c * 2, player.y - s * 2
            local wx, wy = bx - c * 4 - s * side * (7 + flap * 3), by - s * 4 + c * side * (7 + flap * 3)
            local x1, y1 = Iso.toScreen(bx, by, 6 + (player.z or 0))
            local x2, y2 = Iso.toScreen(wx, wy, 7 + (player.z or 0))
            lg.polygon("fill", x1, y1, x2, y2, (x1 + x2) / 2 + (y2 - y1) * 0.25, (y1 + y2) / 2 - (x2 - x1) * 0.25)
        end
        lg.setColor(1, 1, 1, 1)
    end,
}
