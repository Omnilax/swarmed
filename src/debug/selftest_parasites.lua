-- Parasites (src/game/parasites.lua) and the Green Mushroom that purges them.
--   love . --selftest --parasites
-- A parasite goes in the bug, not the bag, and still counts (stats, procs, HUD row); it devours
-- its host items; it can't be offered twice; the Parasites setting turns them off; Flu halves
-- HP and doubles damage; Cordyceps walks for you; lice breed; it survives a run save; the
-- mushroom sprouts, wilts with the next wave, and walking into it purges everything.
local State = require("src.core.state")
local Content = require("src.content")
local Settings = require("src.core.settings")

return function(wait, shot)
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "run", character = "rhino_beetle" }))
    wait(0.3)
    local world = game.world
    local p, sp = world.player, world.spawner
    local inv = p.inventory
    local Parasites = require("src.game.parasites")
    local Choices = require("src.game.choices")
    world.flags.god = true
    world.flags.freezeAI = true
    sp.enabled = false
    world:clearEnemies()
    world.props:clear()
    world.pendingChoice = nil
    local function run(t) for _ = 1, math.floor(t * 60) do world:update(1 / 60) end end
    local function center() p.x, p.y, p.kvx, p.kvy, p.vx, p.vy = world.size / 2, world.size / 2, 0, 0, 0, 0 end
    sp.phase, sp.wave, sp.waveTime = "wave", 5, 0
    center()

    -- every parasite def loads, with its icon
    local defs = {}
    for _, d in ipairs(Content.items:all()) do if d.parasite then defs[#defs + 1] = d end end
    assert(#defs >= 10, "expected 10 parasites, got " .. #defs)
    for _, d in ipairs(defs) do
        assert(d.rarity == "parasite" and d.curse, d.id .. " needs rarity parasite and a curse line")
        assert(Content.sprites:get(d.icon), d.id .. " icon missing")
    end

    -- they show up in item choices at wave 5, and never while the setting is off
    local seen = false
    for _ = 1, 800 do if Choices.pickDef(world, {}).parasite then seen = true break end end
    assert(seen, "parasites should be offered")
    Settings.set("parasites", "off")
    for _ = 1, 800 do assert(not Choices.pickDef(world, {}).parasite, "parasites offered while off") end
    Settings.set("parasites", "normal")

    -- Flu: lives outside the bag, halves HP, doubles damage
    local hp0, dmg0 = p.stats:get("maxHp"), p.stats:get("damage")
    local cells0 = inv:usedCells()
    inv:add("flu_virus")
    assert(inv:usedCells() == cells0, "a parasite should take no bag space")
    assert(inv:count("flu_virus") == 1 and Parasites.count(inv) == 1, "flu should count")
    assert(math.abs(p.stats:get("maxHp") - hp0 * 0.5) < 1, "flu should halve max HP")
    assert(p.stats:get("damage") == dmg0 + 100, "flu should add +100% damage")
    -- not offered again once carried
    for _ = 1, 400 do assert(Choices.pickDef(world, {}).id ~= "flu_virus", "flu offered twice") end
    -- the sneeze
    run(7.5)
    assert(p.stunT ~= nil, "player should still exist")

    -- Void-style feeding: Cordyceps Puppeteer devours Cordyceps in the bag
    inv:add("cordyceps", 2)
    local area0 = p.stats:get("area")
    inv:add("cordyceps_puppet")
    assert(inv:count("cordyceps") == 0, "the puppeteer should devour its host items")
    assert(p.stats:get("area") == area0 + 30, "two devoured hosts should give +30% area (" .. p.stats:get("area") - area0 .. ")")
    assert(p.steer, "the puppeteer should steer")
    -- it walks on its own with no input
    center()
    local x0, y0 = p.x, p.y
    run(1)
    assert((p.x - x0) ^ 2 + (p.y - y0) ^ 2 > 20 * 20, "cordyceps should walk you around")

    -- lice breed every wave
    inv:add("head_lice")
    local as1 = p.stats:get("attackSpeed")
    inv:trigger("onWaveStart", { world = world, player = p, wave = 6, procDepth = 0 })
    assert(Parasites.find(inv, "head_lice").level == 2, "lice should breed")
    assert(p.stats:get("attackSpeed") > as1, "more lice, more attack speed")
    assert(Parasites.count(inv) == 3, "three parasites")
    -- the max: no more are offered
    for _ = 1, 400 do assert(not Choices.pickDef(world, {}).parasite, "a fourth parasite was offered") end

    -- not edible
    assert(not require("src.game.inventory").edible(require("src.game.inventory").newItem("flu_virus")), "parasites can't be eaten")

    -- run save keeps them (with levels and feeding)
    local RunSave = require("src.game.runsave")
    local snap = RunSave.snapshot(game)
    assert(#snap.parasites == 3, "save should hold 3 parasites")
    local keepArea = p.stats:get("area")
    Parasites.purge(world)
    assert(Parasites.count(inv) == 0 and not p.steer, "purged")
    Parasites.restore(inv, snap.parasites)
    assert(Parasites.count(inv) == 3 and Parasites.find(inv, "head_lice").level == 2, "restore should bring them back")
    assert(p.stats:get("area") == keepArea, "restore should keep the feeding bonus")
    p.hp = p.stats:get("maxHp")

    -- the mushroom: sprouts after its delay, wilts at the next wave, purges when walked into
    world.parasiteSince = 0
    center()
    p.steer = nil       -- hold still (cordyceps would walk you into it)
    local m = Parasites.sprout(world, p.x + 45, p.y - 35, 1)
    run(0.5)
    assert(not m.dead and m.delay > 0, "mushroom should still be underground")
    run(1)
    assert(m.delay <= 0, "mushroom should be up")
    shot("parasites_mushroom")
    Parasites.onWaveStart(world, 6)
    run(1)
    assert(m.dead, "an uneaten mushroom should wilt when the next wave starts")
    center()
    local m2 = Parasites.sprout(world, p.x + 150, p.y)
    run(0.6)
    p.x, p.y = m2.x, m2.y
    run(0.1)
    for _ = 1, 60 do if m2.dead then break end p.x, p.y = m2.x, m2.y; run(0.05) end
    assert(m2.dead, ("walking into the mushroom should eat it (grow %s, d %.1f, delay %s, wilt %s)"):format(tostring(m2.st.grow), math.sqrt((p.x - m2.x) ^ 2 + (p.y - m2.y) ^ 2), tostring(m2.delay), tostring(m2.st.wilt)))
    assert(Parasites.count(inv) == 0, "the mushroom should purge every parasite")
    assert(math.abs(p.stats:get("maxHp") - hp0) < 1, "max HP should be back after the purge")
    assert(p.stats:get("damage") == dmg0, "damage should be back after the purge")
    assert(p.stats:get("area") == area0 - 0, "feeding bonus should go with the purge")

    -- every parasite can go in and come out without errors, and runs a few seconds
    for _, d in ipairs(defs) do
        inv:add(d.id)
        world:spawnRing(sp:pickEnemy(), 6, p.x, p.y, 60)
        world.flags.freezeAI = false
        run(1.5)
        world.flags.freezeAI = true
        Parasites.purge(world)
        world:clearEnemies()
        center()
    end
    -- what the item choice looks like with parasite cards in it
    local Inventory = require("src.game.inventory")
    local Choice = require("src.states.itemchoice")
    local ch = Choice.new(game, { count = 3, wave = 5 })
    ch.items = { Inventory.newItem("cordyceps_puppet"), Inventory.newItem("flu_virus"), Inventory.newItem("head_lice") }
    ch:refresh()
    State.push(ch)
    wait(1.2)
    shot("parasites_choice")
    State.pop()
    print("[selftest] parasites OK")
end
