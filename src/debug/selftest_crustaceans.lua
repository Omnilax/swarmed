-- Crustacean enemies: shrimp, krill and plankton.   love . --selftest --crustaceans
-- Every species loads in the crustacean family with its sprite; they only live on water maps
-- (Tide Pools, Puddle Patio) and swim in from the sea on the beach; the sea speeds them up and
-- never drowns them; shrimp tail-flip away when hit (cherries after a bite, blue velvets lunge
-- back), cleaner shrimp mend the wounded, lantern krill speed up their school, and sea fireflies
-- leave a slowing glow when they pop.
local State = require("src.core.state")
local Content = require("src.content")

local IDS = { "glass_shrimp", "cherry_shrimp", "blue_shrimp", "tiger_shrimp", "cleaner_shrimp",
    "pink_krill", "lantern_krill", "copepod", "water_flea", "sea_firefly" }

return function(wait, shot)
    local Game = require("src.states.game")
    local Combat = require("src.game.combat")
    local Sprites = require("src.gfx.sprites")
    for _, id in ipairs(IDS) do
        local d = Content.enemies:require(id)
        assert(d.family == "crustacean", id .. " should be a crustacean")
        assert(d.aquatic and d.spawn.habitat == "water", id .. " should be aquatic and live in water")
        assert(d.description ~= "" and d.lore and d.tip, id .. " needs catalogue text")
        assert(Sprites.get(d.sprite), id .. " sprite " .. d.sprite)
    end

    local function run(stage, mode)
        local g = State.switch(Game.new({ mode = mode or "run", character = "rhino_beetle", stage = stage, seed = 11 }))
        return g.world, g
    end

    -- where they live
    local w = run("backyard")
    for _, id in ipairs(IDS) do
        local d = Content.enemies:require(id)
        assert(w.spawner:faunaMul(d) == 0 and not w.spawner:allows(d), id .. " should stay off the backyard")
    end
    w = run("tide_pools")
    for _, id in ipairs(IDS) do
        assert(w.spawner:faunaMul(Content.enemies:require(id)) > 0, id .. " should live at the tide pools")
    end
    local S = w.size
    local st = w.spawner:spawnGroup(Content.enemies:require("pink_krill"), 5)
    assert(st.x > S * 0.95, "krill should swim in from the sea on the beach")
    local inOrder = 0
    for _, d in ipairs(w.spawner.introOrder) do if d.family == "crustacean" then inOrder = inOrder + 1 end end
    assert(inOrder == #IDS, "every crustacean should be in the beach's intro order (" .. inOrder .. ")")
    local pw = run("puddle_patio")
    assert(pw.spawner:faunaMul(Content.enemies:require("water_flea")) > 0, "water fleas live in puddles")
    assert(pw.spawner:faunaMul(Content.enemies:require("tiger_shrimp")) == 0, "no tiger shrimp in a puddle")

    -- the sea: crustaceans go faster in it, ants slower, and it never drowns them
    local m = w.director.mechanic
    -- the tide comes and goes now: bring it in so the edge is sea
    m.st.t = m.params.period * 0.5
    m.def.update(w, m, 0.05)
    m.st.depth = w.size * m.params.high
    w.flags.freezeAI = true
    local krill = w:spawnEnemy("pink_krill", S - 6, S * 0.5)
    local ant = w:spawnEnemy("worker_ant", S - 6, S * 0.52)
    assert(m.def.field(w, m, krill.x, krill.y, krill) > 1, "krill should be at home in the sea")
    assert(m.def.field(w, m, ant.x, ant.y, ant) < 1, "ants struggle in the sea")
    w.spawner.phase = "wave"
    for _ = 1, 240 do m.def.update(w, m, 1 / 60) end
    assert(not krill.dead, "the sea drowned a krill")
    print("[crustaceans] homes and the sea OK")

    -- behaviours, in the sandbox on the beach
    local g
    w, g = run("tide_pools", "sandbox")
    wait(0.3)
    local pl = w.player
    w.flags.god = true
    pl.attack.timer = 1e9
    local function step(sec) for _ = 1, math.floor(sec * 60) do w:update(1 / 60) end end
    local function reset()
        w:clearEnemies()
        w.hazards:clear()
        pl.x, pl.y = S * 0.45, S * 0.5
    end
    local function dist(e) return math.sqrt((e.x - pl.x) ^ 2 + (e.y - pl.y) ^ 2) end

    -- a glass shrimp tail-flips away when hit (try a few hits, it's a chance)
    reset()
    local gs = w:spawnEnemy("glass_shrimp", pl.x + 30, pl.y)
    gs.hp, gs.maxHp = 500, 500
    local fled = false
    for _ = 1, 20 do
        local d0 = dist(gs)
        Combat.damage(w, gs, 1, { knockback = 0, noCrit = true })
        if gs.st.mode == "flee" then
            step(0.25)
            fled = dist(gs) > d0 + 6
            break
        end
        step(0.05)
    end
    assert(fled, "glass shrimp should flick away backwards when hit")

    -- a blue velvet shrimp lunges back after its flick
    reset()
    local bs = w:spawnEnemy("blue_shrimp", pl.x + 30, pl.y)
    bs.hp, bs.maxHp = 500, 500
    local lunged = false
    for _ = 1, 40 do
        if bs.st.mode == "swim" and bs.st.fleeCd <= 0 then Combat.damage(w, bs, 1, { knockback = 0, noCrit = true }) end
        step(0.05)
        if bs.st.mode == "lunge" then lunged = true break end
    end
    assert(lunged, "blue velvet shrimp should lunge back after a flick")

    -- a cherry shrimp nips and darts off
    reset()
    local cs = w:spawnEnemy("cherry_shrimp", pl.x + 5, pl.y)
    local nipped = false
    for _ = 1, 180 do
        w:update(1 / 60)
        if cs.st.mode == "flee" then nipped = true break end
    end
    assert(nipped, "cherry shrimp should dart off after a bite")

    -- a cleaner shrimp mends a wounded ant (the player well away)
    reset()
    pl.x, pl.y = S * 0.15, S * 0.15
    local hurt = w:spawnEnemy("bulldog_ant", S * 0.5, S * 0.5)
    hurt.hp = hurt.maxHp * 0.3
    hurt.speed = 0
    local cl = w:spawnEnemy("cleaner_shrimp", S * 0.5 + 40, S * 0.5)
    local hp0 = hurt.hp
    for _ = 1, 240 do
        hurt.x, hurt.y = S * 0.5, S * 0.5
        w:update(1 / 60)
    end
    assert(hurt.hp > hp0 + 2, ("cleaner shrimp should mend the wounded (%.1f -> %.1f)"):format(hp0, hurt.hp))
    assert(cl.st.patient == hurt or hurt.hp >= hurt.maxHp * 0.95, ("cleaner shrimp should pick the wounded ant (%s, %.1f/%.1f)"):format(tostring(cl.st.patient and cl.st.patient.def.id), hurt.hp, hurt.maxHp))

    -- a lantern krill lights up the school
    reset()
    local lk = w:spawnEnemy("lantern_krill", pl.x + 120, pl.y)
    local pk = w:spawnEnemy("pink_krill", pl.x + 126, pl.y + 4)
    step(0.6)
    assert(pk.st.lit > 0, "krill near a lantern should be lit")
    w:killEnemy(lk)
    step(1)
    assert(pk.st.lit <= 0, "the light goes out with the lantern")

    -- a sea firefly spills a slowing glow
    reset()
    local ff = w:spawnEnemy("sea_firefly", pl.x + 40, pl.y)
    local zones = #w.hazards.zones
    w:killEnemy(ff)
    step(0.1)
    assert(#w.hazards.zones > zones and w.hazards.zones[#w.hazards.zones].slow, "a sea firefly should leave a slowing glow")
    print("[crustaceans] behaviours OK")

    -- everyone at once, for a look
    reset()
    pl.x, pl.y = S * 0.62, S * 0.5
    local Settings = require("src.core.settings")
    Settings.set("timeOfDay", "day")
    for i, id in ipairs(IDS) do
        local a = i / #IDS * math.pi * 2
        local n = (id == "tiger_shrimp" or id == "cleaner_shrimp") and 1 or 3
        w:spawnRing(id, n, pl.x + math.cos(a) * 70, pl.y + math.sin(a) * 70, 6)
    end
    w.flags.freezeAI = true
    wait(0.5)
    shot("crustaceans")
    w.flags.freezeAI = false
    wait(1.5)
    shot("crustaceans_moving")
    Settings.set("timeOfDay", "cycle")
    print("[selftest] crustaceans OK (" .. #IDS .. " species)")
end
