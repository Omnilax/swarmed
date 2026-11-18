-- The Wiki (Field Guide > Wiki): every section builds, every page writes without an error, the
-- pages scroll, and it works on a phone held sideways and upright.
--   love . --selftest --wiki   (saves selftest_wiki_*.png)
local State = require("src.core.state")
local Settings = require("src.core.settings")
local Records = require("src.game.records")
local Theme = require("src.ui.theme")
local Touch = require("src.core.touch")
local Wiki = require("src.game.wiki")
local WikiState = require("src.states.wiki")

return function(wait, shot)
    Records.noSave = true
    Settings.set("unlockAll", true)

    -- every page of every section, written and drawn once
    local total = 0
    for i, s in ipairs(Wiki.SECTIONS) do
        local entries = Wiki.entries(i)
        assert(#entries > 0, "wiki section " .. s.id .. " is empty")
        for _, e in ipairs(entries) do
            local ok, blocks = pcall(e.build, e.def)
            assert(ok, "wiki page " .. s.id .. "/" .. tostring(e.title) .. " failed: " .. tostring(blocks))
            assert(type(blocks) == "table" and #blocks > 0, "wiki page " .. s.id .. "/" .. tostring(e.title) .. " is empty")
            total = total + 1
        end
    end
    print("[selftest] wiki: " .. total .. " pages in " .. #Wiki.SECTIONS .. " sections")
    assert(Wiki.howItWorks("content/behaviors/bee_bumble.lua"):find("Bumblebee"), "behaviour notes not read from the file")
    assert(not Wiki.howItWorks("content/behaviors/bee_bumble.lua"):find("params"), "params left in the behaviour notes")

    -- the Field Guide links to it
    local fg = State.switch(require("src.states.fieldguide").new())
    local found
    for _, it in ipairs(fg.menu.items) do if it.label == "Enemies" and it.link then found = it end end
    assert(found, "the Field Guide has no Wiki section buttons")
    found.onActivate()
    wait(0.1)
    assert(getmetatable(State.top()) == WikiState, "Field Guide > Wiki > Enemies did not open the wiki")
    local wiki = State.top()
    assert(Wiki.SECTIONS[wiki.section].id == "enemies", "opened the wrong section")

    -- desktop: list and page side by side, a section per tab, the page scrolls
    for _, id in ipairs({ "bugs", "enemies", "items", "world", "notes" }) do
        for i, s in ipairs(Wiki.SECTIONS) do if s.id == id then wiki:setSection(i) end end
        wiki.menu:move(1)
        wiki.menu:move(1)
        wait(0.15)
        shot("wiki_" .. id)
    end
    wiki:setSection(1)
    wiki:openTitle("Mantis")
    wait(0.1)
    assert(wiki.pageH and wiki.viewH, "page height not measured")
    if wiki.pageH > wiki.viewH then
        wiki:scrollBy(99999)
        wait(0.1)
        assert(wiki.scroll > 0 and wiki.scroll <= wiki.pageH - wiki.viewH + 1, "page did not scroll")
        shot("wiki_scrolled")
    end
    -- tab clicks switch sections
    local r = wiki.tabRects[3]
    wiki:mousepressed(r[1] + 4, r[2] + 4, 1)
    assert(wiki.section == 3, "clicking a tab did not switch section")

    -- phones: sideways keeps both panes, upright shows the list, then the page with a Back button
    local ww, wh, wflags = love.window.getMode()
    local ref, mobile = Theme.refHeight, Touch.mobile
    Theme.refHeight, Touch.mobile = 480, true
    Settings.set("touchControls", "on")
    love.window.setMode(844, 390, wflags)
    wiki:setSection(1)
    wiki.menu:move(1)
    wait(0.15)
    shot("wiki_phone_wide")
    love.window.setMode(390, 844, wflags)
    wait(0.1)
    assert(wiki:narrow(), "an upright phone should get the one-pane wiki")
    shot("wiki_phone_list")
    wiki:openTitle("Mantis")
    wait(0.15)
    assert(wiki.open, "picking an entry on a phone did not open its page")
    shot("wiki_phone_page")
    local b = wiki.backRect
    assert(b, "no Back button on the phone page")
    wiki:mousepressed(b[1] + 4, b[2] + 4, 1)
    assert(not wiki.open, "Back did not close the page")
    love.window.setMode(ww, wh, wflags)
    Theme.refHeight, Touch.mobile = ref, mobile
    Settings.set("touchControls", "auto")

    -- from the pause menu too (over a run)
    local game = State.switch(require("src.states.game").new({ mode = "run", character = "mantis", seed = 5 }))
    wait(0.2)
    State.push(WikiState.new({ section = "items", inRun = true }))
    wait(0.15)
    shot("wiki_inrun")
    State.pop()
    Settings.set("unlockAll", false)
    print("[selftest] wiki OK")
end
