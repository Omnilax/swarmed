-- Crowd stress test:  love . --profile --stress [--nojit] [--cpudraw] [--quick]
-- A deliberately ugly fight: a real wave mix (wave 12 species, elites, fliers, shooters) kept
-- topped up at 100 / 250 / 500 / 900 / 1400 enemies around an auto-attacking player with
-- chain and explosion procs, so things die, burst, bleed and drop nectar all the time.
-- Prints a line per crowd size: frame ms (average, 95th percentile, worst), sprite draws,
-- garbage per frame and the population of every pool; with --split also update and draw time
-- and garbage by subsystem (exclusive time, so nested calls are not counted twice).
--   --nojit    interpreter only (close to the web/phone build)
--   --cpudraw  graphics calls do nothing: draw time is the Lua work alone
--   --quick    fewer frames per size (250 and 900 only)
--   --split    time and garbage by subsystem (the timers slow LuaJIT down a little, so the
--              frame totals are best read from a run without it)
--   --lines    hottest source lines at 900 (--byfunc: by function)
--   --gclines  source lines that allocate the most at 900
--   --drawsby  source lines that issue the most sprite draws at 900
--   --jitlog   every trace LuaJIT compiles or aborts, written to jit.log
--   --jitdefault (a main.lua flag) runs with LuaJIT's stock limits, for comparing
local Stress = {}

local now = love.timer.getTime

-- Exclusive timers: time spent in a wrapped function minus the time of wrapped calls inside it.
local acc, stackChild, depth = {}, {}, 0
local mem, memChild = {}, {}
local gcount = collectgarbage
local SPLIT = false
local function wrap(tbl, key, label)
    if not SPLIT then return end
    local f = tbl[key]
    if type(f) ~= "function" then return end
    tbl[key] = function(...)
        depth = depth + 1
        stackChild[depth], memChild[depth] = 0, 0
        local m0 = gcount("count")
        local t0 = now()
        local a, b, c, d = f(...)
        local el = now() - t0
        local ml = gcount("count") - m0
        local ex = el - stackChild[depth]
        local mx = ml - memChild[depth]
        depth = depth - 1
        if depth > 0 then stackChild[depth] = stackChild[depth] + el memChild[depth] = memChild[depth] + ml end
        acc[label] = (acc[label] or 0) + ex
        mem[label] = (mem[label] or 0) + mx
        return a, b, c, d
    end
end

local UPDATE_KEYS = { "world (hash, cleanup, fx, camera)", "player + attacks", "enemy AI (behaviours)", "enemy move/separation/bites",
    "combat damage", "kills (death fx, drops)", "particles", "nectar beads", "corpses", "spawner", "director/hazards/bosses", "rewards/feedback" }
local DRAW_KEYS = { "world sprites (sort, shadows, bodies)", "ground + decals", "particles", "particle glow", "fx glow",
    "lighting", "rims/shading", "beads", "props/hazards/air", "weather/ambience", "screen post + hud + text" }

