-- Stage hazards (the sparrow and the giant anteater):  love . --selftest --hazards
-- Lets each one hunt a god-mode run for a while in real time with a crowd of ants about, and
-- takes a screenshot of every attack it makes (selftest_hz_<id>_<mode>.png), so their look and
-- their telegraphs can be checked by eye. The rules are checked in --happenings.
local State = require("src.core.state")
local Content = require("src.content")
local Settings = require("src.core.settings")

return function(wait, shot)
    local Game = require("src.states.game")
    local levelUps = Settings.get("levelUps")
    Settings.set("levelUps", "points")          -- no level-up cards over the screenshots
    for _, b in ipairs(Content.bosses:all()) do
        if b.hazard then
            local game = State.switch(Game.new({ mode = "run", character = "rhino_beetle", stage = "backyard" }))
            wait(0.2)
            local world = game.world
            world.flags.god = true
            world:clearEnemies()
            world.spawner.enabled = false
            local pl, dir = world.player, world.director
            pl.x, pl.y = world.size / 2, world.size / 2
            local worker = Content.enemies:require("worker_ant")
            local h = dir:startBoss(b.id)
            local shots, t0 = {}, love.timer.getTime()
            local key = { swoop = 0.55, swoopWarn = 0.8, landWarn = 0.7, peckWarn = 0.3, gustWarn = 0.5, circle = 1.5,
                flickWarn = 0.6, flick = 0.1, sweepWarn = 0.8, sweep = 0.4, rakeWarn = 0.8, rake = 0.15, enter = 0.8, idle = 0.5 }
            while love.timer.getTime() - t0 < 45 do
                local n = 0
                for i = 1, world.enemyCount do if not world.enemies[i].dead then n = n + 1 end end
                if n < 70 then
                    for _ = 1, 10 do
                        local a, d = love.math.random() * math.pi * 2, 60 + love.math.random() * 160
                        world:spawnEnemy(worker, pl.x + math.cos(a) * d, pl.y + math.sin(a) * d)
                    end
                end
                pl.hp = pl.maxHp or pl.hp
                local m = h.st.mode
                if m and key[m] and not shots[m] and (h.st.t or 0) >= key[m] and (m ~= "peckWarn" or (h.st.pecks or 0) >= 2) then
                    shots[m] = true
                    print(("[selftest]   %s at %.0f,%.0f z %.0f (player %.0f,%.0f)"):format(m, h.st.x or h.st.ex or 0, h.st.y or h.st.ey or 0, h.st.z or 0, pl.x, pl.y))
                    shot("hz_" .. b.id .. "_" .. m)
                end
                wait(0.03)
            end
            local got = {}
            for k in pairs(shots) do got[#got + 1] = k end
            table.sort(got)
            print("[selftest] hazard " .. b.id .. " shots: " .. table.concat(got, " "))
            dir:endHazard(true)
            wait(1)
            shot("hz_" .. b.id .. "_leaving")
            wait(3)
            assert(not dir.hazard, b.id .. " should have left")
        end
    end
    Settings.set("levelUps", levelUps)
    print("[selftest] hazards OK")
end
