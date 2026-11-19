-- One-press looks, shown at the top of Settings > Lighting. Each look sets every Lighting and
-- Camera option (plus Time of Day and Shadow Strength) so players don't have to go through them
-- one by one; when the current values match none of them the row reads "Custom".
-- A look lists only what differs from the defaults: everything else is set back to its default,
-- so Standard (no changes) is exactly the default setup. Add a look by adding a row.
local Schema = require("src.config.settings_schema")

-- Options a look leaves alone (on/off features rather than a style).
local SKIP = { photoMode = true, screenshotKey = true, zoomKeys = true }

local LOOKS = {
    { id = "standard", label = "Standard",
        desc = "The default: bold lights with glare kept in check, shadows and rim light, a full day cycle, nothing showy.",
        set = {} },
    { id = "classic", label = "Classic",
        desc = "The look from before the lighting update: soft lights, blob shadows only, no extras.",
        set = { lightStyle = "soft", glareGuard = false, richDay = false, sunShadows = false, contactShadows = false,
            rimLight = false, actorsPop = false, cloudShadows = "off", warningLights = false, hazardGlow = false,
            threatLights = false, nightLantern = false, wetGround = false, fallingLeaves = false, glowDecor = false,
            deathStyles = false, squashStretch = false, windGusts = false, heatHaze = false, silhouettes = false,
            shotsOnTop = false } },
    { id = "dynamic", label = "Dynamic",
        desc = "Everything moves: strong lights, long shadows, drifting clouds, gusts, tracks, light pops on big kills and a camera that zooms with the fight.",
        set = { lightStrength = 130, sunRays = true, cloudShadows = "always", killLights = true, hordeTracks = true,
            autoZoom = "subtle", waveClearZoom = true, shakeStyle = "directional", cameraPunch = 120 } },
    { id = "cinematic", label = "Cinematic",
        desc = "Like a film: a colour grade per map, sun rays, a lower camera, boss intros with letterbox bars and grass in the foreground.",
        set = { lightStrength = 120, sunRays = true, cloudShadows = "always", colourGrade = "map", killLights = true,
            autoZoom = "subtle", bossIntro = true, waveClearZoom = true, foregroundGrass = true, cameraHeight = "low" } },
    { id = "dark", label = "Dark",
        desc = "Always night and deep shadow: you, the threats and the glowing mushrooms carry the light. Tense and moody.",
        set = { timeOfDay = "night", darkness = 130, lightStrength = 120, killLights = true, threatOutlines = "elites",
            fallingLeaves = false } },
    { id = "sunny", label = "Sunny",
        desc = "Always bright day with soft shadows and no clouds. Easy on the eyes and easy to read.",
        set = { timeOfDay = "day", darkness = 70, lightStrength = 80, cloudShadows = "off", wetGround = false } },
    { id = "clarity", label = "Clarity",
        desc = "Tuned for seeing the fight: muted ground, outlines on threats, faded own effects, the back of the horde darker, nothing drifting.",
        set = { lightStrength = 90, ownEffects = 60, sunShadows = false, backgroundDim = 25, threatOutlines = "all",
            cloudShadows = "off", hordeDepth = true, fallingLeaves = false, heatHaze = false, windGusts = false } },
    { id = "cozy", label = "Cozy",
        desc = "Forever golden hour: warm light, sun rays, falling leaves and glowing mushrooms, with a gentle camera.",
        set = { timeOfDay = "sunset", sunRays = true, colourGrade = "map", smoothZoom = true, shakeStyle = "directional",
            cameraPunch = 50 } },
    { id = "moody", label = "Moody",
        desc = "Dusk, heavy clouds, wet ground and a colour grade that darkens act by act.",
        set = { timeOfDay = "evening", darkness = 120, cloudShadows = "always", colourGrade = "act", hordeTracks = true,
            sunRays = false } },
    { id = "minimal", label = "Minimal",
        desc = "Calm and clean: soft lights, no weather extras, drifting leaves or camera kicks. Light on older computers.",
        set = { lightStyle = "soft", richDay = false, sunShadows = false, rimLight = false, cloudShadows = "off",
            wetGround = false, fallingLeaves = false, glowDecor = false, windGusts = false, heatHaze = false,
            deathStyles = false, ownEffects = 80, cameraPunch = 50 } },
    -- Low-glare looks: dimmer glows on top of the scene so sparks and flashes never hide the fight.
    { id = "softglow", label = "Soft Glow",
        desc = "Standard, but gentler: lights a little weaker and sparks, swooshes and flashes at half glare. A good first try if the glare feels like too much.",
        set = { lightStrength = 80, glareAmount = 50, ownEffects = 80, killLights = false, sunRays = false } },
    { id = "overcast", label = "Overcast",
        desc = "A cloudy day: even, flat light with almost no glare, light shadows and no sun rays. Very easy to read.",
        set = { timeOfDay = "day", darkness = 80, lightStyle = "soft", lightStrength = 70, glareAmount = 40,
            cloudShadows = "always", rimLight = false, sunRays = false, heatHaze = false, wetGround = false } },
    { id = "noglare", label = "No Glare",
        desc = "As little glow as the game allows: soft lights, the lowest glare, your own effects faded, no glowing decor or haze. Ants and attack warnings stay clear.",
        set = { lightStyle = "soft", glareAmount = 20, ownEffects = 50, rimLight = false, glowDecor = false,
            heatHaze = false, sunRays = false, killLights = false, threatOutlines = "elites" } },
    { id = "brightclear", label = "Bright & Clear",
        desc = "Always day, light shadows and low glare, with outlines on elites and queens. Bright without the dazzle.",
        set = { timeOfDay = "day", darkness = 70, lightStrength = 80, glareAmount = 40, ownEffects = 70,
            threatOutlines = "elites", heatHaze = false, sunRays = false } },
}

-- Fill each look out to every option it covers.
local looks = {}
for _, L in ipairs(LOOKS) do
    local values = { timeOfDay = "cycle", darkness = 100 }
    for _, s in ipairs(Schema) do
        if (s.category == "Lighting" or s.category == "Camera") and not SKIP[s.key] then values[s.key] = s.default end
    end
    for k, v in pairs(L.set) do
        assert(values[k] ~= nil, "look " .. L.id .. " sets an unknown option " .. k)
        values[k] = v
    end
    looks[#looks + 1] = { id = L.id, label = L.label, desc = L.desc, values = values }
end
return looks
