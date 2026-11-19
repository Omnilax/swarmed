-- Music and sound touches (Audio tab). Each has its own setting:
--   Music Follows Day: the score's night colours (softer drums, a swelling pad) follow the time of
--     day; off keeps the daytime mix all run.
--   Positional Sound: kills and hits pan left / right by where they are on screen and get quieter
--     further away.
--   Ambient Sounds (volume): birds by day and crickets at night on the leafy maps, dry wind in the
--     desert, drips after rain; they hush while the fight is loud.
--   Musical Stingers: wave clears and kill streaks play short notes in the score's key (D minor)
--     instead of the fixed sounds.
local Settings = require("src.core.settings")
local Audio = require("src.core.audio")

local Soundscape = {}

local function hz(m) return 440 * 2 ^ ((m - 69) / 12) end

local made = false
local function make()
    if made then return end
    made = true
    -- stingers in D minor, the score's key (src/core/music.lua CHORDS)
    Audio.addSynth("sting_clear", { wave = "triangle", notes = { hz(62), hz(65), hz(69), hz(74) }, duration = 0.6, volume = 0.45, decay = 1.2, pitchVar = 0 })
    Audio.addSynth("sting_streak", { wave = "triangle", notes = { hz(69), hz(74) }, duration = 0.25, volume = 0.35, decay = 1.5, pitchVar = 0 })
    -- ambience
    Audio.addSynth("amb_bird", { wave = "sine", notes = { 2600, 3100, 2800, 3400 }, duration = 0.32, volume = 0.18, decay = 1, vibrato = { 30, 0.04 }, pitchVar = 0.25 })
    Audio.addSynth("amb_cricket", { wave = "square", freq = 4200, duration = 0.12, volume = 0.08, decay = 0.5, vibrato = { 60, 0.5 }, pitchVar = 0.05 })
    Audio.addSynth("amb_wind", { wave = "noise", freq = 200, duration = 1.6, volume = 0.12, attack = 0.6, decay = 2, pitchVar = 0.2 })
    Audio.addSynth("amb_surf", { wave = "noise", freq = 320, duration = 2.4, volume = 0.13, attack = 1.0, decay = 1.6, pitchVar = 0.15 })
    Audio.addSynth("amb_drip", { wave = "sine", freq = 1400, to = 700, duration = 0.08, volume = 0.18, decay = 3, pitchVar = 0.3 })
end

local DESERT = { dune_field = true, sandstone_wash = true }

-- Every frame of a run (src/game/feedback.lua).
function Soundscape.update(world, dt)
    make()
    -- the listener for Positional Sound: the view's centre, in projected pixels
    local cam = world.camera
    Audio.listener = cam and { x = cam.x, y = cam.y, w = require("src.core.screen").viewW or 640 } or nil
    local vol = Settings.get("ambientVolume") / 100
    if vol <= 0 or world.flags.demo then return end
    if world.enemyCount > 60 or (world.attackers or 0) > 2 then return end      -- hush in a big fight
    Soundscape.t = (Soundscape.t or 2) - dt
    if Soundscape.t > 0 then return end
    local day = world:daylight()
    local id = world.stage.id
    local w = world.weather
    local wid = w.def and w.def.id
    local pick
    if world.stage.shore and love.math.random() < 0.6 then pick = "amb_surf"
    elseif (world.wetness or 0) > 0.3 and love.math.random() < 0.5 then pick = "amb_drip"
    elseif DESERT[id] or wid == "windy" or wid == "dust" then pick = "amb_wind"
    elseif day < 0.4 then pick = "amb_cricket"
    else pick = "amb_bird" end
    Soundscape.t = pick == "amb_cricket" and (0.25 + love.math.random() * 0.6) or (2 + love.math.random() * 4)
    Audio.play(pick, { volume = vol, pan = (love.math.random() - 0.5) * 1.6 })
end

-- Wave clear / kill streak: true when a stinger played instead of the usual sound.
function Soundscape.sting(kind)
    if not Settings.get("musicalStingers") then return false end
    make()
    Audio.play(kind == "streak" and "sting_streak" or "sting_clear")
    return true
end

return Soundscape
