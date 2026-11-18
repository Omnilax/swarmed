-- Keepsakes (src/game/keepsakes.lua): bought in the Burrow, picked in mode select, applied as a
-- trade in the run, kept by a saved run, ignored by the daily run.
--   love . --selftest --keepsakes   (saves selftest_keepsake_row.png, selftest_burrow_keepsakes.png)
local State = require("src.core.state")
local Records = require("src.game.records")

return function(wait, shot)
    Records.noSave = true
    local Keepsakes = require("src.game.keepsakes")
    local Amber = require("src.game.amber")
    local Game = require("src.states.game")
    -- the Burrow has a Keepsakes shelf
    local found
    for _, sh in ipairs(Amber.shelves()) do if sh.id == "keepsakes" then found = sh end end
    assert(found and #found.list == #Keepsakes.list, "the Burrow should sell keepsakes")

    local function run(params)
        params.mode, params.character, params.seed = "run", "rhino_beetle", 3
        local g = State.switch(Game.new(params))
        wait(0.1)
        return g.world
    end
    -- none chosen: the bug as it is
    Keepsakes.choose(nil)
    local base = run({})
    local hp, speed = base.player.stats:get("maxHp"), base.player.stats:get("moveSpeed")
    assert(base.keepsake == nil, "no keepsake by default")

    -- Snail Shell: more health, slower
    assert(Keepsakes.choose("snail_shell"), "choosing an owned keepsake")
    local w = run({})
    assert(w.keepsake == "snail_shell", "the run carries the chosen keepsake")
    assert(w.player.stats:get("maxHp") > hp and w.player.stats:get("moveSpeed") < speed, "Snail Shell is a trade")
    -- a saved run keeps its own, whatever is chosen now
    local snap = require("src.game.runsave").snapshot(State.top())
    Keepsakes.choose("wasp_sting")
    local params = require("src.game.runsave").params(snap)
    local w2 = run(params)
    assert(w2.keepsake == "snail_shell", "a resumed run keeps its keepsake")

    -- Honey Jar: a head start of nectar, less earned
    Keepsakes.choose("honey_jar")
    local w3 = run({})
    assert(w3.nectar == 30, "Honey Jar starts with 30 nectar")
    w3:addNectar(20)
    assert(w3.nectar == 30 + 17, "Honey Jar earns 15% less nectar")
    -- the daily run ignores keepsakes
    local d = require("src.game.daily").params()
    local g = State.switch(Game.new(d))
    wait(0.1)
    assert(g.world.keepsake == nil, "the daily run takes no keepsake")

    -- the row in mode select
    State.switch(require("src.states.modeselect").new())
    local ms = State.top()
    for i, it in ipairs(ms.menu.items) do if it.keepsake then ms.menu.focus = i end end
    wait(0.3)
    shot("keepsake_row")
    local b = require("src.states.burrow").new()
    State.switch(b)
    wait(0.2)
    shot("burrow_keepsakes")
    Keepsakes.choose(nil)
    print("[selftest] keepsakes OK")
end
