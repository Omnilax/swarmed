-- Checks the round-16 dashes of the seven bugs that used to share the plain dash: assassin bug
-- (ambush), emperor scorpion (claw wall), hissing roach (scurry), jumping spider (safety line),
-- rhino beetle (horn charge), scorpion (tail flick), stag beetle (clumsy flight).
--   love . --selftest --dashes
local State = require("src.core.state")
local Content = require("src.content")
local Input = require("src.core.input")

return function(wait, shot)
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "sandbox", character = "assassin_bug" }))
    wait(0.5)
    local world = game.world
    local pl = world.player
    local oldDevice = Input.lastDevice
    local function run(sec)
        for _ = 1, math.floor(sec * 60) do
            Input.lastDevice = "gamepad"      -- pointer = along the aim, not the real mouse
            world:update(1 / 60)
            Input.consume("dash")
            Input.consume("secondary")
            Input.consume("attack")
        end
    end
    local function hold(id, on) Input.virtualDown[id] = on or nil end
    local function use(id)
        hold("dash", false)
        world:clearEnemies()
        world.hazards:clear()
        pl:setCharacter(Content.characters:get(id))
        pl.x, pl.y = world.size * 0.5, world.size * 0.5
        pl.hp = pl.stats:get("maxHp")
        pl.attack.timer, pl.secondary.timer = 1e9, 1e9
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
    local function dash(sec)
        Input.press("dash")
        run(sec or 0.5)
    end

    -- Assassin bug: hold = stealth (cloaked, stabs hit x bonus), let go = visible again
    use("assassin_bug")
    local a1 = ant(22)
    Input.virtualDown = Input.virtualDown or {}
    Input.virtualDown.dash = true
    run(0.3)
    assert(pl.cloakT and pl.stealthMul, "stealth did not cloak")
    pl.attack.type.fire(pl, world, 1, 0, pl.attack.params)
    assert(9999 - a1.hp >= pl.attack.params.damage * 2, "stab from stealth was not stronger")
    Input.virtualDown.dash = nil
    run(0.2)
    assert(not pl.cloakT and not pl.stealthMul, "stealth did not end on release")
    print("[dashes] assassin bug OK")

    -- Emperor scorpion: hold = claw wall (front hits glance off, ants ahead pushed), release = shove
    use("emperor_scorpion")
    world.flags.god = false
    local front = ant(22)
    hold("dash", true)
    run(0.2)
    assert(pl.holdMode, "claw wall did not raise")
    local hp = pl.hp
    pl.iframes = 0
    pl:hurt(10, front)
    assert(pl.hp == hp, "a bite from the front got through the claw wall")
    local back = ant(-22)
    pl:hurt(10, back)
    assert(pl.hp < hp, "a bite from behind should get through")
    local fx0 = front.x
    run(0.6)
    assert(front.x > fx0 + 4 and front.hp < 9999, "claw wall did not bulldoze the ant ahead")
    shot("dashes_emperor_wall")
    back.x, back.y, back.kvx, back.kvy = pl.x - 20, pl.y, 0, 0
    local bx = back.x
    hold("dash", false)
    run(0.3)
    assert(not pl.holdMode, "claw wall stayed up")
    assert(back.x < bx - 4, ("letting go of the claw wall did not shove (%.1f -> %.1f, player %.1f)"):format(bx, back.x, pl.x))
    print("[dashes] emperor scorpion OK")

    -- Hissing roach: startles the ant touching it and comes out running faster
    use("hissing_roach")
    local r1 = ant(-8)
    dash(0.2)
    assert(r1.stunT > 0, "scurry did not startle the touching ant")
    assert(pl.moveMul and pl.moveMul > 1, "no speed burst after scurrying")
    run(0.8)
    assert(not pl.moveMul, "scurry speed burst never ended")
    assert(pl.dashCharges >= 1, "roach should still have scurries left")
    print("[dashes] hissing roach OK")

    -- Jumping spider: leap out on a line, press again to zip back (free, no charge)
    use("jumping_spider")
    local x0 = pl.x
    dash(0.5)
    assert(pl.x > x0 + 60 and pl.silk, "safety line leap went " .. (pl.x - x0))
    assert(pl.dashCharges == 0, "leap should spend the charge")
    shot("dashes_spider_line")
    dash(0.5)
    assert(math.abs(pl.x - x0) < 12, "zip back did not return to the anchor (" .. (pl.x - x0) .. ")")
    assert(not pl.silk, "line still up after zipping back")
    print("[dashes] jumping spider OK")

    -- Rhino beetle: scoops ants onto the horn and heaves them at the end
    use("rhino_beetle")
    local list = { ant(24, 0), ant(30, 2), ant(36, -2), ant(44, 0) }
    Input.press("dash")
    run(0.12)
    local carried = pl.carry and pl.carry.kind == "horn" and #pl.carry.list or 0
    assert(carried >= 1, "horn charge scooped nothing")
    shot("dashes_rhino_horn")
    run(0.6)
    assert(not pl.carry, "horn charge never heaved its ants")
    local hit = 0
    for _, e in ipairs(list) do if e.hp < 9999 then hit = hit + 1 end end
    assert(hit >= 2, "horn charge hurt only " .. hit .. " ants")
    for _, e in ipairs(list) do assert(not e.held, "an ant was left stuck on the horn") end
    print("[dashes] rhino beetle OK (" .. carried .. " scooped)")

    -- Scorpion: springs back from the aim, stinging the spot it left
    use("scorpion")
    local s1 = ant(30)
    local sx = pl.x
    dash(0.5)
    assert(pl.x < sx - 40, "tail flick did not spring backwards")
    assert(s1.hp < 9999 and s1.poisonT and s1.poisonT > 0 or s1.hp < 9999, "tail flick missed the ant ahead")
    print("[dashes] scorpion OK")

    -- Stag beetle: airborne, steerable, lands with a thud
    use("stag_beetle")
    Input.press("dash")
    run(0.15)
    assert((pl.z or 0) > 4, "stag beetle did not take off")
    shot("dashes_stag_flight")
    pl.aimX, pl.aimY = 0, 1   -- pointer swings below: the flight should bend that way
    local y0 = pl.y
    local land = ant(0, 0)
    run(0.1)
    land.x, land.y = pl.x + 20, pl.y + 20
    run(0.6)
    assert(pl.y > y0 + 5, "clumsy flight did not steer")
    assert(land.hp < 9999, "clumsy flight landing did not hit")
    print("[dashes] stag beetle OK")

    -- Mantis: sways sideways across the aim, and the next strike is a sure crit
    use("mantis")
    local y0, x0 = pl.y, pl.x
    dash(0.4)
    assert(math.abs(pl.y - y0) > 30 and math.abs(pl.x - x0) < 30, "leaf sway did not step sideways")
    assert(pl.swayPrimed, "leaf sway did not ready a crit")
    local m1 = ant(25)
    pl.attack.timer = 0
    Input.press("attack")
    for _ = 1, 20 do Input.lastDevice = "gamepad"; world:update(1 / 60) end
    assert(m1.hp < 9999 - 8, "primed strike did not crit")
    assert(not pl.swayPrimed, "the sure crit should be used up")
    print("[dashes] mantis OK")

    -- Shared stamina: blocks drain it and break when it runs dry; pressed dashes spend it
    use("lobster")
    hold("dash", true)
    run(0.5)
    assert(pl.blocking and pl.stamina.cur < pl.stamina.max, "block should drain stamina")
    run(3)
    assert(not pl.blocking, "block should break when stamina runs out")
    hold("dash", false)
    run(0.1)
    hold("dash", true)
    run(0.1)
    assert(not pl.blocking, "a broken block should not go straight back up")
    hold("dash", false)
    run(3.5)
    hold("dash", true)
    run(0.1)
    assert(pl.blocking, "block should come back once stamina refills")
    use("hissing_roach")
    for _ = 1, 4 do dash(0.3) end
    assert(pl.dashCharges == 0 and pl.stamina.cur < pl.stamina.cost, "scurries should spend stamina")
    print("[dashes] stamina OK")

    -- No playable bug should be left on the plain dash
    for _, c in ipairs(Content.characters:all()) do
        assert(not (c.dash and c.dash.type == "dash"), c.name .. " still uses the plain dash")
    end

    world.flags.freezeAI, world.flags.god = false, true
    Input.lastDevice = oldDevice
    print("[selftest] dashes OK")
end
