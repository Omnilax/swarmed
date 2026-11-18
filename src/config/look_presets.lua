-- One-press looks, shown at the top of Settings > Lighting. Each sets the listed settings and
-- leaves every other one alone; when the current values match none of them the row reads
-- "Custom". (Same shape as src/config/settings_presets.lua.)
return {
    { id = "standard", label = "Standard", desc = "The default look: bold lights with glare kept in check, shadows and rim light, nothing showy.",
        values = { lightStyle = "bold", lightStrength = 100, glareGuard = true, ownEffects = 100, richDay = true, sunShadows = true,
            contactShadows = true, rimLight = true, actorsPop = true, backgroundDim = 0, threatOutlines = "off", sunRays = false,
            cloudShadows = "weather", colourGrade = "off", killLights = false, hordeDepth = false, autoZoom = "off", bossIntro = false,
            waveClearZoom = false, foregroundGrass = false } },
    { id = "clarity", label = "Clarity", desc = "Everything tuned for seeing the fight: muted ground, outlines on threats, faded own effects, no drifting shadows or rays.",
        values = { lightStyle = "bold", lightStrength = 90, glareGuard = true, ownEffects = 60, richDay = true, sunShadows = false,
            contactShadows = true, rimLight = true, actorsPop = true, backgroundDim = 25, threatOutlines = "all", sunRays = false,
            cloudShadows = "off", colourGrade = "off", killLights = false, hordeDepth = true, autoZoom = "off", bossIntro = false,
            waveClearZoom = false, foregroundGrass = false } },
    { id = "cinematic", label = "Cinematic", desc = "Strong lights, long shadows, sun rays, cloud shadows, a colour grade per map, boss intros and an auto-zooming camera.",
        values = { lightStyle = "bold", lightStrength = 120, glareGuard = true, ownEffects = 100, richDay = true, sunShadows = true,
            contactShadows = true, rimLight = true, actorsPop = true, backgroundDim = 0, threatOutlines = "off", sunRays = true,
            cloudShadows = "always", colourGrade = "map", killLights = true, hordeDepth = false, autoZoom = "subtle", bossIntro = true,
            waveClearZoom = true, foregroundGrass = true } },
    { id = "classic", label = "Classic", desc = "The look from before the lighting update: soft lights, blob shadows only, no extras.",
        values = { lightStyle = "soft", lightStrength = 100, glareGuard = false, ownEffects = 100, richDay = false, sunShadows = false,
            contactShadows = false, rimLight = false, actorsPop = false, backgroundDim = 0, threatOutlines = "off", sunRays = false,
            cloudShadows = "off", colourGrade = "off", killLights = false, hordeDepth = false, warningLights = false, hazardGlow = false,
            threatLights = false, nightLantern = false, wetGround = false, fallingLeaves = false, glowDecor = false, deathStyles = false,
            squashStretch = false, windGusts = false, heatHaze = false, silhouettes = false, shotsOnTop = false, autoZoom = "off",
            bossIntro = false, waveClearZoom = false, foregroundGrass = false } },
}
