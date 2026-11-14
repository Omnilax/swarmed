-- Checks for the reworked moves of hermit crab, camel spider, vinegaroon, mantis shrimp, wolf
-- spider, centipede, millipede, dung beetle and mantis:  love . --selftest --rework2
-- Drives held and pressed inputs through Input.virtualDown / Input.press and takes stills.
local State = require("src.core.state")
local Content = require("src.content")
local Input = require("src.core.input")

return function(wait, shot)
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "sandbox", character = "hermit_crab" }))
    wait(0.5)
    local world = game.world
    local pl = world.player
    world.flags.god = false
    local function run(sec)
        for _ = 1, math.floor(sec * 60) do
            world:update(1 / 60)
            Input.consume("dash")
            Input.consume("secondary")
            Input.consume("attack")
        end
    end
    local function hold(id, on) Input.virtualDown[id] = on or nil end
    local function use(id)
        hold("dash", false) hold("attack", false) hold("secondary", false)
        world:clearEnemies()
        world.hazards:clear()
        pl:setCharacter(Content.characters:get(id))
        pl.x, pl.y = world.size * 0.5, world.size * 0.5
        pl.hp = pl.stats:get("maxHp")
        pl.attack.timer = 1e9
        pl.momX, pl.momY, pl.kvx, pl.kvy = 0, 0, 0, 0
        pl.aimX, pl.aimY = 1, 0
        world.hitstop, world.hitstopCd = 0, 99
        world.flags.god = true
        return pl.secondary
    end
    local function hpOf(list) local t = 0 for _, e in ipairs(list) do t = t + math.max(0, e.hp) end return t end
    local function wall(n, dx)
        local list = {}
        for i = 1, n do
            local e = world:spawnEnemy("bullet_ant", pl.x + dx, pl.y + (i - (n + 1) / 2) * 8)
            e.hp, e.maxHp = 9999, 9999
            list[#list + 1] = e
        end
        world.flags.freezeAI = true
        return list
    end

    -- Hermit crab: two anemones back to back
    local sec = use("hermit_crab")
    run(0.1)
    for _ = 1, 2 do
        Input.press("secondary")
        run(0.45)
    end
    local n = 0
    for _, z in ipairs(world.hazards.zones) do if z.anemone then n = n + 1 end end
    assert(n == 2, "hermit crab planted " .. n .. " anemones back to back (want 2)")
    Input.press("secondary")
    run(0.1)
    n = 0
    for _, z in ipairs(world.hazards.zones) do if z.anemone and z.t < z.maxLife - 0.5 then n = n + 1 end end
    assert(n == 2, "third anemone came too soon")
    print("[rework2] hermit crab OK")

    -- Mantis: less health
    use("mantis")
    assert(pl.stats:get("maxHp") <= 40, "mantis hp")

    -- Mantis shrimp: a punch per click; held dash charges a bigger punch and a longer launch
    use("mantis_shrimp")
    assert(not pl.attack.type.manual, "mantis shrimp attack should fire per click")
    local function recoil(t)
        use("mantis_shrimp")
        local ws = wall(5, 26)
        local x0 = pl.x
        hold("dash", true)
        run(t)
        assert(pl.recoil, "holding shift did not wind up")
        hold("dash", false)
        run(0.6)
        return 9999 * #ws - hpOf(ws), x0 - pl.x
    end
    local d1, l1 = recoil(0.05)
    local d2, l2 = recoil(1.0)
    print(("[rework2] recoil tap %.0f dmg %.0f px, full %.0f dmg %.0f px"):format(d1, l1, d2, l2))
    assert(d1 > 0 and d2 > d1 * 2, "charged recoil punch should hit much harder")
    assert(l1 > 40 and l2 > l1 * 1.5, "charged recoil should launch further")
    world.flags.freezeAI = false
    print("[rework2] mantis shrimp OK")

    -- Wolf spider: dash then hidden
    use("wolf_spider")
    Input.press("dash")
    run(0.4)
    assert(pl.cloakT, "wolf spider not hidden after its dash")
    run(1.6)
    assert(not pl.cloakT, "wolf spider stayed hidden")
    print("[rework2] wolf spider OK")

    -- Vinegaroon: two dashes from one charge, then cooldown
    use("vinegaroon")
    local x0 = pl.x
    Input.press("dash")
    run(0.25)
    Input.press("dash")
    run(0.25)
    local moved = pl.x - x0
    assert(moved > 110, "vinegaroon double dash moved only " .. moved)
    local x1 = pl.x
    Input.press("dash")
    run(0.25)
    assert(math.abs(pl.x - x1) < 5, "vinegaroon got a third dash")
    print("[rework2] vinegaroon OK")

    -- Centipede: hold = reversed, jabs from the tail; release = flip that hits all round
    use("centipede")
    run(0.3)
    hold("dash", true)
    run(0.5)
    assert(pl.reversed, "centipede did not reverse")
    local tail = pl.chain[#pl.chain]
    assert(tail.x > pl.x + 20, "centipede tail not aimed forward")
    local ws = wall(3, 50)
    pl.attack.timer = 0
    hold("attack", true)
    run(0.3)
    hold("attack", false)
    assert(hpOf(ws) < 9999 * 3, "tail jabs did not reach")
    shot("rework2_centipede_reversed")
    world:clearEnemies()
    local ring = {}
    for i = 1, 6 do
        local a = i / 6 * math.pi * 2
        local e = world:spawnEnemy("bullet_ant", pl.x + math.cos(a) * 22, pl.y + math.sin(a) * 22)
        e.hp, e.maxHp = 9999, 9999
        ring[#ring + 1] = e
    end
    hold("dash", false)
    run(0.1)
    assert(not pl.reversed, "centipede did not flip back")
    local hit = 0
    for _, e in ipairs(ring) do if e.hp < 9999 then hit = hit + 1 end end
    assert(hit >= 5, "flip hit only " .. hit .. " of 6 ants around it")
    run(0.4)
    world.flags.freezeAI = false
    print("[rework2] centipede OK")

    -- Camel spider: double thrust pierces a line; holding Shift tunnels (unseen), letting go erupts
    use("camel_spider")
    local ws2 = wall(1, 20)
    local e2 = world:spawnEnemy("bullet_ant", pl.x + 34, pl.y)
    e2.hp, e2.maxHp = 9999, 9999
    pl.attack.type.fire(pl, world, 1, 0, pl.attack.params)
    run(0.3)
    assert(ws2[1].hp < 9999 and e2.hp < 9999, "jaw pierce did not skewer the line")
    world:clearEnemies()
    hold("dash", true)
    run(0.5)
    assert(pl.holdMode and pl.hidden and pl.cloakT, "camel spider did not burrow")
    local ring = {}
    for i = 1, 6 do
        local a = i / 6 * math.pi * 2
        local e = world:spawnEnemy("bullet_ant", pl.x + math.cos(a) * 20, pl.y + math.sin(a) * 20)
        e.hp, e.maxHp = 9999, 9999
        ring[#ring + 1] = e
    end
    hold("dash", false)
    run(0.1)
    assert(not pl.hidden and not pl.cloakT, "camel spider did not surface")
    assert(hpOf(ring) < 9999 * 6, "eruption hit nothing")
    world.flags.freezeAI = false
    print("[rework2] camel spider OK")

    -- Millipede: hold = ball roll (faster, bumps ants)
    use("millipede")
    local walk = pl.stats:get("moveSpeed")
    hold("dash", true)
    Input.virtualDown.move_right = true
    run(0.5)
    assert(pl.holdMode and (pl.runMul or 1) > 1.3, "millipede did not roll")
    shot("rework2_millipede_ball")
    hold("dash", false)
    Input.virtualDown.move_right = nil
    run(0.2)
    assert(not pl.holdMode and not pl.chainPose, "millipede did not uncurl")
    print("[rework2] millipede OK (walk " .. walk .. ")")

    -- Dung beetle: big ball = slower walk; ride needs a big ball; throw cooldown grows with size
    local sec2 = use("dung_beetle")
    run(0.1)
    local d = pl.dung
    hold("dash", true)
    run(0.2)
    assert(not pl.holdMode, "rode a tiny ball")
    hold("dash", false)
    run(0.3)
    d.r = 16
    run(0.1)
    assert(pl.moveMul and pl.moveMul < 0.8, "big ball did not slow the beetle")
    hold("dash", true)
    run(0.3)
    assert(pl.holdMode and d.ride and pl.z > 10, "dung beetle did not climb on its ball")
    shot("rework2_dung_ride")
    hold("dash", false)
    run(0.3)
    assert(not d.ride and pl.z < 1, "dung beetle did not climb off")
    sec2.timer = 0
    sec2.type.fire(pl, world, 1, 0, sec2.params, pl.x + 60, pl.y)
    sec2.timer = sec2.params.cooldown
    run(0.05)
    assert(sec2.timer > sec2.params.cooldown + 1, "big throw added no cooldown")
    -- and it actually kills: bash a pack of plain worker ants, then bowl the ball through more
    use("dung_beetle")
    run(0.2)
    world.flags.freezeAI = true
    local kos0 = world.kos
    for i = 1, 6 do world:spawnEnemy("worker_ant", pl.x + 22, pl.y + (i - 3.5) * 6) end
    pl.attack.timer = 0
    hold("attack", true)
    run(3)
    hold("attack", false)
    local bashKos = world.kos - kos0
    assert(bashKos >= 3, "dung bash killed only " .. bashKos .. " of 6 worker ants")
    -- (the aim follows the real mouse here, so line the ants up on the ball's own path)
    local bx, by = require("content.attacks._dungball").pos(pl, pl.dung)
    for i = 1, 6 do world:spawnEnemy("worker_ant", bx + 50 + i * 12, by) end
    sec2.timer = 0
    sec2.type.fire(pl, world, 1, 0, sec2.params, bx + 200, by)
    run(1.5)
    local throwKos = world.kos - kos0 - bashKos
    assert(throwKos >= 2, "dung throw killed only " .. throwKos .. " of 6 worker ants")
    world.flags.freezeAI = false
    print("[rework2] dung beetle OK (bash kills " .. bashKos .. ", throw kills " .. throwKos .. ")")

    hold("dash", false) hold("attack", false) hold("secondary", false)
    print("[selftest] rework2 OK")
end
