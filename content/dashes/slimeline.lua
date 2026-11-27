-- Slime line (velvet worm): it shoots a strand of slime out BEHIND it, away from where you
-- aim, sticks it to the ground and reels itself back along it, out of trouble. Pulling away
-- gives it a breather: a small heal every time.
-- params: distance (95), speed (x normal dash speed, 1.05), heal (5), charges (1)
local Audio = require("src.core.audio")
local Iso = require("src.core.iso")
local util = require("src.core.util")

local SLIME = { 0.95, 0.92, 0.78 }

return {
    name = "Slime Line",
    description = "Shoot a slime strand behind you and reel yourself back along it, away from your aim. Heals you a little.",
    start = function(player, world, dx, dy, params)
        local bx, by = -player.aimX, -player.aimY
        local dist = params.distance or 95
        local S = world.size
        local ax = util.clamp(player.x + bx * dist, 10, S - 10)
        local ay = util.clamp(player.y + by * dist, 10, S - 10)
        player.slimeAnchor = { x = ax, y = ay }
        player:lunge(bx, by, util.len(ax - player.x, ay - player.y), params.speed or 1.05)
        player:heal(params.heal or 5)
        world:floatText(player.x, player.y - 8, "+" .. (params.heal or 5), { 0.6, 1, 0.6 }, false)
        world.particles:burst(ax, ay, 6, { SLIME }, 40, 20, { grav = 100 })
        Audio.play("dash", { pitch = 1.5, volume = 0.6 })
    end,
    -- the strand from the anchor to the worm while it reels in
    draw = function(player, world, params)
        local a = player.slimeAnchor
        if not a then return end
        if player.dashT <= 0 then player.slimeAnchor = nil return end
        local lg = love.graphics
        local x1, y1 = Iso.toScreen(a.x, a.y)
        local x2, y2 = Iso.toScreen(player.x, player.y)
        lg.setColor(SLIME[1], SLIME[2], SLIME[3], 0.8)
        lg.setLineWidth(1)
        lg.line(x1, y1, x2, y2 - 3)
        lg.circle("fill", x1, y1, 2)
        lg.setColor(1, 1, 1, 1)
    end,
}
