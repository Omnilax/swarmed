-- One-press graphics presets, shown at the top of Settings > Video. Each sets the listed
-- settings and leaves every other one alone; when the current values match none of them the
-- row reads "Custom". Add a preset by adding a row; add a setting to one by adding a key.
return {
    { id = "performance", label = "Performance", desc = "Chunky pixels, no lighting, shadows, rim light, splats or weather and few particles. For phones, browsers and old laptops.",
        values = { renderResolution = "640x360", lighting = false, particles = 1, decals = false, decalFade = 5, weather = "off",
            glareGuard = false, rimLight = false, sunShadows = false, contactShadows = false, actorsPop = false, fallingLeaves = false } },
    { id = "balanced", label = "Balanced", desc = "The standard look: lighting, weather and splats at a medium pixel size.",
        values = { renderResolution = "960x540", lighting = true, particles = 3, decals = true, decalFade = 10, weather = "random" } },
    { id = "pretty", label = "Pretty", desc = "Fine pixels and a wider view, splats that stay longer, everything on.",
        values = { renderResolution = "1280x720", lighting = true, particles = 3, decals = true, decalFade = 25, weather = "random" } },
}
