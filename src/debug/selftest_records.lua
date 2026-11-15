-- Records: kills per species, run history, achievements unlocking, the save round trip and the
-- Records screen (every tab). Never writes the real save (Records.noSave under --selftest).
--   love . --selftest --records   runs just this part (also part of the full selftest)
local State = require("src.core.state")
local Content = require("src.content")
local Records = require("src.game.records")
local util = require("src.core.util")

return function(wait, shot)
    local saved = Records.profile
    Records.noSave = true
    Records.reset()
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "run", character = "rhino_beetle" }))
    wait(0.2)
    local world = game.world
    local run = Records.run
    assert(run and run.world == world, "run not tracked")
    assert(Records.get().runs == 1, "run not counted")
    world.spawner.enabled = false
    world:clearEnemies()
    -- kills: plain ants, an elite and a queen
    local pl = world.player
    for _ = 1, 120 do world:killEnemy(world:spawnEnemy("worker_ant", pl.x + 80, pl.y)) end
    local elite = Content.elites:all()[1]
    world:killEnemy(world:spawnEnemy("worker_ant", pl.x + 80, pl.y, elite))
    local queen = Content.enemies:filter(function(d) return d.boss end)[1]
    world:killEnemy(world:spawnEnemy(queen.id, pl.x + 80, pl.y))
    for _ = 1, 3 do world:update(1 / 60) end
    local p = Records.get()
    assert(p.kills == 122, "lifetime kills " .. p.kills)
    assert(run.killsBy.worker_ant == 121, "per species kills")
    assert(p.killsByFamily.ant >= 121 and p.elites == 1 and p.queens == 1, "family / elite / queen counts")
    assert(p.elitesBy[elite.id] == 1, "elite affix count")
    -- waves, a flawless clear, items
    world.events:emit("wave_started", 3)
    world.events:emit("wave_cleared", 3)
    assert(p.bestWave == 3 and p.flawlessWaves == 1, "wave records")
    world.events:emit("item_eaten", {})
    assert(p.itemsEaten == 1, "eaten count")
    Records.update(1)
    for _, id in ipairs({ "kills_100", "elites_1", "queens_1", "flawless", "eat_1" }) do
        assert(Records.unlocked(id), "achievement " .. id .. " did not unlock")
    end
    assert(not Records.unlocked("kills_1000"), "kills_1000 unlocked too early")
    assert(#Records.toasts > 0, "no unlock card")
    wait(0.6)
    shot("records_toast")
    -- winning, then falling
    world.events:emit("run_won", 15)
    assert(p.wins == 1 and p.characters.rhino_beetle.wins == 1 and Records.unlocked("win"), "win not recorded")
    if Content.skins and Content.skins:get("gilded") then
        assert(require("src.game.cosmetics").data.unlocked.gilded, "winning did not unlock the gilded skin")
    end
    world.flags.god = false
    pl:hurt(99999)
    assert(run.ended and run.outcome == "died", "death did not end the run")
    assert(#p.history == 1 and p.history[1].won and p.history[1].kills == 122, "history line")
    -- the save round trip
    local back = assert(loadstring("return " .. util.serialize(p)))()
    assert(back.kills == p.kills and back.killsBy.worker_ant == 121 and back.history[1].character == "rhino_beetle", "save round trip")
    -- a quit run is recorded too, a second run counts
    game = State.switch(Game.new({ mode = "run", character = Content.characters:all()[2].id, gameMode = "larvae" }))
    wait(6)
    State.switch(require("src.states.menu").new())
    assert(p.runs == 2 and #p.history == 2 and p.history[1].outcome == "quit" and p.history[1].mode == "larvae", "quit run")
    -- sandbox runs are not tracked
    State.switch(Game.new({ mode = "sandbox", character = "rhino_beetle" }))
    wait(0.1)
    assert(p.runs == 2, "sandbox counted as a run")
    -- every achievement's progress check runs without error, with and without a run
    for _, a in ipairs(Content.achievements:all()) do
        local ok, err = pcall(a.value, p, nil)
        assert(ok, "achievement " .. a.id .. ": " .. tostring(err))
        local v, goal = Records.progress(a, p)
        assert(type(v) == "number" and type(goal) == "number" and goal >= 1, a.id .. " progress")
    end
    -- the Records screen, every tab, scrolled to the end
    State.switch(require("src.states.menu").new())
    local scr = State.push(require("src.states.records").new())
    for tab = 1, 5 do
        scr:setTab(tab)
        wait(0.1)
        local focus = { 1, 2, 3, 2, 6 }
        scr.menu.focus = math.min(#scr.menu.items, focus[tab])
        scr.menu:fixFocus(1)
        wait(0.2)
        shot("records_tab" .. tab)
        for i = 1, #scr.menu.items do
            scr.menu.focus = i
            scr.menu:fixFocus(1)
            scr:draw()
        end
        scr.menu:wheelmoved(0, -100)
        scr:draw()
    end
    State.pop()
    print(("[selftest] records OK (%d achievements, %d unlocked in the test)"):format(Content.achievements:count(),
        (function() local n = 0 for _ in pairs(p.achievements) do n = n + 1 end return n end)()))
    Records.profile = saved or Records.load()
end
