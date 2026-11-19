-- Maps with their own wildlife (content/stages `fauna`, Spawner:faunaMul, Pacing.shuffleOrder).
--   love . --selftest --maps
-- Each new map loads and draws; its `first` species opens wave 1; species it leaves out never
-- come; the species it favours arrive sooner than on the backyard; mode select has a map row.
local State = require("src.core.state")
local Content = require("src.content")

return function(wait, shot)
    local Game = require("src.states.game")
    local function world(stage, seed)
        local g = State.switch(Game.new({ mode = "run", character = "rhino_beetle", stage = stage, seed = seed }))
        return g.world, g
    end
    local function rank(order, id)
        for i, d in ipairs(order) do if d.id == id then return i end end
        return 999
    end
    for _, id in ipairs({ "dune_field", "rainforest_floor", "rotting_log", "wildflower_meadow" }) do
        local st = Content.stages:require(id)
        local w = world(id, 1234)
        wait(0.3)
        local order = w.spawner.introOrder
        if st.fauna.first then assert(order[1].id == st.fauna.first, id .. ": first species should be " .. st.fauna.first .. " (got " .. order[1].id .. ")") end
        for k, v in pairs(st.fauna) do
            if v == 0 then
                for _, d in ipairs(order) do assert(d.id ~= k and d.family ~= k or w.spawner:faunaMul(d) > 0, id .. ": " .. d.id .. " should be left out") end
            end
        end
        shot("map_" .. id)
    end
    -- favoured species come sooner than on the backyard (average over a few seeds)
    local function avg(stage, sp)
        local t = 0
        for s = 1, 6 do t = t + rank(world(stage, s * 977).spawner.introOrder, sp) end
        return t / 6
    end
    local dune, yard = avg("dune_field", "honeypot_ant"), avg("backyard", "honeypot_ant")
    assert(dune < yard, ("honeypot ants should come sooner in the dunes (%.1f vs %.1f)"):format(dune, yard))
    local log, yard2 = avg("rotting_log", "termite_soldier"), avg("backyard", "termite_soldier")
    assert(log < yard2, ("termites should come sooner on the log (%.1f vs %.1f)"):format(log, yard2))
    print(("[maps] honeypot rank dunes %.1f / backyard %.1f, termite soldier log %.1f / backyard %.1f"):format(dune, yard, log, yard2))
    -- mode select: a map row with who lives there
    local ms = State.switch(require("src.states.modeselect").new())
    assert(ms.menu.items[2].map, "mode select should open with a map row under its header")
    require("src.game.cosmetics").setLocation("dune_field")
    ms.menu.focus = 2
    wait(0.2)
    shot("maps_modeselect")
    local info = require("src.states.modeselect").mapInfo()
    assert(info.name == "Dune Field" and info.facts[1][2]:find("Desert Ant"), "map panel: " .. tostring(info.facts[1][2]))
    require("src.game.cosmetics").setLocation("backyard")
    print("[selftest] maps ok")
end
