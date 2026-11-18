-- Checks for Custom Waves and the scripted / new modes:  love . --selftest --customwaves
--   * wave sets: cleaning, text round trip, pasted text that tries to run code is refused
--   * the wave builder: mode select -> builder -> set -> wave pages, add / duplicate / delete,
--     Play -> bug select for the Custom Waves mode (stills of each page)
--   * a custom run: exact counts per wave, only the species named, the wave's modifiers, events
--     and encounter, its queen, the run won after the last wave (counted for the mode only)
--   * the run save carries the set; Gauntlet follows its script; Royal Court has a queen every wave
local State = require("src.core.state")
local Content = require("src.content")
local Settings = require("src.core.settings")
local Rules = require("src.game.rules")
local CustomWaves = require("src.game.customwaves")
local util = require("src.core.util")

return function(wait, shot)
    local Game = require("src.states.game")
    CustomWaves.noSave = true
    CustomWaves.data = nil
    local saved = {}
    for k, v in pairs({ waveOverlap = false, waveBreak = "auto", midWaveEvents = "normal", bossEncounters = true }) do
        if Rules.byKey[k] then saved[k] = { Rules.test[k] } Rules.set(k, v)
        else saved[k] = { Settings.get(k) } Settings.set(k, v) end
    end

    -- sets: cleaning and text
    local set = { name = "Test Set", enemyHp = 1, enemyDamage = 1, hpPerWave = 0, elites = "none", waves = {
        { groups = { { "worker_ant", 25 } } },
        { groups = { { "fire_ant", 12 }, { "not_a_bug", 50 } }, mods = { "armored", "nope" }, events = { "acorns" } },
        { groups = { { "soldier_ant", 6 } }, queen = "queen_fire", encounter = "sparrow" },
    } }
    local clean = CustomWaves.clean(set)
    assert(#clean.waves == 3, "clean dropped a wave")
    assert(#clean.waves[2].groups == 1 and #clean.waves[2].mods == 1, "clean kept an unknown species or modifier")
    local text = CustomWaves.toText(set)
    local back = assert(CustomWaves.fromText(text), "a copied set didn't paste back")
    assert(back.name == "Test Set" and #back.waves == 3 and back.waves[3].queen == "queen_fire", "pasted set changed")
    assert(not CustomWaves.fromText("return os.exit()"), "pasted text could call os.exit")
    assert(not CustomWaves.fromText("while true do end"), "pasted text could hang the game")
    assert(not CustomWaves.fromText("hello there"), "pasted nonsense was accepted")
    assert(not CustomWaves.fromText("return { waves = {} }"), "an empty set was accepted")
    print("[selftest] customwaves: sets and text OK")

    -- run rules: game-changing switches live in a set, never in Settings (src/game/rules.lua)
    for _, r in ipairs(Rules.LIST) do
        assert(not Settings.byKey[r.key], "run rule " .. r.key .. " is still a global setting")
    end
    local ruled = util.deepcopy(set)
    ruled.rules = { mapGambles = "off", parasites = false, levelUps = "nah", bogus = 1, dashTech = true }
    local rc = CustomWaves.clean(ruled)
    assert(rc.rules and rc.rules.mapGambles == "off" and rc.rules.parasites == false, "clean dropped the set's rules")
    assert(rc.rules.levelUps == nil and rc.rules.bogus == nil and rc.rules.dashTech == nil, "clean kept a bad or default rule")
    local rb = assert(CustomWaves.fromText(CustomWaves.toText(ruled)), "a set with rules didn't paste back")
    assert(rb.rules and rb.rules.mapGambles == "off", "pasting lost the set's rules")
    local m = CustomWaves.modeDef(Content.modes:get("custom"), ruled)
    assert(m.parasites == false and m.rules.mapGambles == "off", "the set's rules didn't reach its mode")
    local before = Rules.current
    Rules.begin(m.rules)
    assert(Rules.get("mapGambles") == "off" and Rules.get("parasites") == false, "the run doesn't use the set's rules")
    Rules.begin(nil)
    assert(Rules.get("mapGambles") == "normal" and Rules.get("difficulty") == "worker", "the main game doesn't use the default rules")
    -- a set's own item pool
    ruled.itemsOff = { honeydew = true, not_an_item = true }
    local ri = CustomWaves.clean(ruled)
    assert(ri.itemsOff and ri.itemsOff.honeydew and not ri.itemsOff.not_an_item, "clean mangled the set's item pool")
    local Unlocks = require("src.game.unlocks")
    local wasFree = Unlocks.free
    Unlocks.free = false
    Rules.begin(CustomWaves.modeDef(Content.modes:get("custom"), ruled).rules)
    assert(not Unlocks.inPool("honeydew"), "the set's switched-off item is still in the pool")
    Rules.begin(nil)
    assert(Unlocks.inPool("honeydew"), "the main game lost an item from its pool")
    Unlocks.free = wasFree
    Rules.begin(before)
    print("[selftest] customwaves: run rules OK")

    -- the builder screens
    local ms = State.push(require("src.states.modeselect").new())
    for i, it in ipairs(ms.menu.items) do if it.mode and it.mode.id == "custom" then ms.menu.focus = i end end
    wait(0.2)
    shot("custom_modeselect")
    ms.menu:focused().onActivate()
    local wb = State.top()
    assert(wb.page == "sets", "Custom Waves did not open the wave builder")
    wait(0.2)
    shot("custom_sets")
    local function press(label)
        for i, it in ipairs(wb.menu.items) do
            if it.label == label then
                assert(not it.disabled, label .. " is disabled")
                wb.menu.focus = i
                it.onActivate()
                return it
            end
        end
        error("no '" .. label .. "' row on the " .. wb.page .. " page")
    end
    press("New Set")
    assert(wb.page == "set" and #wb.data.sets == 2, "New Set did not open a new set")
    press("Add Wave")
    assert(wb.page == "wave" and #wb:set().waves == 2, "Add Wave did not add a wave")
    press("Add Group")
    local w = wb:wave()
    assert(#w.groups == 2, "Add Group did not add a group")
    w.groups[2] = { "fire_ant", 15 }
    w.queen = "queen_fire"
    wb:toggleIn(w, "mods", "swarm", true, 3)
    wb:toggleIn(w, "events", "acorns", true, 4)
    w.encounter = "anteater"
    wb:build(2)
    wait(0.2)
    shot("custom_wave")
    press("Duplicate Wave")
    assert(#wb:set().waves == 3 and wb.wi == 3, "Duplicate Wave")
    press("Delete Wave")
    press("Delete Wave")          -- (twice: the first press asks)
    assert(#wb:set().waves == 2 and wb.page == "set", "Delete Wave")
    wait(0.2)
    shot("custom_set")
    -- renaming by typing
    press("Rename")
    assert(wb.typing, "Rename did not start typing")
    for _ = 1, 20 do wb:keypressed("backspace") end
    wb:textinput("Sky Raid")
    wb:keypressed("return")
    assert(wb:set().name == "Sky Raid", "rename gave '" .. wb:set().name .. "'")
    press("Play This Set")
    local cs = State.top()
    assert(cs.gameMode == "custom", "Play did not open the bug select for Custom Waves")
    assert(CustomWaves.active().name == "Sky Raid", "Play did not pick the set")
    State.pop()
    State.pop()
    State.pop()
    print("[selftest] customwaves: builder OK")

    -- a custom run, played fast: the player can't die, the field is swept now and then
    local function play(params, seconds, check, until_)
        local game = State.switch(Game.new(params))
        local world = game.world
        world.flags.god = true
        local spawn = world.spawnEnemy
        world.spawnEnemy = function(wd, def, x, y, elite)
            local e = spawn(wd, def, x, y, elite)
            if e and check then check(world, e) end
            return e
        end
        local sweep = 0
        for f = 1, seconds * 30 do
            world:update(1 / 30)
            world.player.hp = world.player.stats:get("maxHp")
            sweep = sweep + 1 / 30
            if sweep > 2 and world.spawner.waveTime > 4 then
                sweep = 0
                for i = world.enemyCount, 1, -1 do
                    local e = world.enemies[i]
                    if e and not e.dead then world:killEnemy(e) end
                end
            end
            if world.pendingChoice then world.pendingChoice = nil end
            if until_ and until_(world) then break end
            if f % 300 == 0 then coroutine.yield() end
        end
        return game, world
    end
    local Records = require("src.game.records")
    local winsBefore = Records.get().wins
    local counts, events, encounters, mods = {}, {}, {}, {}
    local function critter(d)
        for _, t in ipairs(d.tags or {}) do if t == "treasure" or t == "goal" then return true end end
        return d.encounter
    end
    local game, world
    game, world = play({ mode = "run", character = "rhino_beetle", gameMode = "custom", customWaves = set }, 400,
        function(wd, e)
            if critter(e.def) then return end
            local n = wd.spawner.wave
            counts[n] = counts[n] or {}
            counts[n][e.def.id] = (counts[n][e.def.id] or 0) + 1
        end,
        function(wd)
            if wd.pendingVictory then return true end
            if not wd._hooked then
                wd._hooked = true
                wd.events:on("event_started", function(id) events[#events + 1] = { id, wd.spawner.wave } end)
                wd.events:on("encounter_started", function(id) encounters[#encounters + 1] = { id, wd.spawner.wave } end)
                wd.events:on("wave_modifier", function(d, n) mods[#mods + 1] = { d.id, n } end)
            end
        end)
    local sp = world.spawner
    assert(world.gameMode == "custom" and world.customWaves and world.customWaves.name == "Test Set", "the run didn't use the set")
    assert(world.pendingVictory and world.won, "clearing the last custom wave did not win (wave " .. sp.wave .. ")")
    assert(sp.wave == 3, "won on wave " .. sp.wave)
    local function only(n, id, want)
        local c = counts[n] or {}
        for k, v in pairs(c) do
            if k ~= id and not (n == 3 and (k == "fire_ant" or k == "queen_fire")) then error(("wave %d: a %s got in"):format(n, k)) end
        end
        assert((c[id] or 0) == want, ("wave %d: %d %s, wanted %d"):format(n, c[id] or 0, id, want))
    end
    only(1, "worker_ant", 25)
    only(2, "fire_ant", 12)
    only(3, "soldier_ant", 6)
    assert((counts[3] or {}).queen_fire == 1, "wave 3: no queen")
    local function has(list, id, n)
        for _, x in ipairs(list) do if x[1] == id and x[2] == n then return true end end
    end
    assert(has(mods, "armored", 2) and #mods == 1, "wave 2's modifier didn't come (or a random one did)")
    assert(has(events, "acorns", 2), "wave 2's event didn't come")
    assert(has(encounters, "sparrow", 3), "wave 3's sparrow didn't come")
    assert(Records.get().wins == winsBefore, "a custom win counted as a real win")
    print(("[selftest] customwaves: run OK (%d + %d + %d, queen, armored, acorns, sparrow, won)"):format(
        counts[1].worker_ant, counts[2].fire_ant, counts[3].soldier_ant))
    -- the run save carries the set (so editing the set later can't change a saved run)
    local snap = require("src.game.runsave").snapshot(game)
    assert(snap.customWaves and #snap.customWaves.waves == 3, "the run save lost the wave set")
    local rp = require("src.game.runsave").params(snap)
    assert(rp.customWaves == snap.customWaves, "resume params lost the wave set")
    State.switch(game)
    wait(0.4)
    shot("custom_run")

    -- Gauntlet: the script's species and modifiers
    local gseen = {}
    game, world = play({ mode = "run", character = "rhino_beetle", gameMode = "gauntlet" }, 300,
        function(wd, e) if not critter(e.def) then gseen[wd.spawner.wave] = gseen[wd.spawner.wave] or {} gseen[wd.spawner.wave][e.def.id] = true end end,
        function(wd) return wd.spawner.wave >= 4 and wd.spawner.phase == "break" end)
    local gm = Content.modes:get("gauntlet")
    for n = 1, 3 do
        for id in pairs(gseen[n] or {}) do
            local ok = false
            for _, g in ipairs(gm.waves[n].groups) do if g[1] == id then ok = true end end
            assert(ok, ("gauntlet wave %d: a %s got in"):format(n, id))
        end
    end
    assert(world.spawner.modsByWave[2][1].id == "frenzied", "gauntlet wave 2 isn't Frenzied")
    print("[selftest] customwaves: gauntlet OK")

    -- Royal Court: a queen every wave
    local queens = {}
    game, world = play({ mode = "run", character = "rhino_beetle", gameMode = "royalcourt" }, 400,
        function(wd, e)
            local pool = wd.spawner.mode.bossPool or {}
            if e.def.boss or require("src.core.util").contains(pool, e.def.id) then queens[wd.spawner.wave] = true end
        end,
        function(wd) return wd.spawner.wave >= 4 and wd.spawner.phase == "break" end)
    for n = 1, 4 do
        assert(queens[n], "royal court wave " .. n .. " had no queen")
    end
    print("[selftest] customwaves: royal court OK")

    for k, v in pairs(saved) do
        if Rules.byKey[k] then Rules.set(k, v[1]) else Settings.set(k, v[1]) end
    end
    CustomWaves.data = nil
    CustomWaves.noSave = nil
    print("[selftest] customwaves OK")
end
