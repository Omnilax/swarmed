-- Frenzy meter, streak buffs, slow-mo / punch, treasure ant, mini-goals, route gates and the proc
-- snowball (src/game/rewards.lua and friends):  love . --selftest --combat
local State = require("src.core.state")
local Content = require("src.content")
local Settings = require("src.core.settings")

return function(wait, shot)
    assert(Content.frenzies:count() >= 2 and Content.streaks:count() >= 4 and Content.goals:count() >= 4 and Content.routes:count() >= 3,
        "reward content missing")
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "run", character = "rhino_beetle" }))
    local world = game.world
    local rw, p, sp = world.rewards, world.player, world.spawner
    world.flags.god = true
    sp.enabled = false          -- the test drives the waves itself
    wait(0.3)
    local function run(t) for _ = 1, math.floor(t * 60) do world:update(1 / 60) end end
    local function clear() world:clearEnemies() end

    -- frenzy: kills fill the meter; a full meter blows away a crowd and dents a queen
    local fz = rw.frenzy
    assert(fz.charge == 0 and not fz:ready(), "meter should start empty")
    world:spawnRing("worker_ant", 5, p.x, p.y, 10)
    for i = 1, world.enemyCount do require("src.game.combat").damage(world, world.enemies[i], 999) end
    assert(fz.charge >= 5, "kills did not fill the meter (" .. fz.charge .. ")")
    run(0.1)
    fz:add(fz.max)
    assert(fz:ready(), "meter should be ready")
    world:spawnRing("worker_ant", 150, p.x, p.y, 120)
    world:spawnRing("soldier_ant", 30, p.x, p.y, 80)
    local queen = world:spawnEnemy(Content.enemies:filter(function(d) return d.boss end)[1].id, p.x + 60, p.y)
    run(0.05)
    local before = world.enemyCount
    assert(fz:unleash(), "unleash failed")
    assert(fz:shielded(), "player should be safe during the move")
    run(0.25)
    shot("frenzy_quake")
    run(1.2)
    print(("[combat] quake: %d -> %d enemies, queen %d/%d"):format(before, world.enemyCount, queen.hp, queen.maxHp))
    assert(world.enemyCount <= 2, "quake should clear the screen")
    assert(queen.dead or queen.hp < queen.maxHp, "quake should hurt the queen")
    assert(not fz.active and fz.buffT, "the buff should follow the move")
    clear()

    -- the storm frenzy belongs to flyers
    assert(require("src.game.frenzy").defFor(Content.characters:get("dragonfly"), rw.cfg.frenzy).id == "storm", "flyers should get the storm")

    -- slow motion and a camera punch on a big multi-kill
    run(1.5)
    local feel = rw.cfg.feel
    -- heavy-hit freezes are scaled down (and stay off with the Hit Stop setting off)
    world.hitstop = 0
    world:hitStop(0.1)
    assert(math.abs(world.hitstop - 0.1 * feel.stopScale) < 1e-6, "hitStop should scale the freeze")
    run(0.2)
    assert(feel.stopKills >= 10 and feel.stopCooldown >= 2, "multi-kill freezes should stay rare")
    world:spawnRing("worker_ant", feel.bigKill + 5, p.x, p.y, 6)
    list = {}
    for i = 1, world.enemyCount do list[i] = world.enemies[i] end
    world.killsThisFrame = 0
    for _, e in ipairs(list) do world:killEnemy(e) end
    rw:update(1 / 60)
    assert(rw.slowT > 0 and world.camera.kick > 0, "big kill gave no slow-mo / punch")
    run(1)
    clear()

    -- kill streaks: every 50 in a combo gives a buff (first let earlier buffs run out)
    world.combo = 0
    run(7)
    local spd = p.stats:get("moveSpeed") + p.stats:get("damage") + p.stats:get("attackSpeed") + p.stats:get("luck")
    world.combo, world.comboTimer = 50, 2.5
    run(0.05)
    assert(#rw.streaks.active >= 1, "no streak buff at 50")
    assert(p.stats:get("moveSpeed") + p.stats:get("damage") + p.stats:get("attackSpeed") + p.stats:get("luck") > spd, "streak buff changed no stat")
    world.combo = 100
    run(0.05)
    assert(#rw.streaks.active >= 1 and rw.streaks.level == 2, "no streak buff at 100")
    world.combo = 0
    run(7)
    assert(#rw.streaks.active == 0, "streak buffs should wear off")

    -- treasure ant: flees, pays out when caught, burrows away when ignored (no KO)
    sp.enabled = true
    sp.phase, sp.wave, sp.waveTime = "wave", 4, 0
    sp.queue, sp.streams = { { def = Content.enemies:get("worker_ant"), count = 1, x = 0, y = 0, at = 999 } }, {}
    rw:spawnTreasure()
    local t
    for i = 1, world.enemyCount do if world.enemies[i].def.id == "treasure_ant" then t = world.enemies[i] end end
    assert(t and t.elite and t.elite.id == "gilded", "treasure ant missing or not gilded")
    local d0 = (t.x - p.x) ^ 2 + (t.y - p.y) ^ 2
    run(1)
    assert((t.x - p.x) ^ 2 + (t.y - p.y) ^ 2 > d0, "treasure ant did not run away")
    local xp0, fz0 = world.xp, fz.charge
    require("src.game.combat").damage(world, t, 9999)
    run(0.1)
    assert(world.xp >= xp0 + rw.cfg.treasure.xp and fz.charge > fz0, "treasure gave no reward")
    rw:spawnTreasure()
    for i = 1, world.enemyCount do if world.enemies[i].def.id == "treasure_ant" then t = world.enemies[i] end end
    local kos = world.kos
    t.st.t = 999
    world:update(1 / 60)
    assert(t.dead and t.escaped and world.kos == kos, "treasure ant should escape without a KO")
    clear()

    -- mini-goals
    local goals = rw.goals
    local function settled(g) return g.result end
    -- courier: shows up, gets killed -> done
    local g = goals:waveStarted(4, "courier")
    sp.waveTime = 3.5
    run(0.1)
    assert(g.courier and not g.courier.dead, "no courier")
    shot("goal_courier")
    xp0 = world.xp
    require("src.game.combat").damage(world, g.courier, 9999)
    run(0.1)
    assert(settled(g) == "done" and world.xp >= xp0 + g.def.reward.xp, "courier kill should finish the goal")
    -- a courier that gets home fails it
    g = goals:waveStarted(4, "courier")
    run(0.1)
    g.courier.x, g.courier.y = g.courier.st.tx, g.courier.st.ty
    run(0.2)
    assert(settled(g) == "failed", "an escaped courier should fail the goal")
    clear()
    -- aphid: some ants go for it and it gets hurt
    g = goals:waveStarted(5, "aphid")
    local a = g.aphid
    world:spawnRing("worker_ant", 40, a.x, a.y, 60)
    run(3)
    assert(#a.lured > 0, "no ants went for the aphid")
    assert(a.hp < a.max, "the aphid took no damage")
    shot("goal_aphid")
    a.hp = a.max
    clear()
    goals:waveCleared()
    assert(settled(g) == "done", "a living aphid at wave end should be a success")
    -- combo and blitz
    g = goals:waveStarted(3, "combo")
    world.combo, world.comboTimer = g.target, 2.5
    run(0.05)
    assert(settled(g) == "done", "combo goal")
    g = goals:waveStarted(3, "blitz")
    world:spawnRing("worker_ant", g.target, p.x, p.y, 40)
    list = {}
    for i = 1, world.enemyCount do list[i] = world.enemies[i] end
    for _, e in ipairs(list) do world:killEnemy(e) end
    run(0.05)
    assert(settled(g) == "done", "blitz goal")
    clear()
    world.combo = 0

    -- routes: two tunnels after a wave; walking into the hard one starts a harder wave, and
    -- clearing it makes the next item choice's best card rarer
    goals.current = nil
    sp.phase, sp.timer, sp.wave = "break", 3, 4
    sp.queue, sp.streams = {}, {}
    world.pendingChoice = nil
    rw.routes:offer(5)
    local gates = rw.routes.gates
    assert(gates and #gates == 2 and sp.timer >= rw.cfg.routes.minBreak, "no route gates")
    local hard = gates[1].def.kind == "hard" and gates[1] or gates[2]
    run(0.5)
    shot("route_gates")
    local normal = sp:groupSize(Content.enemies:get("worker_ant"))
    p.x, p.y = hard.x, hard.y
    run(0.1)
    assert(sp.phase == "wave" and sp.wave == 5 and world.route == hard.def, "walking into a gate did not start that route")
    print(("[combat] route %s: group %d (normal ~%d)"):format(hard.def.name, sp:groupSize(Content.enemies:get("worker_ant")), normal))
    clear()
    sp.queue, sp.streams, sp.portals = {}, {}, {}
    run(0.2)
    assert(sp.phase == "break" and world.route == nil, "route wave did not clear")
    if hard.def.reward.minRarity then
        assert(world.pendingChoice and world.pendingChoice.minRarity == hard.def.reward.minRarity, "route prize did not reach the item choice")
    end
    world.pendingChoice = nil
    rw.routes.gates = nil
    -- ignoring the gates gives a normal wave
    rw.routes:offer(6)
    sp:startWave()
    run(0.05)
    assert(world.route == nil and rw.routes.gates == nil, "an ignored route should give a normal wave")
    clear()
    sp.queue, sp.streams = {}, {}

    -- proc snowball
    sp.wave = 1
    local m1, d1 = rw:procMul(), rw:procDepth()
    sp.wave = 10
    local m10, d10 = rw:procMul(), rw:procDepth()
    assert(m1 == 1 and m10 > 1.5 and d1 == 2 and d10 == 3, "proc snowball numbers off")
    print(("[combat] procs: x%.2f depth %d at wave 1, x%.2f depth %d at wave 10"):format(m1, d1, m10, d10))

    -- stress: a wave-10 proc build in a big crowd, then a frenzy, stays fast
    sp.enabled = false
    for _, it in ipairs(Content.items:all()) do
        if #it.procs > 0 then world:giveItem(it.id) end
    end
    world:spawnRing("worker_ant", 500, p.x, p.y, 90)
    world:spawnRing("fire_ant", 100, p.x, p.y, 50)
    local t0 = love.timer.getTime()
    run(2)
    local ms = (love.timer.getTime() - t0) / 120 * 1000
    fz:add(fz.max)
    fz:unleash()
    t0 = love.timer.getTime()
    run(1)
    local msF = (love.timer.getTime() - t0) / 60 * 1000
    print(("[combat] wave-10 proc build: %.2f ms/frame fighting, %.2f ms/frame during the frenzy, %d procs items"):format(ms, msF, #world.player.inventory.order))
    shot("proc_snowball")
    assert(msF < 60, "frenzy with a proc build is too slow")
    print("[combat] OK")
end
