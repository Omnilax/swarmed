-- Item choice + bag quality of life:  love . --selftest --choiceqol
-- Reroll, lock, ban, synergy tags, stat previews, bag sort, drag-to-eat, pause screen.
local State = require("src.core.state")
local Stats = require("src.game.stats")
local Choices = require("src.game.choices")
local Inventory = require("src.game.inventory")

return function(wait, shot)
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "run", character = "rhino_beetle" }))
    local world = game.world
    world.flags.god = true
    world.spawner.enabled = false
    world.pendingChoice = nil
    wait(0.3)
    local inv = world.player.inventory
    local run = Choices.state(world)
    local Choice = require("src.states.itemchoice")

    -- every stat explains itself in numbers
    for _, sd in ipairs(Stats.defs) do
        assert(Stats.explain(sd.id, world.player.stats:get(sd.id)) ~= "", sd.id .. " has no info text")
    end

    -- stat preview: coffee bean adds speed
    local pv = Choices.preview(world.player.stats, Inventory.newItem("coffee_bean").def)
    local speed
    for _, l in ipairs(pv) do if l.id == "moveSpeed" then speed = l end end
    assert(speed and speed.after > speed.before and speed.good, "speed preview wrong")
    assert(speed.text:find("»"), "preview text has no arrow")

    -- synergy tags count bag items
    inv:add("chitin_plate", 2)
    local tags = Choices.bagTags(inv)
    for _, t in ipairs(Inventory.newItem("chitin_plate").def.tags) do assert(tags[t] == 2, "tag count wrong for " .. t) end

    -- reroll: unlocked cards change, locked ones stay, a charge is used
    local c = State.push(Choice.new(game, { count = 3, wave = 3 }))
    wait(1.0)
    shot("choice_qol")
    -- window focus changes on a screen that keeps a numeric `focus` row must not crash
    love.focus(false); love.focus(true); love.visible(false); love.visible(true)
    local lockedId = c.items[2].id
    c:toggleLock(2)
    assert(c.items[2].locked, "lock did not lock")
    local before = run.rerolls
    local oldIds = { c.items[1].id, c.items[3].id }
    assert(c:reroll(), "reroll failed")
    assert(run.rerolls == before - 1, "reroll did not use a charge")
    assert(c.items[2].id == lockedId and c.items[2].locked, "locked card moved on reroll")
    assert(c.items[1].id ~= oldIds[1] or c.items[3].id ~= oldIds[2], "reroll changed nothing")
    wait(0.2)
    shot("choice_qol_locked")

    -- ban: two presses, the item is gone for the run
    local banId = c.items[1].id
    local bans = run.banishes
    assert(not c:ban(1) and c.armedBan == 1, "first ban press should only arm it")
    wait(0.1)
    shot("choice_qol_ban_armed")
    assert(c:ban(1), "second ban press did not ban")
    assert(run.banned[banId] and run.banishes == bans - 1, "ban not recorded")
    assert(c.items[1].id ~= banId, "banned card still shown")
    for _ = 1, 200 do
        local d = Choices.pickDef(world, {})
        assert(d.id ~= banId, "banned item rolled again")
    end

    -- skip: the locked card comes back next time
    c:activate(c:skipIndex()); c:activate(c:skipIndex())
    assert(State.top() ~= c, "skip did not close")
    local c2 = State.push(Choice.new(game, { count = 3, wave = 3 }))
    local found = false
    for _, it in ipairs(c2.items) do if it.id == lockedId and it.locked then found = true end end
    assert(found, "locked card did not come back")
    wait(1.0)
    -- taking the locked card uses it up
    for i, it in ipairs(c2.items) do if it.id == lockedId then c2:activate(i); c2:activate(i) break end end
    assert(#run.locked == 0, "taken locked card is still remembered")
    wait(0.2)

    -- reroll with every card locked does nothing; no charges left does nothing
    local c3 = State.push(Choice.new(game, { count = 3, wave = 3 }))
    wait(1.0)
    for i = 1, 3 do c3:toggleLock(i) end
    local r0 = run.rerolls
    assert(not c3:reroll() and run.rerolls == r0, "reroll with all locked should do nothing")
    for i = 1, 3 do c3:toggleLock(i) end
    run.rerolls = 0
    assert(not c3:reroll(), "reroll with no charges should fail")
    c3:activate(c3:skipIndex()); c3:activate(c3:skipIndex())

    -- queens give rerolls back
    Choices.onQueen(world)
    assert(run.rerolls == 1, "queen did not give a reroll back")

    -- bag sort: same items, same stats, tidier
    inv:clear()
    local ids = { "chitin_plate", "coffee_bean", "amber" }
    local all = {}
    for _, d in ipairs(require("src.content").items.list) do all[#all + 1] = d.id end
    for i = 1, 12 do ids[#ids + 1] = all[(i * 7) % #all + 1] end
    for _, id in ipairs(ids) do inv:add(id, 1) end
    -- scatter: put each item at the last spot it fits
    local count0 = #inv.bag
    -- (tag set bonuses depend on which items touch, so a sort may change them: compare without)
    local function noSets()
        local out = {}
        for _, st in ipairs(inv.sets or {}) do world.player.stats:removeSource("set:" .. st.tag) end
        for _, sd in ipairs(Stats.defs) do out[sd.id] = world.player.stats:get(sd.id) end
        inv:recount()
        return out
    end
    local snapshot = noSets()
    local InvState = require("src.states.inventory")
    local bagState = State.push(InvState.new(game))
    wait(0.3)
    shot("bag_before_sort")
    bagState:sort()
    assert(#inv.bag == count0, "sort lost items")
    local after = noSets()
    for _, sd in ipairs(Stats.defs) do
        assert(math.abs(after[sd.id] - snapshot[sd.id]) < 1e-6, "sort changed " .. sd.id)
    end
    for _, e in ipairs(inv.bag) do assert(inv:fits(e.item, e.x, e.y) == false, "grid out of date") end
    wait(0.3)
    shot("bag_after_sort")

    -- drag an item out of the case: it is eaten
    bagState:layout()
    local L = bagState.L
    local e = inv.bag[1]
    local px, py = L.bag.x + (e.x + 0.5) * L.C, L.bag.y + (e.y + 0.5) * L.C
    local n0 = #inv.bag
    world.player.hp = 1
    bagState:mousepressed(px, py, 1)
    assert(bagState.held and bagState.drag, "drag did not start")
    bagState:mousemoved(px, py + L.C * 3)
    bagState:mousemoved(2, 2)
    love.mouse.setPosition(2, 2)
    wait(0.1)
    shot("bag_drag_out")
    bagState:mousereleased(2, 2, 1)
    assert(not bagState.held and #inv.bag == n0 - 1 and world.player.hp > 1, "drag out did not eat")
    -- drag inside the bag moves it
    e = inv.bag[1]
    px, py = L.bag.x + (e.x + 0.5) * L.C, L.bag.y + (e.y + 0.5) * L.C
    bagState:mousepressed(px, py, 1)
    -- aim at an empty cell (where the sort left room depends on the Bag Sort Order)
    local ex, ey
    for yy = inv.rows - 1, 0, -1 do
        for xx = inv.cols - 1, 0, -1 do
            if not ex and not inv:entryAt(xx, yy) then ex, ey = xx, yy end
        end
    end
    ex, ey = ex or inv.cols - 1, ey or inv.rows - 1
    local tx, ty = L.bag.x + (ex + 0.5) * L.C, L.bag.y + (ey + 0.5) * L.C
    bagState:mousemoved(tx, ty)
    bagState:mousereleased(tx, ty, 1)
    assert(not bagState.held and #inv.bag == n0 - 1, "drag inside the bag lost the item")
    love.mouse.setPosition(L.side.x + 20, L.side.y + L.side.h - 10)
    wait(0.2)
    shot("bag_stat_tip")
    bagState:close()

    -- pause: every stat, every item
    local pause = State.push(require("src.states.pause").new(game))
    love.mouse.setPosition(40, 120)
    wait(0.3)
    shot("pause_stats")
    pause:wheelmoved(0, -3)
    wait(0.1)
    State.pop()
    print("[choiceqol] OK")
end
