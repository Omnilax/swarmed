-- Bug select (grid, family tabs, sections):  love . --selftest --charselect
-- Saves selftest_charselect_*.png at 1280x720 and at a phone-sized 800x450.
local State = require("src.core.state")
local Content = require("src.content")
local Prefs = require("src.game.prefs")
local Input = require("src.core.input")
local Families = require("src.config.bugfamilies")

return function(wait, shot)
    Prefs.get().favourites = {}
    Prefs.set("bugTab", "all")
    Prefs.set("filter", "all")
    Prefs.set("sort", "default")
    local CharSelect = require("src.states.charselect")
    local cs = State.push(CharSelect.new())
    local all = Content.characters:all()
    assert(#cs.list == #all, "every bug listed in All")
    -- every bug has a family and the All tab is grouped by it
    local lastOrder = 0
    for _, e in ipairs(cs.list) do
        local o = Families.of(e.def).order
        assert(o >= lastOrder, "All tab grouped by family (" .. e.def.id .. ")")
        lastOrder = o
    end
    assert(Families.of(Content.characters:get("stag_beetle")).id == "beetle", "beetle family")
    assert(Families.of(Content.characters:get("tarantula")).id == "spider", "spider family")
    assert(Families.of(Content.characters:get("scorpion")).id == "arachnid", "scorpion family")
    assert(Families.of(Content.characters:get("lobster")).id == "crustacean", "crustacean family")
    assert(Families.of(Content.characters:get("centipede")).id == "myriapod", "myriapod family")
    assert(Families.of(Content.characters:get("mantis")).id == "insect", "insect family")
    -- family tab
    cs:setTab("spider")
    for _, e in ipairs(cs.list) do assert(Families.of(e.def).id == "spider", "spider tab let " .. e.def.id .. " through") end
    assert(#cs.list >= 3, "spiders listed")
    cs:shiftTab(1)
    assert(cs.tab == "arachnid", "E moves to the next family")
    cs:setTab("all")
    -- grid navigation
    assert(cs:focusOn("rhino_beetle"), "focus by id")
    local f0 = cs.focus
    cs:step(1, 0)
    assert(cs.focus == f0 + 1, "right steps one tile")
    cs:step(0, 1)
    assert(cs.focus > f0 + 1, "down goes to a lower row")
    -- favourites get their own section first
    cs:focusOn("mantis")
    Input.press("ui_favourite")
    cs:update(1 / 60)
    Input.endFrame()
    assert(cs.list[1].def.id == "mantis" and cs.list[1].section == "favourites", "favourite pinned on top")
    cs:setTab("favourites")
    assert(#cs.list == 1, "favourites tab")
    cs:setTab("all")
    -- playstyle filter and sort
    cs:setStyle("tank")
    for _, e in ipairs(cs.list) do assert(e.def.playstyle == "tank", "style filter") end
    cs:setStyle("all")
    cs:setSort("speed")
    cs:focusOn("rhino_beetle")
    wait(1.6)
    shot("charselect_grid")
    cs:setSort("default")
    cs:setTab("beetle")
    cs:focusOn("stag_beetle")
    wait(1.2)
    shot("charselect_tab")
    cs:setTab("all")
    -- scroll to the bottom
    cs:focusOn(cs.list[#cs.list].def.id)
    wait(1.2)
    shot("charselect_bottom")
    -- locked bugs: dark silhouettes with a padlock, and what opens them
    local Unlocks = require("src.game.unlocks")
    local wasFree = Unlocks.free
    Unlocks.free = false
    cs:build()
    for i, e in ipairs(cs.list) do if not Unlocks.bug(e.def.id) then cs.focus = i cs:ensureVisible() break end end
    wait(1.0)
    shot("charselect_locked")
    Unlocks.free = wasFree
    cs:build()
    -- phone size
    love.window.setMode(800, 450)
    cs.layoutCache = nil
    cs:focusOn("rhino_beetle")
    Input.lastDevice = "touch"
    wait(1.5)
    shot("charselect_small")
    -- mouse: a tap on a tile highlights it first, the second tap would play
    local L = cs:layout()
    local t = L.tiles[cs.focus + 1]
    cs:mousepressed(L.grid.x + t.x + 5, L.grid.y + t.y - cs.scrollShown + 5, 1)
    assert(State.top() == cs, "first tap only highlights")
    -- a phone's bigger UI (src/core/touch.lua sets refHeight 480 on touch screens)
    local Theme = require("src.ui.theme")
    Theme.refHeight = 480
    cs.layoutCache = nil
    cs:focusOn("lobster")
    wait(1.2)
    shot("charselect_phone")
    Theme.refHeight = 720
    Input.lastDevice = "keyboard"
    love.window.setMode(1280, 720)
    Prefs.get().favourites = {}
    State.pop()
    print("[charselect] OK")
end
