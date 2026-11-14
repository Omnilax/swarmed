-- Safety line (jumping spider): a big leap to where you point, trailing a silk line anchored
-- where you took off. While the line holds, press dash again (no charge needed) to zip back
-- along it to the anchor. Jump out, bite, get yanked home.
-- params: distance (furthest leap, 125), hop (height, 18), speed (x normal dash speed, 1.1),
--         line (seconds the anchor holds, 2.5), zip (speed x of the zip back, 1.7)
local Iso = require("src.core.iso")
local Input = require("src.core.input")
local Audio = require("src.core.audio")

local function zip(player, world, params)
    local a = player.silk
    player.silk = nil
    local dx, dy = a.x - player.x, a.y - player.y
    local d = math.sqrt(dx * dx + dy * dy)
    if d < 8 then return end
    player.dashHop, player.dashHit = 0, nil
    player:lunge(dx / d, dy / d, d, params.zip or 1.7)
    player.dashT0 = player.dashT
    player.iframes = math.max(player.iframes, player.dashT * 0.8 + 0.05)
    world.particles:burst(player.x, player.y, 5, { { 0.9, 0.95, 1 } }, 50, 10, { grav = 40 })
    Audio.play("dash", { pitch = 2, volume = 0.6 })
end

return {
    name = "Safety Line",
    description = "Leap to where you point, trailing a silk line. Press again while it holds to zip back to where you jumped from.",
    jump = true,
    free = function(player) return player.silk ~= nil end,
    start = function(player, world, dx, dy, params, px, py)
        if player.silk then
            zip(player, world, params)      -- the zip back is free (see free below)
            return
        end
        local range = params.distance or 125
        local tx, ty = (px or player.x) - player.x, (py or player.y) - player.y
        local d = math.sqrt(tx * tx + ty * ty)
        if d < 12 then tx, ty, d = dx, dy, range else tx, ty = tx / d, ty / d end
        d = math.max(40, math.min(range, d))
        player.silk = { x = player.x, y = player.y, t = params.line or 2.5 }
        player:lunge(tx, ty, d, params.speed or 1.1)
        player.dashHop = params.hop or 18
    end,
    tick = function(player, world, dt, params)
        local a = player.silk
        if not a then return end
        a.t = a.t - dt
        if a.t <= 0 or player.dead then player.silk = nil return end
    end,
    -- the silk line from the anchor to the spinnerets, fading as it wears thin
    draw = function(player, world, params)
        local a = player.silk
        if not a or player.dead then return end
        local lg = love.graphics
        local x1, y1 = Iso.toScreen(a.x, a.y, 0)
        local x2, y2 = Iso.toScreen(player.x - player.aimX * 4, player.y - player.aimY * 4, 2 + (player.z or 0))
        lg.setLineWidth(1)
        lg.setColor(0.92, 0.96, 1, 0.35 + 0.5 * math.min(1, a.t / 0.8))
        lg.line(x1, y1, (x1 + x2) / 2, (y1 + y2) / 2 + 2, x2, y2)
        lg.rectangle("fill", math.floor(x1 - 1), math.floor(y1 - 1), 2, 2)
        lg.setColor(1, 1, 1, 1)
    end,
}
