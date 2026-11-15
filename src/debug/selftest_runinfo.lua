-- HUD and run info: damage by source, kills by species, hits taken and the killer, the seed,
-- combined damage numbers, the next-wave preview, first sightings, the enemies-left count, the
-- run summary / death recap screens and the accessibility palettes.
--   love . --selftest --runinfo   (saves selftest_runinfo_*.png)
local State = require("src.core.state")
local Content = require("src.content")
local Settings = require("src.core.settings")
local Records = require("src.game.records")
local Combat = require("src.game.combat")
local RunStats = require("src.game.runstats")

return function(wait, shot)
    Records.noSave = true
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "run", character = "scorpion", seed = 4242 }))
    wait(0.2)
    local world = game.world
    local pl = world.player
    local rs = world.runStats
    assert(world.seed == 4242, "seed not kept")
    assert(rs and rs.totalDealt == 0, "no run stats")
    world.flags.god = true

    -- damage by source: an item proc, the main attack, poison ticks, something unlabelled
    world.spawner.enabled = false
    local a = world:spawnEnemy("soldier_ant", pl.x + 30, pl.y)
    local prev = RunStats.push(world, "Test Item")
    Combat.damage(world, a, 3, { noCrit = true })
    RunStats.leave(world, prev)
    assert((rs.dealt["Test Item"] or 0) > 0, "item damage not counted")
    pl.curMove = "attack"
    Combat.damage(world, a, 2, { noCrit = true, poison = { 8, 2 } })
    pl.curMove = nil
    local atkName = pl.attack.type.name
    assert((rs.dealt[atkName] or 0) > 0, "attack damage not counted as " .. tostring(atkName))
    assert(a.poisonSrc == atkName, "poison source not remembered")
    local before = rs.dealt[atkName]
    for _ = 1, 70 do world:update(1 / 60) end
    assert(a.dead or rs.dealt[atkName] > before, "poison ticks not counted for the attack")
    -- overkill is not counted
    local b = world:spawnEnemy("worker_ant", pl.x + 30, pl.y)
    local hp = b.hp
    Combat.damage(world, b, 500, { noCrit = true, source = "Big Hit" })
    assert(rs.dealt["Big Hit"] <= hp + 0.01, "overkill counted")
    assert((rs.kills.worker_ant or 0) >= 1, "kill by species")

    -- hits taken, the recap and the killer
    world.flags.god = false
    pl.iframes = 0
    local biter = world:spawnEnemy("worker_ant", pl.x + 5, pl.y)
    pl:hurt(2, biter)
    pl:hurt(2, biter)
    assert(rs.hits[#rs.hits].count == 2 and rs.hits[#rs.hits].name == "Worker Ant", "bites did not fold into one line")
    world.hitBy = "Fire Ant"
    pl:hurt(3, "acid")
    assert(rs.hits[#rs.hits].name == "Acid spit (Fire Ant)", "hazard maker not named: " .. rs.hits[#rs.hits].name)
    for i = 1, 6 do world.time = world.time + 1 pl:hurt(1, "pebble") end
    assert(#rs.hits <= RunStats.HITS, "hit list too long")

    -- combined damage numbers
    Settings.set("damageNumbers", "all")
    Settings.set("combineDamageNumbers", true)
    local c = world:spawnEnemy("soldier_ant", pl.x + 40, pl.y)
    c.hp, c.maxHp = 999, 999
    local n0 = #world.texts
    for _ = 1, 5 do Combat.damage(world, c, 2, { noCrit = true }) end
    assert(#world.texts == n0 + 1, "numbers were not combined (" .. (#world.texts - n0) .. " texts)")
    assert(c._dmgText.value >= 10, "combined total")
    Settings.set("combineDamageNumbers", false)
    for _ = 1, 3 do Combat.damage(world, c, 2, { noCrit = true }) end
    assert(#world.texts == n0 + 4, "separate numbers")
    Settings.set("damageNumbers", "crits")

    -- next-wave preview
    local sp = world.spawner
    local pv = sp:preview()
    assert(pv and pv.wave == sp.wave + 1, "preview wave")
    assert(pv.newSpecies, "first wave preview has no species")
    sp.nextModifiers = { { name = "Test Modifier", description = "Ants are testy.", color = "#ff8040" } }
    assert(sp:preview().modifiers[1].name == "Test Modifier", "preview modifiers")
    world:clearEnemies()
    sp.enabled = true
    sp.phase, sp.timer = "break", 30
    pl.hp = pl.stats:get("maxHp")
    wait(0.3)
    shot("runinfo_preview")
    sp.nextModifiers = nil

    -- first sighting popup (once per species ever, unless "Every Run")
    Settings.set("speciesPopups", "run")
    local st = world._runHud
    assert(st, "run hud not attached")
    world:spawnEnemy("bullet_ant", pl.x + 120, pl.y)
    assert(#st.queue >= 1 or st.cur, "no sighting card")
    world:spawnEnemy("bullet_ant", pl.x + 120, pl.y)
    local q = #st.queue
    assert(q <= 1, "same species queued twice")
    sp:startWave()
    wait(1.2)
    shot("runinfo_sighting")
    Settings.set("speciesPopups", "new")

    -- enemies left
    local Hud = require("src.ui.runhud")
    local left, frac = Hud.remaining(world)
    assert(type(left) == "number" and left >= 0, "remaining count")
    assert(frac == nil or (frac >= 0 and frac <= 1), "wave progress")

    -- accessibility palettes and contrast
    Settings.set("safePalette", true)
    Settings.set("telegraphContrast", true)
    local Elites = require("src.game.elites")
    for _, el in ipairs(Content.elites:all()) do
        if el.safeColor then assert(Elites.color(el) ~= Elites.color, "safe colour") end
    end
    world:spawnEnemy("soldier_ant", pl.x + 40, pl.y, Content.elites:all()[1])
    world.hazards:addZone({ x = pl.x - 40, y = pl.y, r = 20, life = 5, damage = 4, color = { 0.6, 1, 0.3 } })
    wait(1)
    shot("runinfo_contrast")
    Settings.set("safePalette", false)
    Settings.set("telegraphContrast", false)
    Settings.set("enemyHealthBars", "elites")
    wait(0.2)
    Settings.set("enemyHealthBars", "damaged")

    -- run summary and the death recap
    State.push(require("src.states.runsummary").new(game))
    wait(0.4)
    shot("runinfo_summary")
    State.pop()
    world.flags.god = false
    pl.iframes = 0
    pl:hurt(99999, world:spawnEnemy("bullet_ant", pl.x + 5, pl.y))
    assert(rs.killer and rs.killer.name == "Bullet Ant", "killer not recorded")
    wait(1.8)
    shot("runinfo_gameover")
    -- the Records screen draws its progress bars
    State.switch(require("src.states.menu").new())
    local scr = State.push(require("src.states.records").new())
    if scr.setTab then scr:setTab(4) end
    wait(0.3)
    shot("runinfo_achievements")
    Records.noSave = false
    print("[runinfo] OK")
end
