-- An acorn that fell from above (the "acorns" event). Heavy: rolls slowly but hits hard.
return {
    name = "Acorn",
    radius = 7, pushable = true, mass = 3, friction = 2.0, crushSpeed = 50, damage = 20, roll = true,
    batSpeed = 200, dashSpeed = 250,
    max = 8, life = 60,     -- they don't pile up: the oldest one goes, and squirrels take them in time
    draw = function(world, o, sx, sy)
        local lg = love.graphics
        local a = o.roll or 0
        lg.setColor(0, 0, 0, 0.35)
        lg.ellipse("fill", sx + 1, sy + 2, 10, 5)
        lg.setColor(0.55, 0.32, 0.12, 1)
        lg.ellipse("fill", sx, sy - 4, 8, 6)
        lg.setColor(0.72, 0.46, 0.2, 1)
        lg.ellipse("fill", sx - 2, sy - 5, 4, 3)
        -- the cap, turning as it rolls
        local cx = math.floor(sx + math.cos(a) * 4)
        lg.setColor(0.38, 0.3, 0.17, 1)
        lg.ellipse("fill", cx, sy - 8, 6, 3)
        lg.setColor(0.5, 0.4, 0.24, 1)
        lg.rectangle("fill", cx - 3, sy - 9, 2, 1)
        lg.rectangle("fill", cx + 1, sy - 8, 2, 1)
        lg.setColor(0.3, 0.22, 0.12, 1)
        lg.rectangle("fill", cx, sy - 12, 1, 3)
    end,
}
