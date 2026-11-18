-- The guided tutorial (src/game/lessons.lua) and the Field Guide (src/states/fieldguide.lua).
--   love . --selftest --tutorial
-- Plays every lesson by doing what it asks (with test shortcuts for the button presses), checks
-- the run isn't tracked or saved, that it ends back on the title screen, and that the Field
-- Guide opens, hides systems not met yet, and shows them once met.
local State = require("src.core.state")
local Settings = require("src.core.settings")

return function(wait, shot)
    local Lessons = require("src.game.lessons")
    local Game = require("src.states.game")
    local Records = require("src.game.records")
    local runs0 = Records.get().runs
    local game = State.switch(Game.new({ mode = "run", character = "rhino_beetle", gameMode = "tutorial" }))
    wait(0.3)
    local world = game.world
    assert(world.lessons and Lessons.current(world).id == "move", "the tutorial should start on the move lesson")
    assert(not world.spawner.enabled, "the colony's own waves are off in the tutorial")
    assert(Records.get().runs == runs0, "the tutorial is not a tracked run")
    assert(not require("src.game.runsave").allowed(game), "the tutorial never saves")
    shot("tutorial_move")
    local p = world.player
    local function killAll()
        for i = 1, world.enemyCount do
            local e = world.enemies[i]
            if e and not e.dead then e.hp = 0 world:killEnemy(e) end
        end
    end
    local seen = {}
    for _ = 1, 60 * 90 do
        if world.lessons.finished then break end
        local l = Lessons.current(world)
        if not seen[l.id] then seen[l.id] = true; print("[tutorial] lesson " .. l.id) end
        local L = world.lessons.L
        if l.id == "move" then p.x = p.x + 3 if p.x > world.size - 40 then p.x = 40 end end
        if l.id == "dash" then L.dashed = true end
        if l.id == "special" then L.special = true killAll() end
        if l.id == "attack" or l.id == "swarm" or l.id == "elite" or l.id == "queen" then killAll() end
        if l.id == "nectar" then L.t = math.max(L.t, 15) end
        if l.id == "bag" then world.events:emit("bag_opened") end
        if l.id == "shop" then world.events:emit("shop_bought", {}) end
        if l.id == "frenzy" then world.events:emit("frenzy_unleashed", {}) killAll() end
        if l.id == "item" and State.top() ~= game then
            if l.id == "item" then shot("tutorial_item") end
            State.top().t = 10
            State.top():activate(1) State.top():activate(1)
        end
        if State.top() ~= game and State.top() ~= nil and State.top().entry then
            State.top().t = 10
            State.top():activate(1) State.top():activate(1)
        end
        if l.id == "elite" and not seen.panelShot then seen.panelShot = true wait(1) shot("tutorial_panel") end
        wait(1 / 60)
        if State.top() ~= game and not State.find(Game) then break end
    end
    for _, l in ipairs(Lessons.list) do assert(seen[l.id], "lesson never reached: " .. l.id) end
    for _ = 1, 120 do
        if not State.find(Game) then break end
        wait(1 / 60)
    end
    assert(not State.find(Game), "the tutorial should end on the title screen")
    assert(require("src.game.prefs").get().tutorialDone, "finishing the tutorial should be remembered")

    -- the Field Guide: systems not met yet stay hidden
    local Tutorial = require("src.game.tutorial")
    local savedSeen = Tutorial.seen
    Tutorial.seen = {}
    Settings.set("gentleStart", true)
    local FG = require("src.states.fieldguide")
    local fg = State.push(FG.new())
    wait(0.2)
    local hidden, shown = 0, 0
    for _, it in ipairs(fg.menu.items) do
        if it.page and not it.known then hidden = hidden + 1 assert(it.label == "? ? ?", "unmet page should be ? ? ?") end
        if it.page and it.known then shown = shown + 1 end
    end
    assert(hidden >= 5 and shown >= 15, ("guide pages: %d hidden, %d shown"):format(hidden, shown))
    fg.menu.focus = 3
    shot("fieldguide")
    State.pop()
    Tutorial.seen = { ["sys:events"] = true }
    fg = State.push(FG.new())
    for _, it in ipairs(fg.menu.items) do
        if it.page and it.page.system == "events" then assert(it.known, "a met system's page should show") end
    end
    State.pop()
    Tutorial.seen = savedSeen
    print("[selftest] tutorial ok")
end
