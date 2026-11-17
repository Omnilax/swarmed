-- A pebble: roll it into a column of ants and it flattens them.
local PA = require("src.gfx.propart")
local Paint = require("src.gfx.paint")
return {
    name = "Pebble",
    radius = 6, pushable = true, mass = 2, friction = 2.2, crushSpeed = 55, damage = 14, roll = true,
    init = function(world, o)
        o.r = o.r * (0.8 + love.math.random() * 0.5)
        o.shade = 0.85 + love.math.random() * 0.25
    end,
    draw = function(world, o, sx, sy)
        local lg, r, c = love.graphics, o.r, o.shade
        lg.setColor(0, 0, 0, 0.35)
        lg.ellipse("fill", sx + 1, sy + 2, r * 1.5, r * 0.75)
        local a = math.floor((o.roll or 0) / (math.pi / 8) + 0.5) * (math.pi / 8)
        Paint.draw(PA.pebble(r, o.uid or 0), sx, sy - r * 0.45, a * 0.5, 1, 1, { c, c, c, 1 })
    end,
}
