-- Acts (src/game/acts.lua): a run plans three maps; starting wave 6 moves the run to act 2's map
-- with everything carried over; Travel Between Acts off keeps it on one map.
--   love . --selftest --acts   (saves selftest_act2.png)
local State = require("src.core.state")
local Settings = require("src.core.settings")
local Records = require("src.game.records")
local RunSave = require("src.game.runsave")

return function(wait, shot)
    Records.noSave = true
    RunSave.noSave = true
    local Game = require("src.states.game")
    local Acts = require("src.game.acts")
    local game = State.switch(Game.new({ mode = "run", character = "rhino_beetle", stage = "backyard", seed = 99 }))
    wait(0.2)
    local w = game.world
    assert(Acts.enabled(w), "a colony run should have acts")
    assert(#w.actRoute == 3 and w.actRoute[1] == "backyard", "route should start on the chosen map")
    assert(w.actRoute[2] ~= w.actRoute[1] and w.actRoute[3] ~= w.actRoute[2], "acts should be on different maps when several are open")
    assert(Acts.actOf(5) == 1 and Acts.actOf(6) == 2 and Acts.actOf(11) == 3 and Acts.actOf(20) == 3, "act numbers")
    -- the same seed plans the same route
    local again = Acts.plan(w)
    for i = 1, 3 do assert(again[i] == w.actRoute[i], "a seed should always plan the same route") end

    -- end of act 1: break after wave 5, with a bag and some KOs
    local sp = w.spawner
    sp.wave, sp.phase, sp.timer = 5, "break", math.huge
    w.kos, w.nectar = 321, 17
    w:giveItem("cactus_spine")
    local items = #w.player.inventory.order
    assert(Acts.travelsBefore(w, 6), "wave 6 should start on a new map")
    assert(Acts.nextLine(w), "the break should say where the colony goes")
    assert(not Acts.travelsBefore(w, 5) and not Acts.travelsBefore(w, 7), "only act boundaries travel")
    wait(0.2)
    shot("act_break")
    game:nextWave()
    local g2 = State.top()
    assert(g2 ~= game and g2.world, "starting wave 6 should move the run")
    local w2 = g2.world
    assert(w2.stage.id == w.actRoute[2], "act 2 should be on " .. w.actRoute[2] .. " (got " .. w2.stage.id .. ")")
    assert(w2.act == 2, "world.act should be 2")
    assert(w2.kos == 321 and w2.nectar == 17, "KOs and nectar carry over")
    assert(#w2.player.inventory.order == items, "the bag carries over")
    assert(w2.spawner.wave == 5 and w2.spawner.phase == "break", "the new map starts with a breather before wave 6")
    assert(not Acts.travelsBefore(w2, 6), "no second move for the same act")
    wait(1.0)
    shot("act2")
    g2:nextWave()
    assert(State.top() == g2 and w2.spawner.wave == 6 and w2.spawner.phase == "wave", "wave 6 starts on the new map")
    -- the victory screen tells the route back
    local V = require("src.states.victory")
    local ending = V.ending(w2, { wave = 15, first = true })
    print("[selftest] ending: " .. tostring(ending))
    assert(ending and ending:find(require("src.content").stages:get(w.actRoute[2]).name, 1, true), "the ending names the maps crossed")
    State.push(V.new(g2, { wave = 15, first = true }))
    wait(1.0)
    shot("victory_ending")
    State.pop()
    print("[selftest] act 2 on " .. w2.stage.id .. ", route " .. table.concat(w.actRoute, " > "))

    -- switched off: the run stays put
    Settings.set("travelActs", false)
    local g3 = State.switch(Game.new({ mode = "run", character = "rhino_beetle", stage = "backyard", seed = 99 }))
    wait(0.1)
    g3.world.spawner.wave, g3.world.spawner.phase = 5, "break"
    g3:nextWave()
    assert(State.top() == g3 and g3.world.stage.id == "backyard", "Travel Between Acts off should keep the map")
    Settings.set("travelActs", true)
    print("[selftest] acts OK")
end
