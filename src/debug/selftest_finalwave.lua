-- The end of a run:  love . --selftest --finalwave
-- Jumps to wave 15, checks crowned queens come one after another and own the boss bar, that
-- clearing the wave wins the run (event, victory screen, bag +1 row), that "Keep Going" leads on
-- to the item choice and wave 16, and that wave 30 is the next final wave.
local State = require("src.core.state")

return function(wait, shot)
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "run", character = "rhino_beetle" }))
    wait(0.3)
    local world = game.world
    local sp, pl = world.spawner, world.player
    world.flags.god = true
    local won
    world.events:on("run_won", function(w) won = w end)
    assert(sp:finalWave() == 15 and sp:isFinal(15) and not sp:isFinal(10) and sp:isFinal(30), "final wave should be 15")
    world:clearEnemies()
    sp:startWave(15)
    assert(sp.finalThisWave and sp.bossWave and sp.crownLeft >= 1, "wave 15 should be the final boss wave")
    local function killAll()
        for i = 1, world.enemyCount do
            local e = world.enemies[i]
            if not e.dead then world:killEnemy(e) end
        end
    end
    -- first crowned queen
    local queens, ids, guard = {}, {}, 0
    while #queens < 2 and guard < 60 * 120 do
        guard = guard + 1
        world:update(1 / 60)
        if world.boss and world.boss.title and world.boss ~= queens[#queens] then
            queens[#queens + 1] = world.boss
            ids[#ids + 1] = world.boss.def.id
            if #queens == 1 then
                wait(0.4)
                shot("finalwave_queen")
            end
            assert(world.boss.maxHp > 400, "a crowned queen should be tougher than a plain one")
        end
        -- the rest of the wave arrives; keep clearing it, and the queen once she is out
        if world.time % 1 < 1 / 60 then killAll() end
    end
    assert(#queens == 2, "two crowned queens should come in the final wave, got " .. #queens)
    assert(ids[1] ~= ids[2], "the second queen should be a different species")
    -- clear everything: the run is won
    guard = 0
    while sp.phase == "wave" and guard < 60 * 120 do
        guard = guard + 1
        killAll()
        world:update(1 / 60)
    end
    assert(sp.phase == "break", "final wave never ended")
    assert(won == 15 and world.won, "run_won should fire on wave 15")
    assert(pl.inventory.rows == 4 and pl.inventory.cols * pl.inventory.rows == 40, "bag should grow a row")
    -- the game opens the victory screen, then the item choice
    world.time = world.time + 2
    game:update(1 / 60)
    local top = State.top()
    assert(top and top.info and top.info.first, "victory screen should open")
    wait(1.2)
    shot("finalwave_victory")
    top.t = 5
    top.menu.items[1].onActivate()
    assert(State.top() == game and world.continued, "keep going should return to the game")
    game:update(1 / 60)
    -- (level-up cards earned in the final wave come first)
    for _ = 1, 40 do
        local t = State.top()
        if not t.lu then break end
        t.t = 10
        t:activate(1); t:activate(1)
        if State.top() == game then game:update(1 / 60) end
    end
    assert(State.top() ~= game and State.top().items, "the item choice should follow (top: " .. tostring(State.top().items) .. ", pending " .. tostring(world.pendingChoice) .. ")")
    State.pop()
    -- and on we go
    world:clearEnemies()
    sp:startWave(16)
    assert(not sp.finalThisWave, "wave 16 is a normal wave")
    State.switch(require("src.states.menu").new())
    print("[selftest] final wave OK")
end
