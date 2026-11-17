-- Wave rewards and the inventory window:  love . --selftest --rewards
-- The reward bloom (walk in / pulled by Next Wave / rolls in by itself), the break waiting for
-- it, the steps strip over level-ups and the item, rewards flying in with gain cards, TAB
-- opening the inventory window with its BAG / SKILLS / SHOP tabs, and "Open at Once".
local State = require("src.core.state")
local Settings = require("src.core.settings")
local Input = require("src.core.input")

return function(wait, shot)
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "run", character = "rhino_beetle" }))
    local world = game.world
    world.flags.god = true
    wait(0.5)
    local sp = world.spawner
    local p = world.player

    -- clear a wave with two level-ups waiting
    local function clearWave()
        if sp.phase ~= "wave" then sp:startWave() end
        sp.queue, sp.streams = {}, {}
        world:clearEnemies()
        for _ = 1, 400 do
            wait(1 / 60)
            if world.pendingChoice then break end
        end
        assert(world.pendingChoice, "no reward after clearing the wave")
    end
    require("src.game.levelups").grant(world, 2, { source = "level" })
    for _, e in ipairs(world.levelups.queue) do e.level = 3 end
    clearWave()
    for _ = 1, 120 do
        wait(1 / 60)
        if world.rewardFlow:bloom() then break end
    end
    local bloom = world.rewardFlow:bloom()
    assert(bloom, "the reward bloom did not sprout")
    assert(State.top() == game, "a reward screen opened before the bloom was touched")
    local timer = sp.timer
    wait(1.0)
    assert(sp.phase == "break" and sp.timer == timer, "the break should wait for the bloom")
    assert(world.rewardFlow:contents():find("2 level%-ups"), "bloom label should list the level-ups: " .. world.rewardFlow:contents())
    shot("rewards_bloom")
    -- Next Wave pulls it to you (instead of starting the wave)
    local wave = sp.wave
    game:nextWave()
    assert(bloom.pulled and sp.wave == wave, "Next Wave should pull the bloom, not start a wave")
    for _ = 1, 300 do
        wait(1 / 60)
        if State.top() ~= game then break end
    end
    local top = State.top()
    assert(top.lu, "the level-up cards should open first after the bloom")
    local flow = world.rewardFlow
    assert(flow.steps and #flow.steps == 3 and flow:stepOf(top.entry) == 1, "the steps strip should show 2 levels + item")
    wait(0.6)
    shot("rewards_steps")
    top.t = 10
    top:activate(1); top:activate(1)
    wait(0.05)
    top = State.top()
    assert(top.lu and flow:stepOf(top.entry) == 2, "second level-up should be step 2")
    top.t = 10
    top:activate(1); top:activate(1)
    wait(0.05)
    local choice = State.top()
    assert(choice.items, "the item choice should come last")
    assert(flow:stepOf("item") == 3, "the item is step 3")
    shot("rewards_item_step")
    choice.t = 10
    local before = #p.inventory.bag
    choice:activate(1); choice:activate(1)
    assert(State.top() == game and #p.inventory.bag == before + 1, "taking the item failed")
    assert(flow.steps == nil, "steps should end with the item")
    assert(#flow.flights >= 1, "the item should fly in from the bloom")
    wait(0.25)
    shot("rewards_flight")
    for _ = 1, 120 do
        wait(1 / 60)
        if #flow.flights == 0 then break end
    end
    assert(#flow.toasts >= 3, "every reward should get a gain card (got " .. #flow.toasts .. ")")
    assert(flow.toasts[1].g.title == "NEW ITEM", "newest card should be the item")
    shot("rewards_toasts")
    -- the break goes on after the rewards
    assert(not world.pendingChoice, "choice left pending")
    for _ = 1, 600 do
        wait(1 / 60)
        if sp.phase == "wave" then break end
    end
    assert(sp.phase == "wave", "next wave did not start after the rewards")
    print("[rewards] bloom, steps, flights OK")

    -- left alone, the bloom rolls to you by itself
    clearWave()
    for _ = 1, 900 do
        wait(1 / 60)
        if State.top() ~= game then break end
        p.x, p.y = world.size / 2, world.size / 2   -- stand still
    end
    assert(State.top().items or State.top().lu, "an untouched bloom should roll in and open")
    while State.top() ~= game do
        local t = State.top()
        t.t = 10
        if t.lu then t:activate(1); t:activate(1) else t:activate(t:skipIndex()); t:activate(t:skipIndex()) end
        wait(0.05)
    end
    print("[rewards] bloom rolls in OK")

    -- TAB opens the inventory window; E goes round its tabs; TAB closes it
    local tab = Input.getKeys("inventory")[1]
    assert(tab == "tab", "TAB should open the inventory (got " .. tostring(tab) .. ")")
    Input.keypressed("tab", false)
    wait(0.1)
    assert(State.top().inv, "TAB did not open the bag")
    wait(0.05)
    Input.keypressed("e", false)
    wait(0.1)
    assert(getmetatable(State.top()) == require("src.states.skilltree"), "E should open SKILLS")
    Input.keypressed("e", false)
    wait(0.1)
    assert(getmetatable(State.top()) == require("src.states.shop"), "E again should open SHOP")
    shot("rewards_shop_tab")
    Input.keypressed("tab", false)
    wait(0.1)
    assert(State.top() == game, "TAB should close the window")
    print("[rewards] TAB window OK")

    -- Open at Once: the screens follow the wave without a bloom
    Settings.set("waveRewards", "instant")
    sp:startWave()
    clearWave()
    for _ = 1, 200 do
        wait(1 / 60)
        if State.top() ~= game then break end
    end
    assert(State.top() ~= game and not world.rewardFlow:bloom(), "Open at Once should skip the bloom")
    Settings.set("waveRewards", "bloom")
    print("[rewards] OK")
end
