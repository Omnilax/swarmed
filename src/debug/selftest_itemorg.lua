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
    State.push(require("src.states.itemcatalogue").new())
    wait(0.5)
    shot("itemorg_catalogue")
    State.pop()
    print("[itemorg] " .. (fails == 0 and "OK" or (fails .. " failures")))
end
