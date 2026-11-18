-- Automated smoke test + benchmark:  love . --selftest
-- Walks through every screen, takes screenshots (saved in the LÖVE save folder), stress tests
-- the horde and prints timings, then quits. Useful after big changes.
local State = require("src.core.state")
local Content = require("src.content")

local util = require("src.core.util")
local util_indexOf = util.indexOf
local Inventory = require("src.game.inventory")
local Input = require("src.core.input")

local Selftest = {}
local co, waitT = nil, 0

local function wait(t)
    waitT = t
    coroutine.yield()
end

local function shot(name)
    love.graphics.captureScreenshot("selftest_" .. name .. ".png")
    print("[selftest] screenshot " .. name)
    wait(0.1)
end

local function benchUpdate(world, frames)
    local t0 = love.timer.getTime()
    for _ = 1, frames do world:update(1 / 60) end
    return (love.timer.getTime() - t0) / frames * 1000
end

local function benchDraw(game, frames)
    local t0 = love.timer.getTime()
    for _ = 1, frames do
        love.graphics.origin()
        game:draw()
        love.graphics.flushBatch()
    end
    return (love.timer.getTime() - t0) / frames * 1000
end

-- Inventory checks and screenshot (also:  love . --selftest --inventory)
local function inventoryScene(game, world)
    -- Inventory: shaped items in a small bag. Pick up, place, turn, swap, drop, overflow.
    world.flags.freezeAI = true
    local inv = world.player.inventory
    inv:clear()
    assert(inv.cols * inv.rows == 30, "bag should be 30 cells")
    for _, id in ipairs({ "chitin_plate", "termite_mandible", "mantis_forelimb", "honeydew", "honeydew" }) do world:giveItem(id) end
    assert(#inv.bag == 5 and inv:count("honeydew") == 2 and inv:usedCells() == 13, "items should fit and stack")
    local armor = world.player.stats:get("armor")
    local invState = State.push(require("src.states.inventory").new(game))
    invState:layout()
    local plateE
    for _, o in ipairs(inv.bag) do if o.item.id == "chitin_plate" then plateE = o end end
    invState:primary({ kind = "bag", x = plateE.x, y = plateE.y })       -- pick up: stops counting
    assert(invState.held and world.player.stats:get("armor") < armor, "pick up failed")
    local fx, fy = inv:findSpace(invState.held.item)
    invState:primary({ kind = "bag", x = fx, y = fy })                    -- put down elsewhere
    assert(not invState.held and world.player.stats:get("armor") == armor, "place failed")
    -- an L shape turned four times comes back to where it started, covering different cells
    local limbE
    for _, o in ipairs(inv.bag) do if o.item.id == "mantis_forelimb" then limbE = o end end
    invState:primary({ kind = "bag", x = limbE.x, y = limbE.y })
    local it = invState.held.item
    local before = Inventory.cells(it)
    invState:rotate()
    local w, h = Inventory.size(it)
    assert(w == 3 and h == 2 and Inventory.cells(it) ~= before, "rotate failed")
    fx, fy = inv:findSpace(it)
    invState:primary({ kind = "bag", x = fx, y = fy })
    assert(not invState.held and inv:count("mantis_forelimb") == 1, "turned place failed")
    -- right click eats an item: it's gone and heals by rarity
    for _, o in ipairs(inv.bag) do if o.item.id == "chitin_plate" then plateE = o end end
    world.player.hp = 10
    local gain = Inventory.eatValue(plateE.item)
    invState:secondary({ kind = "bag", x = plateE.x, y = plateE.y })
    assert(inv:count("chitin_plate") == 0 and world.player.stats:get("armor") < armor, "eat failed")
    assert(math.abs(world.player.hp - math.min(world.player.stats:get("maxHp"), 10 + gain)) < 0.01, "eating did not heal")
    assert(Inventory.eatValue(Inventory.newItem("royal_jelly")) > Inventory.eatValue(Inventory.newItem("honeydew")), "rarer/bigger should heal more")
    world.player.hp = world.player.stats:get("maxHp")
    -- a full bag: what doesn't fit is eaten (items never lie on the ground)
    world.player.hp = 1
    assert(world:giveItem("royal_jelly", 12) > 0 and inv:usedCells() <= 30, "bag should fill up")
    assert(world.player.hp > 1 and world.pickups == nil, "overflow should be eaten, not dropped")
    world.player.hp = world.player.stats:get("maxHp")
    -- a nice mix of shapes for the screenshot, with the cursor on the scarab shell
    inv:clear()
    for _, id in ipairs({ "silk_bundle", "scarab_shell", "dragonfly_wings", "mantis_forelimb", "royal_jelly", "termite_mandible",
                          "hornet_stinger", "four_leaf_clover", "honeydew", "ember_gland" }) do
        world:giveItem(id)
    end
    print("[selftest] inventory OK (" .. #inv.bag .. " items, " .. inv:usedCells() .. "/30 cells)")
    local lastDev = Input.lastDevice
    Input.lastDevice = "gamepad"
    for _, o in ipairs(inv.bag) do if o.item.id == "scarab_shell" then invState.cursor = { kind = "bag", x = o.x + 1, y = o.y } end end
    wait(0.3)
    shot("inventory")
    Input.lastDevice = lastDev
    invState:close()
    world.flags.freezeAI = false
end

-- Every bug's special and dash in action, one screenshot each (also run by the full test).
--   love . --selftest --specials   runs just this part
local function specialsScene()
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "sandbox", character = "wolf_spider" }))
    wait(0.5)
    local world = game.world
    world.flags.god = true
    for _, cdef in ipairs(Content.characters:all()) do
        world:clearEnemies()
        local pl = world.player
        pl:setCharacter(cdef)
        pl.x, pl.y = world.size * 0.45, world.size * 0.45
        pl.momX, pl.momY = 0, 0
        pl.attack.timer = 1e9
        world:spawnRing("worker_ant", 26, pl.x + 40, pl.y, 26)
        world:spawnRing("soldier_ant", 6, pl.x, pl.y, 60)
        world.flags.freezeAI = true
        wait(0.3)
        pl.attack.type.fire(pl, world, 1, 0, pl.attack.params)
        wait(0.04)
        shot("attack_" .. cdef.id)
        local sec = pl.secondary
        sec.type.fire(pl, world, 1, 0, sec.params, pl.x + 70, pl.y + 10)
        wait(0.22)
        shot("special_" .. cdef.id)
        wait(0.8)
        world.flags.freezeAI = false
        -- dash
        if pl.dashDef.hold then
            pl.dashDef.update(pl, world, 0.016, pl.dashParams, true)
            pl.dashDef.update(pl, world, 0.016, pl.dashParams, false)
        else
            pl.dashDef.start(pl, world, -1, 0, pl.dashParams, pl.x - 120, pl.y - 40)
            pl.dashT0 = pl.dashT
            if cdef.id == "orb_weaver" then
                wait(0.18)
                shot("dash_grapple")
            end
        end
        wait(0.8)
        assert(not pl.ropeVX or pl.grapple, "grapple left a rope velocity behind")
        world.hazards:clear()
    end
    -- held specials: drag out a silk wall, munch on snatched ants
    world:clearEnemies()
    local pl = world.player
    pl:setCharacter(Content.characters:get("orb_weaver"))
    local sp = pl.secondary
    sp.type.fire(pl, world, 1, 0, sp.params, pl.x + 30, pl.y - 50)
    sp.type.update(pl, world, 0.1, sp.params, true, pl.x + 30, pl.y + 50)
    assert(pl.weave and #world.hazards.walls == 0, "silk wall should still be spinning")
    sp.type.update(pl, world, 0.1, sp.params, false, pl.x + 30, pl.y + 50)
    local wall = world.hazards.walls[1]
    assert(wall and math.abs((wall.y2 - wall.y1) - 100) < 1, "silk wall not built")
    world:spawnRing("worker_ant", 12, pl.x + 70, pl.y, 8)
    pl.attack.timer = 1e9     -- don't web them before they reach the wall
    for _ = 1, 45 do world:update(1 / 30) end
    pl.attack.timer = 0
    assert(wall.caught > 0, "silk wall caught nothing")
    world:clearEnemies()
    pl:setCharacter(Content.characters:get("mantis"))
    sp = pl.secondary
    world.flags.freezeAI = true
    for k = -1, 1 do world:spawnEnemy("worker_ant", pl.x + 26, pl.y + k * 6) end
    world:update(1 / 60)
    pl.hp = 10
    sp.type.fire(pl, world, 1, 0, sp.params, pl.x + 80, pl.y)
    assert(pl.carry and #pl.carry.list > 0, "snatch caught nothing")
    for _ = 1, 4 do sp.type.update(pl, world, 0.05, sp.params, true, pl.x + 80, pl.y) end
    assert(pl.hp > 10, "munching did not heal")
    sp.type.update(pl, world, 0.05, sp.params, false, pl.x + 80, pl.y)
    assert(not pl.carry and #world.thrown > 0, "snatched ants were not flung")
    world.flags.freezeAI = false
    world:clearEnemies()
    print("[selftest] every special and dash OK")
    return game
end

-- Every item's procs firing at once in a live fight, plus a bag of the round-12 items.
--   love . --selftest --items   runs just this part
local function itemsScene()
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "sandbox", character = "rhino_beetle" }))
    wait(0.5)
    local world = game.world
    local pl, inv = world.player, world.player.inventory
    -- one stack of everything (past what the bag holds, so every proc is in play)
    inv:clear()
    for _, def in ipairs(Content.items:all()) do
        inv.counts[def.id] = 1
        inv.order[#inv.order + 1] = def.id
    end
    world.flags.demo, world.flags.god = true, false
    world:spawnRing("worker_ant", 40, pl.x, pl.y, 50)
    world:spawnRing("soldier_ant", 10, pl.x, pl.y, 90)
    local hpBefore = 0
    for k = 1, 8 do
        inv:trigger("onWaveStart", { world = world, player = pl, wave = k, procDepth = 0 })
        inv:trigger("onDash", { world = world, player = pl, procDepth = 0 })
        inv:trigger("onDodge", { world = world, player = pl, procDepth = 0 })
        pl.iframes = 0
        pl:hurt(4, "test")
        pl.hp = 0.5
        pl.iframes = 0
        pl:hurt(30, "test")            -- tardigrade / cicada shell keep the player alive
        assert(not pl.dead and pl.hp >= 1, "a killing bite should have been survived")
        pl:heal(1000)
        hpBefore = pl.hp
        wait(0.6)
        if world.enemyCount < 20 then world:spawnRing("worker_ant", 30, pl.x, pl.y, 60) end
    end
    local meal = Inventory.newItem("honeydew")
    -- the Hungry Tapeworm curse stops meals healing at all: take it out for the gut flora check
    inv.counts.hungry_tapeworm, inv.sums = nil, nil
    for i = #inv.order, 1, -1 do if inv.order[i] == "hungry_tapeworm" then table.remove(inv.order, i) end end
    pl.hp = 1
    local healed = inv:eat(meal)
    assert(healed > Inventory.eatValue(meal), "gut flora should make meals heal more")
    shot("items_procs")
    world.flags.demo, world.flags.god = false, true
    print("[selftest] all " .. #Content.items:all() .. " items' procs OK")
    -- the bag, filled with the new natural items
    inv:clear()
    pl:heal(1000)
    for _, id in ipairs({ "venus_flytrap", "honeycomb", "fly_agaric", "earthworm", "slime_mold", "mycelium", "amber",
                          "tardigrade", "quartz_crystal", "chili_pepper", "acorn_cap", "rose_thorn", "gnat_swarm" }) do
        inv:add(id)
    end
    world.flags.freezeAI = true
    local invState = State.push(require("src.states.inventory").new(game))
    invState:layout()
    for _, o in ipairs(inv.bag) do if o.item.id == "venus_flytrap" then invState.cursor = { kind = "bag", x = o.x, y = o.y + 1 } end end
    local lastDev = Input.lastDevice
    Input.lastDevice = "gamepad"
    wait(0.3)
    shot("items_bag")
    Input.lastDevice = lastDev
    invState:close()
    world.flags.freezeAI = false
end

-- The item catalogue and every sandbox tab, driven through their real code paths.
--   love . --selftest --sandboxkit   runs just this part
local function sandboxScene()
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "sandbox", character = "mantis" }))
    wait(0.4)
    local world, sb = game.world, game.sandbox
    local inv = world.player.inventory
    inv:clear()
    -- catalogue: every item listed, filters narrow it, giving and taking reach the bag
    local cat = State.push(require("src.states.itemcatalogue").new({ game = game }))
    assert(#cat.list == #Content.items:all(), "catalogue should list every item")
    cat:give(Content.items:require("amber"), 1)
    cat:give(Content.items:require("ember_gland"), 2)
    assert(inv:count("amber") == 1 and inv:count("ember_gland") == 2, "catalogue give")
    cat:take(Content.items:require("ember_gland"))
    assert(inv:count("ember_gland") == 1, "catalogue take")
    for i, tab in ipairs(cat.tabs) do
        cat:setTab(i)
        for _, def in ipairs(cat.list) do
            assert(tab.id == "all" or def.rarity == tab.id or (tab.id == "owned" and inv:count(def.id) > 0), "rarity tab " .. tab.id)
        end
    end
    cat:setTab(1)
    for i = 1, #cat.kinds do cat:setKind(i) end
    cat:setKind(1)
    cat.query = "gland"
    cat:refilter()
    assert(#cat.list >= 1, "search should find the glands")
    cat.query = ""
    cat:refilter()
    for _ = 1, 12 do cat:step(1, 0) end
    cat:step(0, 1)
    wait(0.3)
    shot("item_catalogue")
    State.pop()
    local menuCat = State.push(require("src.states.itemcatalogue").new())
    wait(0.2)
    shot("item_catalogue_menu")
    State.pop()
    assert(menuCat.game == nil and State.top() == game)
    -- spawn catalogue: enemies / queens / characters as pictures; spawn, place, play as
    local sc = State.push(require("src.states.spawncatalogue").new({ game = game, tab = "enemies" }))
    local nEnemies, nQueens = 0, 0
    for _, def in ipairs(Content.enemies:all()) do if def.boss then nQueens = nQueens + 1 else nEnemies = nEnemies + 1 end end
    assert(#sc.list == nEnemies, "spawn catalogue should list every enemy")
    for i = 2, #sc.families do
        sc:setFamily(i)
        for _, def in ipairs(sc.list) do assert(def.family == sc.families[i].id, "family filter") end
    end
    sc:setFamily(1)
    sb.amount, sb.elite = 5, "none"
    local before = world.enemyCount
    sc:step(1, 0)
    assert(sb.enemy == sc.list[sc.focus].id, "focusing an enemy makes it the sandbox pick")
    sc:spawnAround(sc.list[sc.focus])
    assert(world.enemyCount == before + 5, "spawn catalogue spawns Amount enemies")
    for _, row in ipairs(sc:optionRows()) do row.set(row.options[#row.options][1]) end
    sb.amount, sb.elite, sb.hpMul = 5, "none", 1
    for i = 1, 3 do
        sc:setTab(i)
        for _ = 1, 9 do sc:step(0, 1) end
        sc:wheelmoved(0, -50)
        wait(0.15)
        shot("spawn_catalogue_" .. sc:kind())
    end
    sc:setTab(2)
    assert(#sc.list == nQueens, "queen tab lists every queen")
    sc:place(sc.list[1])
    assert(State.top() == game and sb.placing and sb.placing.boss, "place closes and arms placing")
    before = world.enemyCount
    sb:placeAt(world.player.x + 60, world.player.y)
    assert(world.enemyCount == before + 1, "placing a queen drops one")
    sb.placing = nil
    sc = State.push(require("src.states.spawncatalogue").new({ game = game, tab = "characters" }))
    local other
    for _, def in ipairs(sc.list) do if def.id ~= world.player.def.id then other = def break end end
    sc:playAs(other)
    assert(world.player.def.id == other.id, "play as switches character")
    sb:setCharacter("mantis")
    inv = world.player.inventory
    State.pop()
    world:clearEnemies()
    -- every sandbox tab draws, and its buttons work
    for t = 1, 5 do
        sb:setTab(t)
        wait(0.15)
        shot("sandbox_tab" .. t)
    end
    sb:setTab(1)
    sb.hpMul = 1000
    for _, it in ipairs(sb.menu.items) do
        if it.label == "Every species at once" or it.label == "Every elite of this ant" or it.label == "March in from the edge" then it.onActivate() end
    end
    assert(world.enemyCount > 20, "sandbox spawns")
    sb.hpMul = 1
    sb:setTab(2)
    sb.bag = 3
    sb:applyBag()
    assert(inv.cols == 14 and inv.rows == 9, "bigger bag")
    for _, def in ipairs(Content.items:all()) do world:giveItem(def.id) end
    sb.bag = 1
    sb:applyBag()
    assert(inv.cols == 10 and inv.rows == 3, "bag back to normal")
    sb:setTab(3)
    for _, it in ipairs(sb.menu.items) do
        if it.type == "slider" then it.set(it.max); it.set(it.min); it.set(it.get()) end
        if it.label == "Reset stats" or it.label == "Take 10 damage" then it.onActivate() end
    end
    assert(not world.player.dead, "sandbox hurt must not kill")
    sb:setTab(4)
    sb:startWave(5)
    assert(world.spawner.wave == 5 and world.spawner.bossWave, "wave 5 is a queen wave")
    wait(1.5)
    shot("sandbox_wave5")
    world:clearEnemies()
    world.spawner.queue, world.spawner.streams = {}, {}
    sb:setTab(5)
    wait(1)
    print("[selftest] sandbox kit OK (proc log " .. #sb.procs .. " entries, " .. sb.meter.kills .. " kills metered)")
end

-- Phone touch controls: stick, drag-to-aim special, dash, bag, pause and menu taps.
--   love . --selftest --touchtest   runs just this part
local function touchScene()
    local Touch = require("src.core.touch")
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "sandbox", character = "rhino_beetle" }))
    wait(0.5)
    local world, pl = game.world, game.world.player
    game.sandbox.visible = false
    world:clearEnemies()
    local wasActive = Touch.active
    Touch.active = true
    local function button(id)
        for _, b in ipairs(Touch.buttons()) do if b.id == id then return b end end
        error("no touch button " .. id)
    end
    -- the stick walks the bug
    local x0, y0 = pl.x, pl.y
    local w, h = love.graphics.getDimensions()
    Touch.pressed(1, w * 0.2, h * 0.7)
    Touch.moved(1, w * 0.2 + h * 0.3, h * 0.7)
    wait(0.4)
    assert(Input.virtualMove and util.len(pl.x - x0, pl.y - y0) > 10, "touch stick did not move the bug")
    shot("touch_controls")
    Touch.released(1, w * 0.2 + h * 0.3, h * 0.7)
    assert(not Input.virtualMove, "stick should let go")
    -- drag-to-aim special: nothing while held, fires on release
    local sec = pl.secondary
    sec.timer = 0
    local sp = button("special")
    assert(sp.fireOnRelease, "the rhino's special should be drag-to-aim")
    Touch.pressed(2, sp.x, sp.y)
    Touch.moved(2, sp.x - sp.r, sp.y)
    wait(0.1)
    assert(sec.timer <= 0 and Input.virtualAim and Input.virtualAim.x < 0, "special should aim while held")
    Touch.released(2, sp.x - sp.r, sp.y)
    wait(0.1)
    assert(sec.timer > 0, "special should fire on release")
    -- dash: a tap
    local charges = pl.dashCharges
    local d = button("dash")
    Touch.pressed(3, d.x, d.y)
    wait(0.05)
    Touch.released(3, d.x, d.y)
    assert(pl.dashCharges < charges, "dash button did not dash")
    wait(0.5)
    -- bag opens the inventory, CLOSE shuts it
    local bag = button("bag")
    Touch.pressed(4, bag.x, bag.y)
    Touch.released(4, bag.x, bag.y)
    wait(0.1)
    assert(State.top().touchControls == "inventory", "bag button should open the inventory")
    local close = button("close")
    Touch.pressed(5, close.x, close.y)
    Touch.released(5, close.x, close.y)
    wait(0.1)
    assert(State.top() == game, "close button should shut the inventory")
    -- pause, then a tap on Resume (taps are clicks in menus)
    local pause = button("pause")
    Touch.pressed(6, pause.x, pause.y)
    Touch.released(6, pause.x, pause.y)
    wait(0.1)
    local ps = State.top()
    assert(ps ~= game and ps.menu, "pause button should pause")
    local mx, my = ps.menu:rect()
    Touch.pressed(7, mx + 20, my + ps.menu:rowH() / 2)
    Touch.released(7, mx + 20, my + ps.menu:rowH() / 2)
    wait(0.1)
    assert(State.top() == game, "tapping Resume should resume")
    Touch.active = wasActive
    print("[selftest] touch controls OK")
end

-- Termites: burrowing workers, alarm soldiers, glue nasutes, egg-laying neotenics, and the
-- queen with her king.   love . --selftest --termites   runs just this part
local function termiteScene()
    local Game = require("src.states.game")
    local Combat = require("src.game.combat")
    local game = State.switch(Game.new({ mode = "sandbox", character = "rhino_beetle" }))
    wait(0.5)
    local world = game.world
    local pl = world.player
    world.flags.god = true
    pl.attack.timer = 1e9
    world:clearEnemies()
    pl.x, pl.y = world.size * 0.5, world.size * 0.5
    -- a worker starts buried: untouchable until it surfaces next to the player
    local w = world:spawnEnemy("termite_worker", pl.x + 120, pl.y)
    assert(w.hidden, "termite worker should start underground")
    assert(Combat.damage(world, w, 50) == 0, "a buried termite took damage")
    for _ = 1, 150 do world:update(1 / 30) if not w.hidden then break end end
    assert(not w.hidden and w.st.mode == "up", "termite worker never surfaced")
    assert((w.x - pl.x) ^ 2 + (w.y - pl.y) ^ 2 < 40 * 40, "termite surfaced far from the player")
    -- a hurt soldier drums an alarm: termites around it go into a frenzy
    world:clearEnemies()
    local s = world:spawnEnemy("termite_soldier", pl.x + 60, pl.y)
    local mate = world:spawnEnemy("termite_nasute", pl.x + 70, pl.y + 8)
    Combat.damage(world, s, 1, { noCrit = true })
    assert(s.st.mode == "drum", "hurt soldier did not drum")
    for _ = 1, 30 do world:update(1 / 30) end
    assert(mate.slowT > 0 and mate.slowMul > 1, "alarm did not frenzy nearby termites")
    -- nasutes squirt glue that leaves sticky patches
    world:clearEnemies()
    world:spawnEnemy("termite_nasute", pl.x + 90, pl.y)
    local glue = false
    for _ = 1, 150 do
        world:update(1 / 30)
        for _, z in ipairs(world.hazards.zones) do if z.kind == "glue" then glue = true end end
        if glue then break end
    end
    assert(glue, "nasute never left a glue patch")
    -- a neotenic lays a clutch, and the clutch hatches into termites
    world:clearEnemies()
    world:spawnEnemy("termite_neotenic", pl.x + 150, pl.y)
    local egg
    for _ = 1, 150 do
        world:update(1 / 30)
        for i = 1, world.enemyCount do if world.enemies[i].def.id == "termite_eggs" then egg = world.enemies[i] end end
        if egg then break end
    end
    assert(egg, "neotenic laid no eggs")
    local before = world.enemyCount
    egg.st.t = 0.01
    world:update(1 / 30)
    world:update(1 / 30)
    assert(world.enemyCount > before, "egg clutch did not hatch")
    -- the queen arrives with her king; he keeps her healing, and rages when she dies
    world:clearEnemies()
    world.hazards:clear()
    local q = world:spawnEnemy("queen_termite", pl.x + 90, pl.y - 20)
    assert(world.boss == q, "termite queen is not a boss")
    world:update(1 / 30)
    local king = q.st.king
    assert(king and king.def.id == "termite_king", "termite queen came without her king")
    for i = 1, 8 do world:spawnRing(({ "termite_worker", "termite_soldier", "termite_nasute", "termite_neotenic" })[i % 4 + 1], 3, pl.x - 60 + i * 12, pl.y + 50, 10) end
    q.hp = q.maxHp * 0.5
    local hp0 = q.hp
    for _ = 1, 60 do world:update(1 / 30) end
    assert(q.hp > hp0, "tended queen did not heal")
    wait(0.5)
    shot("termites")
    king.hp = 1
    Combat.damage(world, king, 5, { noCrit = true })
    world:update(1 / 30)
    assert(not q.behavior.kingAlive(q.st), "queen still thinks the king lives")
    world:clearEnemies()
    q = world:spawnEnemy("queen_termite", pl.x + 90, pl.y - 20)
    world:update(1 / 30)
    king = q.st.king
    q.hp = 1
    Combat.damage(world, q, 5, { noCrit = true })
    for _ = 1, 40 do world:update(1 / 30) end     -- (a queen's death freezes the action, then slow motion)
    assert(king.st.widowed, "king did not notice the queen dying")
    world:clearEnemies()
    world.hazards:clear()
    print("[selftest] termites OK")
end

-- Round 14: bees, wasps and hornets. Checks the mechanics that are easy to break: barbed
-- stings, burrowing, armour, curling up, paralysis, blinding, zombies, carrying, nests, cages,
-- heat balls and raids.   love . --selftest --hymenoptera   runs just this part
local function hymenopteraScene()
    local Game = require("src.states.game")
    local Combat = require("src.game.combat")
    local AI = require("src.game.ai")
    local game = State.switch(Game.new({ mode = "sandbox", character = "rhino_beetle" }))
    wait(0.5)
    local world = game.world
    local pl = world.player
    world.flags.god = true
    pl.attack.timer = 1e9
    local function run(sec) for _ = 1, math.floor(sec * 60) do world:update(1 / 60) end end
    local function reset()
        world:clearEnemies()
        pl.x, pl.y = world.size * 0.5, world.size * 0.5
        pl.venomT, pl.stunT, pl.blindT, pl.gumT, pl.gumMul = 0, 0, 0, 0, 1
    end
    local function count(id)
        local n = 0
        for i = 1, world.enemyCount do if world.enemies[i].def.id == id and not world.enemies[i].dead then n = n + 1 end end
        return n
    end
    reset()
    -- a honey bee stings once, leaves venom and dies
    local b = world:spawnEnemy("honey_bee", pl.x + 14, pl.y)
    run(1)
    assert(count("honey_bee") == 0 and pl.venomT > 0, "honey bee did not sting and die")
    -- mining bee: untouchable while tunnelling
    reset()
    b = world:spawnEnemy("mining_bee", pl.x + 60, pl.y)
    b.st.mode, b.st.t = "land", 0
    run(0.1)
    assert(b.hidden and Combat.damage(world, b, 50) == 0, "mining bee was hittable underground")
    run(3)
    assert(not b.hidden, "mining bee never came back up")
    -- velvet ant: weak hits glance off, heavy ones land
    reset()
    local v = world:spawnEnemy("velvet_ant", pl.x + 60, pl.y)
    v.hp, v.maxHp = 999, 999
    local weak = Combat.damage(world, v, 3, { noCrit = true })
    local strong = Combat.damage(world, v, 20, { noCrit = true })
    assert(weak <= 1 and strong >= 20, "velvet ant armour threshold is off (" .. weak .. ", " .. strong .. ")")
    -- cuckoo wasp: curls into a ball and shrugs off the next hit
    local cw = world:spawnEnemy("cuckoo_wasp", pl.x - 60, pl.y)
    cw.hp, cw.maxHp = 999, 999
    Combat.damage(world, cw, 10, { noCrit = true, kbx = -1, kby = 0 })
    assert(cw.st.mode == "ball", "cuckoo wasp did not curl up")
    assert(Combat.damage(world, cw, 10, { noCrit = true }) <= 1, "curled cuckoo wasp was not armoured")
    -- tarantula hawk: the sting paralyses and drags
    reset()
    local th = world:spawnEnemy("tarantula_hawk", pl.x + 12, pl.y)
    th.st.mode, th.st.t, th.st.dx, th.st.dy = "lunge", 0.25, -1, 0
    run(0.1)
    assert(pl.stunT > 0 and th.st.mode == "drag", "tarantula hawk did not paralyse")
    local x0 = pl.x
    run(0.5)
    assert(math.abs(pl.x - x0) > 3, "tarantula hawk did not drag the player")
    run(2)
    assert(pl.stunT <= 0, "paralysis did not wear off")
    -- bald-faced hornet: the venom jet blinds
    reset()
    local bf = world:spawnEnemy("bald_faced_hornet", pl.x + 50, pl.y)
    bf.st.mode, bf.st.t = "windup", 0
    run(0.6)
    assert(pl.blindT > 0, "bald-faced hornet's jet did not blind")
    shot("hymenoptera_blinded")
    -- stingless bees gum up the jaws
    reset()
    world:spawnRing("stingless_bee", 4, pl.x, pl.y, 12)
    run(2.5)
    assert(pl.gumMul < 1, "stingless bee did not gum up attacks")
    -- jewel wasp zombifies an ant; cicada killer carries one off
    reset()
    world:spawnRing("soldier_ant", 6, pl.x + 120, pl.y, 10)
    local jw = world:spawnEnemy("jewel_wasp", pl.x + 100, pl.y)
    jw.st.cd = 0
    local ck = world:spawnEnemy("cicada_killer", pl.x + 110, pl.y + 10)
    ck.st.cd = 0
    local zombie, carried = false, false
    for _ = 1, 300 do
        world:update(1 / 60)
        for i = 1, world.enemyCount do
            local e = world.enemies[i]
            if e.elite and e.elite.id == "zombified" then zombie = true end
            if e.held and e.heldBy == ck then carried = true end
        end
    end
    assert(zombie, "jewel wasp did not zombify an ant")
    assert(carried, "cicada killer did not pick up an ant")
    world:killEnemy(ck)
    run(0.1)
    for i = 1, world.enemyCount do assert(not world.enemies[i].held, "ant still held after the cicada killer died") end
    -- paper wasp builds a nest that releases wasps; mud dauber builds pipes
    reset()
    local pw = world:spawnEnemy("paper_wasp", pl.x + 80, pl.y)
    pw.st.mode, pw.st.tx, pw.st.ty, pw.st.t = "build", pl.x + 80, pl.y, 0
    run(0.1)
    assert(count("paper_nest") == 1, "paper wasp built no nest")
    run(4.5)
    assert(count("paper_wasp") >= 2, "the nest released no wasps")
    local md = world:spawnEnemy("mud_dauber", pl.x - 40, pl.y)
    md.st.t = 0
    run(5)
    assert(count("mud_pipe") >= 3, "mud dauber built no pipes")
    shot("hymenoptera_builders")
    -- Japanese honey bees heat up a ball round the player
    reset()
    world:spawnRing("japanese_honey_bee", 10, pl.x, pl.y, 20)
    local hot = 0
    for _ = 1, 360 do
        world:update(1 / 60)
        local _, g = AI.group(world, "japanese_honey_bee")
        hot = math.max(hot, g.heat or 0)
    end
    assert(hot > 0.3, "Japanese honey bees never heated up")
    -- giant hornet marks you and calls a raid
    reset()
    local gh = world:spawnEnemy("giant_hornet", pl.x + 40, pl.y)
    run(2)
    assert(gh.st.marked, "giant hornet did not mark the player")
    run(3)
    assert(count("giant_hornet") >= 2, "no raid arrived")
    -- everything at once, flying about
    reset()
    local list = Content.enemies:filter(function(d) return (d.family == "bee" or d.family == "wasp" or d.family == "hornet") and d.spawn.weight > 0 end)
    for i, d in ipairs(list) do
        local a = i / #list * math.pi * 2
        world:spawnRing(d.id, 2, pl.x + math.cos(a) * 100, pl.y + math.sin(a) * 100, 6)
    end
    world.flags.god = true
    local Settings = require("src.core.settings")
    Settings.set("timeOfDay", "day")
    pl.blindT = 0
    wait(3)
    shot("hymenoptera")
    pl.attack.timer = 0
    wait(2)
    Settings.set("timeOfDay", "cycle")
    reset()
    print("[selftest] hymenoptera OK (" .. #list .. " species)")
end

local function script(flags)
    if flags["--termites"] then termiteScene() love.event.quit() return end
    if flags["--finalwave"] then require("src.debug.selftest_finalwave")(wait, shot) love.event.quit() return end
    if flags["--entries"] then require("src.debug.selftest_entries")(wait, shot) love.event.quit() return end
    if flags["--gentle"] then require("src.debug.selftest_gentle")(wait, shot) love.event.quit() return end
    if flags["--gambles"] then require("src.debug.selftest_gambles")(wait, shot) love.event.quit() return end
    if flags["--hazards"] then require("src.debug.selftest_hazards")(wait, shot) love.event.quit() return end
    if flags["--happenings"] then require("src.debug.selftest_happenings")(wait, shot) love.event.quit() return end
    if flags["--props"] then require("src.debug.selftest_props")(wait, shot) love.event.quit() return end
    if flags["--stability"] then require("src.debug.selftest_stability")(wait, shot) love.event.quit() return end
    if flags["--rewards"] then require("src.debug.selftest_rewards")(wait, shot) love.event.quit() return end
    if flags["--economy"] then require("src.debug.selftest_economy")(wait, shot) love.event.quit() return end
    if flags["--choiceqol"] then require("src.debug.selftest_choiceqol")(wait, shot) love.event.quit() return end
    if flags["--molts"] then require("src.debug.selftest_molts")(wait, shot) love.event.quit() return end
    if flags["--nectar"] then require("src.debug.selftest_nectar")(wait, shot) love.event.quit() return end
    if flags["--combat"] then require("src.debug.selftest_combat")(wait, shot) love.event.quit() return end
    if flags["--skipwave"] then require("src.debug.selftest_skipwave")(wait, shot) love.event.quit() return end
    if flags["--arttour"] then require("src.debug.selftest_arttour")(wait, shot) love.event.quit() return end
    if flags["--itemorg"] then require("src.debug.selftest_itemorg")(wait, shot) love.event.quit() return end
    if flags["--uitour"] then require("src.debug.selftest_ui")(wait, shot) love.event.quit() return end
    if flags["--creator"] then require("src.debug.selftest_creator")(wait, shot) love.event.quit() return end
    if flags["--hudsize"] then require("src.debug.selftest_hudsize")(wait, shot) love.event.quit() return end
    if flags["--batch1"] then require("src.debug.selftest_batch1")(wait, shot) love.event.quit() return end
    if flags["--rework2"] then require("src.debug.selftest_rework2")(wait, shot) love.event.quit() return end
    if flags["--rework3"] then require("src.debug.selftest_rework3")(wait, shot) love.event.quit() return end
    if flags["--dashes"] then require("src.debug.selftest_dashes")(wait, shot) love.event.quit() return end
    if flags["--levelups"] then require("src.debug.selftest_levelups")(wait, shot) love.event.quit() return end
    if flags["--skills"] then require("src.debug.selftest_skills")(wait, shot) love.event.quit() return end
    if flags["--cosmetics"] then require("src.debug.selftest_cosmetics")(wait, shot) love.event.quit() return end
    if flags["--qol"] then require("src.debug.selftest_qol")(wait, shot) love.event.quit() return end
    if flags["--customwaves"] then require("src.debug.selftest_customwaves")(wait, shot) love.event.quit() return end
    if flags["--modes"] then require("src.debug.selftest_modes")(wait, shot) love.event.quit() return end
    if flags["--mastery"] then require("src.debug.selftest_mastery")(wait, shot) love.event.quit() return end
    if flags["--records"] then require("src.debug.selftest_records")(wait, shot) love.event.quit() return end
    if flags["--runinfo"] then require("src.debug.selftest_runinfo")(wait, shot) love.event.quit() return end
    if flags["--polish"] then require("src.debug.selftest_polish")(wait, shot) love.event.quit() return end
    if flags["--pacing"] then require("src.debug.selftest_pacing")(wait, shot) love.event.quit() return end
    if flags["--hymenoptera"] then hymenopteraScene() love.event.quit() return end
    if flags["--animtest"] then require("src.debug.selftest_anims")(wait, shot) love.event.quit() return end
    if flags["--specials"] then specialsScene() love.event.quit() return end
    if flags["--touchtest"] then touchScene() love.event.quit() return end
    if flags["--items"] then itemsScene() love.event.quit() return end
    if flags["--sandboxkit"] then sandboxScene() love.event.quit() return end
    if flags["--inventory"] then
        local g = State.switch(require("src.states.game").new({ mode = "sandbox", character = "rhino_beetle" }))
        wait(0.5)
        inventoryScene(g, g.world)
        love.event.quit()
        return
    end
    wait(6)
    shot("menu")

    local Settings = require("src.core.settings")
    local settings = State.push(require("src.states.settings").new())
    wait(0.2)
    shot("settings_video")
    for _ = 1, 5 do settings:switchTab(1) end
    wait(0.2)
    shot("settings_controls")
    -- Poke every setting both ways on every tab, then restore defaults.

    for tab = 1, #settings.categories do
        settings.tab = tab
        settings:build()
        for _, it in ipairs(settings.menu.items) do
            if it.type == "toggle" or it.type == "slider" or it.type == "choice" then
                settings.menu:adjust(it, 1)
                settings.menu:adjust(it, -1)
            end
        end
        Settings.resetCategory(settings.categories[tab])
    end
    -- Rebind dash to K through the real capture path, check it, then reset.
    settings.tab = util_indexOf(settings.categories, "Controls")
    settings:build()
    for _, it in ipairs(settings.menu.items) do
        if it.type == "keybind" and it.action == "dash" and it.slot == 1 then settings.menu:activate(it) break end
    end
    Input.keypressed("k", false)
    assert(Input.getKeys("dash")[1] == "k", "rebinding failed")
    Settings.resetCategory("Controls")
    assert(Input.getKeys("dash")[1] == "space", "reset bindings failed")
    print("[selftest] settings + rebinding OK")
    State.pop()

    State.push(require("src.states.catalogue").new())
    wait(0.3)
    shot("catalogue")
    State.pop()

    State.push(require("src.states.charselect").new())
    wait(0.3)
    shot("charselect")

    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "run", character = "rhino_beetle" }))
    game.world.flags.god = true
    local sp = game.world.spawner
    -- wave 4: three species already met, a fourth introduced alone, from several sides
    sp:startWave(4)
    assert(#sp.knownList == 4 and sp.newSpecies == sp.knownList[4], "wave 4 should introduce a 4th species")
    assert(#sp.entries >= 3, "ants should come from several sides")
    for _, g in ipairs(sp.queue) do
        assert(sp.known[g.def.id], "a wave sent a species not introduced yet: " .. g.def.id)
    end
    print("[selftest] wave intro OK: " .. sp.newSpecies.name .. " (" .. #sp.entries .. " entries, " .. #sp.queue .. " groups)")
    wait(2.6)
    shot("species_intro")
    for _ = 1, 6 do sp:spawnGroup() end
    wait(3)
    shot("run")
    -- the wave never times out: it ends only once every enemy is dead
    sp.queue, sp.streams = {}, {}
    sp.waveTime = 500
    wait(0.3)
    assert(sp.phase == "wave" and game.world.enemyCount > 0, "wave ended with enemies still alive")
    game.world:clearEnemies()
    wait(0.5)
    assert(sp.phase == "break", "wave did not end after clearing it")
    shot("wave_break")
    -- the wave's rewards sprout as a bloom next to the bug; walking into it opens them
    wait(1.2)
    local bloom = game.world.rewardFlow:bloom()
    assert(bloom, "no reward bloom after the wave")
    assert(State.top() == game, "reward screens opened before the bloom was touched")
    shot("reward_bloom")
    game.world.player.x, game.world.player.y = bloom.x, bloom.y
    wait(1.0)
    -- level-up cards earned in the wave come first, right before the item choice
    for _ = 1, 20 do
        local top = State.top()
        if not top.lu then break end
        top.t = 10
        top:activate(1); top:activate(1)
        wait(0.05)
    end
    assert(#game.world.levelups.queue == 0, "level-up picks left over")
    local choice = State.top()
    assert(choice.items and #choice.items >= 3, "no item choice after the wave")
    local ids = {}
    for _, it in ipairs(choice.items) do assert(not ids[it.id], "duplicate card"); ids[it.id] = true end
    -- no accidental picks: ignored while it opens, then pick + confirm
    local before = #game.world.player.inventory.bag
    choice.t = 0
    choice:activate(1)
    assert(State.top() == choice and not choice.armed, "item choice took input while opening")
    wait(choice.ARM_TIME + 0.1)
    choice:activate(1)
    assert(State.top() == choice and choice.armed == 1, "first press should only pick the card")
    shot("item_choice")
    choice:activate(1)
    assert(State.top() == game and #game.world.player.inventory.bag == before + 1, "taking an item failed")
    print("[selftest] item choice OK")
    wait(sp.timer + 0.6)
    assert(game.world.spawner.phase == "wave", "next wave did not start")
    shot("wave_start")
    -- jump to a boss wave: a queen must arrive
    game.world:clearEnemies()
    game.world.spawner.streams = {}
    game.world.spawner:startWave(5)
    wait(3)
    assert(game.world.boss and game.world.boss.def.boss, "no queen on the boss wave")
    print("[selftest] boss wave OK: " .. game.world.boss.def.name)
    shot("boss_wave")
    State.push(require("src.states.pause").new(game))
    wait(0.2)
    shot("pause")
    State.pop()

    -- Dash, then die and reach the results screen.
    Input.keypressed("space", false)
    wait(0.08)
    shot("dash")
    wait(0.3)
    game.world.flags.god = false
    game.world.player.iframes = 0
    game.world.player.hp = 1
    game.world.player:hurt(999)
    wait(2)
    assert(State.top() ~= game, "game over screen did not appear")
    shot("gameover")

    game = State.switch(Game.new({ mode = "sandbox", character = "wolf_spider" }))
    local world = game.world
    world.player.inventory:add("static_antenna", 3)
    world.player.inventory:add("ember_gland", 2)
    world:spawnRing("worker_ant", 300, world.player.x, world.player.y, 90)
    world:spawnRing("fire_ant", 150, world.player.x, world.player.y, 160)
    world:spawnRing("soldier_ant", 50, world.player.x, world.player.y, 200)
    wait(2.5)
    shot("sandbox")

    -- Crowd damage: ten biting ants must hurt far more than one.
    local function biteTest(n)
        world:clearEnemies()
        world.flags.god = false
        local pl = world.player
        pl.iframes = 0
        pl.attack.timer = 1e9      -- don't kill the test ants
        for i = 1, n do world:spawnEnemy("worker_ant", pl.x + math.cos(i) * 4, pl.y + math.sin(i) * 4) end
        world.flags.freezeAI = true
        local lost = 0
        -- (weather can slow the fight down, and a big moment freezes it: keep both out of the count)
        local weather = Settings.get("weatherEffects")
        Settings.set("weatherEffects", false)
        for _ = 1, 120 do
            local full = pl.stats:get("maxHp")
            pl.hp = full           -- keep it alive and measure what each frame takes
            world.hitstop = 0
            world:update(1 / 60)
            lost = lost + math.max(0, full - pl.hp)
        end
        Settings.set("weatherEffects", weather)
        world.flags.freezeAI = false
        world.flags.god = true
        pl.attack.timer = 0
        pl.hp = pl.stats:get("maxHp")
        return lost
    end
    local one, ten = biteTest(1), biteTest(10)
    print(("[selftest] bites over 2s: 1 ant %.1f dmg, 10 ants %.1f dmg"):format(one, ten))
    assert(ten > one * 5, "damage does not scale with the number of attackers")

    -- Every species and a queen, side by side, fighting for a few seconds.
    world:clearEnemies()
    world.ground:clearDecals()
    local species = Content.enemies:filter(function(d) return not d.boss end)
    for i, d in ipairs(species) do
        local a = i / #species * math.pi * 2
        world:spawnRing(d.id, 4, world.player.x + math.cos(a) * 90, world.player.y + math.sin(a) * 90, 6)
    end
    world:spawnEnemy("queen_honeypot", world.player.x + 110, world.player.y - 30)
    assert(world.boss, "queen did not register as boss")
    world.player.attack.timer = 1e9    -- let them show off instead of dying instantly
    wait(3)
    shot("species")
    world.player.attack.timer = 0
    State.push(require("src.states.catalogue").new())
    for _ = 1, 12 do Input.keypressed("down", false) wait(0.02) end
    wait(0.2)
    shot("catalogue_new")
    State.pop()
    world:clearEnemies()
    assert(world.boss == nil)

    -- Round 7: charge interrupts, returning shots, latching, elites, time of day.
    local Combat = require("src.game.combat")
    local pl = world.player
    pl.attack.timer = 1e9
    world.flags.god = true
    for _, id in ipairs({ "soldier_ant", "bullet_ant", "bigheaded_ant" }) do
        local ch = world:spawnEnemy(id, pl.x + 60, pl.y, "armored")
        ch.hp, ch.maxHp = 999, 999
        ch.st.mode, ch.st.t, ch.st.dx, ch.st.dy = "windup", 0.5, -1, 0
        Combat.damage(world, ch, 1, { kbx = 1, kby = 0 })
        assert(ch.st.mode == "stagger", id .. " was not staggered out of its charge")
    end
    world:clearEnemies()
    local acid = world.hazards:shoot({ x = pl.x + 20, y = pl.y, vx = -150, vy = 0, r = 3, damage = 4, life = 2, color = { 0.5, 1, 0.3 } })
    local victim = world:spawnEnemy("worker_ant", pl.x + 70, pl.y)
    victim.hp, victim.maxHp = 999, 999
    world.flags.freezeAI = true
    assert(world.hazards:deflect(pl.x, pl.y, 40, 0, 1.2) == 1 and acid.friendly and acid.vx > 0, "acid was not returned")
    for _ = 1, 40 do world:update(1 / 60) end
    assert(victim.hp < 999, "returned acid did not hurt the ant")
    world.flags.freezeAI = false
    world:clearEnemies()
    for i = 1, 8 do world:spawnEnemy("driver_ant", pl.x + math.cos(i) * 12, pl.y + math.sin(i) * 12) end
    for _ = 1, 60 do world:update(1 / 60) end
    assert(world.latchCount > 0 and pl.slowMul < 1, "driver ants did not latch on")
    pl.dashT = 0.1
    world:update(1 / 60)
    pl.dashT = 0
    world:update(1 / 60)
    assert(world.latchCount == 0, "dash did not shake off the driver ants")
    print("[selftest] interrupts, returned acid, latching OK")

    -- The new species with every elite affix, on a sunny day.
    world:clearEnemies()
    world.ground:clearDecals()
    Settings.set("timeOfDay", "day")
    local newOnes = { "flying_ant", "weaver_ant", "bulldog_ant", "driver_ant", "dracula_ant", "matabele_ant",
        "pharaoh_ant", "bigheaded_ant", "desert_ant", "pebble_ant" }
    -- a frozen line-up first, so each species can be seen clearly
    world.flags.freezeAI = true
    for i, id in ipairs(newOnes) do
        local a = i / #newOnes * math.pi * 2
        world:spawnRing(id, id == "pharaoh_ant" and 8 or 3, pl.x + math.cos(a) * 60, pl.y + math.sin(a) * 60, -30)
    end
    wait(0.5)
    shot("round7_lineup")
    world.flags.freezeAI = false
    world:clearEnemies()
    for i, id in ipairs(newOnes) do
        local a = i / #newOnes * math.pi * 2
        world:spawnRing(id, id == "pharaoh_ant" and 14 or 4, pl.x + math.cos(a) * 95, pl.y + math.sin(a) * 95, 8)
    end
    wait(3)
    shot("round7_species")
    pl.attack.timer = 0
    wait(3)
    world:clearEnemies()
    Settings.set("timeOfDay", "sunset")
    local elites = Content.elites:all()
    for i, el in ipairs(elites) do
        local a = i / #elites * math.pi * 2
        local sp = { "green_ant", "worker_ant", "soldier_ant", "bulldog_ant", "weaver_ant" }
        world:spawnRing(sp[(i - 1) % #sp + 1], 3, pl.x + math.cos(a) * 70, pl.y + math.sin(a) * 70, 6, el)
    end
    pl.attack.timer = 1e9
    wait(2.5)
    shot("round7_elites")
    pl.attack.timer = 0
    Settings.set("timeOfDay", "night")
    wait(1.5)
    shot("round7_night")
    Settings.set("timeOfDay", "cycle")
    local cat = State.push(require("src.states.catalogue").new())
    for i, it in ipairs(cat.menu.items) do if it.elite and it.elite.id == "aggressive" then cat.menu.focus = i end end
    wait(0.3)
    shot("round7_catalogue_elite")
    State.pop()
    world:clearEnemies()
    for _, id in ipairs(newOnes) do world:spawnEnemy("queen_" .. id:gsub("_ant", ""), pl.x + 150, pl.y) world:clearEnemies() end

    -- Every character fights for a moment with its own attack.
    world:clearEnemies()
    world.flags.freezeAI = false
    world.flags.god = true
    for _, cdef in ipairs(Content.characters:all()) do
        world.player:setCharacter(cdef)
        -- (let the last bug's moves wind down first: a held mode or a block left over from it
        -- can hold back the first attack until the crowd is already hugging the new bug)
        wait(0.5)
        world.player.attack.timer = 0
        -- (a ring a little out, so the ants walk in through ranged puffs such as stink clouds,
        -- which land about 50 out and would miss a crowd already hugging the bug)
        world:spawnRing("worker_ant", 40, world.player.x, world.player.y, 50)
        world:spawnRing("green_ant", 4, world.player.x, world.player.y, 90)
        local before = world.kos
        -- slow killers (stink clouds, a small dung ball) need longer on a slow test machine
        for _ = 1, 40 do
            wait(0.2)
            if world.kos > before then break end
        end
        assert(world.kos > before, cdef.id .. " did not kill anything")
        -- special attack and dash
        local pl2 = world.player
        world:spawnRing("worker_ant", 20, pl2.x + 50, pl2.y, 20)
        local sec = pl2.secondary
        assert(sec, cdef.id .. " has no special attack")
        sec.type.fire(pl2, world, 1, 0, sec.params, pl2.x + 60, pl2.y)
        if pl2.dung then pl2.dung.r = 14 end      -- dung beetle can only ride a big ball
        if pl2.dashDef.hold and not pl2.dashDef.blocked then
            -- hold-Shift stamina modes (run, fly, dig, roll): on for a moment, then off
            pl2.dashDef.update(pl2, world, 0.016, pl2.dashParams, true)
            assert(pl2.holdMode or not pl2.dashDef.stamina, cdef.id .. " hold mode did not start")
            pl2.dashDef.update(pl2, world, 0.3, pl2.dashParams, true)
            pl2.dashDef.update(pl2, world, 0.016, pl2.dashParams, false)
            assert(not pl2.holdMode, cdef.id .. " hold mode did not stop")
        elseif pl2.dashDef.hold then
            pl2.dashDef.update(pl2, world, 0.016, pl2.dashParams, true)
            world.flags.god = false
            local hp = pl2.hp
            pl2.iframes = 0
            pl2:hurt(10, world.enemies[1])
            assert(pl2.hp == hp, "block did not stop damage")
            pl2.dashDef.update(pl2, world, 0.016, pl2.dashParams, false)
            world.flags.god = true
        else
            pl2.dashDef.start(pl2, world, 0, 1, pl2.dashParams, pl2.x - 80, pl2.y)
        end
        wait(0.8)
        if cdef.id == "bombardier_beetle" or cdef.id == "orb_weaver" or cdef.id == "lobster" or cdef.id == "mantis" then
            shot("chars_" .. cdef.id)
        end
        world:clearEnemies()
        world.hazards:clear()
    end
    -- the centipede wandering and turning, so its body follows its path
    world.flags.demo = true
    world.player:setCharacter(Content.characters:get("centipede"))
    world:spawnRing("worker_ant", 24, world.player.x, world.player.y, 70)
    wait(2.5)
    shot("round9_centipede")
    world.flags.demo = false
    world:clearEnemies()
    world.player:setCharacter(Content.characters:get("wolf_spider"))
    print("[selftest] all " .. #Content.characters:all() .. " characters fight OK")

    -- Roster: every character model side by side.
    local Theme = require("src.ui.theme")
    local Sprites = require("src.gfx.sprites")
    local roster = { t = 0 }
    function roster:update(dt) self.t = self.t + dt end
    function roster:draw()
        local lg = love.graphics
        lg.clear(0.12, 0.11, 0.1)
        local all = Content.characters:all()
        local cols = 4
        local W, H = lg.getDimensions()
        for i, c in ipairs(all) do
            local cx = (i - 1) % cols
            local cy = math.floor((i - 1) / cols)
            local x, y = W / cols * (cx + 0.5), 110 + cy * 200
            lg.setColor(0, 0, 0, 0.35)
            lg.ellipse("fill", x, y + 10, 70, 26)
            lg.setColor(1, 1, 1, 1)
            local legs = Sprites.get(c.model.legs)
            Sprites.drawModel(c.model, math.floor(self.t * legs.fps) + 1, x, y, -0.5 + math.sin(self.t + i) * 0.3, false, 4, 4)
            lg.setFont(Theme.font(18))
            Theme.printShadow(c.name, x - 120, y + 50, Theme.colors.text, "center", 240)
        end
    end
    State.push(roster)
    wait(0.6)
    shot("chars_roster")
    State.pop()

    inventoryScene(game, world)

    -- Benchmarks (god mode on so the player survives).
    world.flags.god = true
    for _, target in ipairs({ 250, 500, 1000, 1500 }) do
        world:clearEnemies()
        world.flags.freezeAI = false
        local defs = Content.enemies:filter(function(d) return not d.boss end)
        local p = world.player
        for i = 1, target do
            local def = defs[(i % #defs) + 1]
            local a, r = love.math.random() * math.pi * 2, 60 + love.math.random() * 260
            world:spawnEnemy(def, p.x + math.cos(a) * r, p.y + math.sin(a) * r)
        end
        -- Freeze attacks from killing the benchmark population too fast.
        p.attack.timer = 1e9
        local up = benchUpdate(world, 60)
        local before = love.graphics.getStats().drawcalls
        local dr = benchDraw(game, 20)
        local stats = { drawcalls = love.graphics.getStats().drawcalls - before }
        print(("[selftest] %4d enemies: update %.2f ms, draw %.2f ms, draw calls/frame %d"):format(world.enemyCount, up, dr, stats.drawcalls / 20))
        p.attack.timer = 0
    end
    world:clearEnemies()
    world:spawnRing("worker_ant", 400, world.player.x, world.player.y, 70)
    wait(2)
    shot("sandbox_fight")
    -- Close-up of death effects: a fresh floor, a tight ring of ants, a few seconds of fighting.
    world:clearEnemies()
    world.ground:clearDecals()
    world:spawnRing("worker_ant", 60, world.player.x, world.player.y, 45)
    world:spawnRing("soldier_ant", 12, world.player.x, world.player.y, 70)
    wait(2.5)
    shot("splatter")
    Settings.set("colorblindMode", "deuteranopia")
    Settings.set("playerOutline", true)
    Settings.set("brightness", 120)
    Settings.set("showOverlay", true)
    Settings.set("showHitboxes", true)
    wait(0.5)
    shot("filters_and_debug")
    Settings.resetCategory("Accessibility")
    Settings.resetCategory("Video")
    Settings.resetCategory("Developer")
    Settings.save()
    specialsScene()
    itemsScene()
    sandboxScene()
    touchScene()
    termiteScene()
    hymenopteraScene()
    require("src.debug.selftest_skills")(wait, shot)
    require("src.debug.selftest_levelups")(wait, shot)
    require("src.debug.selftest_records")(wait, shot)
    require("src.debug.selftest_mastery")(wait, shot)
    require("src.debug.selftest_polish")(wait, shot)
    require("src.debug.selftest_pacing")(wait, shot)
    require("src.debug.selftest_anims")(wait, shot)
    print("[selftest] save dir: " .. love.filesystem.getSaveDirectory())
    print("[selftest] OK")
    love.event.quit()
end

function Selftest.start(flags)
    -- most tests step through waves without clicking cards: level-ups wait for the wave's end
    -- (tests of the Right Away flow set "levelUpWhen" themselves)
    require("src.core.settings").set("levelUpWhen", "wave")
    co = coroutine.create(function() script(flags) end)
end

function Selftest.update(dt)
    if not co or coroutine.status(co) == "dead" then return end
    waitT = waitT - dt
    if waitT > 0 then return end
    local ok, err = coroutine.resume(co)
    if not ok then
        print("[selftest] FAILED: " .. tostring(err) .. "\n" .. debug.traceback(co))
        love.event.quit(1)
    end
end

function Selftest.draw() end

return Selftest
