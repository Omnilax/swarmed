-- Item organisation test:  love . --selftest --itemorg
-- Every item has a category; the bag sorts by category; the shop and catalogue group by it.
-- Saves selftest_itemorg_<screen>.png (bag, shop, item choice, catalogue) to check icons by eye.
local State = require("src.core.state")
local Content = require("src.content")

return function(wait, shot)
    local fails = 0
    local function check(ok, msg)
        if not ok then fails = fails + 1 print("[itemorg] FAIL " .. msg) end
    end

    local Categories = require("src.config.categories")
    for _, def in ipairs(Content.items:all()) do
        check(Categories.index[def.category], def.id .. " has no valid category")
    end
    wait(2)
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "run", character = "rhino_beetle" }))
    game.world.flags.god = true
    wait(1)
    local inv = game.world.player.inventory
    for _, id in ipairs({ "sugar_cube", "dew_drop", "salt_crystal", "chitin_plate", "coffee_bean", "honeydew",
        "static_antenna", "four_leaf_clover", "spider_fang", "acorn_cap", "rotifer", "gnat_swarm", "amber",
        "alarm_pheromone", "maple_seed", "pine_needle" }) do
        pcall(inv.add, inv, id, 1)
    end
    -- SORT by category: reading the bag left to right, top to bottom, categories never go back
    check(inv:autoSort("category"), "category sort failed to pack")
    local first = {}
    for _, e in ipairs(inv.bag) do
        local k = e.y * inv.cols + e.x
        local r = Categories.rank(e.item.def.category)
        if not first[r] or k < first[r] then first[r] = k end
    end
    local prev = -1
    for r = 1, #Categories.order do
        if first[r] then check(first[r] > prev, "category " .. Categories.order[r] .. " starts before the one above it"); prev = first[r] end
    end
    love.mouse.setPosition(5, 700)
    State.push(require("src.states.inventory").new(game))
    wait(0.5)
    shot("itemorg_bag")
    State.pop()
    game.world.nectar = 500
    local Economy = require("src.game.economy")
    local shop = Economy.restock(game.world)
    check(shop and #shop.offers > 0, "shop has no offers")
    if shop then
        local last = 0
        for _, o in ipairs(shop.offers) do
            if o.kind == "item" then
                local r = Categories.rank(o.def.category)
                check(r >= last, "shop offers not in category order")
                last = r
            end
        end
    end
    State.push(require("src.states.shop").new(game))
    wait(0.6)
    shot("itemorg_shop")
    State.pop()
    game.world.pendingChoice = nil
    State.push(require("src.states.itemchoice").new(game, { count = 3, wave = 3 }))
    wait(1.2)
    shot("itemorg_choice")
    State.pop()
    -- batch-2 item hooks (2026-11-18)
    do
        local world, p = game.world, game.world.player
        local ItemFx = require("src.game.itemfx")
        -- Cuckoo Wasp Shell: the first reroll after a restock is free
        pcall(inv.add, inv, "cuckoo_wasp_shell", 1)
        Economy.restock(world)
        check(Economy.rerollPrice(world) == 0, "cuckoo wasp shell: first reroll not free")
        world.nectar = 0
        Economy.rerollShop(world)
        check(Economy.rerollPrice(world) > 0, "cuckoo wasp shell: second reroll should cost")
        -- Seed Cache: nectar at each wave clear
        pcall(inv.add, inv, "seed_cache", 1)
        local s = Economy.state(world)
        s.interestWave = -1
        local before = Economy.nectar(world)
        Economy.payInterest(world)
        check(Economy.nectar(world) >= before + 3, "seed cache paid nothing at the wave clear")
        -- Pill Bug Plates' guard: bites hurt far less while curled
        world.flags.god = false
        p.iframes = 0; p.hp = 100
        p:hurt(20, "test")
        local plain = 100 - p.hp
        ItemFx.guard(p, 0.3, 3)
        p.iframes = 0; p.hp = 100
        p:hurt(20, "test")
        local curled = 100 - p.hp
        check(curled < plain * 0.5, ("guard did not cut damage (%.1f vs %.1f)"):format(curled, plain))
        p.itemGuardT = 0
        world.flags.god = true
        p.hp = p.stats:get("maxHp")
        -- Ladybug Shell: with enough copies every card rolls above common
        local Choices = require("src.game.choices")
        inv.sums = nil
        inv.counts.ladybug_spots = 10
        inv.order[#inv.order + 1] = "ladybug_spots"
        inv.sums = nil
        local commons = 0
        for _ = 1, 20 do
            for _, it in pairs(Choices.roll(world, 3)) do if it.def.rarity == "common" then commons = commons + 1 end end
        end
        check(commons == 0, "ladybug shell: " .. commons .. " common cards with a full bump")
        inv:recount()
        -- Cuckoo Egg hatches into a legendary after 3 more waves
        pcall(inv.add, inv, "cuckoo_egg", 1)
        check(inv:count("cuckoo_egg") == 1, "cuckoo egg did not go in the bag")
        for k = 1, 4 do inv:trigger("onWaveStart", { world = world, player = p, wave = k, procDepth = 0 }) end
        wait(0.3)
        check(inv:count("cuckoo_egg") == 0, "cuckoo egg did not hatch")
        local legend = false
        for _, e in ipairs(inv.bag) do if e.item.def.rarity == "legendary" then legend = true end end
        check(legend, "cuckoo egg hatched no legendary")
        -- every new item's icon exists and fills its cells
        local Sprites = require("src.gfx.sprites")
        for _, id in ipairs({ "flea_legs", "springtail_tail", "snail_slime", "nymph_gill", "thistle_down", "monarch_wing",
            "spittlebug_foam", "sundew_leaf", "antlion_sand", "bolas_thread", "pea_pod", "seed_cache", "pollen_basket",
            "ladybug_spots", "cuckoo_wasp_shell", "truffle", "hercules_horn", "tiger_beetle_jaw", "velvet_ant_sting",
            "smoldering_bark", "pill_bug_plates", "oak_gall", "aphid_herd", "bee_bread", "cuckoo_egg", "zombie_fungus",
            "driver_ant_mandible" }) do
            local def = Content.items.byId[id]
            check(def, "missing item " .. id)
            if def then check(Sprites.get(def.icon), "missing icon for " .. id) end
        end
        print("[itemorg] batch-2 hooks checked")
    end
    State.push(require("src.states.itemcatalogue").new())
    wait(0.5)
    shot("itemorg_catalogue")
    State.pop()
    print("[itemorg] " .. (fails == 0 and "OK" or (fails .. " failures")))
end
