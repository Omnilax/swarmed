-- Map gambles (src/game/gambles.lua): dewdrop shrine, challenge bell, gamble flower.
--   love . --selftest --gambles
-- The shrine fills while you stand in it, calls ants, offers three blessings and gives the one
-- you walk into; the bell rings on a hit, calls a pack, pays out when it falls in time and
-- not when it doesn't; the flower takes nectar and every petal does its thing; the setting
-- schedules them (or not); unused ones leave with the next wave; blessings survive a save.
local State = require("src.core.state")
local Content = require("src.content")
local Settings = require("src.core.settings")
local Rules = require("src.game.rules")
local util = require("src.core.util")

return function(wait, shot)
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "run", character = "rhino_beetle" }))
    wait(0.3)
    local world = game.world
    local p, sp, G = world.player, world.spawner, world.gambles
    world.flags.god = true
    world.flags.freezeAI = true
    sp.enabled = false
    world:clearEnemies()
    world.props:clear()
    world.pendingChoice = nil
    local function run(t) for _ = 1, math.floor(t * 60) do world:update(1 / 60) end end
    local function center() p.x, p.y, p.kvx, p.kvy, p.vx, p.vy = world.size / 2, world.size / 2, 0, 0, 0, 0 end
    local function wave(n) sp.phase, sp.wave, sp.waveTime = "wave", n, 0 end
    assert(G and #G:kinds() >= 3, "gamble props missing")
    wave(5)
    center()

    -- the shrine: nothing while you're out of it, fills while you're in it, calls ants
    local sh = G:place("dewdrop_shrine", p.x + 120, p.y)
    run(1)
    assert(sh.st.charge == 0 and world.enemyCount == 0, "shrine should not fill with nobody in it")
    p.x, p.y = sh.x, sh.y
    run(3)
    local half = sh.st.charge
    assert(half > 0.4 and half < 0.6, "shrine should be about half full after 3 s (" .. half .. ")")
    assert(world.enemyCount > 0, "the shrine should draw ants in while it fills")
    p.x = sh.x + 200
    run(1)
    assert(sh.st.charge < half, "the dew should dry while you're out of the ring")
    p.x, p.y = sh.x, sh.y
    run(4)
    assert(sh.st.state == "offer" and #sh.st.offers == 3, "a full shrine should offer three blessings")
    world:clearEnemies()
    p.x, p.y = sh.x + 30, sh.y + 45
    run(0.8)
    shot("gamble_shrine")
    local b = sh.st.offers[2]
    local before = p.stats:get(b.stat)
    run(1)
    -- walk into the second bubble
    local a = -math.pi * 0.75
    p.x, p.y = sh.x + math.cos(a) * sh.st.ring * 1.15, sh.y + math.sin(a) * sh.st.ring * 1.15
    run(0.1)
    assert(#world.blessings == 1 and world.blessings[1].stat == b.stat, "walking into a bubble should bless you")
    assert(math.abs(p.stats:get(b.stat) - before) > 0, "the blessing should change " .. b.stat)
    run(1.5)
    assert(sh.dead or not world.props.list[1] or world.props:count("dewdrop_shrine") == 0, "a used shrine should go")
    print(("[gambles] shrine OK: %s"):format(G.describe(b.stat, b.add)))

    -- the bell: no ring in a break; a hit rings it in a wave; beat the pack for the prize
    center()
    sp.phase = "break"
    local bell = G:place("challenge_bell", p.x + 20, p.y)
    bell.def.onHit(world, bell)
    assert(bell.st.state == "idle" and world.enemyCount == 0, "the bell should not ring between waves")
    wave(8)
    p.aimX, p.aimY = 1, 0
    world.director:playerAttacked(1, 0)
    assert(bell.st.state == "on", "an attack should ring the bell")
    local pack = bell.st.total
    local elites = 0
    for _, m in ipairs(bell.st.pack) do if m.e.elite then elites = elites + 1 end end
    assert(pack >= 10 and elites >= 2, ("the bell should call a pack with elites (%d, %d elite)"):format(pack, elites))
    run(0.5)
    shot("gamble_bell")
    world.rewards.minRarity = nil
    local xp0 = world.xp
    for _, m in ipairs(bell.st.pack) do world:killEnemy(m.e) end
    run(0.1)
    assert(bell.st.won == true, "killing the pack should win the challenge")
    assert(world.rewards.minRarity == "rare", "the prize should raise the next pick (" .. tostring(world.rewards.minRarity) .. ")")
    assert(world.xp > xp0 + pack, "the prize should give bonus XP")
    world.rewards.minRarity = nil
    -- too slow: no prize, the pack stays
    world:clearEnemies()
    local bell2 = G:place("challenge_bell", p.x + 20, p.y)
    bell2.def.onHit(world, bell2)
    bell2.st.timeLeft = 0.05
    run(0.2)
    assert(bell2.st.won == false and world.rewards.minRarity == nil, "a slow challenge should pay nothing")
    assert(world.enemyCount > 0, "the pack should stay when the time runs out")
    world:clearEnemies()
    print(("[gambles] bell OK: pack of %d, %d elite"):format(pack, elites))

    -- the flower: needs nectar; stand in a shim if the nectar currency isn't in this build
    local shim = world.spendNectar == nil
    if shim then
        assert(not Content.props:require("gamble_flower").gamble.allowed(world), "no flower without nectar")
        world.nectar = 0
        world.addNectar = function(w, n) w.nectar = w.nectar + n end
        world.canAffordNectar = function(w, n) return w.nectar >= n end
        world.spendNectar = function(w, n) if w.nectar < n then return false end w.nectar = w.nectar - n return true end
    end
    assert(Content.props:require("gamble_flower").gamble.allowed(world), "the flower should be allowed with nectar")
    world:addNectar(-(world.nectar or 0) + 5)
    center()
    local fl = G:place("gamble_flower", p.x + 10, p.y)
    run(0.5)
    assert(fl.st.spins == 0 and (world.nectar or 0) == 5, "a flower should not spin without enough nectar")
    local outs = G.cfg.flower.outcomes
    local seen = {}
    for i, out in ipairs(outs) do
        if fl.dead or fl.leaving then
            world.props:clear("gamble_flower")
            fl = G:place("gamble_flower", p.x + 10, p.y)
        end
        fl.st.spins, fl.st.say = 0, 0
        world:addNectar(500)
        local n0, bag0, bl0 = world.nectar, #p.inventory.bag, #world.blessings
        p.hp = 10
        p.x, p.y = fl.x, fl.y
        run(1 / 60 * 2)
        assert(fl.st.spinning, "walking in with nectar should spin the flower")
        assert(world.nectar < n0, "a spin should cost nectar")
        fl.st.land = i
        local paid = fl.st.paid
        p.x = fl.x + 120
        run(2)
        assert(not fl.st.spinning and fl.st.lastOut == out, "the spin should land on " .. out.id)
        if out.id == "jackpot" then assert(world.nectar >= n0 - paid + paid * 3 - 0.01, "jackpot pays 3x") end
        if out.id == "refund" then assert(math.abs(world.nectar - n0) < 0.01, "refund gives the nectar back") end
        if out.id == "heal" then assert(p.hp >= p.stats:get("maxHp"), "heal fills HP") end
        if out.id == "item" or out.id == "rare_item" then assert(#p.inventory.bag > bag0 or #world.texts > 0, "an item should arrive") end
        if out.id == "blessing" or out.id == "curse" then assert(#world.blessings == bl0 + 1, out.id .. " should change a stat") end
        if out.id == "swarm" then assert(world.enemyCount > 0, "ants petal should call ants") end
        world:clearEnemies()
        seen[#seen + 1] = out.id
    end
    -- three spins and it wilts
    world.props:clear("gamble_flower")
    run(0.1)
    fl = G:place("gamble_flower", p.x + 10, p.y)
    world:addNectar(1000)
    for _ = 1, 3 do
        fl.st.say = 0
        p.x, p.y = fl.x, fl.y
        run(1 / 30)
        p.x = fl.x + 120
        fl.st.land = 8    -- "nothing"
        run(2)
    end
    assert(fl.leaving or fl.dead, "the flower should wilt after three spins")
    print("[gambles] flower OK: " .. table.concat(seen, ", ") .. (shim and " (nectar shim)" or ""))
    world.props:clear()
    world:clearEnemies()
    run(0.1)

    -- scheduling: off places nothing, often places some, and they arrive during the wave
    Rules.set("mapGambles", "off")
    G:onWaveStart(5)
    assert(#G.schedule == 0, "Map Gambles off should place nothing")
    Rules.set("mapGambles", "often")
    local got = 0
    for _ = 1, 10 do G:onWaveStart(5) got = got + #G.schedule end
    assert(got >= 5, "Often should line up gambles most waves (" .. got .. "/10)")
    G:onWaveStart(1)
    assert(#G.schedule == 0, "no gambles on wave 1")
    repeat G:onWaveStart(6) until #G.schedule > 0
    wave(6)
    sp.waveTime = 10
    run(0.1)
    assert(G:count() >= 1, "a scheduled gamble should arrive in the wave")
    -- unused ones leave when the next wave starts
    G:onWaveStart(7)
    G.schedule = {}
    run(1.2)
    local left = 0
    for _, o in ipairs(world.props.list) do if o.def.gamble and not o.dead and not o.leaving then left = left + 1 end end
    assert(left == 0, "unused gambles should leave with the next wave")
    Rules.set("mapGambles", "normal")
    G.schedule = {}

    -- blessings survive a save
    local RunSave = require("src.game.runsave")
    G:bless("armor", 3, "shrine")
    local armor = p.stats:get("armor")
    sp.phase = "break"
    local snap = util.deepcopy(RunSave.snapshot(game))
    snap = assert(loadstring("return " .. util.serialize(snap)))()
    local g2 = State.switch(Game.new(RunSave.params(snap)))
    wait(0.2)
    local w2 = g2.world
    assert(#w2.blessings == #world.blessings, "blessings should be saved")
    assert(math.abs(w2.player.stats:get("armor") - armor) < 0.01, "blessed armor should come back after a resume")
    RunSave.clear()
    print("[selftest] gambles OK")
end
