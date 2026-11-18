-- Bug Creator round 3 and the tidied menus:  love . --selftest --creator2
-- Saves selftest_c2_*.png.
local State = require("src.core.state")
local Content = require("src.content")

return function(wait, shot)
    -- 1. main menu: short main page, Collection page, Continue on top when a run is saved
    local RunSave = require("src.game.runsave")
    local peek, describe = RunSave.peek, RunSave.describe
    RunSave.peek = function() return { fake = true } end
    RunSave.describe = function() return "Mantis, wave 7" end
    local mm = State.switch(require("src.states.menu").new())
    wait(0.4)
    shot("c2_menu_saved")
    local labels = {}
    for _, it in ipairs(mm.menu.items) do labels[#labels + 1] = it.label end
    assert(labels[1]:find("^Continue"), "a saved run should be the first row")
    assert(labels[2] == "New Run", "Play reads New Run when a run is saved")
    assert(#mm.menu.items <= 9, "the main page should stay short, has " .. #mm.menu.items)
    RunSave.peek, RunSave.describe = peek, describe
    mm:buildItems()
    assert(mm.menu.items[1].label == "Play", "no save -> Play first")
    local col
    for _, it in ipairs(mm.menu.items) do if it.label:find("^Collection") then col = it end end
    col.onActivate()
    wait(0.3)
    shot("c2_menu_collection")
    local names = {}
    for _, it in ipairs(mm.menu.items) do names[it.label] = true end
    assert(names["Bug Catalogue"] and names["Item Catalogue"] and names["Records"] and names["Cosmetics"] and names["Back"],
        "Collection lists the catalogues, records and cosmetics")
    mm.menu.opts.onBack()
    assert(mm.menu:focused().label:find("^Collection"), "Back lands on the Collection row")

    -- 2. mode select: grouped under headings
    local ms = State.push(require("src.states.modeselect").new())
    wait(0.3)
    shot("c2_modeselect")
    local heads = 0
    for _, it in ipairs(ms.menu.items) do if it.type == "header" then heads = heads + 1 end end
    assert(heads == 3, "three mode headings, got " .. heads)
    assert(ms.menu:focused() and ms.menu:focused().mode, "focus starts on a mode")
    State.pop()

    if _G.CREATOR2_MORE then _G.CREATOR2_MORE(wait, shot) end
    State.switch(require("src.states.menu").new())
end
