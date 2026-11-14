-- Checks for the 2026-10-29 character pass: whip scorpion antenna whip, dragonfly (walks, air
-- dive lunge, ground sweep, hold-to-carry bomb), lobster claws, stink bug spray, scorpion venom:
--   love . --selftest --rework3
local State = require("src.core.state")
local Content = require("src.content")
local Input = require("src.core.input")

return function(wait, shot)
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "sandbox", character = "whip_scorpion" }))
    wait(0.5)
    local world = game.world
    local pl = world.player
    local function run(sec)
        for _ = 1, math.floor(sec * 60) do
            world:update(1 / 60)
            Input.consume("dash") Input.consume("secondary") Input.consume("attack")
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
        world.flags.freezeAI = true
    end
    local function ant(dx, dy)
        local e = world:spawnEnemy("bullet_ant", pl.x + dx, pl.y + (dy or 0))
        e.hp, e.maxHp = 9999, 9999
        return e
    end
    Input.lastDevice = "gamepad"     -- pointer follows the aim

    -- Whip scorpion: the feelers catch an ant, it zips over and cracks the whip
    use("whip_scorpion")
    local a = ant(90)
    local x0 = pl.x
    Input.press("dash")
    world:update(1 / 60)
    run(0.08)
    shot("rework3_whip")
    run(0.6)
    assert(a.hp < 9999, "antenna whip did not lash the ant")
    assert(pl.x > x0 + 40 and not pl.grapple, "antenna whip did not haul the bug to the ant")
    print("[rework3] whip scorpion OK")

    -- Dragonfly: walks; flying attack is an untouchable dive; ground attack sweeps; carry + bomb
    use("dragonfly")
    run(0.1)
    assert((pl.moveMul or 1) >= 0.7, "dragonfly should walk")
    local front, side = ant(30), ant(5, 30)
    run(0.02)
    pl.attack.type.fire(pl, world, 1, 0, pl.attack.params)
    assert(front.hp < 9999 and side.hp < 9999, "ground sweep should reach the front and the side")
    world:clearEnemies()
    hold("dash", true)
    run(0.3)
    assert(pl.airborne, "dragonfly did not take off")
    local line = { ant(30), ant(55) }
    run(0.02)
    x0 = pl.x
    pl.attack.type.fire(pl, world, 1, 0, pl.attack.params)
    assert(pl.iframes >= pl.dashT, "dive lunge should be untouchable")
    run(0.3)
    assert(pl.x > x0 + 40 and line[1].hp < 9999 and line[2].hp < 9999, "dive lunge did not rake the line")
    hold("dash", false)
    run(0.4)
    world:clearEnemies()
    local e = world:spawnEnemy("soldier_ant", pl.x + 14, pl.y)
    hold("secondary", true)
    run(2.5)
    assert(pl.carry and not e.dead, "the carried ant should be held for as long as you like")
    world:spawnRing("worker_ant", 8, pl.x, pl.y, 16)
    hold("secondary", false)
    run(0.5)
    assert(not pl.carry, "letting go did not drop the ant")
    print("[rework3] dragonfly OK")

    -- Assassin bug shove, scorpion venom on the pincers
    use("scorpion")
    a = ant(20)
    run(0.02)
    pl.attack.type.fire(pl, world, 1, 0, pl.attack.params)
    assert(a.poisonT > 0, "scorpion pincers should poison")
    use("emperor_scorpion")
    a = ant(26)
    run(0.02)
    pl.attack.type.fire(pl, world, 1, 0, pl.attack.params)
    assert(a.poisonT > 0, "emperor scorpion claws should poison")
    print("[rework3] scorpions OK")

    -- Stills: lobster claws (rest, charging, block), stink bug spray
    use("lobster")
    world.flags.freezeAI = false
    world:spawnRing("worker_ant", 10, pl.x + 50, pl.y, 20)
    run(0.3)
    shot("rework3_lobster")
    hold("attack", true)
    run(0.6)
    shot("rework3_lobster_charge")
    hold("attack", false)
    hold("dash", true)
    run(0.4)
    shot("rework3_lobster_block")
    use("stink_bug")
    world.flags.freezeAI = false
    world:spawnRing("worker_ant", 10, pl.x + 50, pl.y, 20)
    pl.attack.timer = 0
    run(0.9)
    shot("rework3_stink")
    hold("dash", false)
    print("[rework3] stills OK")
end
