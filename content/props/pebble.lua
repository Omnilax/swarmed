-- A pebble: roll it into a column of ants and it flattens them.
return {
    name = "Pebble",
    radius = 6, pushable = true, mass = 2, friction = 2.2, crushSpeed = 55, damage = 14, roll = true, material = "stone",
    init = function(world, o)
        o.r = o.r * (0.8 + love.math.random() * 0.5)
        o.shade = 0.85 + love.math.random() * 0.25
    end,
    draw = function(world, o, sx, sy)
        local lg, r, c = love.graphics, o.r, o.shade
        lg.setColor(0, 0, 0, 0.35)
        lg.ellipse("fill", sx + 1, sy + 2, r * 1.5, r * 0.75)
        lg.setColor(0.42 * c, 0.4 * c, 0.38 * c, 1)
        lg.ellipse("fill", sx, sy - r * 0.35, r * 1.35, r * 0.85)
        lg.setColor(0.6 * c, 0.57 * c, 0.53 * c, 1)
        lg.ellipse("fill", sx - 1, sy - r * 0.55, r * 1.0, r * 0.55)
        -- a fleck that turns as it rolls
        local a = o.roll or 0
        lg.setColor(0.78 * c, 0.75 * c, 0.7 * c, 1)
        lg.rectangle("fill", math.floor(sx + math.cos(a) * r * 0.6) - 1, math.floor(sy - r * 0.6 + math.sin(a) * r * 0.25), 2, 1)
    end,
}
