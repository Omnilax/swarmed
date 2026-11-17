-- A twig: long and light. Shove it side-on and it sweeps a whole line of ants flat.
return {
    name = "Twig",
    radius = 3, length = 46, pushable = true, mass = 1.5, friction = 2.6, crushSpeed = 50, damage = 11,
    spinOnLaunch = 3, material = "wood", grabRadius = 10,   -- swung or thrown, it clubs a wide path
    init = function(world, o) o.r = 3 o.knot = love.math.random() * 0.6 + 0.2 end,
    draw = function(world, o, sx, sy)
        -- a painted stick lying on the ground (src/gfx/propart.lua), its shadow under it;
        -- o.z lifts it while it is held or thrown
        local PA = require("src.gfx.propart")
        local pic = PA.twig(o.def.length, o.knot or 0.5)
        PA.drawFlat(pic, o.x + 1.5, o.y + 1.5, o.angle, 0, { 0, 0, 0, 0.3 })
        PA.drawFlat(pic, o.x, o.y, o.angle, (o.z or 0) + 2)
    end,
}
