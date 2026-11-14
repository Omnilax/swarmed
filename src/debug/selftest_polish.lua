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

    world.spawner.enabled = false
    world:clearEnemies()
    local pl = world.player
    for i = 1, 40 do world:spawnEnemy("worker_ant", pl.x + 120 + i, pl.y + 60) end
    wait(0.3)
    assert(Music.mood == "wave" or Music.mood == "swarm", "mood with ants: " .. Music.mood)

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
