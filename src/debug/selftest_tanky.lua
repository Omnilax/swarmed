-- Tanky builds can die (2026-11-19 playtest):  love . --selftest --tanky
-- Crowd and shredder bites crack armor, payback procs hit at most 5 ants, every level gives a
-- skill point (skips give one more), the whip scorpion attacks slower, the dragonfly dives
-- where you steer, and every item says what it does.
local State = require("src.core.state")
local Content = require("src.content")
local Skills = require("src.game.skills")
local Combat = require("src.game.combat")
local Cfg = require("src.config.defense")

return function(wait, shot)
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "run", character = "lobster" }))
    wait(0.2)
    local world = game.world
    world:clearEnemies()
    world.spawner.enabled = false
    local p = world.player
    p.stats:addModifier("test_tank", "armor", 30, 0)
    local base = p.stats:get("armor")

    -- the crowd: every ant on you past the first cracks 1.5 armor, up to 80%
    world.attackers = 1
    assert(p:effectiveArmor() == base, "one ant should not crack armor")
    world.attackers = 11
    assert(math.abs(p:effectiveArmor() - (base - 15)) < 0.01, "10 extra ants should crack 15 armor, got " .. p:effectiveArmor())
    world.attackers = 200
    assert(math.abs(p:effectiveArmor() - base * (1 - Cfg.crowd.maxFrac)) < 0.01, "the crowd should leave 20% of the armor")
    world.attackers = 0

    -- shredders: soldier ant bites stack up to their max, then wear off
    local sh = Content.enemies:get("soldier_ant").shred
    assert(sh and sh.armor > 0, "soldier ants should shred armor")
    for _ = 1, 10 do p:shred(sh.armor, sh.time, sh.max) end
    assert(p.shredArmor == sh.max, "shred should cap at max (got " .. p.shredArmor .. ")")
    assert(math.abs(p:effectiveArmor() - (base - sh.max)) < 0.01, "shred should lower effective armor")
    p.shredT = 0
    for _ = 1, 600 do p:update(1 / 60) end
    assert(p.shredArmor == 0, "shred should wear off")

    -- payback: a hurt proc hits at most 5 ants, nearest first
    local worker = Content.enemies:require("worker_ant")
    for i = 1, 20 do
        local a = i / 20 * math.pi * 2
        world:spawnEnemy(worker, p.x + math.cos(a) * (6 + i * 0.3), p.y + math.sin(a) * (6 + i * 0.3))
    end
    world.flags.god = true
    wait(0.05)
    local near = #Combat.collect(world, p.x, p.y, 60)
    assert(near >= 10, "ants should be around (" .. near .. ")")
    world.retaliateCap = Cfg.retaliate.maxTargets
    local hits = Combat.area(world, p.x, p.y, 60, 1, {})
    world.retaliateCap = nil
    assert(hits == 5, "payback should hit 5 ants, hit " .. hits)
    assert(Combat.area(world, p.x, p.y, 60, 0.01, {}) == near, "plain area hits should not be capped")
    local before = 0
    p.inventory:add("goliath_carapace")
    for _ = 1, 30 do                    -- 50% proc: lash, but only 5 at a time
        local cap
        local prev = Combat.area
        Combat.area = function(w, ...) cap = w.retaliateCap return prev(w, ...) end
        p.inventory:trigger("onHurt", { world = world, player = p, damage = 1, procDepth = 0 })
        Combat.area = prev
        if cap then before = cap end
    end
    assert(before == Cfg.retaliate.maxTargets and world.retaliateCap == nil, "onHurt procs should run under the payback cap")
    world:clearEnemies()

    world.flags.god = false
    -- every level is a skill point, skipping its card is one more
    local sk, lu = p.skills, world.levelups
    local pts = sk.points
    world:grantXP(Skills.xpFor(sk.level + 1))
    assert(sk.points == pts + 1 and #lu.queue >= 1, "a level should give a point and a card pick")
    lu:take(require("src.game.levelups").skipCard())
    assert(sk.points == pts + 2, "skipping should give an extra point")

    -- whip scorpion: slower palps
    local ws = Content.characters:get("whip_scorpion")
    assert(ws.attack.cooldown >= 0.8 and ws.secondary.cooldown >= 1.3, "whip scorpion should attack slower")

    -- every item says what it does somewhere on its card
    for _, d in ipairs(Content.items:all()) do
        assert(d.description and d.description ~= "", d.id .. " has no description")
    end
    print("[selftest] tanky: crowd + shred crack armor, payback capped at " .. Cfg.retaliate.maxTargets .. ", level+skip points ok")
end
