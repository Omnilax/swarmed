-- Checks for the Velvet Worm: slower than the millipede, chain body, poison skin when bitten,
-- slime strings slow every ant they touch, the slime line reels you backwards and heals, and
-- slowed ants burst when they die.
--   love . --selftest --velvetworm
local State = require("src.core.state")
local Content = require("src.content")
local Input = require("src.core.input")
local Combat = require("src.game.combat")
local Stamina = require("src.game.stamina")

return function(wait, shot)
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "sandbox", character = "velvet_worm" }))
    wait(0.5)
    local world = game.world
    local pl = world.player
    local function step(n)
        for _ = 1, n or 1 do
            world:update(1 / 60)
            Input.consume("dash") Input.consume("secondary") Input.consume("attack")
        end
    end
    local function reset()
        world:clearEnemies()
        world.hazards:clear()
        pl.x, pl.y = world.size * 0.5, world.size * 0.5
        pl.hp = pl.stats:get("maxHp")
        pl.attack.timer, pl.secondary.timer = 1e9, 1e9
        pl.momX, pl.momY, pl.kvx, pl.kvy = 0, 0, 0, 0
        pl.aimX, pl.aimY, pl.iframes = 1, 0, 0
        local s = Stamina.state(pl)
        s.cur, s.lockT, s.delayT = s.max, 0, 0
        world.hitstop, world.hitstopCd = 0, 99
        world.flags.freezeAI = true
    end
    local function ant(dx, dy, hp)
        local e = world:spawnEnemy("bullet_ant", pl.x + dx, pl.y + (dy or 0))
        e.hp, e.maxHp = hp or 9999, hp or 9999
        return e
    end
    Input.lastDevice = "gamepad"

    local milli = Content.characters:get("millipede")
    assert(pl.def.stats.moveSpeed < milli.stats.moveSpeed, "velvet worm should be slower than the millipede")
    assert(pl.chain and #pl.chain >= 12, "velvet worm should have a long chain body")
    assert((pl.model.ripple or 1) > 1, "velvet worm should wriggle more than other chain bugs")

    -- Bitten: ants touching it are poisoned
    reset()
    local biter = ant(6)
    step(1)
    pl.iframes = 0
    world.flags.god = false

    pl:hurt(3, "test")
    world.flags.god = true
    assert((biter.poisonT or 0) > 0, "an ant touching the worm should be poisoned when it gets hurt")

    -- Slime string: slows every ant along the line
    reset()
    local line = {}
    for d = 30, 150, 30 do line[#line + 1] = ant(d) end
    pl.secondary.type.fire(pl, world, 1, 0, pl.secondary.params)
    step(10)
    shot("velvetworm_string")
    step(30)
    for i, e in ipairs(line) do assert((e.slowT or 0) > 0, "slime string missed ant " .. i) end

    -- Slime line: reels backwards (away from the aim) and heals
    reset()
    pl.hp = 30
    local x0 = pl.x
    Input.press("dash")
    step(1)
    step(30)
    assert(pl.x < x0 - 50, "slime line should reel the worm backwards")
    assert(pl.hp > 30, "slime line should heal")

    -- Slowed ants burst when they die; unslowed ones don't
    reset()
    local a, b = ant(40, 0, 5), ant(52, 0)
    a.slowT, a.slowMul = 2, 0.4
    step(1)
    Combat.damage(world, a, 50, {})
    step(2)
    assert(a.dead or a.hp <= 0, "test ant should die")
    assert(b.hp < 9999, "a slowed ant should burst and hurt its neighbour")
    reset()
    local c, d = ant(40, 0, 5), ant(52, 0)
    step(1)
    Combat.damage(world, c, 50, {})
    step(2)
    assert(d.hp == 9999, "an ant that wasn't slowed should not burst")

    -- Walk about so the screenshot shows the wriggle
    reset()
    Input.virtualMove = { x = 0.7, y = 0.7 }
    step(25)
    Input.virtualMove = { x = 1, y = -0.3 }
    step(25)
    shot("velvetworm_wriggle")
    Input.virtualMove = nil
    print("[velvetworm] OK")
end
