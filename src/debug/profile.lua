-- Performance profile:  love . --profile
-- Runs a scripted massacre (big streaming waves, a player with chain/explosion procs killing
-- hundreds) and prints where frame time goes, plus LuaJIT's hottest functions. Then quits.
local State = require("src.core.state")

local Profile = {}

local function now() return love.timer.getTime() end

function Profile.start()
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "sandbox", character = "wolf_spider" }))
    local world = game.world
    world.player.inventory:add("static_antenna", 3)
    world.player.inventory:add("ember_gland", 2)
    world.spawner.wave = 8
    local prof = require("jit.profile")
    local counts = {}
    prof.start("fl", function(th, samples)
        local k = prof.dumpstack(th, "pl", 1)
        counts[k] = (counts[k] or 0) + samples
    end)
    local t = { update = 0, decals = 0, draw = 0 }
    local alloc = 0
    local frames, peak, maxEnemies, kos0 = 600, 0, 0, world.kos
    for f = 1, frames do
        if f % 20 == 1 and world.enemyCount < 1400 then
            for _ = 1, 4 do world.spawner:spawnGroup(nil, 60) end
        end
        local t0 = now()
        local k0 = world.kos
        local m0 = collectgarbage("count")
        world:update(1 / 60)
        local t1 = now()
        world:flushDecals()
        local t2 = now()
        love.graphics.origin()
        game:draw()
        love.graphics.flushBatch()
        local t3 = now()
        local m1 = collectgarbage("count")
        if m1 > m0 then alloc = alloc + (m1 - m0) end
        t.update, t.decals, t.draw = t.update + t1 - t0, t.decals + t2 - t1, t.draw + t3 - t2
        peak = math.max(peak, t3 - t0)
        if t3 - t0 > 0.1 then
            print(("[profile] slow frame %d: %.0f ms (update %.0f, decals %.0f, draw %.0f) kills %d splats %d particles %d enemies %d"):format(
                f, (t3 - t0) * 1000, (t1 - t0) * 1000, (t2 - t1) * 1000, (t3 - t2) * 1000, world.kos - k0, #world.pendingSplats, world.particles.n, world.enemyCount))
        end
        maxEnemies = math.max(maxEnemies, world.enemyCount)
    end
    prof.stop()
    print(("[profile] %d frames, up to %d enemies, %d kills, particles now %d, corpses %d"):format(
        frames, maxEnemies, world.kos - kos0, world.particles.n, #world.corpses))
    print(("[profile] avg ms/frame: update %.2f  decals %.2f  draw %.2f   worst frame %.1f ms"):format(
        t.update / frames * 1000, t.decals / frames * 1000, t.draw / frames * 1000, peak * 1000))
    print(("[profile] Lua garbage: %.0f KB/frame, heap now %.0f KB"):format(alloc / frames, collectgarbage("count")))
    local arr = {}
    for k, v in pairs(counts) do arr[#arr + 1] = { k, v } end
    table.sort(arr, function(a, b) return a[2] > b[2] end)
    for i = 1, math.min(18, #arr) do print(("[profile] %6d  %s"):format(arr[i][2], arr[i][1])) end
    love.event.quit()
end

return Profile
