-- Wave pacing:  love . --selftest --pacing
-- Checks the pieces of src/game/pacing.lua: big early waves, the shuffled species order (and
-- that a seed repeats it), wave modifiers (rolled ahead, never on queen waves), shield walls,
-- pincers and ambushes, the straggler call, overlapping waves, par time / heat, the early-call
-- streak, the royal guard and the daily run.
local State = require("src.core.state")
local Content = require("src.content")
local Settings = require("src.core.settings")
local Pacing = require("src.game.pacing")

return function(wait, shot)
    -- (settings persist: start from the defaults whatever an earlier test left)
    for _, k in ipairs({ "waveOverlap", "waveModifiers", "adaptiveWaves" }) do Settings.set(k, true) end
    Settings.set("speciesOrder", "random")
    Settings.set("waveBreak", "auto")
    local Game = require("src.states.game")
    local step
    local function newRun(params)
        local game = State.switch(Game.new(params or { mode = "run", character = "rhino_beetle" }))
        wait(0.2)
        local world = game.world
        world.flags.god = true
        world:clearEnemies()
        step = function(n) for _ = 1, n do world:update(1 / 60) end end
        return game, world, world.spawner, world.player
    end
    local function killAll(world)
        for i = 1, world.enemyCount do
            local e = world.enemies[i]
            if e and not e.dead then world:killEnemy(e) end
        end
    end
    local function ids(list, n)
        local out = {}
        for i = 1, math.min(n, #list) do out[i] = list[i].id end
        return table.concat(out, ",")
    end

    -- species order: shuffled per run, the same for the same seed, workers first
    local _, w1, s1 = newRun({ mode = "run", character = "rhino_beetle", seed = 12345 })
    local o1 = ids(s1.introOrder, 15)
    local _, _, s2 = newRun({ mode = "run", character = "rhino_beetle", seed = 12345 })
    assert(ids(s2.introOrder, 15) == o1, "the same seed should give the same species order")
    local _, _, s3 = newRun({ mode = "run", character = "rhino_beetle", seed = 999 })
    assert(ids(s3.introOrder, 15) ~= o1, "another seed should shuffle the species differently")
    assert(s1.introOrder[1].id == "worker_ant" and s3.introOrder[1].id == "worker_ant", "workers should always come first")
    Settings.set("speciesOrder", "classic")
    local _, _, sc = newRun()
    local _, _, sc2 = newRun()
    assert(ids(sc.introOrder, 15) == ids(sc2.introOrder, 15), "classic order should not change between runs")
    Settings.set("speciesOrder", "random")
    print("[selftest] species order: " .. o1)

    -- wave modifiers: rolled ahead, stable, never on queen / final waves, same per seed
    local withMods, list = 0, {}
    for n = 1, 30 do
        local m = s1:modifiersFor(n)
        assert(m == s1:modifiersFor(n), "modifiers should be rolled once per wave")
        assert(ids(m, 3) == ids(s2:modifiersFor(n), 3), "the same seed should roll the same modifiers")
        if n < 3 or n % 5 == 0 then assert(#m == 0, "wave " .. n .. " should have no modifiers") end
        if #m > 0 then withMods = withMods + 1 list[#list + 1] = n .. ":" .. ids(m, 3) end
    end
    assert(withMods >= 6, "too few waves got a modifier (" .. withMods .. ")")
    print("[selftest] modifiers: " .. table.concat(list, " "))

    -- big early waves: wave 1 sends lots of frail ants
    local game, world, sp, pl = newRun()
    sp:startWave(1)
    local planned = 0
    for _, g in ipairs(sp.queue) do planned = planned + g.count end
    assert(planned >= 80, "wave 1 should be big (" .. planned .. " ants)")
    step(240)
    local e1 = world.enemies[1]
    assert(e1 and e1.maxHp <= 2, "wave 1 ants should fall to one hit (hp " .. tostring(e1 and e1.maxHp) .. ")")
    assert(sp.par > 10 and sp.par < 90, "wave 1 par time looks wrong (" .. sp.par .. ")")
    wait(0.2)
    shot("pacing_wave1")

    -- a forced modifier: shield wall (groups step out in ranks at once)
    local function forceMods(n, ...)
        sp.modsByWave[n] = { ... }
    end
    world:clearEnemies()
    forceMods(6, Content.wavemods:require("shield_wall"))
    sp:startWave(6)
    local wall = 0
    for _, g in ipairs(sp.queue) do if g.formation == "wall" then wall = wall + 1 end end
    assert(wall > 0, "a shield wall wave should have wall groups")
    local before = world.enemyCount
    for _ = 1, 600 do
        step(1)
        if world.enemyCount - before >= 8 then break end
    end
    assert(world.enemyCount - before >= 8, "a shield wall group should arrive all at once")
    wait(0.3)
    shot("pacing_wall")

    -- pincer: each column split in two
    world:clearEnemies()
    sp.queue, sp.streams, sp.portals = {}, {}, {}
    forceMods(7, Content.wavemods:require("pincer"))
    sp:startWave(7)
    local pairsAt = {}
    for _, g in ipairs(sp.queue) do pairsAt[g.at] = (pairsAt[g.at] or 0) + 1 end
    local split = false
    for _, n in pairs(pairsAt) do if n >= 2 then split = true end end
    assert(split, "a pincer wave should send groups in pairs")

    -- ambush: half the groups burst up around the player at once
    world:clearEnemies()
    sp.queue, sp.streams, sp.portals = {}, {}, {}
    forceMods(8, Content.wavemods:require("ambush"))
    sp:startWave(8)
    local amb = 0
    for _, g in ipairs(sp.queue) do if g.ambush then amb = amb + 1 end end
    assert(amb > 0, "an ambush wave should have ambush groups")
    step(170)
    assert(#sp.portals >= 3, "the ambush should open several spots at once (" .. #sp.portals .. ")")
    for _, pt in ipairs(sp.portals) do
        local d = math.sqrt((pt.x - pl.x) ^ 2 + (pt.y - pl.y) ^ 2)
        assert(d > 60, "an ambush spot opened on top of the player")
    end
    wait(0.3)
    shot("pacing_ambush")

    -- swarm modifier: more, frailer ants
    local swarm = Pacing.combine({ Content.wavemods:require("swarm") })
    assert(swarm.groupSize > 1 and swarm.hp < 1, "swarm should mean more, frailer ants")

    -- straggler call: a far-off last ant burrows and comes up near the player
    world:clearEnemies()
    sp.queue, sp.streams, sp.portals = {}, {}, {}
    sp.phase, sp.waveTime = "wave", 20
    sp.bossWave, sp.finalThisWave = true, false     -- (no overlap: this wave must be emptied)
    local far = world:spawnEnemy("worker_ant", 20, 20)
    pl.x, pl.y = world.size - 60, world.size - 60
    step(2)
    assert(far.called and far.hidden, "a far-off straggler should be called")
    step(70)
    local d = math.sqrt((far.x - pl.x) ^ 2 + (far.y - pl.y) ^ 2)
    assert(not far.hidden and d < 140, "the called straggler should pop up near the player (" .. math.floor(d) .. ")")
    killAll(world)
    step(2)
    assert(sp.phase == "break", "the wave should end once the straggler is dead")
    world.pendingChoice = nil

    -- overlapping waves: with ~15% left the wave breaks and the next one comes in
    world:clearEnemies()
    sp.queue, sp.streams, sp.portals = {}, {}, {}
    sp:startWave(9)
    sp.bossWave, sp.finalThisWave = false, false
    sp.queue = {}
    for i = 1, 40 do world:spawnEnemy("worker_ant", 40 + i * 3, 40) end
    sp.waveSpawned, sp.waveTime = 40, 20
    for i = 1, 35 do world:killEnemy(world.enemies[i]) end
    step(2)
    assert(sp.phase == "break" and sp.overlapped, "a wave with 5 of 40 ants left should overlap into the next")
    assert(world.pendingChoice, "an overlapped wave still gives its item choice")
    assert(world.enemyCount > 0, "the leftovers should still be around")
    step(5)
    assert(sp.phase == "break", "the next wave waits for the item choice")
    world.pendingChoice = nil
    step(2)
    assert(sp.phase == "wave" and sp.wave == 10, "the next wave should start right after the pick")
    Settings.set("waveOverlap", false)
    sp.queue, sp.streams, sp.portals = {}, {}, {}
    sp.waveSpawned, sp.waveTime, sp.bossWave = 40, 20, false
    world:clearEnemies()
    for i = 1, 3 do world:spawnEnemy("worker_ant", pl.x + 100 + i * 3, pl.y) end
    step(2)
    assert(sp.phase == "wave", "with Overlapping Waves off every ant must die first")
    Settings.set("waveOverlap", true)
    world:clearEnemies()
    step(2)
    world.pendingChoice = nil

    -- par / heat: past par the ants speed up; under par pays XP
    sp:startWave(11)
    sp.bossWave, sp.finalThisWave = true, false     -- (no overlap with a single ant left)
    sp.queue = {}
    local ant = world:spawnEnemy("worker_ant", pl.x + 60, pl.y)
    ant.rushed, ant.called = true, true     -- (keep the last-ant rush and the call out of it)
    local base = ant.speed
    sp.pressure, sp.calmT = 0, 0
    sp.waveTime = sp.par + 40
    step(2)
    assert(sp.heat > 0.9 and ant.speed > base * 1.25, "heat should speed ants up past par")
    sp.waveTime, sp.pressure, sp.calmT = 0, 0, 0
    step(2)
    assert(math.abs(ant.speed - base) < base * 0.05, "the heat should cool off again")
    local xp0 = world.xp
    sp.calledEarly = true
    world:clearEnemies()
    step(2)
    assert(world.xp > xp0 and sp.earlyStreak == 1, "an early-called wave under par should pay XP")
    world.pendingChoice = nil

    -- royal guard: a queen arrives ringed by guards and shrugs off damage until they fall
    world:clearEnemies()
    sp.queue, sp.streams, sp.portals = {}, {}, {}
    local queen = Content.enemies:require("queen_worker")
    sp:spawnGroup(queen, 1, pl.x + 120, pl.y)
    step(3)
    local q = world.boss
    assert(q and q.guards and q.guards >= 6, "the queen should bring a royal guard")
    local Combat = require("src.game.combat")
    local hp = q.hp
    Combat.damage(world, q, 100, { noCrit = true })
    local guarded = hp - q.hp
    wait(0.3)
    shot("pacing_guard")
    for i = 1, world.enemyCount do
        local e = world.enemies[i]
        if e and not e.dead and e.guardOf == q then world:killEnemy(e) end
    end
    step(1)
    assert(q.guards == 0, "killing the guards should break the guard")
    hp = q.hp
    Combat.damage(world, q, 100, { noCrit = true })
    assert(hp - q.hp > guarded * 2, "the queen should take full damage once her guard is broken")

    -- the daily run: the same bug / stage / seed all day
    local Daily = require("src.game.daily")
    local a, b = Daily.params(), Daily.params()
    assert(a.seed == b.seed and a.character == b.character and a.stage == b.stage, "the daily run should not change during a day")
    local tomorrow = Daily.params(os.time() + 86400)
    assert(tomorrow.seed ~= a.seed, "tomorrow's daily run should differ")
    local _, dw = newRun(a)
    assert(dw.seed == a.seed and dw.daily == a.daily and dw.player.def.id == a.character, "the daily run params should reach the world")
    print("[selftest] daily run " .. a.daily .. ": " .. a.character .. " on " .. a.stage)
    print("[selftest] pacing OK")
end
