-- Nectar beads, the wave-end magnet, ground pickups and the nectar currency API
-- (src/game/nectar.lua):  love . --selftest --nectar
local State = require("src.core.state")
local Content = require("src.content")
local Combat = require("src.game.combat")

return function(wait, shot)
    assert(Content.pickups:get("magnet") and Content.pickups:get("freeze") and Content.pickups:get("frenzy"), "pickup content missing")
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "run", character = "rhino_beetle" }))
    local world = game.world
    local p, sp, nb = world.player, world.spawner, world.beads
    sp.enabled = false
    wait(0.3)
    local function run(t) for _ = 1, math.floor(t * 60) do world:update(1 / 60) end end
    local function kill(e) Combat.damage(world, e, 99999, { noCrit = true }) end
    local cfg = nb.cfg
    local range = p.stats:get("pickupRange")
    local cx, cy = world.size / 2, world.size / 2
    p.x, p.y = cx, cy

    -- a kill out of range: a bead lies on the floor, no XP yet
    local xp0 = world.xp
    kill(world:spawnEnemy("worker_ant", cx + range + 60, cy))
    run(0.5)
    assert(nb.n == 1 and nb:pending() == 1, "a kill should drop one bead worth 1 (got " .. nb.n .. " / " .. nb:pending() .. ")")
    assert(world.xp == xp0, "XP should wait until the bead is collected")
    -- more kills on the same spot merge into the same bead
    for _ = 1, 5 do kill(world:spawnEnemy("worker_ant", cx + range + 60, cy)) end
    run(0.4)
    assert(nb.n == 1 and nb:pending() == 6, "beads on one spot should merge (" .. nb.n .. " beads, " .. nb:pending() .. ")")
    -- walk over: inside Pickup Range it drifts in, XP and nectar arrive together
    local changed = 0
    world.events:on("nectar_changed", function(total, delta) changed = changed + delta end)
    p.x = cx + range + 40
    run(1.0)
    assert(nb.n == 0, "the bead should have drifted in")
    assert(world.xp == xp0 + 6 and world.nectar == 6 and changed == 6, ("collect gave xp %d nectar %d"):format(world.xp - xp0, world.nectar))
    p.x, p.y = cx, cy

    -- currency API
    assert(not world:spendNectar(100) and world.nectar == 6, "spending more than the balance should fail and change nothing")
    assert(world:canAffordNectar(6) and not world:canAffordNectar(7), "canAffordNectar")
    assert(world:spendNectar(4) and world.nectar == 2 and world.nectarSpent == 4, "spend")
    world:addNectar(10, p.x, p.y)
    assert(world.nectar == 12 and world.nectarEarned == 16, "addNectar")

    -- the wave-end magnet sweeps up the whole floor, and the chime climbs
    for k = 1, 40 do world:dropNectar(cx + math.cos(k) * 300, cy + math.sin(k) * 300, 1) end
    run(0.5)
    local pend = nb:pending()
    assert(pend == 40 and nb.n > 10, "40 beads should lie around the arena (" .. nb.n .. ", " .. pend .. ")")
    shot("nectar_floor")
    local xp1 = world.xp
    world.events:emit("wave_cleared", 1)
    run(0.15)
    shot("nectar_magnet")
    local peak = 0
    for _ = 1, 90 do
        world:update(1 / 60)
        peak = math.max(peak, nb.chain)
    end
    assert(nb.n == 0 and world.xp == xp1 + 40, "the wave-end magnet should collect every bead (" .. nb.n .. " left)")
    assert(peak >= 3, "the pickup chime should climb along the sweep (chain " .. peak .. ")")

    -- floor cap: value is never lost, the bead count stays bounded
    local function drawMs()
        local t0 = love.timer.getTime()
        for _ = 1, 30 do game:draw() end
        return (love.timer.getTime() - t0) / 30 * 1000
    end
    local base = drawMs()
    for _ = 1, 2000 do world:dropNectar(love.math.random(20, world.size - 20), love.math.random(20, world.size - 20), 1) end
    assert(nb.n <= cfg.maxBeads and nb:pending() == 2000, ("cap: %d beads, %d value"):format(nb.n, nb:pending()))
    -- drawing a full floor is one batch: time it
    local ms = drawMs()
    print(("[nectar] %d beads on the floor: frame draw %.2f ms (%.2f ms with none)"):format(nb.n, ms, base))
    -- a save while beads lie around counts them as collected
    local snap = require("src.game.runsave").snapshot(game)
    assert(snap.nectar == world.nectar + 2000 and snap.xp == world.xp + 2000, "save should count beads on the floor")
    nb:collectAll()
    assert(nb.n == 0 and world.nectar >= 2012, "collectAll")

    -- pickups: frost freezes the swarm (no moving, no biting)
    world.flags.god = false
    local ant = world:spawnEnemy("worker_ant", cx + 70, cy)
    ant.hp, ant.maxHp = 1e9, 1e9
    local fdef = Content.pickups:get("freeze")
    world:dropPickup("freeze", cx + 20, cy)
    run(0.6)
    assert(world.freezeT > 0, "touching frost should freeze the enemies")
    -- (hits still knock a frozen ant about, so watch one that's out of reach)
    ant.x, ant.y = p.x + 90, p.y
    local ax = ant.x
    run(1)
    assert(math.abs(ant.x - ax) < 1, ("a frozen ant should not walk (moved %.1f)"):format(ant.x - ax))
    -- and one right on top of the player doesn't bite
    local hp0 = p.hp
    ant.x, ant.y = p.x + 2, p.y
    world:update(1 / 60)
    assert(world.attackers == 0 and p.hp == hp0, "a frozen ant should not bite")
    shot("nectar_frozen")
    run(fdef.time)
    assert(world.freezeT == 0, "the freeze should wear off")
    world.flags.god = true
    world:clearEnemies()

    -- royal jelly fills the frenzy meter
    local fz = world.rewards.frenzy
    fz.charge = 0
    world:dropPickup("frenzy", cx + 20, cy)
    run(0.6)
    assert(fz.charge >= fz.max, "royal jelly should fill the frenzy meter")
    fz.charge = 0

    -- the magnet pickup pulls in beads from across the arena
    world:dropNectar(cx - 350, cy + 200, 5)
    world:dropNectar(cx + 300, cy - 300, 5)
    run(0.5)
    local pk = world:dropPickup("magnet", cx + 20, cy)
    assert(pk, "dropPickup")
    run(1.8)
    assert(nb.n == 0, "the magnet pickup should collect every bead")

    -- pickups that are never collected fade away
    world:dropPickup("magnet", cx + 400, cy + 400)
    run(cfg.pickupLife + 0.5)
    assert(#nb.pickups == 0, "an uncollected pickup should fade")

    -- elites drop pickups (forced here), and a gilded elite's bead carries its bonus
    local old = cfg.eliteChance
    cfg.eliteChance = 1
    local e = world:spawnEnemy("worker_ant", cx + range + 80, cy, "gilded")
    kill(e)
    run(0.1)
    assert(#nb.pickups == 1, "an elite should drop a pickup")
    assert(nb:pending() == 1 + Content.elites:get("gilded").bonusXP, "gilded bead should hold the bonus XP (" .. nb:pending() .. ")")
    cfg.eliteChance = old
    shot("nectar_pickup")

    -- Auto Collect: beads fly in from anywhere
    local Settings = require("src.core.settings")
    local prev = Settings.get("autoCollect")
    Settings.set("autoCollect", true)
    run(2)
    assert(nb.n == 0 and #nb.pickups == 0, "auto collect should bring everything in")
    Settings.set("autoCollect", prev)

    -- a real wave: kills drop beads, and the run's nectar ends up equal to the kill XP
    world:clearEnemies()
    local n0, x0 = world.nectar, world.xp
    world:spawnRing("worker_ant", 30, cx, cy, 90)
    for i = 1, world.enemyCount do kill(world.enemies[i]) end
    run(0.1)
    world.events:emit("wave_cleared", 2)
    run(2)
    assert(world.nectar - n0 == 30 and world.xp - x0 == 30, ("30 kills gave %d nectar, %d XP"):format(world.nectar - n0, world.xp - x0))
    print("[nectar] all nectar checks passed")
end
