-- Checks for the game modes:  love . --selftest --modes
-- Plays the first waves of every mode at high speed (the player can't die and the field is
-- swept every couple of seconds) and checks who came: families, elites, queens, endless levels,
-- starting items. Takes stills of the mode select and starting items screens.
local State = require("src.core.state")
local Content = require("src.content")

return function(wait, shot)
    local Game = require("src.states.game")

    -- screens
    local ms = State.push(require("src.states.modeselect").new())
    wait(0.3)
    shot("modes_select")
    for i, it in ipairs(ms.menu.items) do
        if it.mode and it.mode.id == "endless" then ms.menu.focus = i end
    end
    wait(0.2)
    shot("modes_select_endless")
    ms.menu:focused().onActivate()                  -- -> character select for endless
    wait(0.2)
    local cs = State.top()
    cs:pick(cs.list[1].def)                          -- the first bug -> starting items
    local lo = State.top()
    assert(lo.budget and lo.picked, "endless did not open the starting items screen")
    for _, id in ipairs({ "honeydew", "chitin_plate", "royal_jelly" }) do lo:add(Content.items:get(id)) end
    for _ = 1, 40 do lo:add(Content.items:get("honeydew")) end      -- runs out of points, never over
    assert(lo:spent() <= lo.budget, "loadout went over budget")
    wait(0.3)
    shot("modes_loadout")
    local picked = #lo.picked
    local ids = {}
    for _, d in ipairs(lo.picked) do ids[d.id] = true end
    local g = lo:start()
    wait(0.3)
    assert(g.world
 and g.world.gameMode == "endless", "loadout did not start an endless run")
    local have = 0
    for id in pairs(ids) do have = have + g.world.player.inventory:count(id) end

    assert(have >= picked, ("starting items missing: %d of %d"):format(have, picked))

    local function play(modeId, seconds, until_)
        local game = State.switch(Game.new({ mode = "run", character = "rhino_beetle", gameMode = modeId }))
        local world = game.world
        world.flags.god = true
        local seen = { families = {}, spawned = 0, elites = 0, bosses = 0, choices = 0, ids = {} }
        local spawn = world.spawnEnemy
        world.spawnEnemy = function(w, def, x, y, elite)
            local e = spawn(w, def, x, y, elite)
            if e then
                local d = e.def
                -- (reward critters, the treasure ant and a mini-goal's courier, src/game/rewards.lua,
                -- visit every mode, like the boss encounter predators)
                local critter = false
                for _, t in ipairs(d.tags or {}) do if t == "treasure" or t == "goal" then critter = true end end
                if not critter then seen.families[d.family] = true end
                seen.ids[d.id] = true
                if d.boss then seen.bosses = seen.bosses + 1 end
                if not d.boss and d.spawn.weight > 0 then
                    seen.spawned = seen.spawned + 1
                    if e.elite then seen.elites = seen.elites + 1 end
                end
            end
            return e
        end
        local sweep = 0
        local t0 = love.timer.getTime()
        for f = 1, seconds * 30 do
            world:update(1 / 30)
            world.player.hp = world.player.stats:get("maxHp")
            sweep = sweep + 1 / 30
            if sweep > 2.5 then
                sweep = 0
                for i = world.enemyCount, 1, -1 do
                    local e = world.enemies[i]
                    if e and not e.dead and world.time > 0 then world:killEnemy(e) end
                end
            end
            if world.pendingChoice then world.pendingChoice = nil seen.choices = seen.choices + 1 end
            world.pendingVictory = nil
            if until_ and until_(world) then break end
            if f % 300 == 0 then coroutine.yield() end
        end
        seen.wave, seen.world = world.spawner.wave, world
        print(("[selftest] mode %-10s wave %2d  %4d spawned  %3d elite  %d queens  %d choices  %.1fs"):format(
            modeId, seen.wave, seen.spawned, seen.elites, seen.bosses, seen.choices, love.timer.getTime() - t0))
        return seen, game
    end

    local function onlyFamilies(seen, allowed, mode)
        for fam in pairs(seen.families) do
            -- boss encounter predators (src/game/director.lua) visit every mode's boss waves
            local ok = fam == "predator"
            for _, a in ipairs(allowed) do if a == fam then ok = true end end
            assert(ok, mode .. ": a " .. fam .. " got in")
        end
    end

    local reachWave = function(n) return function(w) return w.spawner.wave >= n and w.spawner.phase == "break" end end

    for _, m in ipairs(Content.modes:all()) do
        if not m.endless and not m.tutorial then
            local seen = play(m.id, 600, reachWave(6))
            assert(seen.wave >= 6, m.id .. ": stuck at wave " .. seen.wave)
            assert(seen.spawned > 0, m.id .. ": nothing spawned")
            assert(seen.choices >= 5, m.id .. ": no item choices after waves")
            if m.families then onlyFamilies(seen, m.families, m.id) end
            if m.elites and m.elites.chance == 0 then assert(seen.elites == 0, m.id .. ": elites showed up") end
            if m.elites and m.elites.chance == 1 then
                assert(seen.elites >= seen.spawned * 0.7, ("%s: only %d of %d were elites"):format(m.id, seen.elites, seen.spawned))
            end
            -- boss wave 5 brought a boss (a queen, or the mode's boss pool)
            local boss = seen.bosses > 0
            for _, id in ipairs(m.bossPool or {}) do if seen.ids[id] then boss = true end end
            assert(boss, m.id .. ": no boss on wave 5")
        end
    end

    -- endless: levels tick up on their own, never a break, a queen on level 5, item choices
    local seen, game = play("endless", 230)
    local sp = seen.world.spawner
    assert(sp.wave >= 5, "endless: only reached level " .. sp.wave)
    assert(sp.phase == "wave", "endless went into a break")
    assert(seen.bosses >= 1, "endless: no queen by level 5")
    assert(seen.choices >= 1, "endless: no item choice")
    -- the HUD shows levels
    State.switch(game)
    wait(0.5)
    shot("modes_endless_hud")
    print("[selftest] modes OK (" .. #Content.modes:all() .. " modes)")
end
