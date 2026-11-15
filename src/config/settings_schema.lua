-- Every user-facing setting. The settings screen is generated from this list, so adding a
-- setting here is all it takes to make it show up, save, and load.
--
-- Fields: key, category, label, type ("toggle" | "slider" | "choice"), default, desc
--   slider: min, max, step, unit
--   choice: options = { {value=..., label=...}, ... }
--   window = true  -> changing it re-applies the window mode
local S = {
    categories = { "Video", "Audio", "Gameplay", "Interface", "Accessibility", "Controls", "Developer" },
}

local function add(t) S[#S + 1] = t end

local function percent(v) return v .. "%" end

-- Video ---------------------------------------------------------------------------------
add { key = "fullscreen", category = "Video", label = "Fullscreen", type = "toggle", default = false, window = true,
    desc = "Play in fullscreen." }
add { key = "fullscreenType", category = "Video", label = "Fullscreen Mode", type = "choice", default = "desktop", window = true,
    options = { { value = "desktop", label = "Borderless" }, { value = "exclusive", label = "Exclusive" } },
    desc = "Borderless keeps alt-tab fast. Exclusive can lower input latency." }
add { key = "windowSize", category = "Video", label = "Window Size", type = "choice", default = "1280x720", window = true,
    options = {
        { value = "960x540", label = "960 x 540" }, { value = "1280x720", label = "1280 x 720" },
        { value = "1600x900", label = "1600 x 900" }, { value = "1920x1080", label = "1920 x 1080" },
        { value = "2560x1440", label = "2560 x 1440" },
    },
    desc = "Window size when not fullscreen. The window can also be resized freely." }
add { key = "vsync", category = "Video", label = "VSync", type = "choice", default = 1, window = true,
    options = { { value = 0, label = "Off" }, { value = 1, label = "On" }, { value = -1, label = "Adaptive" } },
    desc = "Sync frames to the monitor refresh rate to prevent tearing." }
add { key = "fpsCap", category = "Video", label = "FPS Limit", type = "choice", default = 0,
    options = {
        { value = 30, label = "30" }, { value = 60, label = "60" }, { value = 120, label = "120" },
        { value = 144, label = "144" }, { value = 240, label = "240" }, { value = 0, label = "Unlimited" },
    },
    desc = "Frame rate limit, used when VSync is off." }
add { key = "renderResolution", category = "Video", label = "Pixel Resolution", type = "choice", default = "960x540",
    options = { { value = "640x360", label = "640 x 360 (chunky)" }, { value = "960x540", label = "960 x 540" }, { value = "1280x720", label = "1280 x 720 (fine)" } },
    desc = "Size of the game's pixel canvas. Higher = smaller pixels, more detail and a wider view." }
add { key = "lighting", category = "Video", label = "Lighting", type = "toggle", default = true,
    desc = "Time-of-day lighting with glowing light sources. Turn off for a flat, fully lit look." }
add { key = "timeOfDay", category = "Video", label = "Time of Day", type = "choice", default = "cycle",
    options = { { value = "cycle", label = "Day / Night Cycle" }, { value = "day", label = "Day" }, { value = "sunset", label = "Sunset" },
        { value = "evening", label = "Evening" }, { value = "night", label = "Night" } },
    desc = "Fixed daylight, sunset, evening or night, or a cycle from morning through sunset and night to dawn." }
add { key = "dayLength", category = "Video", label = "Day Length", type = "choice", default = 300,
    options = { { value = 120, label = "2 min" }, { value = 300, label = "5 min" }, { value = 600, label = "10 min" }, { value = 1200, label = "20 min" } },
    desc = "How long one full day and night lasts in the cycle." }
add { key = "darkness", category = "Video", label = "Shadow Strength", type = "slider", default = 100, min = 0, max = 150, step = 10, format = percent,
    desc = "How strongly the time of day tints and darkens the world. 0% is always full daylight." }
add { key = "pixelPerfect", category = "Video", label = "Pixel Perfect Scaling", type = "toggle", default = true,
    desc = "Scale the pixel canvas by whole numbers when the window is at least twice its size. Crisper pixels, may add black borders." }
add { key = "screenShake", category = "Video", label = "Screen Shake", type = "slider", default = 100, min = 0, max = 200, step = 10, format = percent,
    desc = "How hard the camera shakes on hits and explosions." }
add { key = "hitFlash", category = "Video", label = "Hit Flash", type = "toggle", default = true,
    desc = "Enemies flash white when hit." }
add { key = "particles", category = "Video", label = "Particles", type = "choice", default = 3,
    options = { { value = 0, label = "Off" }, { value = 1, label = "Low" }, { value = 2, label = "Medium" }, { value = 3, label = "High" } },
    desc = "Amount of debris and sparks. Lower this if hordes get slow." }
add { key = "decals", category = "Video", label = "Bug Splats", type = "toggle", default = true,
    desc = "Defeated bugs leave splats, droplets and remains on the ground." }
add { key = "decalFade", category = "Video", label = "Splats Fade After", type = "choice", default = 10,
    options = { { value = 5, label = "5 s" }, { value = 10, label = "10 s" }, { value = 25, label = "25 s" }, { value = 60, label = "60 s" }, { value = 0, label = "Never" } },
    desc = "How long stains and remains stay on the floor before fading away." }
add { key = "brightness", category = "Video", label = "Brightness", type = "slider", default = 100, min = 50, max = 150, step = 5, format = percent,
    desc = "Overall brightness of the game world." }
add { key = "cameraSmoothing", category = "Video", label = "Camera Smoothing", type = "slider", default = 60, min = 0, max = 100, step = 10, format = percent,
    desc = "0% snaps the camera to you, higher values glide." }
add { key = "cameraLookahead", category = "Video", label = "Camera Lookahead", type = "toggle", default = true,
    desc = "Shift the camera slightly towards where you are aiming." }
add { key = "scrollZoom", category = "Video", label = "Scroll Wheel Zoom", type = "toggle", default = true,
    desc = "Zoom the camera in and out with the mouse wheel (or a two-finger pinch on a touch screen)." }
add { key = "weather", category = "Video", label = "Weather", type = "choice", default = "random",
    options = { { value = "random", label = "Random" }, { value = "off", label = "Always Clear" } },
    desc = "Rain, fog, wind and other passing weather. Only changes how the arena looks." }

-- Audio ---------------------------------------------------------------------------------
add { key = "masterVolume", category = "Audio", label = "Master Volume", type = "slider", default = 80, min = 0, max = 100, step = 5, format = percent }
add { key = "musicVolume", category = "Audio", label = "Music Volume", type = "slider", default = 70, min = 0, max = 100, step = 5, format = percent }
add { key = "sfxVolume", category = "Audio", label = "Effects Volume", type = "slider", default = 80, min = 0, max = 100, step = 5, format = percent }
add { key = "uiVolume", category = "Audio", label = "Menu Volume", type = "slider", default = 70, min = 0, max = 100, step = 5, format = percent }
add { key = "muteUnfocused", category = "Audio", label = "Mute When Unfocused", type = "toggle", default = true,
    desc = "Silence the game while its window is in the background." }

-- Gameplay ------------------------------------------------------------------------------
add { key = "difficulty", category = "Gameplay", label = "Difficulty", type = "choice", default = "worker",
    options = {
        { value = "larva", label = "Larva" }, { value = "worker", label = "Worker" },
        { value = "soldier", label = "Soldier" }, { value = "queen", label = "Queen" },
    },
    desc = "Scales enemy health and damage. Larva is relaxed, Queen is brutal." }
add { key = "waveBreak", category = "Gameplay", label = "Next Wave", type = "choice", default = "auto",
    options = { { value = "auto", label = "After 3 s" }, { value = "instant", label = "Right Away" }, { value = "manual", label = "When I Press" } },
    desc = "When the next wave starts after you pick an item. The Next Wave key (N) always starts it at once, and during a wave sends the rest of its ants in early." }
add { key = "waveOverlap", category = "Gameplay", label = "Overlapping Waves", type = "toggle", default = true,
    desc = "When a wave is down to its last few ants, you pick your item and the next wave marches in while they are still about. Off: every ant must die first. (Never with Next Wave set to When I Press.)" }
add { key = "waveModifiers", category = "Gameplay", label = "Wave Modifiers", type = "toggle", default = true,
    desc = "From wave 3, some waves get a twist shown on the banner: Swarm, Armored, Ambush, Shield Wall, Pincer..." }
add { key = "adaptiveWaves", category = "Gameplay", label = "Wave Heat", type = "toggle", default = true,
    desc = "Waves have a par time. Past it the ants speed up and hit harder, and while you stay healthy the packs come quicker and bigger." }
add { key = "speciesOrder", category = "Gameplay", label = "Species Order", type = "choice", default = "random",
    options = { { value = "random", label = "New Each Run" }, { value = "classic", label = "Always the Same" } },
    desc = "The order you meet the colony's species in. New Each Run shuffles it, so bees, wasps and termites can show up early." }
add { key = "eliteFrequency", category = "Gameplay", label = "Elite Ants", type = "choice", default = 1,
    options = { { value = 0, label = "Off" }, { value = 0.5, label = "Rare" }, { value = 1, label = "Normal" }, { value = 2, label = "Lots" } },
    desc = "How often tougher elite ants (Aggressive, Gilded, Armored...) show up. They start appearing from wave 2." }
add { key = "autoAttack", category = "Gameplay", label = "Auto Attack", type = "toggle", default = true,
    desc = "Attack automatically. When off, hold the Attack button." }
add { key = "aimMode", category = "Gameplay", label = "Aim Mode", type = "choice", default = "nearest",
    options = { { value = "nearest", label = "Nearest Enemy" }, { value = "mouse", label = "Mouse" }, { value = "move", label = "Move Direction" } },
    desc = "Where attacks are pointed. A controller's right stick always overrides this." }
add { key = "enemyHealthBars", category = "Gameplay", label = "Enemy Health Bars", type = "choice", default = "damaged",
    options = { { value = "off", label = "Off" }, { value = "elites", label = "Elites & Queens" }, { value = "damaged", label = "When Damaged" }, { value = "always", label = "Always" } },
    desc = "Health bars over enemies. Elites & Queens shows them only on the tough ones; Always also shows full bars." }
add { key = "hitstop", category = "Gameplay", label = "Hit Stop", type = "toggle", default = true,
    desc = "Freeze the action for a split second when you wipe out a crowd. Pure crunch." }
add { key = "slowMotion", category = "Gameplay", label = "Slow Motion", type = "toggle", default = true,
    desc = "A moment of slow motion on huge multi-kills, a queen falling and the frenzy move." }
add { key = "frenzyAuto", category = "Gameplay", label = "Auto Frenzy", type = "toggle", default = false,
    desc = "Unleash the frenzy move by itself as soon as the meter is full (and ants are around). Otherwise press Q." }
add { key = "miniGoals", category = "Gameplay", label = "Mini-Goals", type = "toggle", default = true,
    desc = "Some waves come with an optional side task (catch the courier, guard the aphid...) for bonus XP and frenzy." }
add { key = "routeGates", category = "Gameplay", label = "Route Gates", type = "toggle", default = true,
    desc = "After a wave, walk into one of two tunnels: a safer next wave, or a harder one with a better prize. Needs a break between waves." }
add { key = "damageNumbers", category = "Gameplay", label = "Damage Numbers", type = "choice", default = "crits",
    options = { { value = "off", label = "Off" }, { value = "crits", label = "Crits Only" }, { value = "all", label = "All" } },
    desc = "Numbers that pop off enemies when you hit them." }
add { key = "combineDamageNumbers", category = "Gameplay", label = "Combine Damage Numbers", type = "toggle", default = false,
    desc = "Quick hits on the same enemy add up into one number that keeps counting, instead of a spray of small ones." }
add { key = "showKoCounter", category = "Gameplay", label = "KO Counter", type = "toggle", default = true,
    desc = "Show the running KO count and combo." }
add { key = "tutorialHints", category = "Gameplay", label = "Tutorial Hints", type = "toggle", default = true,
    desc = "Short tips the first time something comes up in a run. Turning it back on shows them all again." }
add { key = "pauseOnFocusLost", category = "Gameplay", label = "Pause When Unfocused", type = "toggle", default = true,
    desc = "Pause when the window loses focus, the app goes to the background, or the controller in use is unplugged." }
add { key = "telegraphs", category = "Gameplay", label = "Attack Warnings", type = "toggle", default = true,
    desc = "Show a warning before enemies charge or lunge." }

-- Interface -----------------------------------------------------------------------------
add { key = "uiFont", category = "Interface", label = "Font", type = "choice", default = "pixel",
    options = { { value = "pixel", label = "Pixel" }, { value = "smooth", label = "Smooth" } },
    desc = "Pixel matches the game's art. Smooth is easier to read at small sizes." }
add { key = "uiScale", category = "Interface", label = "Interface Scale", type = "slider", default = 100, min = 75, max = 150, step = 5, format = percent }
add { key = "hudOpacity", category = "Interface", label = "HUD Opacity", type = "slider", default = 100, min = 30, max = 100, step = 10, format = percent }
add { key = "showTimer", category = "Interface", label = "Show Run Timer", type = "toggle", default = true }
add { key = "showEnemyCount", category = "Interface", label = "Enemies Left", type = "toggle", default = true,
    desc = "A counter under the KO count with how many enemies are still to beat this wave, and a bar of how much of it is done." }
add { key = "nextWavePreview", category = "Interface", label = "Next Wave Preview", type = "toggle", default = true,
    desc = "During the break, show what the next wave brings: a queen, a new species, wave modifiers." }
add { key = "speciesPopups", category = "Interface", label = "First Sighting Popups", type = "choice", default = "new",
    options = { { value = "new", label = "First Time Ever" }, { value = "run", label = "Every Run" }, { value = "off", label = "Off" } },
    desc = "A card with a species' name and what it does the first time it shows up (species introduced by a wave already get the big card)." }
add { key = "offscreenMarkers", category = "Interface", label = "Off-screen Markers", type = "toggle", default = true,
    desc = "Arrows at the screen edge pointing at queens and elites you cannot see." }
add { key = "showFps", category = "Interface", label = "Show FPS", type = "toggle", default = false }
add { key = "cursorStyle", category = "Interface", label = "Cursor", type = "choice", default = "crosshair",
    options = { { value = "crosshair", label = "Crosshair" }, { value = "system", label = "System" }, { value = "hidden", label = "Hidden In Game" } } }

-- Accessibility -------------------------------------------------------------------------
add { key = "reduceFlashing", category = "Accessibility", label = "Reduce Flashing", type = "toggle", default = false,
    desc = "Disables white hit flashes and bright screen effects." }
add { key = "colorblindMode", category = "Accessibility", label = "Colour Filter", type = "choice", default = "off",
    options = {
        { value = "off", label = "Off" }, { value = "protanopia", label = "Protanopia" },
        { value = "deuteranopia", label = "Deuteranopia" }, { value = "tritanopia", label = "Tritanopia" },
    },
    desc = "Shifts game colours to be easier to tell apart." }
add { key = "safePalette", category = "Accessibility", label = "Colourblind-Safe Colours", type = "toggle", default = false,
    desc = "Elites and hazards use a palette that stays distinct with any colour vision (Okabe-Ito): harmful ground is orange, slowing ground blue, healing ground yellow." }
add { key = "telegraphContrast", category = "Accessibility", label = "High-Contrast Warnings", type = "toggle", default = false,
    desc = "Mounds, nest holes, drop shadows, landing rings and attack warnings get a dark outline and bright, thicker rings so they stand out on any ground." }
add { key = "playerOutline", category = "Accessibility", label = "Highlight Player", type = "toggle", default = false,
    desc = "Draw a ring under your bug so you never lose it in a swarm." }
add { key = "gameSpeed", category = "Accessibility", label = "Game Speed", type = "slider", default = 100, min = 50, max = 150, step = 5, format = percent,
    desc = "Below 100% slows the whole game down for more reaction time, above speeds everything up." }

-- Controls ------------------------------------------------------------------------------
add { key = "deadzone", category = "Controls", label = "Stick Deadzone", type = "slider", default = 20, min = 5, max = 50, step = 5, format = percent }
add { key = "vibration", category = "Controls", label = "Controller Vibration", type = "toggle", default = true }
add { key = "touchControls", category = "Controls", label = "Touch Controls", type = "choice", default = "auto",
    options = { { value = "auto", label = "Auto" }, { value = "on", label = "Always" }, { value = "off", label = "Off" } },
    desc = "On-screen stick and buttons. Auto shows them once you touch the screen. Always also lets the mouse press them, for testing on a PC." }
add { key = "touchLayout", category = "Controls", label = "Touch Layout", type = "choice", default = "right",
    options = { { value = "right", label = "Right Handed" }, { value = "left", label = "Left Handed" } },
    desc = "Right Handed: move with the left thumb, buttons on the right. Left Handed swaps the sides." }
add { key = "touchSize", category = "Controls", label = "Touch Button Size", type = "slider", default = 100, min = 60, max = 160, step = 10, format = percent,
    desc = "How big the on-screen stick and buttons are." }
add { key = "touchOpacity", category = "Controls", label = "Touch Button Opacity", type = "slider", default = 70, min = 20, max = 100, step = 10, format = percent }
add { key = "touchStick", category = "Controls", label = "Touch Stick", type = "choice", default = "floating",
    options = { { value = "floating", label = "Floating" }, { value = "fixed", label = "Fixed" } },
    desc = "Floating: the stick appears wherever your thumb lands on the left half. Fixed: it stays in the corner." }
add { key = "touchAimSpecial", category = "Controls", label = "Touch Special Aim", type = "choice", default = "drag",
    options = { { value = "drag", label = "Drag To Aim" }, { value = "tap", label = "Tap (Auto Aim)" } },
    desc = "Drag To Aim: drag off the Special button to aim and let go to fire, or just tap it to fire at the nearest ant. Tap fires the moment you press." }
-- Key binding rows are added to this tab automatically from src/core/input.lua.

-- Developer -----------------------------------------------------------------------------
add { key = "devMode", category = "Developer", label = "Developer Mode", type = "toggle", default = true,
    desc = "Enables the sandbox, console (`), overlay (F3) and debug hotkeys (F1 lists them)." }
add { key = "showHitboxes", category = "Developer", label = "Show Hitboxes", type = "toggle", default = false }
add { key = "showSpatialGrid", category = "Developer", label = "Show Spatial Grid", type = "toggle", default = false }
add { key = "showOverlay", category = "Developer", label = "Performance Overlay", type = "toggle", default = false }

return S
