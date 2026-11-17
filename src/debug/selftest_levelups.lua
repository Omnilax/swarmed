-- Level-up cards, the faster XP curve, rarity rolls, stat cards, fanfare, granting picks and
-- saves:  love . --selftest --levelups
local State = require("src.core.state")
local Settings = require("src.core.settings")
local Content = require("src.content")
local util = require("src.core.util")

return function(wait, shot)
    local Game = require("src.states.game")
    local Skills = require("src.game.skills")
    local LevelUps = require("src.game.levelups")
    local LevelUp = require("src.states.levelup")
    local RunSave = require("src.game.runsave")

    -- the curve: first level ~10 kills, ~3-6 levels from wave 1 (~150 XP), 30-40 levels a run
    local function levelsAt(total)
        local L, s = 0, 0
        while s + Skills.xpFor(L + 1) <= total do L = L + 1; s = s + Skills.xpFor(L) end
        return L
    end
    assert(Skills.xpFor(1) >= 8 and Skills.xpFor(1) <= 12, "first level should take ~10 XP (got " .. Skills.xpFor(1) .. ")")
    assert(Skills.xpFor(20) > Skills.xpFor(5), "the curve should climb")
    local w1, run = levelsAt(150), levelsAt(15000)
    assert(w1 >= 3 and w1 <= 6, "wave 1 should give 3-6 levels (got " .. w1 .. ")")
    assert(run >= 30 and run <= 40, "a 15-wave run should give 30-40 levels (got " .. run .. ")")
    print(("[levelups] curve: %d levels from wave 1, %d from a full run"):format(w1, run))

    local slowSetting, timing = Settings.get("slowMotion"), Settings.get("levelUpWhen")
    Settings.set("slowMotion", true)
    Settings.set("levelUpWhen", "wave")
    local game = State.switch(Game.new({ mode = "run", character = "rhino_beetle" }))
    local world = game.world
    world.flags.god = true
    world.spawner.enabled = false
    wait(0.3)
    local p, sk, lu = world.player, world.player.skills, world.levelups
    assert(lu and lu:enabled(), "a run should use level-up cards")

    -- a level queues a pick instead of a skill point, with the fanfare
    local fx0 = #world.fx
    world:grantXP(Skills.xpFor(1))
    assert(sk.level == 1 and sk.points == 0 and #lu.queue == 1, "a level should queue a card pick (points " .. sk.points .. ", queue " .. #lu.queue .. ")")
    assert(world.rewards.slowT > 0, "level-up should slow the game for a moment")
    assert(#world.fx >= fx0 + 1, "level-up should flash a ring")

    -- picks wait for the end of the wave; the item choice moment shows them
    local sp = world.spawner
    sp.enabled, sp.phase = true, "wave"
    assert(lu:nextToShow(false) == nil, "a level-up pick showed mid-wave")
    assert(lu:nextToShow(true) ~= nil, "the item choice moment should show the pick")
    world.pendingChoice = { count = 3, wave = 1, at = world.time + 100 }
    sp.phase = "break"
    assert(lu:nextToShow(false) == nil, "the pick should wait for the item choice it comes with")
    world.pendingChoice = nil
    assert(lu:nextToShow(false) ~= nil, "between waves the pick should show")
    sp.enabled = false

    -- the cards screen: two presses to take a card
    wait(0.1)
    local scr = State.top()
    assert(getmetatable(scr) == LevelUp, "the game should open the level-up cards")
    assert(#scr.cards == 3, "a pick should deal 3 cards (got " .. #scr.cards .. ")")
    scr:activate(1)
    assert(not scr.armed, "cards should ignore input for a moment")
    wait(0.7)
    shot("levelup_cards")
    -- force a known stat card in the first slot to check what taking it does
    local def = Content.levelcards:get("swift_legs")
    local legendary = lu:statCard(def, lu.cfg.rarities[4])
    local common = lu:statCard(def, lu.cfg.rarities[1])
    assert(math.abs(legendary.statsMult.moveSpeed - 2 * common.statsMult.moveSpeed) < 0.011, "legendary should double the numbers")
    scr.cards[1] = legendary
    scr:refresh()
    local speed = p.stats:get("moveSpeed")
    scr:activate(1)
    assert(State.top() == scr and scr.armed == 1, "the first press should only pick")
    wait(0.1)
    shot("levelup_armed")
    scr:activate(1)
    assert(State.top() ~= scr, "the second press should take the card")
    assert(#lu.queue == 0, "the pick should leave the queue")
    assert(p.stats:get("moveSpeed") > speed * 1.1, "Swift Legs (legendary) should add ~12% speed")

    -- the skill tree is never on the cards: skipping a pick is the skill point
    for _ = 1, 40 do
        for _, c in ipairs(lu:deal({ level = 20 })) do assert(c.kind == "stat", "level-up cards should be stat cards only") end
    end
    local ptsBefore = sk.points
    lu:take(LevelUps.skipCard())
    assert(sk.points == ptsBefore + 1 and sk.skipped == 1, "a skip should bank a skill point")
    local node = sk.tree.branches[1].nodes[1]
    assert(sk:buy(node.id), "the skipped point should buy a tier-1 node")

    -- rarity: Luck makes rare cards likelier; minRarity is a floor
    local function count(luckAdd, minR)
        p.stats:removeSource("test_luck")
        if luckAdd ~= 0 then p.stats:addModifier("test_luck", "luck", luckAdd, 0) end
        local n = { common = 0, uncommon = 0, rare = 0, legendary = 0 }
        for _ = 1, 3000 do local r = lu:rollRarity(minR); n[r.id] = n[r.id] + 1 end
        return n
    end
    local plain, lucky, floor = count(0), count(200), count(0, "rare")
    p.stats:removeSource("test_luck")
    assert(plain.common > plain.uncommon and plain.uncommon > plain.rare and plain.rare > plain.legendary, "rarity order")
    assert(lucky.legendary > plain.legendary * 2 and lucky.common < plain.common, "Luck should tilt rolls to rarer cards")
    assert(floor.common == 0 and floor.uncommon == 0, "minRarity should be a floor")
    print(("[levelups] legendary: %d/3000 at 0 luck, %d/3000 at 200 luck"):format(plain.legendary, lucky.legendary))

    -- every global card can be dealt and taken
    for _, d in ipairs(Content.levelcards:all()) do
        local c = lu:statCard(d, lu.cfg.rarities[2])
        lu:take(c)
    end
    assert(lu.picks >= 3, "picks are counted")

    -- other systems grant picks (brood cell chests): `now` shows them even mid-wave, back to back
    sp.enabled, sp.phase = true, "wave"
    assert(LevelUps.grant(world, 3, { source = "chest", minRarity = "rare", now = true }) == 3, "grant should queue 3")
    assert(world.levelups:grant(0) == 0, "method form works")
    wait(0.1)
    scr = State.top()
    assert(getmetatable(scr) == LevelUp and scr.entry.source == "chest", "granted picks should open now")
    for _, c in ipairs(scr.cards) do
        if c.kind == "stat" then assert(c.rarity == "rare" or c.rarity == "legendary", "chest minRarity ignored") end
    end
    wait(0.6)
    shot("levelup_chest")
    for k = 1, 3 do
        scr = State.top()
        assert(getmetatable(scr) == LevelUp, "pick " .. k .. " of 3 should be open")
        scr.t = 10
        if k == 3 then
            -- skip the cards for a skill point instead
            local pts = sk.points
            scr:activate(scr:skipIndex())
            scr:activate(scr:skipIndex())
            assert(sk.points == pts + 1, "skipping should give a skill point")
        else
            scr:activate(2); scr:activate(2)
        end
    end
    assert(State.top() == game and #lu.queue == 0, "all three chest picks should be done")
    sp.enabled = false

    -- save and resume: stat cards, waiting picks and skill points come back
    lu:grant(2)
    local snap = util.deepcopy(RunSave.snapshot(game))
    snap = assert(loadstring("return " .. util.serialize(snap)))()
    local g2 = State.switch(Game.new(RunSave.params(snap)))
    local w2 = g2.world
    assert(#w2.levelups.queue == 2, "waiting picks should survive a save")
    assert(math.abs(w2.player.stats:get("moveSpeed") - p.stats:get("moveSpeed")) < 0.01, "stat cards should survive a save")
    assert(w2.player.skills.points == sk.points and w2.player.skills:rank(node.id) == 1, "skill points and bought nodes should survive a save")
    assert(w2.player.skills.skipped == sk.skipped, "the skip count should survive a save")
    w2.levelups.queue = {}

    -- "Right Away" timing opens the cards mid-wave, a beat after the level
    Settings.set("levelUpWhen", "instant")
    world = w2
    world.flags.god = true
    world.spawner.enabled, world.spawner.phase = true, "wave"
    world.spawner.timer = math.huge
    local s2 = world.player.skills
    world:grantXP(s2.toNext - s2.into)
    assert(#world.levelups.queue == 1 and world.levelups:nextToShow(false) == nil, "instant: waits a beat")
    world.time = world.time + 1
    assert(world.levelups:nextToShow(false) ~= nil, "instant: shows mid-wave")
    world.levelups.queue = {}
    world.spawner.enabled = false

    Settings.set("slowMotion", slowSetting)
    Settings.set("levelUpWhen", timing)
    print("[levelups] OK")
end
