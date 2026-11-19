-- UI tour:  love . --selftest --uitour
-- Opens every existing menu and overlay in turn and saves ui_<name>.png in the save folder,
-- so the look of the whole game can be checked by eye after a style change.
local State = require("src.core.state")

return function(wait, shot)
    local function tour(name, make, t)
        local ok, err = pcall(function()
            State.push(make())
            wait(t or 0.4)
            shot("ui_" .. name)
            State.pop()
        end)
        if not ok then print("[uitour] " .. name .. " FAILED: " .. tostring(err)) end
    end

    wait(4)
    shot("ui_menu")
    tour("settings", function() return require("src.states.settings").new() end)
    tour("charselect", function() return require("src.states.charselect").new() end)
    tour("catalogue", function() return require("src.states.catalogue").new() end)
    tour("modeselect", function() return require("src.states.modeselect").new() end)
    tour("burrow", function() return require("src.states.burrow").new() end)
    tour("fieldguide", function() return require("src.states.fieldguide").new() end)
    tour("records", function() return require("src.states.records").new() end)
    tour("cosmetics", function() return require("src.states.cosmetics").new() end)
    tour("itemcatalogue", function() return require("src.states.itemcatalogue").new() end)
    State.switch(require("src.states.menu").new())
    wait(0.6)
    shot("ui_menu_fade")

    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "run", character = "rhino_beetle" }))
    game.world.flags.god = true
    game.world.spawner:startWave(3)
    wait(3)
    for _ = 1, 4 do game.world.spawner:spawnGroup() end
    wait(2)
    shot("ui_hud")
    local inv = game.world.player.inventory
    for _, id in ipairs({ "static_antenna", "ember_gland" }) do pcall(inv.add, inv, id, 1) end
    tour("pause", function() return require("src.states.pause").new(game) end)
    tour("inventory", function() return require("src.states.inventory").new(game) end)
    tour("skilltree", function()
        local sk = game.world.player.skills
        if sk then sk.points = 6 end
        return require("src.states.skilltree").new(game)
    end)
    tour("shop", function()
        game.world.nectar = 400
        return require("src.states.shop").new(game)
    end, 0.6)
    tour("itemchoice", function()
        game.world.pendingChoice = nil
        return require("src.states.itemchoice").new(game, { count = 3, wave = 3 })
    end, 1.2)
    game.world.flags.god = false
    game.world.player.iframes = 0
    game.world.player:hurt(99999)
    wait(2.5)
    shot("ui_gameover")
    print("[uitour] done")
end