function Stress.run(game, world, flags)
    if flags["--jitlog"] then require("jit.v").start("jit.log") end      -- every trace LuaJIT compiles or aborts
    SPLIT = flags["--split"] or false
    local Content = require("src.content")
    local Settings = require("src.core.settings")
    local World = getmetatable(world).__index
    local lg = love.graphics
    world.flags.god = true
    Settings.set("autoAttack", true)
    local p = world.player
    p.inventory:add("static_antenna", 3)
    p.inventory:add("ember_gland", 2)
    local sp = world.spawner
    sp.wave = 12
    sp.update = function() end      -- the test keeps the population itself

    -- instrument
    for _, b in ipairs(Content.behaviors:all()) do wrap(b, "update", "enemy AI (behaviours)") end
    wrap(World, "update", "world (hash, cleanup, fx, camera)")
    wrap(World, "updateEnemies", "enemy move/separation/bites")
    wrap(World, "killEnemy", "kills (death fx, drops)")
    wrap(World, "updateCorpses", "corpses")
    wrap(p, "update", "player + attacks")
    local Combat = require("src.game.combat")
    wrap(Combat, "damage", "combat damage")
    wrap(world.particles, "update", "particles")
    wrap(world.beads, "update", "nectar beads")
    wrap(world.director, "update", "director/hazards/bosses")
    wrap(world.hazards, "update", "director/hazards/bosses")
    wrap(world.rewards, "update", "rewards/feedback")
    wrap(world.rewardFlow, "update", "rewards/feedback")
    wrap(World, "draw", "world sprites (sort, shadows, bodies)")
    wrap(world.ground, "draw", "ground + decals")
    wrap(World, "flushDecals", "ground + decals")
    wrap(world.particles, "draw", "particles")
    wrap(world.particles, "drawGlow", "particle glow")
    wrap(World, "drawFx", "fx glow")
    wrap(World, "drawLighting", "lighting")
    local Shading = require("src.gfx.shading")
    for _, k in ipairs({ "drawGround", "drawRims", "drawWet", "drawRays", "drawPlayerRim" }) do wrap(Shading, k, "rims/shading") end
    wrap(world.beads, "draw", "beads")
    for _, k in ipairs({ "drawProps", "drawGround", "drawAir" }) do wrap(world.director, k, "props/hazards/air") end
    for _, k in ipairs({ "drawGround", "drawAir" }) do wrap(world.hazards, k, "props/hazards/air") end
    wrap(world.weather, "draw", "weather/ambience")
    wrap(world.weather, "drawGlow", "weather/ambience")
    local Ambience = require("src.gfx.ambience")
    for _, k in ipairs({ "drawGround", "drawDecor", "drawLeaves" }) do wrap(Ambience, k, "weather/ambience") end
    wrap(game, "draw", "screen post + hud + text")

    -- the wave-12 mix the spawner would send
    local pool = {}
    for _, def in ipairs(Content.enemies:all()) do
        local s = def.spawn
        if not def.boss and not def.hazard and s and (s.weight or 0) > 0 and (s.minWave or 1) <= 12 then
            for _ = 1, math.max(1, math.floor(s.weight / 5)) do pool[#pool + 1] = def end      -- weighted like the spawner
        end
    end
    local Elites = Content.elites:all()
    local function top(target)
        local made = 0
        while world.enemyCount < target and made < 60 do
            local def = pool[love.math.random(#pool)]
            local a, r = love.math.random() * math.pi * 2, 60 + love.math.random() * 260
            local el = love.math.random() < 0.04 and Elites[love.math.random(#Elites)] or nil
            world:spawnEnemy(def, math.max(10, math.min(world.size - 10, p.x + math.cos(a) * r)),
                math.max(10, math.min(world.size - 10, p.y + math.sin(a) * r)), el)
            made = made + 1
        end
    end

    -- count sprite draws (love.graphics.draw calls)
    local realDraw, drawN = lg.draw, 0
    lg.draw = function(...) drawN = drawN + 1 return realDraw(...) end

    local sizes = flags["--quick"] and { 250, 900 } or { 100, 250, 500, 900, 1400 }
    local frames = flags["--quick"] and 120 or 300
    local rows = {}
    for _, target in ipairs(sizes) do
        world:clearEnemies()
        love.math.setRandomSeed(7)
        top(target)
        for _ = 1, 90 do top(target) world:update(1 / 60) lg.origin() game:draw() end
        -- --gclines: which source lines allocate the most (10 frames, rough)
        if flags["--gclines"] and target >= 900 then
            local by, last, lastKey = {}, collectgarbage("count"), nil
            collectgarbage("collect") collectgarbage("stop")
            debug.sethook(function()
                local m = collectgarbage("count")
                if lastKey and m > last then by[lastKey] = (by[lastKey] or 0) + (m - last) end
                local info = debug.getinfo(2, "Sl")
                lastKey = info and (info.short_src .. ":" .. (info.currentline or 0)) or "?"
                last = collectgarbage("count")
            end, "l")
            for _ = 1, 10 do top(target) world:update(1 / 60) lg.origin() game:draw() end
            debug.sethook()
            collectgarbage("restart")
            local arr = {}
            for k, v in pairs(by) do arr[#arr + 1] = { k, v / 10 } end
            table.sort(arr, function(x, y) return x[2] > y[2] end)
            for i = 1, math.min(25, #arr) do print(("[gc] %7.2f KB/frame  %s"):format(arr[i][2], arr[i][1])) end
        end
        -- garbage by subsystem: 60 frames with the collector paused
        collectgarbage("collect") collectgarbage("stop")
        for k in pairs(mem) do mem[k] = 0 end
        local gm0 = collectgarbage("count")
        for _ = 1, 60 do top(target) world:update(1 / 60) lg.origin() game:draw() end
        local gmTotal = (collectgarbage("count") - gm0) / 60
        collectgarbage("restart")
        local memRow = {}
        for k, v in pairs(mem) do memRow[k] = v / 60 end
        local prof, counts = require("jit.profile"), {}
        if flags["--lines"] and target >= 900 then
            prof.start("fli1", function(th, samples)
                local k = prof.dumpstack(th, flags["--byfunc"] and "F" or "pl", 1)
                counts[k] = (counts[k] or 0) + samples
            end)
        end
        for k in pairs(acc) do acc[k] = 0 end
        local times, garbage, drawCalls, sprites = {}, 0, 0, 0
        local pop = { enemies = 0, particles = 0, corpses = 0, beads = 0, fx = 0, texts = 0 }
        local st0 = lg.getStats()
        local dc0 = st0.drawcalls
        for f = 1, frames do
            top(target)
            local m0 = collectgarbage("count")
            local t0 = now()
            world:update(1 / 60)
            lg.origin()
            drawN = 0
            game:draw()
            lg.flushBatch()
            local t1 = now()
            sprites = sprites + drawN
            local m1 = collectgarbage("count")
            if m1 > m0 then garbage = garbage + (m1 - m0) end
            times[f] = (t1 - t0) * 1000
            pop.enemies = pop.enemies + world.enemyCount
            pop.particles = pop.particles + world.particles.n
            pop.corpses = pop.corpses + #world.corpses
            pop.beads = pop.beads + (world.beads.n or #(world.beads.list or {}))
            pop.fx = pop.fx + #world.fx
            pop.texts = pop.texts + #world.texts
            if f % 30 == 0 then love.graphics.present() end    -- lets the stat counters roll over
        end
        if flags["--lines"] and target >= 900 then
            prof.stop()
            local arr = {}
            for k, v in pairs(counts) do arr[#arr + 1] = { k, v } end
            table.sort(arr, function(a, b) return a[2] > b[2] end)
            for i = 1, math.min(40, #arr) do print(("[lines] %6d  %s"):format(arr[i][2], arr[i][1])) end
        end
        -- --drawsby: which lines issue the sprite draws (one frame)
        if flags["--drawsby"] and target >= 900 then
            local by = {}
            lg.draw = function(...)
                local info = debug.getinfo(2, "Sl")
                local k = info.short_src .. ":" .. info.currentline
                by[k] = (by[k] or 0) + 1
                return realDraw(...)
            end
            lg.origin() game:draw()
            lg.draw = function(...) drawN = drawN + 1 return realDraw(...) end
            local arr = {}
            for k, v in pairs(by) do arr[#arr + 1] = { k, v } end
            table.sort(arr, function(a, b) return a[2] > b[2] end)
            for i = 1, math.min(25, #arr) do print(("[draws] %6d  %s"):format(arr[i][2], arr[i][1])) end
        end
        local st1 = lg.getStats()
        drawCalls = st1.drawcalls
        table.sort(times)
        local sum = 0
        for _, t in ipairs(times) do sum = sum + t end
        local row = { target = target, avg = sum / frames, p95 = times[math.floor(frames * 0.95)], worst = times[frames],
            garbage = garbage / frames, gcTotal = gmTotal, mem = memRow, sprites = sprites / frames, drawCalls = drawCalls, acc = {} }
        for k, v in pairs(acc) do row.acc[k] = v / frames * 1000 end
        for k, v in pairs(pop) do row[k] = v / frames end
        rows[#rows + 1] = row
        print(("[stress] %4d enemies: frame avg %.2f ms, p95 %.2f, worst %.1f | %d sprite draws, garbage %.0f KB/frame (%.0f with the collector paused)"):format(
            row.enemies, row.avg, row.p95, row.worst, row.sprites, row.garbage, row.gcTotal))
        print(("[stress]        particles %d, corpses %d, beads %d, fx %d, texts %d"):format(row.particles, row.corpses, row.beads, row.fx, row.texts))
        if SPLIT then
        for _, k in ipairs(UPDATE_KEYS) do print(("[stress]          update %-40s %6.2f ms %7.1f KB"):format(k, row.acc[k] or 0, row.mem[k] or 0)) end
        for _, k in ipairs(DRAW_KEYS) do print(("[stress]          draw   %-40s %6.2f ms %7.1f KB"):format(k, row.acc[k] or 0, row.mem[k] or 0)) end
        end
    end
    lg.draw = realDraw
    love.event.quit()
end

return Stress
