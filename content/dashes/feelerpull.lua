-- Antenna whip grapple (tailless whip scorpion): it cracks its whip-long feelers out to where you
-- point like a bullwhip. If the tips catch an ant, they lash it and the bug hauls itself straight
-- to it and cracks the whip around it on arrival; if they hit only ground, they hook in and pull
-- the bug there. Ants in the way while it flies in get whipped aside. Two charges.
-- params: range (furthest the feelers reach, 140), hookSpeed (feeler flight, 800), speed (x normal
--         dash speed while hauling in, 1.6), damage (lash on the caught ant, 8), crack (whip crack
--         on arrival at a caught ant, 14), radius (crack, 26), charges (2)
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")
local Combat = require("src.game.combat")
local util = require("src.core.util")

local COLOR = { 0.75, 0.6, 0.42 }

local function haul(player, g, params)
    local dx, dy, d = util.normalize(g.hx - player.x, g.hy - player.y)
    if d < 1 then dx, dy = g.dx, g.dy end
    local stop = g.ant and (player.radius + g.ant.radius + 2) or 6
    player:lunge(dx, dy, math.max(6, d - stop), params.speed or 1.6)
    g.state, g.t = "pull", 0
end

return {
    name = "Antenna Whip",
    description = "Crack your whip-long feelers out where you point. Catch an ant and you lash it, zip to it and crack the whip around it; catch ground and you haul yourself there. Two charges.",
    start = function(player, world, dx, dy, params, px, py)
        local range = params.range or 140
        local tx, ty = px - player.x, py - player.y
        local d = math.sqrt(tx * tx + ty * ty)
        if d < 12 then tx, ty, d = dx, dy, range * 0.7 else tx, ty = tx / d, ty / d end
        d = math.max(30, math.min(range, d))
        player.grapple = { state = "fly", t = 0, hx = player.x, hy = player.y, tx = player.x + tx * d, ty = player.y + ty * d,
            dx = tx, dy = ty, hit = {} }
        player.dashT = 0
        Audio.play("dash", { pitch = 2.1, volume = 0.6 })
    end,
    update = function(player, world, dt, params)
        local g = player.grapple
        if not g then return end
        g.t = g.t + dt
        if g.state == "fly" then
            local sp = (params.hookSpeed or 800) * dt
            local rx, ry = g.tx - g.hx, g.ty - g.hy
            local rl = math.sqrt(rx * rx + ry * ry)
            if rl <= sp then g.hx, g.hy = g.tx, g.ty else g.hx, g.hy = g.hx + rx / rl * sp, g.hy + ry / rl * sp end
            -- the tips snag the first ant they touch
            local e = Combat.collect(world, g.hx, g.hy, 7)[1]
            if e then
                g.ant = e
                g.hx, g.hy = e.x, e.y
                Combat.damage(world, e, params.damage or 8, { knockback = 0, stun = 0.5 })
                world.particles:burst(e.x, e.y, 6, { { 1, 0.85, 0.6 } }, 70, 12, { glow = true })
                Audio.play("hit", { pitch = 2.4, volume = 0.8 })
                haul(player, g, params)
            elseif rl <= sp or g.t > 0.4 then
                world.particles:burst(g.hx, g.hy, 5, { COLOR }, 50, 10, { grav = 200 })
                Audio.play("hit", { pitch = 2, volume = 0.5 })
                haul(player, g, params)
            end
            return
        end
        -- hauling in: follow the caught ant, whip aside whatever is in the way
        if g.ant and not g.ant.dead then g.hx, g.hy = g.ant.x, g.ant.y end
        for _, e in ipairs(Combat.collect(world, player.x, player.y, player.radius + 5)) do
            if e ~= g.ant and not g.hit[e] then
                g.hit[e] = true
                local nx, ny = util.normalize(e.x - player.x, e.y - player.y)
                Combat.damage(world, e, (params.damage or 8) * 0.5, { knockback = 160, kbx = nx - player.dashY * 0.5, kby = ny + player.dashX * 0.5 })
            end
        end
        if player.dashT <= 0 or g.t > 0.6 then
            if g.ant then
                -- the crack: both whips snap around the ant
                local r = (params.radius or 26) * (1 + player.stats:get("area") / 100)
                local cx, cy = player.x + g.dx * 8, player.y + g.dy * 8
                for _, e in ipairs(Combat.collect(world, cx, cy, r)) do
                    Combat.damage(world, e, params.crack or 14, { knockback = 200, kbx = e.x - player.x, kby = e.y - player.y })
                end
                world:addFx({ kind = "ring", x = cx, y = cy, r = r, life = 0.2, color = { 1, 0.9, 0.65 } })
                world.camera:shake(0.06)
                Audio.play("hit", { pitch = 1.6 })
            end
            player.grapple = nil
        end
    end,
    -- both feelers from the head to the tips: a rippling whip while flying, taut while hauling
    draw = function(player, world)
        local g = player.grapple
        if not g or player.dead then return end
        local lg = love.graphics
        local c, s = math.cos(player.wangle), math.sin(player.wangle)
        local x2, y2 = Iso.toScreen(g.hx, g.hy, 1)
        local amp = g.state == "fly" and 4 or 1
        lg.setLineWidth(1)
        lg.setColor(COLOR[1], COLOR[2], COLOR[3], 0.95)
        for side = -1, 1, 2 do
            local x1, y1 = Iso.toScreen(player.x + c * 4 - s * side * 2, player.y + s * 4 + c * side * 2, 4 + (player.z or 0))
            local ex, ey = x2 - x1, y2 - y1
            local el = math.sqrt(ex * ex + ey * ey) + 0.001
            local nx, ny = -ey / el, ex / el
            local pts = {}
            for i = 0, 10 do
                local k = i / 10
                local w = (math.sin(k * math.pi * 3 - g.t * 40 + side) * amp + side * 1.5) * math.sin(k * math.pi)
                pts[#pts + 1] = x1 + ex * k + nx * w
                pts[#pts + 1] = y1 + ey * k + ny * w - math.sin(k * math.pi) * 2
            end
            lg.line(pts)
        end
        lg.setColor(1, 0.9, 0.7, 1)
        lg.points(math.floor(x2) + 0.5, math.floor(y2) + 0.5)
        lg.setColor(1, 1, 1, 1)
    end,
}
