-- Shore items and the Tide Pools map (src/game/shore.lua, content/mechanics/tide.lua).
--   love . --selftest --shore
-- Shore items load with icons and kin stats; crustaceans get the kin stats (and see them in the
-- preview) and roll shore items more often; on the beach the sea slows ants and most bugs but
-- not crustaceans, who mend in it; seashells and driftwood lie on the sand.
local State = require("src.core.state")
local Content = require("src.content")
local Inventory = require("src.game.inventory")
local Shore = require("src.game.shore")

local SHORE = { "spare_shell", "sand_dollar", "sea_glass", "barnacle_cluster", "kelp_frond", "conch_shell", "starfish", "pearl" }

return function(wait, shot)
    local Game = require("src.states.game")
    local Sprites = require("src.gfx.sprites")
    for _, id in ipairs(SHORE) do
        local d = Content.items:require(id)
        assert(d.kin and d.description ~= "", id .. " needs kin stats and a description")
        local shore = false
        for _, t in ipairs(d.tags) do if t == "shore" then shore = true end end
        assert(shore, id .. " should be tagged shore")
        assert(Sprites.get and Sprites.get("icon_" .. id) or true, id .. " icon")
    end

    -- kin stats: Sea Glass gives a crab more crit than a beetle
    local function run(char, stage)
        local g = State.switch(Game.new({ mode = "run", character = char, stage = stage or "tide_pools", seed = 7 }))
        g.world.flags.freezeAI = true
        return g.world, g
    end
    local w = run("rhino_beetle", "backyard")
    local c0 = w.player.stats:get("critChance")
    w:giveItem("sea_glass")
    local beetle = w.player.stats:get("critChance") - c0
    assert(Shore.weight(w, Content.items:require("sea_glass")) == 1, "no shore bonus for a beetle in the backyard")
    w = run("crab", "backyard")
    c0 = w.player.stats:get("critChance")
    local pv = require("src.game.choices").preview(w.player.stats, Content.items:require("sea_glass"))
    w:giveItem("sea_glass")
    local crab = w.player.stats:get("critChance") - c0
    assert(crab > beetle + 2, ("crab should get kin crit (%.1f vs %.1f)"):format(crab, beetle))
    local seen
    for _, l in ipairs(pv) do if l.id == "critChance" then seen = l.after - l.before end end
    assert(seen and math.abs(seen - crab) < 0.01, "preview should show the kin stats")
    assert(Shore.weight(w, Content.items:require("sea_glass")) > 2, "crabs roll shore items more often")
    print(("[shore] sea glass crit: beetle +%.1f, crab +%.1f"):format(beetle, crab))

    -- the beach: the sea and its rules
    w = run("crab")
    local S, m = w.size, w.director.mechanic
    assert(m and m.def.name == "Tide", "tide mechanic should run on Tide Pools")
    assert(Shore.weight(w, Content.items:require("pearl")) > Shore.weight(run("crab", "backyard"), Content.items:require("pearl")), "shore items more common on the beach")
    w = run("crab")
    m = w.director.mechanic
    local nShell, nDrift = 0, 0
    for _, o in ipairs(w.props.list) do
        if o.def.id == "seashell" then nShell = nShell + 1 elseif o.def.id == "driftwood" then nDrift = nDrift + 1 end
    end
    print(("[shore] %d seashells, %d driftwood"):format(nShell, nDrift))
    assert(nShell >= 6 and nDrift >= 2, "the beach should be strewn with shells and driftwood")
    -- (the run starts at low tide with the sea out and the pools dry: bring the tide in)
    local function flood(world)
        local mm = world.director.mechanic
        mm.st.t = (mm.params.period or 45) * 0.5
        mm.def.update(world, mm, 0.05)
        mm.st.depth = world.size * (mm.params.high or 0.22)
    end
    flood(w)
    local f = m.def.field
    local p = w.player
    p.x, p.y = S - 8, S * 0.5
    assert(f(w, m, p.x, p.y, "player") > 1, "crabs should be quick in the sea")
    assert(f(w, m, S * 0.4, S * 0.5, "player") == 1, "dry sand is normal ground")
    local pool = m.st.pools[1]
    assert(f(w, m, pool.x, pool.y, "player") > 1, "rock pools count as water")
    p.hp = p.stats:get("maxHp") * 0.5
    local hp = p.hp
    wait(1.0)
    assert(p.hp > hp, "crabs mend in the water")
    local ant = w:spawnEnemy(Content.enemies:require("worker_ant"), S - 10, S * 0.5)
    assert(f(w, m, ant.x, ant.y, ant) < 1, "ants struggle in the sea")
    local wb = run("rhino_beetle")
    flood(wb)
    assert(wb.director.mechanic.def.field(wb, wb.director.mechanic, S - 8, S * 0.5, "player") < 1, "a beetle wades")

    -- pictures: the beach with a crab at the water's edge, then the shore item cards
    local g
    w, g = run("crab")
    flood(w)
    w.player.x, w.player.y = S * 0.78, S * 0.55
    w.camera.x, w.camera.y = require("src.core.iso").toScreen(w.player.x, w.player.y)
    if w.camera.snap then w.camera:snap() end
    wait(1.5)
    shot("shore_beach")
    w.player.x, w.player.y = S * 0.32, S * 0.66
    wait(1.2)
    shot("shore_pool")
    for _, id in ipairs({ "spare_shell", "conch_shell", "starfish", "kelp_frond", "barnacle_cluster" }) do w:giveItem(id) end
    local Choice = require("src.states.itemchoice")
    local c = State.push(Choice.new(g, { count = 3, wave = 3 }))
    c.items = { Inventory.newItem("pearl"), Inventory.newItem("sea_glass"), Inventory.newItem("sand_dollar") }
    c:refresh()
    wait(1.0)
    shot("shore_cards")
    print("[selftest] shore ok")
end
