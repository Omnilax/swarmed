-- E = next wave, no ground items, Skip in the item choice:  love . --selftest --skipwave
local State = require("src.core.state")
local Input = require("src.core.input")

return function(wait, shot)
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "run", character = "rhino_beetle" }))
    local world = game.world
    world.flags.god = true
    wait(0.5)

    -- E starts the next wave (and no longer opens the bag)
    local nw = Input.getKeys("next_wave")
    assert(nw[1] == "e", "E should be the first next-wave key")
    for _, k in ipairs(Input.getKeys("inventory")) do assert(k ~= "e", "E is still bound to the inventory") end
    world.spawner.timer = math.huge
    local before = world.spawner.wave
    game:nextWave()
    wait(0.3)
    assert(world.spawner.wave == before + 1 and world.spawner.phase == "wave", "next wave did not start")

    -- items never lie on the ground: overflow is eaten
    assert(world.pickups == nil, "ground items still exist")
    world.player.hp = 1
    local eaten = world:giveItem("royal_jelly", 20)
    assert(eaten > 0 and world.player.hp > 1, "overflow was not eaten")
    world.player.inventory:clear()

    -- Skip: two presses, nothing goes in the bag
    world.pendingChoice = nil
    local Choice = require("src.states.itemchoice")
    local c = State.push(Choice.new(game, { count = 3, wave = 3 }))
    wait(1.0)
    shot("itemchoice_skip")
    local skipI = c:skipIndex()
    c:activate(skipI)
    assert(State.top() == c and c.armed == skipI, "first skip press should only arm it")
    wait(0.2)
    shot("itemchoice_skip_armed")
    c:activate(skipI)
    assert(State.top() ~= c, "second skip press should close the choice")
    assert(#world.player.inventory.bag == 0, "skip should not add an item")
    print("[skipwave] OK")
end
