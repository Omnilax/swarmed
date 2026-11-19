-- Music, event sounds, first-run hints and off-screen markers (src/core/music.lua,
-- src/game/feedback.lua, src/game/tutorial.lua).
--   love . --selftest --polish   runs just this part (also part of the full selftest)
local State = require("src.core.state")
local Content = require("src.content")
local Settings = require("src.core.settings")
local Audio = require("src.core.audio")
local Music = require("src.core.music")
local Feedback = require("src.game.feedback")
local Tutorial = require("src.game.tutorial")

local function rms(sd)
    local n, sum = sd:getSampleCount(), 0
    for i = 0, n - 1, 37 do local v = sd:getSample(i) sum = sum + v * v end
    return math.sqrt(sum / (n / 37))
end

return function(wait, shot)
    -- music: every stem renders, is the same length, is not silent, and gets cached
    local t0 = love.timer.getTime()
    Music.finish()
    print(("polish: music ready in %.2f s (loop %.1f s)"):format(love.timer.getTime() - t0, Music.length))
    assert(Music.ready, "music not ready")
    local len
    for name, sd in pairs(Music.data) do
        len = len or sd:getSampleCount()
        assert(sd:getSampleCount() == len, "stem " .. name .. " length differs")
        local r = rms(sd)
        assert(r > 0.02, "stem " .. name .. " is silent (" .. r .. ")")
        assert(love.filesystem.getInfo("music/v1_" .. name .. ".wav"), "stem " .. name .. " not cached")
    end
    local ok, sd = pcall(love.sound.newSoundData, "music/v1_drums.wav")
    assert(ok and sd:getSampleCount() == len, "cached wav does not load back")
    wait(0.2)
    assert(Music.playing, "music not playing")

    -- every bug's signature stem renders, loops with the rest and is not silent
    t0 = love.timer.getTime()
    for _, theme in ipairs(Music.THEMES) do
        Music.setCharacter({ music = theme })
        Music.finish()
        local d = Music.data[theme]
        assert(d and d:getSampleCount() == len, "signature stem " .. theme .. " missing or wrong length")
        assert(rms(d) > 0.02, "signature stem " .. theme .. " is silent")
        assert(Music.stems[theme], "signature stem " .. theme .. " has no source")
    end
    print(("polish: %d signature stems in %.2f s"):format(#Music.THEMES, love.timer.getTime() - t0))
    -- every body plan's band (drums, arp, lead) renders too, and every bug has its own riff
    t0 = love.timer.getTime()
    for _, theme in ipairs(Music.THEMES) do
        for _, part in ipairs(Music.BAND_PARTS) do
            local name = part .. "_" .. theme
            local d = Music.data[name]
            assert(d and d:getSampleCount() == len, "band stem " .. name .. " missing or wrong length")
            assert(rms(d) > 0.02, "band stem " .. name .. " is silent")
        end
    end
    local riffs = {}
    for _, def in ipairs(Content.characters.list) do
        Music.setCharacter(def)
        Music.finish()
        local d = Music.data["motif_" .. def.id]
        assert(d and rms(d) > 0.01, "no riff for " .. def.id)
        -- a fingerprint of the riff: where its notes start
        local f = {}
        for i = 0, len - 1, math.floor(len / 64) do f[#f + 1] = math.abs(d:getSample(i)) > 0.05 and "x" or "." end
        riffs[def.id] = table.concat(f)
    end
    local same = 0
    for a, fa in pairs(riffs) do for b, fb in pairs(riffs) do if a < b and fa == fb then same = same + 1 end end end
    -- MUSIC_PREVIEW=1: write music_bands_preview.wav (one wave loop per body plan) to the save folder
    if os.getenv("MUSIC_PREVIEW") then
        local MIXW = { pad = 0.5, bass = 0.9, arp = 0.45, lead = 0.5, drums = 0.85 }
        local picks = { "rhino_beetle", "tarantula", "lobster", "millipede", "dragonfly", "mantis" }
        local total = len * #picks
        local out = love.sound.newSoundData(total, 22050, 16, 1)
        for k, id in ipairs(picks) do
            local def = Content.characters:get(id)
            local theme = Music.themeFor(def)
            local parts = { { Music.data.pad, MIXW.pad }, { Music.data.bass, MIXW.bass },
                { Music.data["arp_" .. theme], MIXW.arp }, { Music.data["lead_" .. theme], MIXW.lead },
                { Music.data["drums_" .. theme], MIXW.drums }, { Music.data[theme], 0.6 },
                { Music.data["motif_" .. id], 0.6 } }
            for i = 0, len - 1 do
                local v = 0
                for _, pt in ipairs(parts) do if pt[1] then v = v + pt[1]:getSample(i) * pt[2] end end
                out:setSample((k - 1) * len + i, math.max(-1, math.min(1, v * 0.32)))
            end
        end
        local raw = out:getString()
        local function u16(n) return string.char(n % 256, math.floor(n / 256) % 256) end
        local function u32(n) return u16(n % 65536) .. u16(math.floor(n / 65536)) end
        love.filesystem.write("music_bands_preview.wav", "RIFF" .. u32(36 + #raw) .. "WAVEfmt " .. u32(16) .. u16(1) .. u16(1)
            .. u32(22050) .. u32(44100) .. u16(2) .. u16(16) .. "data" .. u32(#raw) .. raw)
        print("polish: wrote music_bands_preview.wav (" .. table.concat(picks, ", ") .. ")")
    end
    print(("polish: %d band stems + %d riffs in %.2f s (%d riff pairs alike)"):format(#Music.THEMES * 3,
        #Content.characters.list, love.timer.getTime() - t0, same))
    -- tags pick the stem, size and speed pick the key
    local function th(id) return Music.themeFor(Content.characters:get(id)) end
    local t1, k1 = th("lobster")
    local t2, k2 = th("dragonfly")
    assert(t1 == "bubble" and t2 == "flute" and th("tarantula") == "creep" and th("millipede") == "rattle"
        and th("mantis") == "kalimba", "wrong signature themes")
    assert(k1 < 0 and k2 > 0, "big slow bugs should play lower, small fast ones higher")

    -- every event sound exists and plays
    for _, name in ipairs({ "swing", "special", "wave_start", "wave_clear", "queen", "victory", "defeat", "heartbeat", "hint" }) do
        assert(Audio.sounds[name], "missing sound " .. name)
        Audio.sounds[name].last = -1
        Audio.play(name)
    end

    -- a run: feedback hooks the world, music follows the fight
    Settings.set("tutorialHints", true)
    Tutorial.seen = {}
    local wasOff = Tutorial.off
    Tutorial.off = false
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "run", character = "rhino_beetle" }))
    wait(1.5)
    local world = game.world
    assert(Feedback.world == world, "feedback did not attach to the run")
    assert(Tutorial.current and Tutorial.current.hint.id == "move", "move hint not shown")
    shot("polish_hint")
    assert(Music.mood == "break" or Music.mood == "wave", "mood at start: " .. Music.mood)
    assert(Music.theme == "chug", "rhino beetle should get the beetle chug: " .. tostring(Music.theme))

    world.spawner.enabled = false
    world:clearEnemies()
    local pl = world.player
    for i = 1, 40 do world:spawnEnemy("worker_ant", pl.x + 120 + i, pl.y + 60) end
    wait(0.3)
    assert(Music.mood == "wave" or Music.mood == "swarm", "mood with ants: " .. Music.mood)
    assert(Music.gains.chug > 0.1, "signature stem not mixed in during a wave")
    -- the beetles' band plays the drums, not the shared kit
    assert((Music.gains.drums_chug or 0) > 0.3 and Music.gains.drums < 0.1, "beetle band not playing the drums")
    assert((Music.gains.motif_rhino_beetle or 0) > 0.1, "rhino beetle riff not playing")
    world.combo = 80
    wait(1)
    assert(Music.frenzy > 0.9 and Music.gains.frenzy > 0.3, "big combo did not bring the frenzy layer in")
    world.combo = 0

    -- a queen far away: boss music, and an arrow points at her
    local queen = Content.enemies:filter(function(d) return d.boss end)[1]
    world:spawnEnemy(queen.id, pl.x + 900, pl.y - 900)
    local elite = Content.elites:all()[1]
    world:spawnEnemy("worker_ant", pl.x - 900, pl.y + 700, elite)
    wait(0.3)
    assert(Music.mood == "boss", "mood with a queen: " .. Music.mood)
    assert(Feedback.boss == world.boss, "queen arrival not noticed")
    shot("polish_markers")

    -- pausing ducks the music
    State.push(require("src.states.pause").new(game))
    wait(0.2)
    assert(Music.duck < 1, "music not ducked under pause")
    State.pop()

    -- low health: heartbeat; then death: everything but the pad fades, the pitch sinks
    world.flags.god = false
    pl.hp = pl.stats:get("maxHp") * 0.1
    Audio.sounds.heartbeat.last = -1
    wait(0.2)
    assert(Feedback.beatT > 0, "no heartbeat at low health")
    wait(1.2)
    assert(Music.danger > 0.9 and Music.gains.danger > 0.3, "low health did not bring the danger layer in")
    pl:hurt(9999, {})
    wait(2.5)
    assert(Music.mood == "dead", "mood after death: " .. Music.mood)
    assert(Music.pitch < 0.95, "pitch did not sink")
    assert(Music.gains.drums < 0.3, "drums still loud after death")

    Tutorial.off = wasOff
    State.switch(require("src.states.menu").new())
    wait(0.3)
    assert(Music.current == "menu", "menus did not get menu music: " .. tostring(Music.current))
    print("polish: ok")
end
