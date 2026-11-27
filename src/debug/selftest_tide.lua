-- The beach tide can't be camped (content/mechanics/tide.lua).
--   love . --selftest --tide
-- The run starts at low tide: the sea is out past the edge and the rock pools are dry. Over one
-- full tide the sea comes in and goes out again, so water is never there for good. At high tide
-- the salt water hurts a beetle (more out of its depth), while a crab, the Water Strider and any
-- bug tagged "aquatic" are at home in it and mend instead. Flying over the water is safe.
local State = require("src.core.state")
local Content = require("src.content")
local Shore = require("src.game.shore")

return function(wait, shot)
    local Game = require("src.states.game")
    local function run(char)
        local g = State.switch(Game.new({ mode = "run", character = char, stage = "tide_pools", seed = 7 }))
        g.world.flags.freezeAI = true
        g.world.flags.god = false
        return g.world, g
    end
    local function flood(w)
        local m = w.director.mechanic
        m.st.t = m.params.period * 0.5
        m.def.update(w, m, 0.05)
        m.st.depth = w.size * m.params.high
        return m
    end

    -- low tide at the start: no sea at the edge, the pools are dry stone
    local w = run("rhino_beetle")
    local S, m = w.size, w.director.mechanic
    local f = m.def.field
    for y = 20, S - 20, 40 do assert(f(w, m, S - 3, y, "player") == 1, "the sea should be out at low tide") end
    for _, pool in ipairs(m.st.pools) do assert(f(w, m, pool.x, pool.y, "player") == 1, "rock pools should be dry at low tide") end

    -- one whole tide, stood on dry sand: the sea comes in, then goes right out again
    local p = w.player
    p.x, p.y = S * 0.15, S * 0.1
    local wetT, dryT, poolWet, poolDry, dt = 0, 0, 0, 0, 0.1
    local pool = m.st.pools[1]
    for _ = 1, math.floor(m.params.period / dt) do
        m.def.update(w, m, dt)
        if f(w, m, S - 3, S * 0.5, "player") < 1 then wetT = wetT + dt else dryT = dryT + dt end
        if f(w, m, pool.x, pool.y, "player") < 1 then poolWet = poolWet + dt else poolDry = poolDry + dt end
    end
    print(("[tide] one tide (%ds): sea in %.0fs / out %.0fs, pools full %.0fs / dry %.0fs"):format(m.params.period, wetT, dryT, poolWet, poolDry))
    assert(wetT > m.params.period * 0.3, "the sea should come in for a good while")
    assert(dryT > m.params.period * 0.25, "the sea should go out for a good while too")
    assert(poolWet > 5 and poolDry > 10, "the rock pools should fill and drain")

    -- high tide: the salt water hurts a beetle, and more out of its depth
    local function loss(char, x, y, secs)
        local ww = run(char)
        local mm = flood(ww)
        local pl = ww.player
        pl.x, pl.y = x, y
        pl.hp = pl.stats:get("maxHp") * 0.6
        local hp0 = pl.hp
        for _ = 1, math.floor(secs / 0.05) do
            pl.x, pl.y = x, y
            mm.def.update(ww, mm, 0.05)
        end
        return hp0 - pl.hp, ww, mm
    end
    local edge = S - S * m.params.high + 6                     -- a few steps into the shallows
    local shallow = loss("rhino_beetle", edge, S * 0.5, 2)
    local deepL = loss("rhino_beetle", S - 8, S * 0.5, 2)
    local dry = loss("rhino_beetle", S * 0.15, S * 0.1, 2)
    print(("[tide] beetle over 2s at high tide: dry %.1f, shallows %.1f, deep %.1f HP"):format(dry, shallow, deepL))
    assert(dry == 0, "dry sand is safe")
    assert(shallow > 2, "the shallows should sting a beetle")
    assert(deepL > shallow * 1.5, "deep water should hurt more than the shallows")
    local pl = loss("rhino_beetle", m.st.pools[1].x, m.st.pools[1].y, 2)
    assert(pl > 2, "a full rock pool stings too")

    -- blocking doesn't keep the water off
    local ww = run("rhino_beetle")
    local mm = flood(ww)
    ww.player.x, ww.player.y = S - 8, S * 0.5
    ww.player.blocking = true
    local hp0 = ww.player.hp
    for _ = 1, 20 do mm.def.update(ww, mm, 0.05) end
    assert(ww.player.hp < hp0 and ww.player.blocking, "blocking shouldn't stop the sting (and stays on)")

    -- flying over the sea is safe
    ww = run("rhino_beetle")
    mm = flood(ww)
    ww.player.x, ww.player.y, ww.player.z = S - 8, S * 0.5, 12
    hp0 = ww.player.hp
    for _ = 1, 20 do ww.player.z = 12; mm.def.update(ww, mm, 0.05) end
    assert(ww.player.hp == hp0, "flying over the water is safe")

    -- water bugs are at home: a crab mends in deep water
    local crab = loss("crab", S - 8, S * 0.5, 2)
    print(("[tide] crab over 2s in deep water: %.1f HP (negative = mended)"):format(crab))
    assert(crab < 0, "a crab should mend in the sea, not get hurt")
    assert(Shore.amphibious({ id = "water_strider", tags = { "insect", "true bug" } }), "the Water Strider is a water bug")
    assert(Shore.amphibious({ id = "my_bug", tags = { "aquatic" } }), "an aquatic-tagged bug is a water bug")
    assert(not Shore.amphibious(Content.characters:require("rhino_beetle")), "a beetle isn't a water bug")
    if Content.characters:get("water_strider") then
        local s = loss("water_strider", S - 8, S * 0.5, 2)
        assert(s <= 0, "the Water Strider shouldn't be hurt by the sea")
        print(("[tide] water strider in deep water: %.1f HP"):format(s))
    end

    -- pictures: low tide (dry pools) and high tide
    local g
    w, g = run("rhino_beetle")
    w.player.x, w.player.y = S * 0.6, S * 0.62
    w.camera.x, w.camera.y = require("src.core.iso").toScreen(w.player.x, w.player.y)
    if w.camera.snap then w.camera:snap() end
    wait(1.0)
    shot("tide_low")
    flood(w)
    wait(1.0)
    shot("tide_high")
    print("[selftest] tide ok")
end
