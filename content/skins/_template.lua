-- TEMPLATE. Copy to content/skins/my_skin.lua. A skin recolours a playable bug in game and in
-- menus; it never changes stats. Pick one per bug in Cosmetics (src/states/cosmetics.lua).
return {
    name = "My Skin",
    description = "One line shown in the Cosmetics screen.",
    order = 99,
    -- character = "tiger_beetle",   -- only this bug can wear it (default: every bug)
    -- locked = true,                -- hidden until Cosmetics.unlock("my_skin") (achievements, shop...)
    hue = 0,                         -- degrees to turn every colour round the colour wheel
    saturation = 1,                  -- colour strength multiplier (0 = greyscale)
    brightness = 1,                  -- value multiplier
    -- tint = "#ffffff",             -- multiplied over the result
    -- keepWhite = false,            -- also recolour near-white pixels (eyes, highlights)
    -- light = { color = "#ff9040", radius = 60, intensity = 0.5 },   -- glows around the bug
    -- model = { legs = ..., body = ..., height = ..., lift = ... },  -- a whole other model instead
}
