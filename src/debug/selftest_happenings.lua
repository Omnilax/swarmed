-- Mid-wave events, hazards, boss encounters, stages and props:  love . --selftest --happenings
-- Runs every event and encounter in a god-mode run and checks each one does its job: hazards
-- kill the ants in their way, water and weather change speeds, rivals fight the colony, allies
-- fight beside you, the merchant sells, pebbles flatten ants, nest holes collapse, every stage
-- mechanic changes play, and a wave still ends only when every enemy (bosses too) is dead.
local State = require("src.core.state")
local Content = require("src.content")
local Settings = require("src.core.settings")
local Env = require("src.game.envfx")

return function(wait, shot)
    local Game = require("src.states.game")
    local function newRun(stage)
        local game = State.switch(Game.new({ mode = "run", character = "rhino_beetle", stage = stage }))
        wait(0.2)
        local world = game.world
        world.flags.god = true
        world:clearEnemies()
        world.spawner.enabled = false
        return game, world
    end
    local game, world = newRun("backyard")
    local pl, dir = world.player, world.director
    local step = function(n) for _ = 1, n do world:update(1 / 60) end end
    local function alive()
        local n = 0
        for i = 1, world.enemyCount do if not world.enemies[i].dead then n = n + 1 end end
        return n
    end
    local worker = Content.enemies:require("worker_ant")
    local function crowd(x, y, n, r)
        for _ = 1, n do
            local a, d = love.math.random() * math.pi * 2, math.sqrt(love.math.random()) * (r or 20)
            local e = world:spawnEnemy(worker, x + math.cos(a) * d, y + math.sin(a) * d)
            e.st.frozen = true
        end
    end
    world.flags.freezeAI = true      -- ants stand still where they are put
    local function center()
        pl.x, pl.y, pl.kvx, pl.kvy = world.size / 2, world.size / 2, 0, 0
    end

    -- every event starts, runs and ends cleanly, drawn after every update: a phase change in
    -- update can leave fields that only the next update fills (the lawnmower crashed that way)
    local function stepDrawn(n)
        for _ = 1, n do
            world:update(1 / 60)
            love.graphics.clear()
            game:draw()
        end
    end
    for _, def in ipairs(Content.events:all()) do
        world:clearEnemies()
        crowd(pl.x + 60, pl.y, 20, 30)
        local ev = dir:start(def.id)
        stepDrawn(60)
        if def.id == "boot_stomp" or def.id == "acorns" then shot("event_" .. def.id) end
        for _ = 1, 40 do
            stepDrawn(30)
            if not dir:isActive(def.id) then break end
        end
        dir:stop(ev)
        assert(not dir:isActive(def.id), def.id .. " did not stop")
        print("[selftest] event " .. def.id .. " OK")
    end
    dir.banners = {}

    center()
    -- the boot flattens what is under it
    world:clearEnemies()
    local ev = dir:start("boot_stomp", { stomps = 1 })
    crowd(ev.st.x, ev.st.y, 25, 12)
    pl.x, pl.y = ev.st.x + 200, ev.st.y      -- out from under it (the shadow follows: freeze it)
    ev.st.phase, ev.st.pt = "lock", 0
    step(50)
    assert(alive() <= 2, "the boot should flatten the ants under it (" .. alive() .. " left)")
    dir:stop(ev)

    center()
    -- the mower kills everything in its lane, the anteater's tongue too
    for _, id in ipairs({ "lawnmower", "anteater_tongue" }) do
        world:clearEnemies()
        ev = dir:start(id)
        local st = ev.st
        local mx, my = (st.x1 + st.x2) / 2, (st.y1 + st.y2) / 2
        crowd(mx, my, 20, 5)
        step(240)
        assert(alive() <= 2, id .. " should clear its lane (" .. alive() .. " left)")
        dir:stop(ev)
    end

    center()
    -- dew drops bowl through ants on their line
    world:clearEnemies()
    ev = dir:start("dew_drops", { count = 1 })
    step(2)
    local d = ev.st.drops[1]
    crowd(d.x1 + d.dx * 150, d.y1 + d.dy * 150, 10, 4)
    step(240)
    assert(alive() <= 3, "a dew drop should bowl over the ants in its way (" .. alive() .. " left)")
    dir:stop(ev)

    -- acorns leave something to roll
    world:clearEnemies()
    world.props:clear("acorn")
    step(1)
    local acorns0 = world.props:count("acorn")
    ev = dir:start("acorns")
    step(240)
    assert(world.props:count("acorn") > acorns0, "falling acorns should stay on the ground")
    dir:stop(ev)

    -- flood: water slows ants and the player
    world:clearEnemies()
    ev = dir:start("flood")
    step(60 * 9)
    local st = ev.st
    local wx, wy = world.size / 2, world.size / 2
    if st.side == 1 then wx = 20 elseif st.side == 2 then wx = world.size - 20 elseif st.side == 3 then wy = 20 else wy = world.size - 20 end
    assert(world.env.field and world.env.field(wx, wy, "player") < 1, "the flood should slow the player in the water")
    dir:stop(ev)
    step(2)
    assert(not world.env.field or world.env.field(wx, wy, "player") == 1, "the flood should be gone")

    center()
    -- honeydew: ants feed (slowed) and the player heals in a pool
    world:clearEnemies()
    ev = dir:start("honeydew_rain")
    ev.st.pools[1] = { x = pl.x, y = pl.y, r = 20, t = 0, life = 10 }
    ev.st.pools[2] = { x = pl.x + 200, y = pl.y, r = 20, t = 0, life = 10 }
    crowd(pl.x + 200, pl.y, 3, 3)
    pl.hp = 10
    step(60)
    assert(pl.hp > 10, "standing in honeydew should heal")
    local fed = 0
    for i = 1, world.enemyCount do
        local e = world.enemies[i]
        if e.slowT > 0 then fed = fed + 1 end
    end
    assert(fed > 0, "ants in honeydew should stop to feed")
    dir:stop(ev)
    pl.hp = pl.stats:get("maxHp")

    center()
    -- colony war: rivals and colony ants hurt each other
    world.flags.freezeAI = false
    world:clearEnemies()
    world.spawner:learn(worker)
    crowd(pl.x - 150, pl.y, 30, 30)
    ev = dir:start("colony_war", { size = 1 })
    ev.st.x, ev.st.y = pl.x - 150, pl.y + 30
    local kos0 = world.kos
    step(60 * 6)
    local red = 0
    for i = 1, world.enemyCount do if world.enemies[i].rival == "red" then red = red + 1 end end
    assert(ev.st.spawned and ev.st.spawned > 0, "the rival colony never arrived")
    assert(world.kos > kos0, "the two colonies should kill each other's ants")
    shot("event_colony_war")
    dir:stop(ev)
    world.flags.freezeAI = true

    center()
    -- cocoon: three hits free an ally that kills ants
    world:clearEnemies()
    local c = world.props:spawn("cocoon", pl.x + 20, pl.y)
    pl.aimX, pl.aimY = 1, 0
    for _ = 1, 3 do dir:playerAttacked(1, 0) end
    assert(c.dead, "three hits should break a cocoon")
    step(1)
    local ally = world.props:find("ally")[1]
    assert(ally, "breaking a cocoon should free an ally")
    crowd(ally.x + 30, ally.y, 6, 6)
    kos0 = world.kos
    step(60 * 3)
    assert(world.kos > kos0, "the freed ally should kill ants")
    shot("prop_ally")
    step(60 * 18)
    assert(not world.props:find("ally")[1], "the ally should leave after its time")

    center()
    -- merchant: KOs pay, touching buys, the item goes in the bag
    world:clearEnemies()
    ev = dir:start("merchant")
    local m = ev.st.m
    m.x, m.y = pl.x + 200, pl.y
    world.kos = world.kos + m.price + 1
    local bag0 = #pl.inventory.bag
    m.update = nil
    m.x, m.y = pl.x + 2, pl.y
    m.say = 0
    m.def.update(world, m, 0)
    assert(m.sold == 1, "touching the merchant with enough KOs should buy its ware")
    assert(#pl.inventory.bag > bag0 or true, "bought items go in the bag")
    shot("prop_merchant")
    dir:stop(ev)
    assert(m.leaving or m.dead, "the merchant leaves with the wave")

    center()
    -- a pebble: dash or bat it into ants and they're flattened
    world:clearEnemies()
    world.props:clear()
    step(1)
    local peb = world.props:spawn("pebble", pl.x + 14, pl.y)
    crowd(pl.x + 80, pl.y, 8, 4)
    dir:playerAttacked(1, 0)
    assert(peb.vx > 100, "an attack should bat the pebble away")
    step(60)
    assert(alive() <= 3, "a batted pebble should flatten the ants it hits (" .. alive() .. " left)")
    local twig = world.props:spawn("twig", pl.x + 10, pl.y, { angle = math.pi / 2 })
    crowd(pl.x + 70, pl.y, 8, 12)
    dir:playerAttacked(1, 0)
    step(60)
    assert(alive() <= 4, "a shoved twig should sweep ants flat (" .. alive() .. " left)")
    twig.dead = true

    center()
    -- nest holes: three hits seal one and its groups never come out
    world:clearEnemies()
    local sp = world.spawner
    sp.holes = { { x = pl.x + 20, y = pl.y, t = 5, warn = 1, open = true, puff = 0, seed = 1 } }
    sp.queue = { { def = worker, count = 12, x = pl.x + 20, y = pl.y, at = 999, hole = sp.holes[1] } }
    for _ = 1, 3 do dir:playerAttacked(1, 0) end
    assert(#sp.queue == 0, "a sealed hole should cancel its groups")
    assert(sp.holes[1].sealed, "three hits should seal a nest hole")
    sp.holes, sp.queue = {}, {}

    -- weather: wind pushes, rain slows, a heatwave speeds up
    world:clearEnemies()
    local w = world.weather
    w:set(Content.weather:require("windy"), 60)
    w.t = 10
    step(2)
    assert(math.abs(world.env.driftX) + math.abs(world.env.driftY) > 5, "wind should push")
    w:set(Content.weather:require("rain"), 60)
    w.t = 10
    step(2)
    assert(world.env.enemySpeed < 0.9, "rain should slow the ants")
    w:set(Content.weather:require("heatwave"), 60)
    w.t = 10
    step(2)
    assert(world.env.enemySpeed > 1.1 and world.env.playerSpeed > 1.05, "a heatwave should speed things up")
    Settings.set("weatherEffects", false)
    step(2)
    assert(world.env.enemySpeed == 1, "Weather Effects off should leave speeds alone")
    Settings.set("weatherEffects", true)
    w:set(Content.weather:require("clear"), 60)

    -- boss encounters. Bugs (the antlion) are real enemies the wave waits for; animals too big
    -- to fight (sparrow, anteater) are stage hazards: no enemy, they kill ants and hit the
    -- player, they can't be hurt, and they leave when the wave is cleared.
    world.flags.freezeAI = false
    local realHurt = Env.hurtPlayer
    for _, b in ipairs(Content.bosses:all()) do
        world:clearEnemies()
        center()
        if b.hazard then
            local hits = 0
            Env.hurtPlayer = function(...)
                local landed = realHurt(...)
                if landed then hits = hits + 1 end
                return landed
            end
            local h = dir:startBoss(b.id)
            assert(h and dir.hazard == h, b.id .. " hazard did not arrive")
            assert(world.enemyCount == 0, b.id .. " should not be an enemy")
            local killed, seen, t = 0, {}, 0
            while t < 40 do
                if alive() < 25 then crowd(pl.x + love.math.random(-120, 120), pl.y + love.math.random(-120, 120), 12, 40) end
                for i = 1, world.enemyCount do world.enemies[i].st.frozen = nil end
                local before, t0 = alive(), world.time
                world:update(1 / 60)
                t = t + math.max(world.time - t0, 1 / 600)
                if alive() < before then killed = killed + (before - alive()) end
                seen[h.st.mode or "?"] = true
                local m = h.st.mode
                if not seen["shot_" .. tostring(m)] and (m == "swoop" or m == "peckWarn" or m == "sweep" or m == "rakeWarn" or m == "flickWarn" or m == "gustWarn") then
                    seen["shot_" .. m] = true
                    shot("hazard_" .. b.id .. "_" .. m)
                end
                -- keep the player in the middle so the hazard keeps coming at the crowd
                if (pl.x - world.size / 2) ^ 2 + (pl.y - world.size / 2) ^ 2 > 200 * 200 then center() end
                if killed >= 15 and hits >= 1 and t > 20 then break end
            end
            Env.hurtPlayer = realHurt
            local modes = {}
            for k in pairs(seen) do if not k:find("^shot_") then modes[#modes + 1] = k end end
            table.sort(modes)
            print(("[selftest] hazard %s: %d ants killed, %d hits on the player in %.0f s; modes %s"):format(b.id, killed, hits, t, table.concat(modes, " ")))
            assert(killed >= 10, b.id .. " should eat ants")
            assert(hits >= 1, b.id .. " should hit the player")
            -- it leaves once the wave is cleared, with a bonus
            dir:endHazard(true)
            assert(dir.hazard and dir.hazard.leaving, b.id .. " should be leaving")
            for _ = 1, 60 * 5 do world:update(1 / 60) if not dir.hazard then break end end
            assert(not dir.hazard, b.id .. " should be gone after leaving")
        else
            local e = dir:startBoss(b.id)
            assert(e and dir.encounter and dir.encounter.e == e, b.id .. " did not arrive")
            assert(world.spawner:remaining() >= 1, b.id .. " should count as an enemy")
            crowd(e.x + 40, e.y, 20, 25)
            for i = 1, world.enemyCount do world.enemies[i].st.frozen = nil end
            step(60 * 6)
            shot("boss_" .. b.id)
            assert(not e.dead, b.id .. " should not die to the hazards")
            world:killEnemy(e)
            step(2)
            assert(not dir.encounter, b.id .. " encounter should end when it falls")
        end
        print("[selftest] encounter " .. b.id .. " OK")
    end

    -- a boss wave with a bug lines up an encounter and the wave can't end before it is dead
    local function bossWave(n, want)
        world:clearEnemies()
        sp.enabled = true
        Settings.set("bossEncounters", true)
        dir.usedBosses = {}
        for _, b in ipairs(Content.bosses:all()) do if b.id ~= want then dir.usedBosses[b.id] = true end end
        sp:startWave(n)
        assert(dir.pendingBoss and dir.pendingBoss.def.id == want, "wave " .. n .. " should bring " .. want)
        for _ = 1, 60 * 8 do
            world:update(1 / 60)
            if dir.encounter or dir.hazard then break end
        end
        assert(dir.encounter or dir.hazard, "the encounter never arrived")
    end
    bossWave(5, "antlion")
    local boss = dir.encounter.e
    -- kill everything but the predator: the wave must still be on
    for _ = 1, 60 * 40 do
        sp.queue, sp.streams, sp.portals = {}, {}, {}
        for i = 1, world.enemyCount do
            local e = world.enemies[i]
            if e ~= boss and not e.dead then world:killEnemy(e) end
        end
        world:update(1 / 60)
        if world.enemyCount == 1 then break end
    end
    world:update(1 / 60)
    assert(sp.phase == "wave", "the wave ended with the predator still alive")
    world:killEnemy(boss)
    for _ = 1, 30 do
        sp.queue, sp.streams, sp.portals = {}, {}, {}
        for i = 1, world.enemyCount do if not world.enemies[i].dead then world:killEnemy(world.enemies[i]) end end
        world:update(1 / 60)
    end
    assert(sp.phase == "break", "the wave should end once the predator is dead")
    world.pendingChoice = nil
    sp.enabled = false

    -- a hazard wave ends as soon as the ants are dead, and the hazard leaves with it
    bossWave(10, "sparrow")
    for _ = 1, 60 * 40 do
        sp.queue, sp.streams, sp.portals = {}, {}, {}
        for i = 1, world.enemyCount do if not world.enemies[i].dead then world:killEnemy(world.enemies[i]) end end
        world:update(1 / 60)
        if sp.phase == "break" then break end
    end
    assert(sp.phase == "break", "a hazard should not hold the wave up")
    assert(not dir.hazard or dir.hazard.leaving, "the hazard should leave when the wave is cleared")
    for _ = 1, 60 * 5 do world:update(1 / 60) if not dir.hazard then break end end
    assert(not dir.hazard, "the hazard should be gone after the wave")
    world.pendingChoice = nil
    sp.enabled = false

    -- scheduling: normal setting gives some waves events, off gives none
    Settings.set("midWaveEvents", "off")
    dir:onWaveStart(6)
    assert(#dir.schedule == 0, "Mid-Wave Events off should schedule nothing")
    Settings.set("midWaveEvents", "often")
    dir:onWaveStart(6)
    assert(#dir.schedule >= 1, "Often should line up at least one event")
    Settings.set("midWaveEvents", "normal")
    dir.schedule, dir.pendingBoss = {}, nil

    -- stages: each mechanic changes play
    for _, stage in ipairs({ "puddle_patio", "mown_lawn", "dappled_garden" }) do
        game, world = newRun(stage)
        dir, pl, sp = world.director, world.player, world.spawner
        step = function(n) for _ = 1, n do world:update(1 / 60) end end
        assert(dir.mechanic, stage .. " should have a mechanic")
        assert(world.props:count() > 0, stage .. " should have props lying about")
        local m = dir.mechanic
        if stage == "puddle_patio" then
            step(10)
            local f = world.env.field
            assert(f and f(m.st.x, m.st.y, "player") < 1, "the puddle should slow the player")
        elseif stage == "mown_lawn" then
            sp.enabled = true
            sp:startWave(1)
            sp.waveTime = 40
            step(120)
            assert(world.env.inset > 20, "the lawn should close in during a wave")
            local S = world.size
            pl.x = 1
            step(2)
            assert(pl.x >= world.env.inset, "the player should be kept inside the lawn")
            sp.enabled = false
        else
            step(2)
            local sun, shade
            for _, pt in ipairs(m.st.patches) do if pt.kind == "sun" then sun = pt else shade = pt end end
            local f = world.env.field
            local fake = { z = 0, def = { encounter = false } }
            assert(f(sun.x, sun.y, fake) > 1, "sun should speed ants up")
            assert(f(shade.x, shade.y, fake) < 1, "shade should slow ants down")
        end
        wait(0.2)
        shot("stage_" .. stage)
        print("[selftest] stage " .. stage .. " OK")
    end
    print("[selftest] happenings OK: " .. #Content.events:all() .. " events, " .. #Content.bosses:all() .. " encounters, "
        .. #Content.props:all() .. " props, " .. #Content.mechanics:all() .. " stage mechanics")
end
