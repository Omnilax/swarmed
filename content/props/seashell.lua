-- A seashell on the sand (the beach's pebble): roll it into a column of ants and it flattens them.
local PA = require("src.gfx.propart")
local Paint = require("src.gfx.paint")
return {
    name = "Seashell",
    radius = 6, pushable = true, mass = 1.6, friction = 2.4, crushSpeed = 55, damage = 13, roll = true, material = "shell",
    bounce = 0.42,
    init = function(world, o)
        o.r = o.r * (0.8 + love.math.random() * 0.45)
        o.shade = 0.9 + love.math.random() * 0.15
    end,
    draw = function(world, o, sx, sy)
        local lg, r, c = love.graphics, o.r, o.shade
        lg.setColor(0, 0, 0, 0.3)
        lg.ellipse("fill", sx + 1, sy + 2, r * 1.4, r * 0.7)
        local a = math.floor((o.roll or 0) / (math.pi / 8) + 0.5) * (math.pi / 8)
        Paint.draw(PA.seashell(r, o.uid or 0), sx, sy - r * 0.4, a * 0.4, 1, 1, { c, c, c, 1 })
    end,
}
