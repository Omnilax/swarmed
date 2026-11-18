-- Gentle Start (src/game/onramp.lua) and the Playtest Log (src/game/playlog.lua).
--   love . --selftest --gentle
-- A first run holds back elites, the shop, events, gambles, routes and visitors until their
-- wave; a third run lets routes in; a system met once is never held back again; each first
-- meeting queues one "NEW" card; the setting, practice and the daily run skip it all; veterans
-- skip it; the playtest log writes a header and one line per wave.
local State = require("src.core.state")
local Settings = require("src.core.settings")

return function(wait, shot)
    local OnRamp = require("src.game.onramp")
    local Tutorial = require("src.game.tutorial")
    local Records = require("src.game.records")
    local Cfg = require("src.config.onramp")
    local savedOff, savedTOff, savedSeen = OnRamp.off, Tutorial.off, Tutorial.seen
    local profile = Records.get()
    local savedRuns = profile.runs
    OnRamp.off, Tutorial.off = false, false
    Tutorial.seen = {}
    Settings.set("gentleStart", true)
    Settings.set("tutorialHints", true)
    Tutorial.seen = {}       -- the setting's change handler may have rewritten it

    local Game = require("src.states.game")
    local function newRun(runsBefore, opts)
        profile.runs = runsBefore
        local g = State.switch(Game.new(opts or { mode = "run", character = "rhino_beetle" }))
        wait(0.2)
        return g.world
    end

    -- the very first run
    local world = newRun(0)
    assert(OnRamp.active(world), "Gentle Start should run a new player's first run")
    assert(OnRamp.runNumber(world) == 1, "first run should be run 1 (" .. OnRamp.runNumber(world) .. ")")
    for id, rule in pairs(Cfg.systems) do
        if rule.run > 1 then
            assert(not OnRamp.allows(world, id, 15), id .. " should wait for run " .. rule.run)
        else
            assert(not OnRamp.allows(world, id, rule.wave - 1), id .. " should wait for wave " .. rule.wave)
            assert(OnRamp.allows(world, id, rule.wave), id .. " should be allowed on wave " .. rule.wave)
        end
    end
    -- the systems themselves listen
    local sp = world.spawner
    sp.wave = 1
    assert(world.director:eventCount(9) == 0, "no mid-wave events in run 1")
    assert(sp:eliteMode().chance == 0, "no elites on wave 1 of run 1")
    assert(#require("src.game.pacing").modifiersFor(sp, 9) == 0, "no wave modifiers in run 1")
    assert(not require("src.game.economy").open(world), "the shop waits for wave 3")
    sp.wave = 3
    assert(require("src.game.economy").open(world), "the shop opens on wave 3")

    -- the first sighting of a system: one NEW card, and remembered
    Tutorial.queue = {}
    world.events:emit("elite_spawned", {})
    assert(OnRamp.seen("elites"), "an elite sighting should be remembered")
    assert(#Tutorial.queue == 1 and Tutorial.queue[1].tag == "NEW", "one NEW card should be queued")
    world.events:emit("elite_spawned", {})
    assert(#Tutorial.queue == 1, "the card shows only once")
    sp.wave = 1
    assert((sp:eliteMode() or {}).chance ~= 0, "elites met once are never held back again")
    -- the card is drawn
    world.player.x, world.player.y = world.size / 2, world.size / 2
    wait(2.5)
    assert(Tutorial.current and Tutorial.current.tag == "NEW", "the NEW card should be on screen")
    shot("gentle_card")

    -- run 3: routes and visitors may come
    world = newRun(2)
    assert(OnRamp.runNumber(world) == 3, "third run")
    assert(OnRamp.allows(world, "routes", 3) and not OnRamp.allows(world, "routes", 2), "routes from wave 3 of run 3")
    assert(OnRamp.calm(world), "run 3 is still calm")
    assert(world.director:eventCount(6) <= 1, "calm runs have at most one event a wave")

    -- the setting off, practice and the daily run: nothing held back
    Settings.set("gentleStart", false)
    world = newRun(0)
    assert(not OnRamp.active(world) and OnRamp.allows(world, "routes", 1), "Gentle Start off holds nothing back")
    Settings.set("gentleStart", true)
    world = newRun(0, { mode = "run", character = "rhino_beetle", practice = { wave = 1 } })
    assert(not OnRamp.active(world), "practice is never held back")
    world = newRun(0, { mode = "run", character = "rhino_beetle", daily = "2026-11-18", seed = 20261118 })
    assert(not OnRamp.active(world), "the daily run is never held back")

    -- veterans: everything counts as met
    Tutorial.seen = {}
    world = newRun(Cfg.veteranRuns)
    for id in pairs(Cfg.systems) do assert(OnRamp.seen(id), "a veteran save should have met " .. id) end

    -- the playtest log
    local PlayLog = require("src.game.playlog")
    love.filesystem.remove(PlayLog.FILE)
    Settings.set("playtestLog", true)
    world.spawner.wave = 2
    world.events:emit("wave_started", 2)
    world.events:emit("player_hurt", { damage = 7 })
    world.events:emit("wave_cleared", 2)
    local text = love.filesystem.read(PlayLog.FILE) or ""
    local lines = {}
    for l in text:gmatch("[^\n]+") do lines[#lines + 1] = l end
    assert(#lines == 2 and lines[1]:find("^date,run,bug"), "playtest log should have a header and one line")
    assert(lines[2]:find(",2,cleared,") and lines[2]:find("rhino_beetle"), "log line should name wave, event and bug: " .. lines[2])
    Settings.set("playtestLog", false)
    love.filesystem.remove(PlayLog.FILE)

    profile.runs = savedRuns
    OnRamp.off, Tutorial.off, Tutorial.seen = savedOff, savedTOff, savedSeen
    print("[selftest] gentle start ok")
end
