-- Driftwood: a long, sea-bleached stick (the beach's twig). Shove it side-on to sweep ants flat.
return {
    name = "Driftwood",
    radius = 3.5, length = 58, pushable = true, mass = 2, friction = 2.6, crushSpeed = 50, damage = 12,
    spinOnLaunch = 2.5, material = "wood", grabRadius = 11,
    init = function(world, o) o.r = 3.5 o.knot = love.math.random() * 0.6 + 0.2 end,
    draw = function(world, o, sx, sy)
        local PA = require("src.gfx.propart")
        local pic = PA.twig(o.def.length, o.knot or 0.5, true)
        PA.drawFlat(pic, o.x + 1.5, o.y + 1.5, o.angle, 0, { 0, 0, 0, 0.3 })
        PA.drawFlat(pic, o.x, o.y, o.angle, (o.z or 0) + 2)
    end,
}
