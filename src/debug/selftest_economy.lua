-- Nectar economy:  love . --selftest --economy
-- Hyperbolic chance stacking and soft caps, cursed items, the scrapper, the nectar shop tab,
-- savings interest, and the economy surviving a save and resume.
local State = require("src.core.state")
local Inventory = require("src.game.inventory")
local Economy = require("src.game.economy")
local Choices = require("src.game.choices")
local Stats = require("src.game.stats")
local Content = require("src.content")

return function(wait, shot)
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "run", character = "rhino_beetle" }))
    local world = game.world
    world.flags.god = true
    world.spawner.enabled = false
    world.pendingChoice = nil
    wait(0.3)
    local p = world.player
    local inv = p.inventory
    local Choice = require("src.states.itemchoice")

    ------------------------------------------------------------------------------------------
    -- Hyperbolic stacking
    assert(math.abs(Inventory.stackChance(0.3, 1) - 0.3) < 1e-9, "one roll should be the chance itself")
    local prev = 0
    for m = 1, 40 do
        local c = Inventory.stackChance(0.5, m)
        assert(c < 1 and c > prev, "stacked chance must grow but never reach 100%")
        prev = c
    end
    assert(Inventory.stackChance(0.5, 2) - 0.5 > Inventory.stackChance(0.5, 3) - Inventory.stackChance(0.5, 2),
        "each extra roll must add less than the one before")
    -- luck can no longer push a chance past 100%
    p.stats:addModifier("test:luck", "luck", 500, 0)
    local rose = Content.items:require("rose_thorn")
    local ch = inv:procChance(rose.procs[1], 1)
    assert(ch < 1 and ch > 0.9, "50% chance with huge luck should be high but below 100% (got " .. ch .. ")")
    p.stats:removeSource("test:luck")
    -- chanceStack: copies roll a non-scaling proc more often
    local snail = Content.items:require("snail_shell").procs[1]
    local c1, c3 = inv:procChance(snail, 1, 1), inv:procChance(snail, 3, 1)
    assert(math.abs(c1 - 0.15) < 1e-9 and c3 > c1 and c3 < 0.45, "chanceStack should raise a chance on the curve")
    -- dodge soft cap: a point is a point up to 30, then it creeps toward 60
    p.stats:addModifier("test:dodge", "dodge", 20, 0)
    assert(math.abs(p.stats:get("dodge") - 20) < 1e-6, "dodge below the knee should be untouched")
    p.stats:removeSource("test:dodge")
    p.stats:addModifier("test:dodge", "dodge", 200, 0)
    local d = p.stats:get("dodge")
    assert(d > 50 and d < 60, "dodge should creep toward 60 without reaching it (got " .. d .. ")")
    p.stats:removeSource("test:dodge")
    print("[economy] hyperbolic stacking OK")

    ------------------------------------------------------------------------------------------
    -- Cursed items
    local cursed = {}
    for _, def in ipairs(Content.items:all()) do
        if def.rarity == "cursed" then
            cursed[#cursed + 1] = def.id
            assert(def.curse and def.curse ~= "", def.id .. " has no curse text")
        end
    end
    assert(#cursed >= 6, "expected at least 6 cursed items")
    -- they show up in item choices from wave 3, never as a gift
    world.spawner.wave = 5
    local seen = false
    for _ = 1, 600 do if Choices.pickDef(world, {}).rarity == "cursed" then seen = true break end end
    assert(seen, "cursed items never rolled in item choices")
    for _ = 1, 300 do assert(world:rollItem().def.rarity ~= "cursed", "a cursed item was gifted") end
    -- Hungry Tapeworm: eating no longer heals
    inv:clear()
    inv:add("hungry_tapeworm")
    assert(not Inventory.edible(Inventory.newItem("hungry_tapeworm")), "cursed items must not be edible")
    p.hp = 10
    local healed = inv:eat(Inventory.newItem("royal_jelly"))
    assert(healed == 0 and p.hp == 10, "Hungry Tapeworm should stop eating from healing")
    inv:clear()
    p.hp = p.stats:get("maxHp")
    -- Fool's Gold Scarab: one card fewer; Queen's Pheromone: one more and faster ants
    inv:add("fools_gold_scarab")
    local cfew = Choice.new(game, { count = 3, wave = 5 })
    assert(#cfew.items == 2, "Fool's Gold Scarab should take a card away")
    inv:clear()
    inv:add("queens_pheromone")
    local cmore = Choice.new(game, { count = 3, wave = 5 })
    assert(#cmore.items == 4, "Queen's Pheromone should add a card")
    assert(math.abs(inv:sum("enemySpeed") - 0.2) < 1e-9, "Queen's Pheromone should speed ants up")
    inv:clear()
    -- Glass Wings: -40% Max HP
    local hp0 = p.stats:get("maxHp")
    inv:add("glass_wings")
    assert(math.abs(p.stats:get("maxHp") - hp0 * 0.6) < 0.01, "Glass Wings should cut Max HP")
    inv:clear()
    -- Parasitoid Egg grows each wave start
    inv:add("parasitoid_egg")
    local dmg0 = p.stats:get("damage")
    inv:trigger("onWaveStart", { world = world, player = p, wave = 5, procDepth = 0 })
    inv:trigger("onWaveStart", { world = world, player = p, wave = 6, procDepth = 0 })
    assert(math.abs(p.stats:get("damage") - dmg0 - 12) < 1e-6, "Parasitoid Egg should grow")
    print("[economy] cursed items OK")

    ------------------------------------------------------------------------------------------
    -- Scrapper
    inv:clear()
    Economy.state(world).growth = {}
    world.nectar = 0
    local item = Inventory.newItem("rhino_horn")
    local n, rr = Economy.scrapValue(world, item)
    assert(n > 0, "scrapping should pay nectar")
    local rerolls = Choices.state(world).rerolls
    local got, gotR = Economy.scrap(world, item)
    assert(got == n and Economy.nectar(world) == n, "scrap did not pay")
    assert((Choices.state(world).rerolls == rerolls + 1) == rr, "rare scrap reroll wrong")
    local cn = Economy.scrapValue(world, Inventory.newItem("glass_wings"))
    assert(cn == 0, "cursed items scrap for nothing")
    -- the bag screen: a cursed item can't be eaten, only scrapped
    inv:add("glass_wings")
    inv:add("chitin_plate")
    local bag = State.push(require("src.states.inventory").new(game))
    wait(0.3)
    bag:layout()
    local e
    for _, o in ipairs(inv.bag) do if o.item.id == "glass_wings" then e = o end end
    bag:eat({ kind = "bag", x = e.x, y = e.y })
    assert(inv:count("glass_wings") == 1, "a cursed item was eaten")
    shot("economy_bag")
    assert(bag:scrap({ kind = "bag", x = e.x, y = e.y }) and inv:count("glass_wings") == 0, "scrapping a cursed item failed")
    for _, o in ipairs(inv.bag) do if o.item.id == "chitin_plate" then e = o end end
    local before = Economy.nectar(world)
    bag:scrap({ kind = "bag", x = e.x, y = e.y })
    assert(Economy.nectar(world) > before and inv:count("chitin_plate") == 0, "scrapping from the bag did not pay")
    bag:close()
    print("[economy] scrapper OK")

    ------------------------------------------------------------------------------------------
    -- Interest
    world.spawner.wave = 4
    world.nectar = 100
    local want = Economy.interestPreview(world)
    assert(want == math.min(Economy.interestCap(world), 10), "interest preview wrong")
    world.nectar = 0
    assert(Economy.interestPreview(world) == 0, "no savings, no interest")

    ------------------------------------------------------------------------------------------
    -- Shop
    inv:clear()
    world.nectar = 400
    world.economy.shop = nil
    local c = State.push(Choice.new(game, { count = 3, wave = 4 }))
    assert(Economy.nectar(world) == 400 + want or Economy.nectar(world) > 400, "interest was not paid on open")
    wait(1.0)
    assert(c.hasShop and c.shop and #c.shop.offers == 3, "shop should have 3 offers")
    for _, o in ipairs(c.shop.offers) do
        assert(o.price > 0, "offer has no price")
        if o.kind == "item" then for _, it in ipairs(c.items) do assert(it.id ~= o.item.id, "shop repeats a free card") end end
    end
    c:setTab("shop")
    assert(c.tab == "shop", "shop tab did not open")
    wait(0.2)
    shot("economy_shop")
    -- buy a boost: two presses, nectar goes down, the stat goes up
    local bi
    for i, o in ipairs(c.shop.offers) do if o.kind == "boost" then bi = i end end
    local bo = c.shop.offers[bi]
    local sv = p.stats:get(bo.boost.stat)
    local nb = Economy.nectar(world)
    c:activate(bi)
    assert(c.armed == bi and not bo.sold, "first press should only pick the offer")
    c:activate(bi)
    assert(bo.sold and Economy.nectar(world) == nb - bo.price, "boost purchase failed")
    assert(p.stats:get(bo.boost.stat) > sv, "boost did not raise " .. bo.boost.stat)
    -- buy an item: it goes in the bag
    local ii
    for i, o in ipairs(c.shop.offers) do if o.kind == "item" then ii = i break end end
    local io = c.shop.offers[ii]
    c:activate(ii); c:activate(ii)
    assert(io.sold and inv:count(io.item.id) >= 1, "item purchase failed")
    -- lock the other item, reroll: price climbs, locked and sold stay
    local li
    for i, o in ipairs(c.shop.offers) do if o.kind == "item" and not o.sold then li = i end end
    local p1 = Economy.rerollPrice(world)
    local nr = Economy.nectar(world)
    assert(c:reroll(), "shop reroll failed")
    assert(Economy.nectar(world) == nr - p1 and Economy.rerollPrice(world) > p1, "reroll should cost and get dearer")
    assert(c.shop.offers[ii].sold and c.shop.offers[bi].sold, "reroll moved a sold offer")
    -- everything sold or locked: nothing to reroll
    local lockedKey = c.shop.offers[li].key
    c:toggleLock(li)
    assert(not c:reroll(), "reroll with every offer kept should fail")
    wait(0.3)
    shot("economy_shop_after")
    -- poor: can't buy
    world.nectar = 0
    assert(not c:reroll(), "reroll with no nectar should fail")
    -- back to the free pick, take a card: nothing affordable, so the screen closes
    c:setTab("pick")
    c:activate(1); c:activate(1)
    assert(State.top() ~= c, "taking the free pick with nothing to buy should close")
    -- the locked offer comes back in the next shop
    world.spawner.wave = 5
    local found = false
    for _, o in ipairs(Economy.shop(world).offers) do if o.key == lockedKey and o.locked then found = true end end
    assert(found, "locked shop offer did not come back")
    -- with nectar left, the free pick moves on to the shop
    world.spawner.wave = 6
    world.nectar = 500
    local c2 = State.push(Choice.new(game, { count = 3, wave = 6 }))
    wait(1.0)
    c2:activate(1); c2:activate(1)
    assert(State.top() == c2 and c2.tab == "shop" and c2.picked, "pick should move on to the shop")
    shot("economy_shop_done")
    c2:activate(c2:skipIndex())
    assert(State.top() ~= c2, "DONE should close the shop")
    print("[economy] shop OK")

    ------------------------------------------------------------------------------------------
    -- Save and resume keep boosts and curse growth
    local RunSave = require("src.game.runsave")
    Economy.state(world).growth.parasitoid_egg = 3
    local snap = RunSave.snapshot(game)
    assert(snap.economy and snap.economy.boosts[bo.boost.stat], "economy not saved")
    local game2 = State.switch(Game.new({ mode = "run", character = "rhino_beetle" }))
    wait(0.2)
    local s0 = game2.world.player.stats:get(bo.boost.stat)
    RunSave.restore(game2.world, snap)
    assert(game2.world.player.stats:get(bo.boost.stat) > s0, "shop boost not restored")
    assert(game2.world.economy.growth.parasitoid_egg == 3, "curse growth not restored")
    print("[economy] save OK")
    print("[economy] OK")
end
