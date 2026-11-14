-- TEMPLATE. Copy to content/decor/my_decor.lua. Decor is a map cosmetic: it is painted onto
-- the location's floor once when a run starts (src/game/cosmetics.lua), so it costs nothing
-- per frame. Players switch decor on and off in Cosmetics; any number can be on at once.
local util = require("src.core.util")
return {
    name = "My Decor",
    description = "One line shown in the Cosmetics screen.",
    order = 99,
    -- stages = { "backyard" },     -- only on these locations (default: all)
    -- locked = true,               -- hidden until Cosmetics.unlock("my_decor")
    -- paint(ground, stage, rng): draw with love.graphics; the floor canvas is already bound and
    -- in canvas pixels. ground:toCanvas(wx, wy) turns a world position into a canvas pixel and
    -- stage.size is the arena's side. Use rng (a seeded love RandomGenerator) so it is the
    -- same every run. Add glowing spots to ground.decorLights:
    --   { x, y (projected: ground:toProjected(cx, cy)), radius, color = {r, g, b}, intensity, twinkle }
    paint = function(ground, stage, rng)
        local S = stage.size
        for _ = 1, 20 do
            local cx, cy = ground:toCanvas(rng:random() * S, rng:random() * S)
            love.graphics.setColor(util.hex("#d0c8b0"))
            love.graphics.rectangle("fill", math.floor(cx), math.floor(cy), 2, 1)
        end
    end,
}
