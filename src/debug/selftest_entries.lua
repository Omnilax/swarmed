-- Ways into the arena:  love . --selftest --entries
-- Forces every way on (burrows, flyers dropping in, nest holes, burrow rings), checks each one
-- is telegraphed before anything arrives, never opens on the player, that ants come out of the
-- nest holes, flyers land, and the wave still ends (and the holes close) once everything is dead.
local State = require("src.core.state")
local Content = require("src.content")
local Entries = require("src.game.entries")

return function(wait, shot)
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "run", character = "rhino_beetle" }))
    wait(0.3)
    local world = game.world
    local sp, pl = world.spawner, world.player
    world.flags.god = true
    world:clearEnemies()
    -- (wave pacing would get in the way here: no overlapping waves or wave modifiers)
    sp.cfg.overlap, sp.cfg.modifiers = false, false
    local always = { minWave = 1, chance = 1 }
    sp.cfg.entryStyles = { burrow = always, drop = always, ring = always,
        nest = { minWave = 1, chance = 1, use = 1, holes = { 2, 2 } } }
    local step = function(n) for _ = 1, n do world:update(1 / 60) end end
    local function killAll()
        for i = 1, world.enemyCount do
            local e = world.enemies[i]
            if e and not e.dead then world:killEnemy(e) end
        end
    end

    -- a burrow: a mound first, the ants only after the warning, away from the player
    local worker = Content.enemies:require("worker_ant")
    Entries.send(sp, worker, 6, 0, 0)
    assert(#sp.portals == 1 and sp.portals[1].kind == "burrow", "a worker group should dig up when burrows are forced")
    local pt = sp.portals[1]
    local d = math.sqrt((pt.x - pl.x) ^ 2 + (pt.y - pl.y) ^ 2)
    assert(d >= 80, "a burrow opened too close to the player (" .. math.floor(d) .. ")")
    step(55)
    assert(world.enemyCount == 0, "ants came out before the mound's warning ran out")
    assert(sp:remaining() >= 6, "ants waiting in a mound should count as still to come")
    wait(0.2)
    shot("entries_burrow")
    step(90)
    assert(world.enemyCount > 0 and #sp.portals == 0, "the burrow never opened")

    -- flyers drop in: a shadow, then they come down from high up and can't bite on the way
    world:clearEnemies()
    local fly = Content.enemies:require("flying_ant")
    assert(Entries.pick(sp, fly) == "drop", "flying ants should drop in")
    Entries.send(sp, fly, 5, 0, 0)
    step(65)
    local dropping = 0
    for i = 1, world.enemyCount do if world.enemies[i].dropH then dropping = dropping + 1 end end
    assert(dropping > 0, "flyers should arrive high up and come down")
    shot("entries_drop")
    step(180)
    for i = 1, world.enemyCount do assert(not world.enemies[i].dropH, "a flyer never landed") end

    -- queens always walk in
    for _, q in ipairs(Content.enemies:all()) do
        if q.boss then assert(Entries.pick(sp, q) == "edge", q.id .. " should walk in from the edge") end
    end

    -- a mound right under the player waits for them to step off (a little)
    world:clearEnemies()
    Entries.open(sp, "burrow", worker, 4, pl.x + 5, pl.y)
    step(math.floor(60 * 1.6))
    assert(world.enemyCount == 0 and #sp.portals == 1, "a mound under the player burst out right away")
    step(120)
    assert(#sp.portals == 0, "a mound under the player should still open eventually")

    -- a whole wave with nest holes and rings; it must still end
    world:clearEnemies()
    sp:startWave(6)
    assert(#sp.holes == 2, "forced nest holes should open (" .. #sp.holes .. ")")
    for _, h in ipairs(sp.holes) do
        local hd = math.sqrt((h.x - pl.x) ^ 2 + (h.y - pl.y) ^ 2)
        assert(hd > 150, "a nest hole opened next to the player")
    end
    local holed = 0
    for _, g in ipairs(sp.queue) do if g.hole then holed = holed + 1 end end
    assert(holed > 0, "no group was sent out of the nest holes")
    step(30)
    assert(not sp.holes[1].open, "holes should take a moment to open")
    step(120)
    assert(sp.holes[1].open, "holes should be open after their warning")
    wait(0.3)
    shot("entries_nest")
    local guard, sawRing = 0, false
    while sp.phase == "wave" and guard < 60 * 240 do
        guard = guard + 1
        world:update(1 / 60)
        for _, p in ipairs(sp.portals) do if p.kind == "ringspot" then sawRing = true end end
        if guard % 20 == 0 then killAll() end
        if world.pendingChoice then world.pendingChoice = nil end
    end
    assert(sp.phase == "break", "the wave with nest holes never ended")
    assert(sawRing, "no burrow ring showed up during the wave")
    -- (holes take 0.8 s of game time to close; a level-up's slow motion can stretch that, so
    -- give it up to 4 s of frames)
    for _ = 1, 240 do
        if #sp.holes == 0 then break end
        step(1)
    end
    assert(#sp.holes == 0, "nest holes should close after the wave")

    -- switched off: edge only
    sp.cfg.entryStyles = false
    for _ = 1, 20 do assert(Entries.pick(sp, fly) == "edge", "entryStyles = false should mean edge only") end
    print("[selftest] entries OK (burrow, drop, nest, ring; " .. holed .. " groups from holes)")
end
