-- An acorn that fell from above (the "acorns" event). Heavy: rolls slowly but hits hard.
local PA = require("src.gfx.propart")
local Paint = require("src.gfx.paint")
return {
    name = "Acorn",
    radius = 7, pushable = true, mass = 3, friction = 2.0, crushSpeed = 50, damage = 20, roll = true,
    batSpeed = 200, dashSpeed = 250, material = "nut",
    max = 8, life = 60,     -- they don't pile up: the oldest one goes, and squirrels take them in time
    draw = function(world, o, sx, sy)
        local lg = love.graphics
        lg.setColor(0, 0, 0, 0.35)
        lg.ellipse("fill", sx + 1, sy + 2, 10, 5)
        -- painted (src/gfx/propart.lua); it turns as it rolls, in sixteenths of a turn
        local a = math.floor((o.roll or 0) / (math.pi / 8) + 0.5) * (math.pi / 8)
        Paint.draw(PA.acorn(), sx, sy - 6, a)
    end,
}
