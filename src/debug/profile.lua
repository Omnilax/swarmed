-- Performance profile:  love . --profile
-- Runs a scripted massacre (big streaming waves, a player with chain/explosion procs killing
-- hundreds) and prints where frame time goes, plus LuaJIT's hottest lines (update and draw
-- separately), draw calls and garbage per frame. Then quits.
--   --gclines  with --crowd: the source lines that allocate the most each frame
--   --crowd    repeatable benchmark instead: a fixed horde (500 / 1000 / 2000, packed and spread)
--              around a god-mode player that doesn't attack (--lines: hottest lines, --byfunc: by function)
--   --nojit    interpreter only, close to the phone/web build (plain Lua 5.1, no JIT)
--   --cpudraw  graphics calls do nothing, so draw time is the Lua work alone (the cloud box
--              renders in software, where real draw time is mostly pixel filling)
local State = require("src.core.state")

local Profile = {}

local function now() return love.timer.getTime() end

function Profile.start(flags)
    flags = flags or {}
    Profile.flags = flags
    -- --nojit: run the interpreter only, close to the web/phone build (PUC Lua 5.1, no JIT)
    if flags["--nojit"] then jit.off() end
    love.math.setRandomSeed(1234)
    math.randomseed(1234)
    -- --cpudraw: graphics calls become no-ops, so "draw" measures only the Lua work behind it
    -- (software GL on the cloud box makes real draw timings mostly GPU fill)
    if flags["--cpudraw"] then
        local lg = love.graphics
        for _, k in ipairs({ "draw", "ellipse", "rectangle", "polygon", "line", "circle", "points", "print", "printf",
            "clear", "setCanvas", "setShader", "setBlendMode", "setColor", "setLineWidth", "setLineStyle", "flushBatch",
            "push", "pop", "translate", "scale", "rotate", "origin", "setScissor", "intersectScissor", "setFont", "arc", "stencil", "setStencilTest" }) do
            if lg[k] then lg[k] = function() end end
        end
        lg.getColor = function() return 1, 1, 1, 1 end
    end
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "sandbox", character = "wolf_spider" }))
    local world = game.world
    if flags["--crowd"] then -- --crowd: a repeatable crowd benchmark. The same mixed horde (every non-boss species) stands
