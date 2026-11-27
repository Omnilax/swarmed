-- Checks for the Mole Cricket: sand toss hits harder up close, the dig (fast, untouchable,
-- precise), surfacing with an uppercut or an earthquake, letting go doing nothing, the slow
-- recharge and having to let go of Shift before digging again.
--   love . --selftest --molecricket
local State = require("src.core.state")
local Content = require("src.content")
local Input = require("src.core.input")
local Stamina = require("src.game.stamina")

return function(wait, shot)
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "sandbox", character = "mole_cricket" }))
    wait(0.5)
    local world = game.world
    local pl = world.player
    local function step(n)
        for _ = 1, n or 1 do
            world:update(1 / 60)
            Input.consume("dash") Input.consume("secondary") Input.consume("attack")
        end
    end
    local function hold(id, on) Input.virtualDown[id] = on or nil end
    local function reset()
        hold("dash", false) hold("attack", false) hold("secondary", false)
        world:clearEnemies()
        world.hazards:clear()
        pl.x, pl.y = world.size * 0.5, world.size * 0.5
        pl.hp = pl.stats:get("maxHp")
        pl.attack.timer, pl.secondary.timer = 1e9, 1e9
        pl.momX, pl.momY, pl.kvx, pl.kvy = 0, 0, 0, 0
        pl.aimX, pl.aimY = 1, 0
        pl.moleNeedRelease = nil
        local s = Stamina.state(pl)
        s.cur, s.lockT, s.delayT = s.max, 0, 0
        world.hitstop, world.hitstopCd = 0, 99
        world.flags.freezeAI = true
    end
    local function ant(dx, dy)
        local e = world:spawnEnemy("bullet_ant", pl.x + dx, pl.y + (dy or 0))
        e.hp, e.maxHp = 9999, 9999
        e.mass = 1e6          -- stays put so every grain can reach it
        return e
    end
    Input.lastDevice = "gamepad"     -- pointer follows the aim
    assert(pl.def.id == "mole_cricket" or pl.def.name == "Mole Cricket", "not playing the mole cricket")
    assert(pl.def.movement and pl.def.movement.slide, "mole cricket should be clumsy (slide) on top")

    -- Sand toss: a shotgun, much harder up close than far away. A wall of ants across the
    -- spray at each distance; per grain, close ants take far more.
    local function toss(dist)
        reset()
        local list = {}
        for k = -6, 6 do list[#list + 1] = ant(dist, k * 9) end
        pl.secondary.type.fire(pl, world, 1, 0, pl.secondary.params)
        step(8)
        if dist > 100 then shot("molecricket_sand") end
        step(52)
        local dmg, hits = 0, 0
        for _, e in ipairs(list) do
            if e.hp < 9999 then hits = hits + 1 dmg = dmg + 9999 - e.hp end
        end
        return dmg, hits
    end
    local nearDmg, nearHits = toss(22)
    local farDmg, farHits = toss(150)
    print(("[molecricket] sand toss near %.1f (%d ants), far %.1f (%d ants)"):format(nearDmg, nearHits, farDmg, farHits))
    assert(nearDmg > 0 and farDmg > 0, "sand should reach both near and far ants")
    assert(nearDmg > farDmg * 2, "sand toss should hit much harder up close")

    -- Dig: fast, hidden, untouchable, precise steering
    reset()
    hold("dash", true)
    step(2)
    assert(pl.holdMode and pl.hidden, "holding Shift should dig in")
    assert((pl.runMul or 1) >= 2, "digging should be much faster")
    assert(pl.slideNow == false, "underground steering should be precise")
    local hp = pl.hp
    pl:hurt(20, "test")
    assert(pl.hp == hp, "nothing should hurt the mole cricket underground")
    shot("molecricket_dig")

    -- Attack underground: bursts out with an uppercut
    local front = ant(30)
    Input.press("attack")
    step(1)
    assert(not pl.holdMode and not pl.hidden, "attacking should surface")
    assert(front.hp < 9999, "the uppercut should hit the ant in front")
    assert(pl.slideNow == nil, "clumsy again on top")
    shot("molecricket_uppercut")
    -- Shift still held: no digging again until it is let go
    pl.stamina.cur = pl.stamina.max
    step(30)
    assert(not pl.holdMode, "must let go of Shift before digging again")
    hold("dash", false)
    step(2)
    hold("dash", true)
    step(2)
    assert(pl.holdMode, "after letting go, Shift digs again")

    -- Special underground: earthquake all round, stunning
    local a1, a2 = ant(-70), ant(0, 75)
    Input.press("secondary")
    step(1)
    assert(not pl.holdMode, "the earthquake should surface")
    assert(a1.hp < 9999 and a2.hp < 9999, "the earthquake should hit all round")
    assert((a1.stunT or 0) > 0 and (a2.stunT or 0) > 0, "the earthquake should stun")
    shot("molecricket_quake")

    -- Letting go (or running out) does nothing
    reset()
    hold("dash", true)
    step(5)
    local close = ant(10)
    hold("dash", false)
    step(2)
    assert(not pl.holdMode and not pl.hidden, "letting go should surface")
    assert(close.hp == 9999, "just letting go should not hurt anything")
    reset()
    hold("dash", true)
    step(math.floor(60 * (pl.dashParams.stamina + 0.5)))
    assert(not pl.holdMode, "running out of stamina should surface")
    hold("dash", false)

    -- Long recharge: well over 8 s for a full bar
    local full = pl.stamina.max / Stamina.regenRate(pl)
    print(("[molecricket] full dig recharge %.1f s"):format(full))
    assert(full > 8, "digging should take a long time to recharge")

    -- Skill tree loads and its nodes apply
    local tree = Content.skilltrees:get("mole_cricket")
    assert(tree and #tree.branches >= 3, "skill tree missing")
    print("[molecricket] OK")
end
