-- Rocks and sticks:  love . --selftest --props
-- Pebbles, twigs and acorns react to every hit: they pop off the ground and bounce, squash,
-- chip, a stick struck off-centre spins, blasts scatter them and they knock into each other.
-- Grab attacks pick them up like an ant: the mantis snatch, stag beetle swing & hurl,
-- dragonfly seize, emperor scorpion grab & stab, vinegaroon acid bomb, jumping spider
-- dragline, rhino horn charge and the whip scorpion's antenna whip all work on props.
local State = require("src.core.state")
local Content = require("src.content")
local Combat = require("src.game.combat")

return function(wait, shot)
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "run", character = "rhino_beetle", stage = "backyard" }))
    wait(0.2)
    local world = game.world
    world.flags.god = true
    world.flags.freezeAI = true
    world:clearEnemies()
    world.spawner.enabled = false
    local pl, dir, props = world.player, world.director, world.props
    local function step(n) for _ = 1, n do world:update(1 / 60) end end
    -- step until cond() holds (game time can run slow after big hits), at most `cap` frames
    local function until_(cond, cap)
        for _ = 1, cap or 400 do
            if cond() then return true end
            world:update(1 / 60)
        end
        return cond()
    end
    local function center()
        pl.x, pl.y, pl.kvx, pl.kvy, pl.vx, pl.vy = world.size / 2, world.size / 2, 0, 0, 0, 0
        pl.carry, pl.grapple = nil, nil
        pl.aimX, pl.aimY = 1, 0
        pl.wangle = 0
    end
    local function alive()
        local n = 0
        for i = 1, world.enemyCount do if not world.enemies[i].dead then n = n + 1 end end
        return n
    end
    local worker = Content.enemies:require("worker_ant")
    local function crowd(x, y, n, r)
        for _ = 1, n do
            local a, d = love.math.random() * math.pi * 2, math.sqrt(love.math.random()) * (r or 6)
            local e = world:spawnEnemy(worker, x + math.cos(a) * d, y + math.sin(a) * d)
            e.st.frozen = true
        end
    end
    local function fresh()
        world:clearEnemies()
        props:clear()
        world.thrown = {}
        step(1)
        center()
    end
    local function settled(o) return o.dead or (o.z == 0 and not o.held and o.vx == 0 and o.vy == 0) end
    local function moved(o, x, y) return math.sqrt((o.x - x) ^ 2 + (o.y - y) ^ 2) end

    -- 1. a hit pops a pebble off the ground: it flies, squashes, lands and settles
    fresh()
    local peb = props:spawn("pebble", pl.x + 14, pl.y)
    dir:playerAttacked(1, 0, { damage = 20 })
    assert(peb.vx > 100 and peb.vz > 0, "a hit should bat the pebble away and pop it up")
    assert((peb.squash or 0) > 0, "a struck pebble should squash")
    local peak = 0
    assert(until_(function() peak = math.max(peak, peb.z) return settled(peb) end), "the batted pebble never settled")
    assert(peak > 3, "the pebble should leave the ground (peak " .. peak .. ")")
    print("[selftest] batted pebble pops, bounces and settles OK (peak z " .. string.format("%.1f", peak) .. ")")

    -- harder moves bat further
    fresh()
    local a = props:spawn("pebble", pl.x + 14, pl.y)
    dir:playerAttacked(1, 0, { damage = 4 })
    local weak = a.vx
    fresh()
    a = props:spawn("pebble", pl.x + 14, pl.y)
    dir:playerAttacked(1, 0, { damage = 30 })
    assert(a.vx > weak * 1.3, "a heavy hit should bat a pebble harder (" .. weak .. " vs " .. a.vx .. ")")

    -- 2. a stick struck near one end spins round its middle
    fresh()
    local twig = props:spawn("twig", pl.x + 14, pl.y + 16, { angle = math.pi / 2 })
    twig.angle = math.pi / 2
    dir:playerAttacked(1, 0)
    assert(math.abs(twig.spin or 0) > 2, "an off-centre hit should spin the twig (" .. tostring(twig.spin) .. ")")
    print("[selftest] off-centre hit spins the twig OK")

    -- 3. a blast scatters the pebbles around it
    fresh()
    local p1 = props:spawn("pebble", pl.x + 80, pl.y)
    local p2 = props:spawn("pebble", pl.x + 60, pl.y + 25)
    Combat.explode(world, pl.x + 65, pl.y + 10, 40, 20)
    assert(p1.vx > 30 and p2.vy > 30 and p1.vz > 0, "a blast should throw pebbles out and up")
    print("[selftest] blasts scatter pebbles OK")

    -- 4. marbles: a rolling pebble knocks a resting one on
    fresh()
    local roller = props:spawn("pebble", pl.x + 40, pl.y)
    local target = props:spawn("pebble", pl.x + 80, pl.y)
    props:launch(roller, 1, 0, 260, 0)
    assert(until_(function() return target.vx > 40 end, 60), "a rolling pebble should knock a resting one on")
    assert(roller.vx < 200, "the rolling pebble should give up speed when it hits")
    print("[selftest] pebbles knock into each other OK")

    -- 5. mantis snatch picks up a pebble (no ant in reach), munching it does not heal, and the
    --    fling throws it into the crowd, where it crashes down and rolls on
    fresh()
    pl:setCharacter(Content.characters:get("mantis"))
    center()
    local sp = pl.secondary
    peb = props:spawn("pebble", pl.x + 26, pl.y)
    pl.hp = 10
    sp.type.fire(pl, world, 1, 0, sp.params, pl.x + 100, pl.y)
    assert(pl.carry and pl.carry.list[1] and pl.carry.list[1].e == peb, "snatch should grab the pebble")
    assert(peb.held, "a snatched pebble is held")
    for _ = 1, 4 do sp.type.update(pl, world, 0.05, sp.params, true, pl.x + 100, pl.y) step(1) end
    assert(peb.z > 2 and peb.held, "the pebble should be held up in the forelegs")
    assert(pl.hp <= 10, "munching a pebble should not heal")
    sp.type.update(pl, world, 0.05, sp.params, false, pl.x + 100, pl.y)
    assert(not pl.carry and #world.thrown == 1, "the pebble should be flung")
    -- ants just past where it comes down
    local f = world.thrown[1]
    local fl = math.sqrt(f.vx * f.vx + f.vy * f.vy)
    local land = f.time * fl
    crowd(peb.x + f.vx / fl * (land + 30), peb.y + f.vy / fl * (land + 30), 6, 6)
    local n0 = alive()
    shot("props_snatch_fling")
    assert(until_(function() return #world.thrown == 0 end, 120), "the flung pebble never landed")
    assert(not peb.held and math.sqrt(peb.vx ^ 2 + peb.vy ^ 2) > 60, "a thrown pebble should land and roll on")
    until_(function() return settled(peb) end, 400)
    assert(alive() <= n0 - 2, "the thrown pebble should flatten ants it rolls into (" .. alive() .. " of " .. n0 .. " left)")
    print("[selftest] mantis snatches and flings a pebble OK")

    -- 6. stag beetle: swing & hurl clubs with a twig
    fresh()
    pl:setCharacter(Content.characters:get("stag_beetle"))
    center()
    sp = pl.secondary
    twig = props:spawn("twig", pl.x + 24, pl.y, { angle = 0 })
    crowd(pl.x - 20, pl.y + 20, 4, 3)
    n0 = alive()
    sp.type.fire(pl, world, 1, 0, sp.params, pl.x + 100, pl.y)
    assert(pl.carry and pl.carry.kind == "swing" and pl.carry.h.e == twig, "swing & hurl should grab the twig")
    local x0 = twig.x
    for _ = 1, 40 do
        if not pl.carry then break end
        sp.type.update(pl, world, 1 / 60, sp.params, true, pl.x + 100, pl.y)
        step(1)
    end
    assert(not pl.carry, "the twig should be hurled after the swing")
    assert(alive() < n0 or world.enemies[1].hp < world.enemies[1].maxHp, "the swung twig should club the ants around")
    assert(until_(function() return #world.thrown == 0 end, 120) and moved(twig, x0, pl.y) > 40, "the twig should be hurled away")
    print("[selftest] stag beetle swings and hurls a twig OK")

    -- 7. dragonfly: seize an acorn and drop it like a bomb
    fresh()
    pl:setCharacter(Content.characters:get("dragonfly"))
    center()
    sp = pl.secondary
    local acorn = props:spawn("acorn", pl.x + 14, pl.y)
    sp.type.update(pl, world, 1 / 60, sp.params, true, pl.x + 60, pl.y)
    assert(pl.carry and pl.carry.h.e == acorn, "seize should pick up the acorn")
    for _ = 1, 10 do sp.type.update(pl, world, 1 / 60, sp.params, true, pl.x + 60, pl.y) step(1) end
    crowd(acorn.x, acorn.y, 5, 6)
    n0 = alive()
    sp.type.update(pl, world, 1 / 60, sp.params, false, pl.x + 60, pl.y)
    assert(not pl.carry, "letting go should drop the acorn")
    assert(until_(function() return #world.thrown == 0 end, 120), "the dropped acorn never landed")
    assert(alive() < n0 or world.enemies[1].hp < world.enemies[1].maxHp, "the dropped acorn should blow up the ants below")
    print("[selftest] dragonfly seizes and bombs with an acorn OK")

    -- 8. emperor scorpion: grab & stab a pebble, then slam it down (it bounces, not blasted away)
    fresh()
    pl:setCharacter(Content.characters:get("emperor_scorpion"))
    center()
    sp = pl.secondary
    peb = props:spawn("pebble", pl.x + 24, pl.y)
    sp.type.fire(pl, world, 1, 0, sp.params)
    assert(pl.carry and pl.carry.list[1].e == peb, "grab & stab should grab the pebble")
    for _ = 1, 120 do
        if not pl.carry then break end
        sp.type.update(pl, world, 1 / 60, sp.params, false)
        step(1)
    end
    assert(not pl.carry and not peb.held, "the pebble should be slammed down")
    local sx, sy = peb.x, peb.y
    until_(function() return settled(peb) end)
    assert(moved(peb, sx, sy) < 30, "a slammed pebble should stay about where it was slammed")
    print("[selftest] emperor scorpion grabs, stings and slams a pebble OK")

    -- 9. vinegaroon: acid bomb a pebble
    fresh()
    pl:setCharacter(Content.characters:get("vinegaroon"))
    center()
    sp = pl.secondary
    peb = props:spawn("pebble", pl.x + 20, pl.y)
    sp.type.fire(pl, world, 1, 0, sp.params)
    assert(pl.carry and pl.carry.h.e == peb, "acid bomb should grab the pebble")
    sp.type.update(pl, world, 1 / 60, sp.params, false, pl.x + 100, pl.y)
    assert(not pl.carry and #world.thrown == 1, "the pebble should be hurled")
    assert(until_(function() return #world.thrown == 0 end, 120) and #world.hazards.zones > 0, "the hurled pebble should leave an acid pool")
    print("[selftest] vinegaroon acid-bombs a pebble OK")

    -- 10. jumping spider: the dragline reels a far pebble in to your feet
    fresh()
    pl:setCharacter(Content.characters:get("jumping_spider"))
    center()
    sp = pl.secondary
    peb = props:spawn("pebble", pl.x + 110, pl.y)
    sp.type.fire(pl, world, 1, 0, sp.params, peb.x, peb.y)
    assert(pl.carry and pl.carry.h.e == peb, "the dragline should catch the pebble")
    for _ = 1, 60 do
        if not pl.carry then break end
        sp.type.update(pl, world, 1 / 60, sp.params)
    end
    assert(not pl.carry and not peb.held and moved(peb, pl.x, pl.y) < 30, "the pebble should be reeled in")
    print("[selftest] jumping spider reels in a pebble OK")

    -- 11. rhino beetle: the horn charge scoops a pebble and heaves it
    fresh()
    pl:setCharacter(Content.characters:get("rhino_beetle"))
    center()
    peb = props:spawn("pebble", pl.x + 20, pl.y)
    local dd, dp = pl.dashDef, pl.dashParams
    dd.start(pl, world, 1, 0, dp)
    local scooped = false
    for _ = 1, 60 do
        step(1)
        if peb.held then scooped = true end
        if #world.thrown > 0 then break end
    end
    assert(scooped, "the horn charge should scoop the pebble up")
    assert(until_(function() return #world.thrown == 0 and not peb.held end, 200), "the scooped pebble should be heaved")
    print("[selftest] rhino horn charge scoops and heaves a pebble OK")

    -- 12. whip scorpion: the antenna whip lashes a pebble and cracks it back
    fresh()
    pl:setCharacter(Content.characters:get("whip_scorpion"))
    center()
    peb = props:spawn("pebble", pl.x + 90, pl.y)
    dd, dp = pl.dashDef, pl.dashParams
    dd.start(pl, world, 1, 0, dp, peb.x, peb.y)
    for _ = 1, 30 do
        dd.update(pl, world, 1 / 60, dp)
        if not pl.grapple then break end
    end
    assert(not pl.grapple and peb.vx < -100, "the whip should crack the pebble back toward you (" .. peb.vx .. ")")
    print("[selftest] antenna whip cracks a pebble back OK")

    -- a held prop nobody is placing drops by itself
    fresh()
    peb = props:spawn("pebble", pl.x + 40, pl.y)
    peb.held, peb.z, peb.heldPing = true, 10, 0
    assert(until_(function() return not peb.held and peb.z == 0 end, 120), "an abandoned held prop should drop")

    -- a screenshot of a scatter
    fresh()
    for i = 1, 6 do props:spawn("pebble", pl.x + 40 + i * 6, pl.y + (i % 3) * 8) end
    props:spawn("twig", pl.x + 60, pl.y - 20, { angle = 0.3 })
    Combat.explode(world, pl.x + 58, pl.y + 4, 40, 20)
    step(8)
    shot("props_blast")
    world.flags.freezeAI = false
    print("[selftest] props OK")
end
