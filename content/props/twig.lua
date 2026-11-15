-- A twig: long and light. Shove it side-on and it sweeps a whole line of ants flat.
return {
    name = "Twig",
    radius = 3, length = 46, pushable = true, mass = 1.5, friction = 2.6, crushSpeed = 50, damage = 11,
    spinOnLaunch = 3,
    init = function(world, o) o.r = 3 o.knot = love.math.random() * 0.6 + 0.2 end,
    draw = function(world, o, sx, sy)
        local Iso = require("src.core.iso")
        local lg = love.graphics
        local L = o.def.length
        local cx, cy = math.cos(o.angle) * L / 2, math.sin(o.angle) * L / 2
        local ax, ay = Iso.toScreen(o.x - cx, o.y - cy)
        local bx, by = Iso.toScreen(o.x + cx, o.y + cy)
        lg.setColor(0, 0, 0, 0.3)
        lg.setLineWidth(4)
        lg.line(ax + 1, ay + 2, bx + 1, by + 2)
        lg.setColor(0.32, 0.2, 0.11, 1)
        lg.setLineWidth(4)
        lg.line(ax, ay, bx, by)
        lg.setColor(0.52, 0.36, 0.2, 1)
        lg.setLineWidth(2)
        lg.line(ax, ay - 1, bx, by - 1)
        lg.setLineWidth(1)
        -- a side shoot
        local kx, ky = ax + (bx - ax) * o.knot, ay + (by - ay) * o.knot
        lg.setColor(0.42, 0.28, 0.15, 1)
        lg.line(kx, ky - 1, kx + (by - ay) * 0.15 + 3, ky - 1 - (bx - ax) * 0.08 - 3)
    end,
}
