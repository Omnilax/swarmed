-- Unlocks, item pool, danger levels, mastery records, dash tech, bug rules and the Final Swarm.
--   love . --selftest --mastery   runs just this part (also part of the full selftest)
-- Never writes the real save (Records.noSave and Prefs.noSave under --selftest).
local State = require("src.core.state")
local Content = require("src.content")
local Records = require("src.game.records")
local Unlocks = require("src.game.unlocks")
local Settings = require("src.core.settings")
local Prefs = require("src.game.prefs")

return function(wait, shot)
    local savedProfile, savedFree, savedAll = Records.profile, Unlocks.free, Settings.get("unlockAll")
    Records.noSave, Prefs.noSave = true, true
    Records.reset()
    Unlocks.free = false
    Settings.set("unlockAll", false)
    Unlocks.editing = nil

    -- 1. Locks: 8 starters open, the rest locked; unlock-all opens everything
    local open, all = Unlocks.bugCount()
    assert(open == 8 and all == Content.characters:count(), ("starters: %d of %d open"):format(open, all))
    assert(Unlocks.bug("rhino_beetle") and not Unlocks.bug("crab"), "crab should start locked")
    for _, c in ipairs(Content.characters:all()) do
        assert(Unlocks.bug(c.id) or Unlocks.bugGoal(c.id), "locked bug without a goal: " .. c.id)
    end
    assert(not Unlocks.item("amber") and not Unlocks.inPool("amber"), "amber should start locked")
    Settings.set("unlockAll", true)
    assert(Unlocks.bug("crab") and Unlocks.item("amber") and Unlocks.maxDanger("crab") == 5, "unlock all")
    Settings.set("unlockAll", false)
    -- every locked bug / item has an achievement in the Unlocks category
    local reg = Content.achievements
    assert(reg:get(Unlocks.bugAchievement("crab")) and reg:get(Unlocks.itemAchievement("amber")), "unlock achievements missing")

    -- 2. A goal met mid-run unlocks the bug; a locked item never shows in a choice
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "run", character = "rhino_beetle" }))
    wait(0.2)
    local world = game.world
    world.spawner.enabled = false
    world.flags.god = true
    world:clearEnemies()
    local Choices = require("src.game.choices")
    for _ = 1, 300 do
        local d = Choices.pickDef(world, {})
        assert(d and Unlocks.inPool(d.id), "a locked item was rolled: " .. tostring(d and d.id))
    end
    Records.run.wavesCleared = 5
    Records.check()
    assert(Unlocks.bug("crab"), "clearing wave 5 as the rhino beetle should unlock the crab")
    local card = false
    for _, t in ipairs(Records.toasts) do if t.def.unlockId == "crab" then card = true end end
    assert(card, "unlock card")
    print("[mastery] unlocks OK")

    -- 3. Item pool toggles (only a Custom Waves set's list; the main game has no global pool)
    assert(not Unlocks.setInPool("honeydew", false) and Unlocks.inPool("honeydew"), "the main game's pool changed")
    Unlocks.editing = {}
    assert(Unlocks.setInPool("honeydew", false) and not Unlocks.inPool("honeydew"), "switch off")
    for _ = 1, 300 do assert(Choices.pickDef(world, {}).id ~= "honeydew", "switched-off item rolled") end
    -- switching everything off stops at the minimum
    for _, d in ipairs(Content.items:all()) do Unlocks.setInPool(d.id, false) end
    assert(Unlocks.poolSize() == Unlocks.MIN_POOL, "pool minimum, got " .. Unlocks.poolSize())
    local pool = State.push(require("src.states.itempool").new(Unlocks.editing))
    wait(0.3)
    shot("mastery_itempool")
    pool:close()
    assert(Unlocks.editing == nil and Unlocks.inPool("honeydew"), "closing the item pool left it switched off")
    print("[mastery] item pool OK")

    -- 4. Danger levels: tougher ants, less healing; a win records mastery and opens the next level
    local World = require("src.game.world")
    local calm = World.new({ mode = "run", character = "rhino_beetle", danger = 0 })
    local hard = World.new({ mode = "run", character = "rhino_beetle", danger = 4 })
    assert(hard.danger.level == 4 and hard.danger.healMul == 0.5 and hard.danger.eliteMul == 2, "danger rules fold")
    assert(hard:hpScale() > calm:hpScale() * 1.2, "danger 4 ants should have more health")
    local e1 = calm:spawnEnemy("worker_ant", 100, 100)
    local e2 = hard:spawnEnemy("worker_ant", 100, 100)
    assert(e2.damage > e1.damage, "danger 4 ants should bite harder")
    assert(hard.spawner:eliteMode().mul == 2, "danger 1 doubles elites")
    assert(Unlocks.maxDanger("stag_beetle") == 0, "danger 1 opens with a win")
    State.switch(Game.new({ mode = "run", character = "stag_beetle", danger = 0 }))
    game = State.top()
    wait(0.1)
    game.world.events:emit("run_won", 15)
    assert(Unlocks.bestDanger("stag_beetle") == 0 and Unlocks.maxDanger("stag_beetle") == 1, "win at danger 0 opens danger 1")
    local CharSelect = require("src.states.charselect")
    local cs = State.push(CharSelect.new({ gameMode = "colony" }))
    cs.menu.focus = 3
    for i, it in ipairs(cs.menu.items) do if it.character and it.character.id == "stag_beetle" then cs.menu.focus = i end end
    cs:shiftDanger(Content.characters:get("stag_beetle"), 1)
    assert(CharSelect.danger("stag_beetle") == 1, "danger picker")
    cs:shiftDanger(Content.characters:get("stag_beetle"), 1)
    assert(CharSelect.danger("stag_beetle") == 1, "danger 2 should still be locked")
    wait(0.6)
    shot("mastery_charselect")
    for i, it in ipairs(cs.menu.items) do if it.character and it.locked then cs.menu.focus = i break end end
    wait(0.4)
    shot("mastery_charselect_locked")
    State.pop()
    print("[mastery] danger OK")

    -- 5. Dash tech: a kill mid-dash refunds stamina; a chained dash is faster
    game = State.switch(Game.new({ mode = "sandbox", character = "wolf_spider" }))
    wait(0.2)
    world = game.world
    world.flags.god = true
    world:clearEnemies()
    local pl = world.player
    local Stamina = require("src.game.stamina")
    local DashTech = require("src.game.dashtech")
    local st = Stamina.state(pl)
    world.pilot = { pressed = { dash = true }, down = {} }
    pl:update(1 / 60)
    world.pilot.pressed = {}
    assert(pl.dashTech and pl.dashTech.active, "dash should be tracked")
    local before = st.cur
    local kills = 0
    world.events:on("dash_kill", function() kills = kills + 1 end)
    world:killEnemy(world:spawnEnemy("worker_ant", pl.x + 10, pl.y))
    assert(kills == 1 and st.cur > before + 0.01, ("kill-dash refund: %.2f -> %.2f"):format(before, st.cur))
    for _ = 1, 60 do world:update(1 / 60) if not pl.dashTech.active then break end end
    assert(not pl.dashTech.active, "dash should end")
    st.cur = st.max
    world.pilot.pressed = { dash = true }
    pl:update(1 / 60)
    world.pilot = nil
    assert(pl.dashTech.chain == 1, "a quick second dash should chain, got " .. tostring(pl.dashTech.chain))
    print("[mastery] dash tech OK")

    -- 6. Bug rules
    pl:setCharacter(Content.characters:require("dung_beetle"))
    world.player = pl
    local dmg = pl.stats:get("damage")
    pl.inventory:add("honeydew")
    pl.inventory:eat(pl.inventory.bag[1].item)
    pl.inventory:update(1 / 60)
    assert(pl.stats:get("damage") >= dmg + 2.9, "dung beetle: eaten items add damage")
    pl:setCharacter(Content.characters:require("hissing_roach"))
    pl.hp = 1
    local healed = pl.inventory:eat(require("src.game.inventory").newItem("honeydew"))
    assert(healed == require("src.game.inventory").eatValue(require("src.game.inventory").newItem("honeydew")) * 2, "roach eats double")
    local BugRules = require("src.game.bugrules")
    pl:setCharacter(Content.characters:require("orb_weaver"))
    local _, reps = BugRules.proc(pl, Content.items:all()[1], "onHit", { target = { slowT = 1 } })
    assert(reps == 2, "orb weaver: procs twice on slowed ants")
    print("[mastery] bug rules OK")

    -- 7. The Final Swarm: offered after the win, packs pour in, living through it ends the run
    game = State.switch(Game.new({ mode = "run", character = "rhino_beetle" }))
    wait(0.2)
    world = game.world
    world.flags.god = true
    local sp = world.spawner
    sp:catchUp(15)
    sp.wave = 15
    sp.phase = "break"
    world:clearEnemies()
    sp:chapterCleared()
    game:update(1 / 60)
    local vic = State.top()
    assert(vic.info and vic.info.first, "victory screen")
    local swarmItem
    for _, it in ipairs(vic.menu.items) do if it.label == "Final Swarm" then swarmItem = it end end
    assert(swarmItem, "victory should offer the Final Swarm")
    vic.t = 5
    swarmItem.onActivate()
    assert(State.top() == game and world.finalSwarm, "the swarm should start")
    local FinalSwarm = require("src.game.finalswarm")
    local dur = FinalSwarm.DURATION
    FinalSwarm.DURATION = 8
    local over, peak = nil, 0
    world.events:on("final_swarm_over", function(info) over = info end)
    local shotTaken = false
    while not over do
        game:update(1 / 60)
        peak = math.max(peak, world.enemyCount)
        if not shotTaken and world.finalSwarm.t > 5 then shotTaken = true wait(0.1) shot("mastery_finalswarm") end
        if world.time % 0.5 < 1 / 60 then
            for i = 1, world.enemyCount do
                local e = world.enemies[i]
                if e and not e.dead and love.math.random() < 0.3 then world:killEnemy(e) end
            end
        end
    end
    FinalSwarm.DURATION = dur
    assert(peak > 20, "the swarm should send lots of ants, peak " .. peak)
    assert(over.survived and over.kills > 0, "survived the swarm")
    assert(Records.get().swarmsSurvived == 1, "swarm record")
    world.time = world.time + 2
    game:update(1 / 60)
    vic = State.top()
    assert(vic.info and vic.info.swarm, "swarm result screen")
    wait(1.2)
    shot("mastery_swarm_survived")
    State.switch(require("src.states.menu").new())

    Records.profile = savedProfile
    Unlocks.free = savedFree
    Settings.set("unlockAll", savedAll)
    print("[selftest] mastery OK")
end
