-- Molting, tag set bonuses, brood cell chests and the aphid matriarch:  love . --selftest --molts
local State = require("src.core.state")
local Content = require("src.content")

return function(wait, shot)
    assert(Content.molts:count() >= 12, "molting recipes missing")
    for _, r in ipairs(Content.molts:all()) do
        local d = Content.items:require(r.into)
        assert(d.molted, r.into .. " should be a molted item")
    end
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "run", character = "rhino_beetle" }))
    local world = game.world
    local p, inv = world.player, world.player.inventory
    world.flags.god = true
    world.spawner.enabled = false
    wait(0.3)
    local function run(t) for _ = 1, math.floor(t * 60) do world:update(1 / 60) end end
    local Molting = require("src.game.molting")
    local Inventory = require("src.game.inventory")

    -- molted items never show up in item choices
    local Choices = require("src.game.choices")
    for _ = 1, 200 do
        for _, it in ipairs(Choices.roll(world, 3, "rare")) do assert(not it.def.molted, "molted item dealt: " .. it.id) end
    end

    -- two recipe pieces apart: no molt; touching: seams glow and they molt after a queen wave
    inv:clear()
    inv:placeInBag(Inventory.newItem("ember_gland"), 0, 0)
    local bomb = Inventory.newItem("bombardier_gland")
    inv:placeInBag(bomb, 5, 2)
    assert(#Molting.ready(inv) == 0, "apart pieces should not be ready")
    inv:clear()
    inv:placeInBag(Inventory.newItem("ember_gland"), 0, 0)
    inv:placeInBag(Inventory.newItem("bombardier_gland"), 1, 0)
    inv:placeInBag(Inventory.newItem("dew_drop"), 0, 1)
    local seams, ready = Molting.seams(inv)
    assert(#ready == 1 and ready[1].recipe.into == "magma_gland", "touching pieces should be ready")
    local moltSeam = false
    for _, s in ipairs(seams) do if s.kind == "molt" then moltSeam = #Molting.sharedEdges(s.a, s.b) > 0 end end
    assert(moltSeam, "no glowing seam between the pieces")
    -- a 3-piece recipe with two in place shows a dim (partial) seam
    inv:clear()
    inv:placeInBag(Inventory.newItem("royal_jelly"), 0, 0)
    inv:placeInBag(Inventory.newItem("sugar_cube"), 2, 0)
    local s2 = Molting.seams(inv)
    assert(#s2 == 1 and s2[1].kind == "partial", "partial seam missing")
    inv:placeInBag(Inventory.newItem("honeycomb"), 3, 0)
    assert(#Molting.ready(inv) == 1, "3-piece recipe should be ready")
    State.push(require("src.states.inventory").new(game))
    wait(0.3)
    shot("molt_seams")
    State.pop()

    -- a queen dies: chest drops; the wave clears: they molt and the chest opens
    local queenDef = Content.enemies:filter(function(d) return d.boss end)[1]
    local q = world:spawnEnemy(queenDef.id, p.x + 30, p.y)
    require("src.game.combat").damage(world, q, 1e6)
    run(1)   -- (hitstop and slow motion eat the first moments)
    assert(world.queenThisWave, "queen kill not noted")
    assert(world.props:count("brood_cell") == 1, "queen dropped no brood cell")
    world:clearEnemies()
    world.events:emit("wave_cleared", 1)
    assert(inv:count("queens_comb") == 1 and inv:count("royal_jelly") == 0, "did not molt")
    assert(world.molts == 1, "molt not counted")
    assert(world.pendingChests and #world.pendingChests == 1, "chest did not open at wave end")
    local xp0 = world.xp
    wait(0.2)
    assert(State.top() ~= game, "chest fanfare did not show")
    shot("chest_roll")
    wait(2.6)
    shot("chest_landed")
    State.top():close()
    wait(0.2)
    while State.top() ~= game do State.pop() end
    print(("[molts] chest xp %d -> %d, levelups %s"):format(xp0, world.xp, tostring(world.levelups ~= nil)))

    -- chest odds: luck shifts toward 5
    local Chest = require("src.states.broodcell")
    local tally = { 0, 0, 0 }
    for _ = 1, 3000 do local _, i = Chest.roll(world, "queen"); tally[i] = tally[i] + 1 end
    assert(tally[1] > tally[3] and tally[3] > 0, "odd chest odds")
    print(("[molts] chest odds 1/3/5: %d %d %d"):format(tally[1], tally[2], tally[3]))

    -- treasure ant drops a chest too
    world.rewards:treasureCaught(p.x + 20, p.y)
    run(0.1)
    assert(world.props:count("brood_cell") == 1, "treasure ant dropped no chest")
    world.props:clear("brood_cell")

    -- tag sets: three touching offense items give Warpath
    inv:clear()
    local dmg0 = p.stats:get("damage")
    inv:placeInBag(Inventory.newItem("salt_crystal"), 0, 0)
    inv:placeInBag(Inventory.newItem("sugar_cube"), 1, 0)
    inv:placeInBag(Inventory.newItem("pine_needle"), 2, 0)
    local found
    for _, s in ipairs(inv.sets) do if s.tag == "offense" then found = s end end
    assert(found and found.tier == 1, "offense set missing")
    inv:clear()
    inv:placeInBag(Inventory.newItem("salt_crystal"), 0, 0)
    inv:placeInBag(Inventory.newItem("sugar_cube"), 4, 0)
    inv:placeInBag(Inventory.newItem("pine_needle"), 8, 0)
    for _, s in ipairs(inv.sets) do assert(s.tag ~= "offense", "apart items made a set") end
    print("[molts] sets ok, damage base " .. dmg0)

    -- the aphid matriarch clones an item by eating one of the same rarity
    inv:clear()
    local a = inv:placeInBag(Inventory.newItem("quartz_crystal"), 0, 0)
    local b = inv:placeInBag(Inventory.newItem("leech"), 3, 0)
    inv:placeInBag(Inventory.newItem("dew_drop"), 6, 0)
    world.director:start("aphid_matriarch")
    local m = world.props:find("clone_aphid")[1]
    assert(m, "matriarch did not come")
    m.x, m.y = p.x, p.y
    run(0.1)
    wait(0.2)
    local Dup = State.top()
    assert(Dup ~= game and Dup.aphid == m, "cloning screen did not open")
    wait(0.5)
    Dup:pick(inv:entryAt(6, 0))
    assert(not Dup.target, "dew drop has no partner, should not be pickable")
    Dup:pick(a)
    Dup:pick(b)
    shot("duplicate")
    Dup:pick(b)
    wait(0.1)
    while State.top() ~= game do State.pop() end
    assert(inv:count("quartz_crystal") == 2 and inv:count("leech") == 0, "clone failed")
    assert(m.leaving, "matriarch should leave after a clone")

    -- recipe book page
    State.push(require("src.states.records").new())
    local R = State.top()
    R:setTab(4)
    wait(0.3)
    shot("recipe_book")
    State.pop()
    print("[molts] ok")
end