-- around a god-mode player who doesn't attack, so nothing dies and every run does the same work.
-- Prints update and draw ms per frame at several crowd sizes.
function Profile.crowd(game, world)
    local Content = require("src.content")
    world.flags.god = true
    local p = world.player
    -- the everyday horde: mostly ants, a few fliers (no exploders, so the count stays put)
    local defs = {}
    for _, id in ipairs({ "worker_ant", "army_ant", "fire_ant", "wood_ant", "soldier_ant", "bullet_ant", "bulldog_ant",
        "crazy_ant", "driver_ant", "green_ant", "leafcutter_ant", "pharaoh_ant", "bigheaded_minor", "desert_ant",
        "flying_ant", "honey_bee", "paper_wasp", "sweat_bee" }) do
        defs[#defs + 1] = Content.enemies:get(id)
    end
    -- "spread": the same horde scattered over the whole arena (much of it off screen)
    for _, case in ipairs({ { 500 }, { 1000 }, { 2000 }, { 2000, spread = true } }) do
        local target = case[1]
        world:clearEnemies()
        love.math.setRandomSeed(99)
        for i = 1, target do
            local def = defs[(i % #defs) + 1]
            if case.spread then
                world:spawnEnemy(def, 10 + love.math.random() * (world.size - 20), 10 + love.math.random() * (world.size - 20))
            else
                local a, r = love.math.random() * math.pi * 2, 40 + love.math.random() * 240
                world:spawnEnemy(def, p.x + math.cos(a) * r, p.y + math.sin(a) * r)
            end
        end
        p.attack.timer = 1e9
        if p.secondary then p.secondary.timer = 1e9 end
        for _ = 1, 30 do world:update(1 / 60) end     -- settle (spawn pops, first moves)
        local frames = 240
        local prof, counts = require("jit.profile"), {}
        if Profile.flags["--lines"] then
            prof.start("fli1", function(th, samples)
                local k = prof.dumpstack(th, Profile.flags["--byfunc"] and "F" or "pl", 1)
                counts[k] = (counts[k] or 0) + samples
            end)
        end
        -- --gclines: which source lines allocate (every line's growth in Lua memory over 10 frames of the 1000 horde; numbers are rough)
        if Profile.flags["--gclines"] and target == 1000 and not case.spread then
            collectgarbage("restart")     -- the hook's own garbage must still be collected
            local by, last, lastKey = {}, collectgarbage("count"), nil
            debug.sethook(function()
                local now_ = collectgarbage("count")
                if lastKey and now_ > last then by[lastKey] = (by[lastKey] or 0) + (now_ - last) end
                local info = debug.getinfo(2, "Sl")
                lastKey = info and (info.short_src .. ":" .. (info.currentline or 0)) or "?"
                last = collectgarbage("count")
            end, "l")
            for _ = 1, 10 do world:update(1 / 60) end
            debug.sethook()
            local arr = {}
            for k, v in pairs(by) do arr[#arr + 1] = { k, v / 10 } end
            table.sort(arr, function(x, y) return x[2] > y[2] end)
            for i = 1, math.min(12, #arr) do print(("[gc] %7.2f KB/frame  %s"):format(arr[i][2], arr[i][1])) end
        end
        collectgarbage("stop")
        local g0 = collectgarbage("count")
        local t0 = now()
        for _ = 1, frames do world:update(1 / 60) end
        if Profile.flags["--lines"] then
            prof.stop()
            local arr = {}
            for k, v in pairs(counts) do arr[#arr + 1] = { k, v } end
            table.sort(arr, function(a, b) return a[2] > b[2] end)
            for i = 1, math.min(14, #arr) do print(("[crowd]   %6d  %s"):format(arr[i][2], arr[i][1])) end
        end
        local up = (now() - t0) / frames * 1000
        local g1 = collectgarbage("count")
        for k, v in pairs(_G.GB or {}) do if v / frames > 0.2 then print("[crowd] alloc", k, v / frames) end end
        _G.GB = {}
        local t1 = now()
        for _ = 1, 60 do
            love.graphics.origin()
            game:draw()
            love.graphics.flushBatch()
        end
        local dr = (now() - t1) / 60 * 1000
        local g2 = collectgarbage("count")
        collectgarbage("restart")
        print(("[crowd] %4d enemies%s: update %.2f ms, draw %.2f ms, garbage KB/frame: update %.1f, draw %.1f"):format(
            world.enemyCount, case.spread and " (spread)" or "", up, dr, (g1 - g0) / frames, (g2 - g1) / 60))
    end
    love.event.quit()
end

return Profile.crowd(game, world) end
    world.player.inventory:add("static_antenna", 3)
    world.player.inventory:add("ember_gland", 2)
    world.spawner.wave = 8
    local prof = require("jit.profile")
    -- samples are split by phase so the GPU waits in draw don't hide the Lua hot spots of update
    local buckets = { update = {}, draw = {} }
    local counts = buckets.update
    prof.start("fli1", function(th, samples)
        local k = prof.dumpstack(th, flags["--byfunc"] and "F" or "pl", 1)
        counts[k] = (counts[k] or 0) + samples
    end)
    local t = { update = 0, decals = 0, draw = 0 }
    local alloc = 0
    local frames, peak, maxEnemies, kos0 = 600, 0, 0, world.kos
    local calls, batched = 0, 0
    for f = 1, frames do
        if f % 20 == 1 and world.enemyCount < 1400 then
            for _ = 1, 4 do world.spawner:spawnGroup(nil, 60) end
        end
        local t0 = now()
        local k0 = world.kos
        local m0 = collectgarbage("count")
        counts = buckets.update
        world:update(1 / 60)
        local t1 = now()
        world:flushDecals()
        local t2 = now()
        counts = buckets.draw
        love.graphics.origin()
        game:draw()
        love.graphics.flushBatch()
        local t3 = now()
        -- the counters only reset when a frame is presented, so count this frame's share
        local st = love.graphics.getStats()
        calls, batched = calls + st.drawcalls - (Profile._dc or 0), batched + st.drawcallsbatched - (Profile._dcb or 0)
        Profile._dc, Profile._dcb = st.drawcalls, st.drawcallsbatched
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
    print(("[profile] draw calls/frame %.0f (batched %.0f)"):format(calls / frames, batched / frames))
    print(("[profile] Lua garbage: %.0f KB/frame, heap now %.0f KB"):format(alloc / frames, collectgarbage("count")))
    for _, phase in ipairs({ "update", "draw" }) do
        local arr = {}
        for k, v in pairs(buckets[phase]) do arr[#arr + 1] = { k, v } end
        table.sort(arr, function(a, b) return a[2] > b[2] end)
        print("[profile] hottest lines in " .. phase .. ":")
        for i = 1, math.min(18, #arr) do print(("[profile] %6d  %s"):format(arr[i][2], arr[i][1])) end
    end
    love.event.quit()
end

-- --crowd: a repeatable crowd benchmark. The same mixed horde (every non-boss species) stands
-- around a god-mode player who doesn't attack, so nothing dies and every run does the same work.
-- Prints update and draw ms per frame at several crowd sizes.
function Profile.crowd(game, world)
    local Content = require("src.content")
    world.flags.god = true
    local p = world.player
    -- the everyday horde: mostly ants, a few fliers (no exploders, so the count stays put)
    local defs = {}
    for _, id in ipairs({ "worker_ant", "army_ant", "fire_ant", "wood_ant", "soldier_ant", "bullet_ant", "bulldog_ant",
        "crazy_ant", "driver_ant", "green_ant", "leafcutter_ant", "pharaoh_ant", "bigheaded_minor", "desert_ant",
        "flying_ant", "honey_bee", "paper_wasp", "sweat_bee" }) do
        defs[#defs + 1] = Content.enemies:get(id)
    end
    -- "spread": the same horde scattered over the whole arena (much of it off screen)
    for _, case in ipairs({ { 500 }, { 1000 }, { 2000 }, { 2000, spread = true } }) do
        local target = case[1]
        world:clearEnemies()
        love.math.setRandomSeed(99)
        for i = 1, target do
            local def = defs[(i % #defs) + 1]
            if case.spread then
                world:spawnEnemy(def, 10 + love.math.random() * (world.size - 20), 10 + love.math.random() * (world.size - 20))
            else
                local a, r = love.math.random() * math.pi * 2, 40 + love.math.random() * 240
                world:spawnEnemy(def, p.x + math.cos(a) * r, p.y + math.sin(a) * r)
            end
        end
        p.attack.timer = 1e9
        if p.secondary then p.secondary.timer = 1e9 end
        for _ = 1, 30 do world:update(1 / 60) end     -- settle (spawn pops, first moves)
        local frames = 240
        local prof, counts = require("jit.profile"), {}
        if Profile.flags["--lines"] then
            prof.start("fli1", function(th, samples)
                local k = prof.dumpstack(th, Profile.flags["--byfunc"] and "F" or "pl", 1)
                counts[k] = (counts[k] or 0) + samples
            end)
        end
        -- --gclines: which source lines allocate (every line's growth in Lua memory over 10 frames of the 1000 horde; numbers are rough)
        if Profile.flags["--gclines"] and target == 1000 and not case.spread then
            collectgarbage("restart")     -- the hook's own garbage must still be collected
            local by, last, lastKey = {}, collectgarbage("count"), nil
            debug.sethook(function()
                local now_ = collectgarbage("count")
                if lastKey and now_ > last then by[lastKey] = (by[lastKey] or 0) + (now_ - last) end
                local info = debug.getinfo(2, "Sl")
                lastKey = info and (info.short_src .. ":" .. (info.currentline or 0)) or "?"
                last = collectgarbage("count")
            end, "l")
            for _ = 1, 10 do world:update(1 / 60) end
            debug.sethook()
            local arr = {}
            for k, v in pairs(by) do arr[#arr + 1] = { k, v / 10 } end
            table.sort(arr, function(x, y) return x[2] > y[2] end)
            for i = 1, math.min(12, #arr) do print(("[gc] %7.2f KB/frame  %s"):format(arr[i][2], arr[i][1])) end
        end
        collectgarbage("stop")
        local g0 = collectgarbage("count")
        local t0 = now()
        for _ = 1, frames do world:update(1 / 60) end
        if Profile.flags["--lines"] then
            prof.stop()
            local arr = {}
            for k, v in pairs(counts) do arr[#arr + 1] = { k, v } end
            table.sort(arr, function(a, b) return a[2] > b[2] end)
            for i = 1, math.min(14, #arr) do print(("[crowd]   %6d  %s"):format(arr[i][2], arr[i][1])) end
        end
        local up = (now() - t0) / frames * 1000
        local g1 = collectgarbage("count")
        for k, v in pairs(_G.GB or {}) do if v / frames > 0.2 then print("[crowd] alloc", k, v / frames) end end
        _G.GB = {}
        local t1 = now()
        for _ = 1, 60 do
            love.graphics.origin()
            game:draw()
            love.graphics.flushBatch()
        end
        local dr = (now() - t1) / 60 * 1000
        local g2 = collectgarbage("count")
        collectgarbage("restart")
        print(("[crowd] %4d enemies%s: update %.2f ms, draw %.2f ms, garbage KB/frame: update %.1f, draw %.1f"):format(
            world.enemyCount, case.spread and " (spread)" or "", up, dr, (g1 - g0) / frames, (g2 - g1) / 60))
    end
    love.event.quit()
end

return Profile
