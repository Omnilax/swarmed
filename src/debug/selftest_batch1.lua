-- Checks for the batch-1 bugs' moves:  love . --selftest --batch1
-- Assassin bug, emperor scorpion, crab, hermit crab, dung beetle, dragonfly, stink bug.
-- Also takes a still of each standing (batch1_<id>.png) and one mid-special (batch1_special_<id>.png).
local State = require("src.core.state")
local Content = require("src.content")

return function(wait, shot)
    local Game = require("src.states.game")
    local Combat = require("src.game.combat")
    local game = State.switch(Game.new({ mode = "sandbox", character = "crab" }))
    wait(0.5)
    local world = game.world
    local pl = world.player
    world.flags.god = false
    local function run(sec) for _ = 1, math.floor(sec * 60) do world:update(1 / 60) end end
    local function use(id)
        world:clearEnemies()
        world.hazards:clear()
        pl:setCharacter(Content.characters:get(id))
        pl.x, pl.y = world.size * 0.5, world.size * 0.5
        pl.hp = pl.stats:get("maxHp")
        pl.attack.timer = 1e9
        pl.momX, pl.momY, pl.kvx, pl.kvy = 0, 0, 0, 0
        world.hitstop, world.hitstopCd = 0, 99      -- no hitstop freezes mid-check
        return pl.secondary
    end
    local function alive()
        local n = 0
        for i = 1, world.enemyCount do if not world.enemies[i].dead then n = n + 1 end end
        return n
    end

    -- stills: every new bug standing, then mid-special in a crowd
    for _, id in ipairs({ "assassin_bug", "emperor_scorpion", "crab", "hermit_crab", "dung_beetle", "dragonfly", "stink_bug" }) do
        local sec = use(id)
        world.flags.god = true
        wait(0.4)
        shot("batch1_" .. id)
        world:spawnRing("worker_ant", 20, pl.x + 45, pl.y, 22)
        world.flags.freezeAI = true
        wait(0.1)
        sec.type.fire(pl, world, 1, 0, sec.params, pl.x + 70, pl.y)
        wait(0.2)
        shot("batch1_special_" .. id)
        world.flags.freezeAI = false
        world.flags.god = false
    end

    -- assassin bug: stabs heal, the shove throws the ant back
    local sec = use("assassin_bug")
    world.flags.freezeAI = true
    local e = world:spawnEnemy("soldier_ant", pl.x + 25, pl.y)
    world:update(1 / 60)
    pl.hp = 10
    pl.attack.type.fire(pl, world, 1, 0, pl.attack.params)
    assert(pl.hp > 10, "rostrum stab did not heal (hp " .. pl.hp .. ", ant " .. e.hp .. "/" .. e.maxHp .. ", dx " .. (e.x - pl.x) .. ")")
    local ex = e.x
    sec.type.fire(pl, world, 1, 0, sec.params, pl.x + 50, pl.y)
    run(0.3)
    assert(e.dead or e.x > ex + 10, "shove did not push the ant away")

    -- emperor scorpion: grabs two ants, stings them, slams them
    sec = use("emperor_scorpion")
    for k = -1, 1, 2 do world:spawnEnemy("soldier_ant", pl.x + 26, pl.y + k * 7).hp = 500 end
    world:update(1 / 60)
    sec.type.fire(pl, world, 1, 0, sec.params, pl.x + 50, pl.y)
    assert(pl.carry and #pl.carry.list == 2, "grab & stab should hold two ants")
    for _ = 1, 50 do sec.type.update(pl, world, 1 / 30, sec.params, true, pl.x + 50, pl.y) end
    assert(not pl.carry, "grab & stab never slammed")
    assert(world.enemies[1].poisonT > 0, "stings did not poison")

    -- crab: snip kills instantly and the halves fly
    sec = use("crab")
    e = world:spawnEnemy("bullet_ant", pl.x + 24, pl.y)
    e.hp, e.maxHp = 400, 400
    world:update(1 / 60)
    sec.type.fire(pl, world, 1, 0, sec.params, pl.x + 50, pl.y)
    run(0.3)
    assert(e.dead, "snip in two did not kill the ant")

    -- hermit crab: in the shell nothing hurts, and it can still walk and pinch
    use("hermit_crab")
    world.flags.freezeAI = false
    pl.dashDef.update(pl, world, 1 / 60, pl.dashParams, true)
    hp = pl.hp
    pl:hurt(20, world:spawnEnemy("worker_ant", pl.x + 10, pl.y))
    assert(pl.hp == hp, "shell guard let damage through")
    assert(pl.dashDef.attackWhileBlocking, "shell guard should allow pinching")
    pl.dashDef.update(pl, world, 1 / 60, pl.dashParams, false)

    -- dung beetle: the ball grows as it rolls, then is hurled and bowls ants over
    sec = use("dung_beetle")
    world.flags.freezeAI = true
    run(0.1)
    local r0 = pl.dung.r
    for _ = 1, 60 do pl.x = pl.x + 3 run(1 / 60) end
    assert(pl.dung.r > r0 + 1, "dung ball did not grow when rolled")
    local big = pl.dung.r
    world:spawnRing("worker_ant", 10, pl.x + 80, pl.y, 10)
    local n0 = alive()
    sec.type.fire(pl, world, 1, 0, sec.params, pl.x + 200, pl.y)
    assert(#pl.dung.thrown == 1 and pl.dung.r < big, "ball hurl did not throw the ball")
    run(1.5)
    assert(alive() < n0 or world.enemies[1].hp < world.enemies[1].maxHp, "the thrown ball hit nothing")

    -- dragonfly: can't walk on the ground at all; holding Shift flies, and in the air ground ants
    -- can't hurt it, fliers can; letting go lands it
    local Input = require("src.core.input")
    sec = use("dragonfly")
    world.flags.freezeAI = false
    run(0.1)
    assert(pl.moveMul == 0, "a landed dragonfly should not walk")
    local gx = pl.x
    Input.virtualDown.move_right = true
    run(0.5)
    Input.virtualDown.move_right = nil
    assert(math.abs(pl.x - gx) < 1, "a landed dragonfly walked")
    Input.virtualDown.dash = true
    run(0.3)
    assert(pl.airborne and pl.z > 6, "dragonfly did not take off")
    gx = pl.x
    Input.virtualDown.move_right = true
    run(0.3)
    Input.virtualDown.move_right = nil
    assert(pl.x > gx + 20, "a flying dragonfly should steer")
    hp = pl.hp
    pl:hurt(10, world:spawnEnemy("worker_ant", pl.x + 5, pl.y))
    pl:hurt(10, "acid")
    assert(pl.hp == hp, "a ground ant hurt the flying dragonfly")
    -- (a few tries: the dragonfly's dodge chance can make any single bite miss)
    local bee = world:spawnEnemy("honey_bee", pl.x + 40, pl.y)
    for _ = 1, 20 do
        if pl.hp < hp then break end
        pl.iframes = 0
        pl:hurt(5, bee)
    end
    assert(pl.hp < hp, "a bee should still reach the flying dragonfly")
    for _ = 1, 60 do if pl.airborne then run(0.1) end end
    assert(not pl.airborne, "flight should run out")
    -- still holding Shift: it rests a moment, then takes off again by itself
    for _ = 1, 30 do if not pl.airborne then run(0.1) end end
    assert(pl.airborne, "a resting dragonfly should take off again while Shift is held")
    Input.virtualDown.dash = nil
    run(2)
    assert(pl.stamina.cur > 1, "flight did not recharge on the ground")
    -- seize an ant, take off with it and drop it on a crowd
    world:clearEnemies()
    e = world:spawnEnemy("soldier_ant", pl.x + 14, pl.y)
    e.hp, e.maxHp = 400, 400
    world:spawnRing("worker_ant", 8, pl.x + 30, pl.y, 14)
    world.flags.freezeAI = true
    Input.virtualDown.secondary = true
    run(0.1)
    assert(pl.carry and pl.carry.kind == "dfgrab", "dragonfly did not seize an ant")
    Input.virtualDown.dash = true
    run(0.4)
    Input.virtualDown.secondary = nil
    n0 = alive()
    local hurt0 = 0
    for i = 1, world.enemyCount do local o = world.enemies[i] if o ~= e then hurt0 = hurt0 + o.hp end end
    run(0.6)
    Input.virtualDown.dash = nil
    assert(not pl.carry, "dragonfly did not drop the ant")
    local hurt1 = 0
    for i = 1, world.enemyCount do local o = world.enemies[i] if o ~= e and not o.dead then hurt1 = hurt1 + o.hp end end
    assert(alive() < n0 or hurt1 < hurt0, "the dropped ant hit nothing")
    world.flags.freezeAI = false

    -- stink bug: acid pool turns ants away, the shield blocks everything
    sec = use("stink_bug")
    world.flags.freezeAI = false
    sec.type.fire(pl, world, 1, 0, sec.params, pl.x + 80, pl.y)
    run(0.5)
    local pool
    for _, z in ipairs(world.hazards.zones) do if z.acidPool then pool = z end end
    assert(pool, "no acid pool")
    e = world:spawnEnemy("worker_ant", pool.x + 2, pool.y)
    e.hp = 999
    run(0.5)
    assert(math.sqrt((e.x - pool.x) ^ 2 + (e.y - pool.y) ^ 2) > pool.r * 0.7, "ant stayed in the acid pool (" .. math.sqrt((e.x - pool.x) ^ 2 + (e.y - pool.y) ^ 2) .. " r " .. pool.r .. " dead " .. tostring(e.dead) .. " hp " .. e.hp .. ")")
    pl.dashDef.start(pl, world, 1, 0, pl.dashParams, pl.x + 10, pl.y)
    hp = pl.hp
    pl:hurt(20, "acid")
    assert(pl.hp == hp, "stink shield let damage through")
    run(2)
    pl:hurt(5, "acid")
    assert(pl.hp < hp, "stink shield should wear off")

    world.flags.freezeAI = false
    world:clearEnemies()
    print("[selftest] batch 1 bugs OK")
end
