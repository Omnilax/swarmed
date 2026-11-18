-- One-press presets for whole settings tabs, shown as the first row of their tab. Each sets
-- the listed settings and leaves every other one alone; when the current values match none of
-- them the row reads "Custom". Add a preset by adding a row; add a tab by adding an entry.
--   [tab] = { label = row name, desc = row help, list = { { id, label, desc, values } ... } }
local Video = require("src.config.settings_presets")

local HEAVY_OFF = { glareGuard = false, rimLight = false, sunShadows = false, contactShadows = false, actorsPop = false,
    fallingLeaves = false, cloudShadows = "off", sunRays = false, heatHaze = false, livePreview = false }
local function with(base, extra)
    local t = {}
    for k, v in pairs(base) do t[k] = v end
    for k, v in pairs(extra or {}) do t[k] = v end
    return t
end

return {
    Video = {
        label = "Quality",
        desc = "Sets the graphics options below in one go (changing one after makes it Custom). Lowest and Performance suit phones, browsers and old laptops; High and Ultra a strong PC.",
        list = {
            { id = "lowest", label = "Lowest", desc = "Everything off for the oldest machines: chunky pixels, no lighting, weather, splats or particles, 30 fps cap.",
                values = with(HEAVY_OFF, { renderResolution = "640x360", lighting = false, particles = 0, decals = false, decalFade = 5,
                    weather = "off", fpsCap = 30 }) },
            Video[1],   -- Performance
            Video[2],   -- Balanced
            { id = "high", label = "High", desc = "Fine pixels, splats that stay a while, every light and shadow on.",
                values = { renderResolution = "1280x720", lighting = true, particles = 3, decals = true, decalFade = 25, weather = "random",
                    fpsCap = 0, glareGuard = true, rimLight = true, sunShadows = true, contactShadows = true, actorsPop = true,
                    fallingLeaves = true, cloudShadows = "weather", livePreview = true } },
            { id = "ultra", label = "Ultra", desc = "High plus splats that stay a minute, sun rays, drifting clouds and heat haze.",
                values = { renderResolution = "1280x720", lighting = true, particles = 3, decals = true, decalFade = 60, weather = "random",
                    fpsCap = 0, glareGuard = true, rimLight = true, sunShadows = true, contactShadows = true, actorsPop = true,
                    fallingLeaves = true, cloudShadows = "always", sunRays = true, heatHaze = true, livePreview = true } },
        },
    },
    Audio = {
        label = "Sound Mix",
        desc = "Sets the volumes below in one go.",
        list = {
            { id = "full", label = "Full", desc = "The standard mix: music, effects and ambience.",
                values = { musicVolume = 70, sfxVolume = 80, uiVolume = 70, ambientVolume = 60 } },
            { id = "music", label = "Music First", desc = "The music up front, effects softer, no ambience.",
                values = { musicVolume = 90, sfxVolume = 55, uiVolume = 60, ambientVolume = 0 } },
            { id = "action", label = "Action First", desc = "Hits and kills loud, the music behind them.",
                values = { musicVolume = 45, sfxVolume = 95, uiVolume = 70, ambientVolume = 40 } },
            { id = "nature", label = "Nature", desc = "No music: just the fight and the birds, crickets and wind.",
                values = { musicVolume = 0, sfxVolume = 75, uiVolume = 60, ambientVolume = 100 } },
            { id = "quiet", label = "Quiet", desc = "Everything soft, for late nights.",
                values = { musicVolume = 35, sfxVolume = 35, uiVolume = 35, ambientVolume = 30 } },
        },
    },
    Gameplay = {
        label = "Pace",
        desc = "How the game flows and helps you, in one go. None of these change how hard the ants are (that's Difficulty).",
        list = {
            { id = "relaxed", label = "Relaxed", desc = "Lots of help: nectar collects itself, Frenzy fires itself, rewards open at once, health bars on every ant, all warnings.",
                values = { autoAttack = true, aimMode = "nearest", autoCollect = true, frenzyAuto = true, waveRewards = "instant",
                    waveBreak = "manual", enemyHealthBars = "always", damageNumbers = "all", telegraphs = true, hitstop = true, slowMotion = true } },
            { id = "standard", label = "Standard", desc = "The usual flow.",
                values = { autoAttack = true, aimMode = "nearest", autoCollect = false, frenzyAuto = false, waveRewards = "bloom",
                    waveBreak = "auto", enemyHealthBars = "damaged", damageNumbers = "crits", telegraphs = true, hitstop = true, slowMotion = true } },
            { id = "flow", label = "Nonstop", desc = "No pauses in the action: no hit stop or slow motion, rewards at once, waves roll on by themselves.",
                values = { autoAttack = true, aimMode = "nearest", autoCollect = true, frenzyAuto = false, waveRewards = "instant",
                    waveBreak = "auto", enemyHealthBars = "damaged", damageNumbers = "crits", telegraphs = true, hitstop = false, slowMotion = false } },
            { id = "handson", label = "Hands-On", desc = "You aim at the mouse and attack yourself; fewer numbers and bars on screen.",
                values = { autoAttack = false, aimMode = "mouse", autoCollect = false, frenzyAuto = false, waveRewards = "bloom",
                    waveBreak = "auto", enemyHealthBars = "elites", damageNumbers = "off", telegraphs = true, hitstop = true, slowMotion = true } },
        },
    },
    Interface = {
        label = "HUD Style",
        desc = "How much the screen shows, in one go.",
        list = {
            { id = "full", label = "Full", desc = "Everything: timer, enemies left, next wave, popups, markers.",
                values = { hudDetail = "full", hudScale = 75, hudOpacity = 100, showTimer = true, showEnemyCount = true, nextWavePreview = true,
                    speciesPopups = "new", offscreenMarkers = true, showKoCounter = true, lowHealthPulse = true } },
            { id = "clean", label = "Clean", desc = "Only what matters in the fight, slightly see-through.",
                values = { hudDetail = "clean", hudScale = 70, hudOpacity = 80, showTimer = false, showEnemyCount = true, nextWavePreview = false,
                    speciesPopups = "new", offscreenMarkers = true, showKoCounter = false, lowHealthPulse = true } },
            { id = "minimal", label = "Minimal", desc = "Almost nothing on screen: for screenshots, videos and the brave.",
                values = { hudDetail = "clean", hudScale = 60, hudOpacity = 60, showTimer = false, showEnemyCount = false, nextWavePreview = false,
                    speciesPopups = "off", offscreenMarkers = false, showKoCounter = false, lowHealthPulse = false } },
            { id = "big", label = "Big & Clear", desc = "A larger, fully opaque HUD with every helper on.",
                values = { hudDetail = "full", hudScale = 110, hudOpacity = 100, showTimer = true, showEnemyCount = true, nextWavePreview = true,
                    speciesPopups = "new", offscreenMarkers = true, showKoCounter = true, lowHealthPulse = true } },
        },
    },
    Accessibility = {
        label = "Comfort",
        desc = "Common needs in one go. Mix and match the options below afterwards.",
        list = {
            { id = "none", label = "Standard", desc = "Nothing changed.",
                values = { reduceFlashing = false, safePalette = false, telegraphContrast = false, playerOutline = false, screenShake = 100,
                    cameraPunch = 100, hitstop = true } },
            { id = "visibility", label = "Low Vision", desc = "High-contrast warnings, a ring under your bug, outlines on threats and a bigger HUD.",
                values = { reduceFlashing = false, safePalette = false, telegraphContrast = true, playerOutline = true, screenShake = 100,
                    cameraPunch = 100, hitstop = true, threatOutlines = "all", silhouettes = true, hudScale = 100 } },
            { id = "motion", label = "Motion Comfort", desc = "No flashing, shaking, camera kicks, freezes or shimmer.",
                values = { reduceFlashing = true, safePalette = false, telegraphContrast = false, playerOutline = false, screenShake = 0,
                    cameraPunch = 0, hitstop = false, heatHaze = false, autoZoom = "off", bossIntro = false, waveClearZoom = false } },
            { id = "colour", label = "Colourblind", desc = "Colours that stay apart with any colour vision, plus high-contrast warnings.",
                values = { reduceFlashing = false, safePalette = true, telegraphContrast = true, playerOutline = false, screenShake = 100,
                    cameraPunch = 100, hitstop = true } },
        },
    },
}
