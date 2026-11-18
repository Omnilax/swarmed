-- Visual options (Lighting / Camera tabs, src/gfx/lighting.lua): every option draws without
-- errors, on and off, by day and by night, and screenshots compare the looks.
--   love . --selftest --visuals   (saves selftest_vis_*.png; VIS=night,day to pick times)
local State = require("src.core.state")
local Settings = require("src.core.settings")
local Records = require("src.game.records")
local Schema = require("src.config.settings_schema")

return function(wait, shot)
    Records.noSave = true
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "run", character = "scorpion", seed = 4242 }))
    wait(0.2)
    local world = game.world
    world.flags.god = true
    game:nextWave()
    for _ = 1, 400 do
        wait(1 / 60)
        if world.enemyCount >= 25 then break end
    end
    local Reg = require("src.core.registry")
    -- an elite and a puddle for the threat / hazard lights
    local p = world.player
    for _, def in pairs(Reg.enemies or {}) do
        if def.boss then world:spawnEnemy(def, p.x + 90, p.y - 40) break end
    end
    world.hazards:addZone({ kind = "puddle", x = p.x - 50, y = p.y + 30, r = 18, life = 30, color = { 0.4, 1, 0.3 } })
    wait(0.3)
    -- every toggle in the new tabs, flipped and drawn
    for _, s in ipairs(Schema) do
        if (s.category == "Lighting" or s.category == "Camera") and s.type == "toggle" then
            local was = Settings.get(s.key)
            Settings.set(s.key, not was)
            wait(2 / 60)
            Settings.set(s.key, was)
        end
    end
    -- every choice and slider end in the new tabs too
    for _, s in ipairs(Schema) do
        if (s.category == "Lighting" or s.category == "Camera") then
            local was = Settings.get(s.key)
            if s.type == "choice" then
                for _, o in ipairs(s.options) do Settings.set(s.key, o.value) wait(2 / 60) end
            elseif s.type == "slider" then
                Settings.set(s.key, s.min) wait(2 / 60)
                Settings.set(s.key, s.max) wait(2 / 60)
            end
            Settings.set(s.key, was)
        end
    end
    -- audio options: stingers, ambience and positional placement run without errors
    for _, k in ipairs({ "musicalStingers", "positionalSound", "musicFollowsDay" }) do Settings.set(k, true) end
    Settings.set("ambientVolume", 100)
    local SS = require("src.game.soundscape")
    assert(SS.sting("clear") and SS.sting("streak"), "stingers did not play")
    for _ = 1, 30 do SS.update(world, 0.2) end
    require("src.core.audio").play("kill", { sx = world.camera.x + 200, sy = world.camera.y })
    Settings.set("musicalStingers", false)
    Settings.set("ambientVolume", 60)
    -- everything on at once
    for _, s in ipairs(Schema) do
        if (s.category == "Lighting" or s.category == "Camera") and s.type == "toggle" then Settings.set(s.key, true) end
    end
    Settings.set("autoZoom", "full")
    Settings.set("threatOutlines", "all")
    Settings.set("cloudShadows", "always")
    Settings.set("cameraHeight", "low")
    Settings.set("backgroundDim", 30)
    Settings.set("timeOfDay", "sunset")
    for _ = 1, 60 do wait(1 / 60) end
    shot("vis_all_on")
    -- camera reacts: auto-zoom eases out with a crowd, the boss intro glance runs and ends
    world.camera:glance(0, 0, 0.3)
    for _ = 1, 40 do wait(1 / 60) end
    assert(world.camera.focus == nil, "boss intro glance never ended")
    -- photo mode: opens over the run, takes keys, and puts the camera back
    local cx, cy = world.camera.x, world.camera.y
    local PM = require("src.states.photomode")
    State.push(PM.new(game))
    wait(0.1)
    local top = State.top()
    top:keypressed("t")
    top:keypressed("q")
    top:wheelmoved(0, 2)
    top.game.world.camera.x = cx + 300
    wait(0.1)
    shot("vis_photo")
    State.pop()
    wait(0.05)
    assert(math.abs(world.camera.x - cx) < 1 and world.camera.photoZoom == nil, "photo mode did not restore the camera")
    -- the looks (presets) each apply and read back as themselves
    local SS = require("src.states.settings")
    for _, lp in ipairs(require("src.config.look_presets")) do
        SS.applyPreset(lp)
        assert(SS.current(require("src.config.look_presets")) == lp, "look preset " .. lp.id .. " does not read back")
    end
    for _, s in ipairs(Schema) do
        if (s.category == "Lighting" or s.category == "Camera") then Settings.set(s.key, s.default) end
    end
    Settings.set("timeOfDay", "cycle")
    Settings.set("darkness", 100)
    assert(#require("src.config.look_presets") >= 10, "fewer than 10 looks")
    assert(SS.current(require("src.config.look_presets")).id == "standard", "defaults are not the Standard look")
    -- every tab's presets: known settings, valid values, and each reads back as itself
    for tab, tp in pairs(require("src.config.tab_presets")) do
        assert(#tp.list >= 3, tab .. " has too few presets")
        for _, pr in ipairs(tp.list) do
            for k, v in pairs(pr.values) do
                local def = Settings.byKey[k]
                assert(def, tab .. " preset " .. pr.id .. " sets unknown " .. k)
                if def.type == "choice" then
                    local ok = false
                    for _, o in ipairs(def.options) do if o.value == v then ok = true end end
                    assert(ok, tab .. " preset " .. pr.id .. ": bad value for " .. k)
                elseif def.type == "slider" then
                    assert(v >= def.min and v <= def.max, tab .. " preset " .. pr.id .. ": " .. k .. " out of range")
                end
            end
            local saved = {}
            for k in pairs(pr.values) do saved[k] = Settings.get(k) end
            SS.applyPreset(pr)
            assert(SS.current(tp.list) == pr, tab .. " preset " .. pr.id .. " does not read back")
            for k, v in pairs(saved) do Settings.set(k, v) end
        end
    end
    -- a picture of each look (VISLOOKS=1)
    if os.getenv("VISLOOKS") then
        for _, lp in ipairs(require("src.config.look_presets")) do
            SS.applyPreset(lp)
            for _ = 1, 30 do wait(1 / 60) end
            shot("look_" .. lp.id)
        end
        SS.applyPreset(require("src.config.look_presets")[1])
    end
    -- hold to inspect: slows the run and labels nearby enemies
    Settings.set("timeOfDay", "day")
    local Input = require("src.core.input")
    local realDown = Input.down
    Input.down = function(id) if id == "inspect" then return true end return realDown(id) end
    assert(require("src.ui.inspect").timeScale(world) < 1, "inspect does not slow the run")
    for _ = 1, 10 do wait(1 / 60) end
    shot("vis_inspect")
    Input.down = realDown
    -- settings with the live preview beside the Lighting tab
    local st = SS.new()
    for i, c in ipairs(st.categories) do if c == "Lighting" then st.tab = i end end
    st:build()
    State.push(st)
    for _ = 1, 20 do wait(1 / 60) end
    shot("vis_settings_lighting")
    State.pop()
    wait(0.05)
    Settings.set("backgroundDim", 0)
    -- frame rate with each look over a crowd (VISBENCH=1)
    if os.getenv("VISBENCH") then
        local LP = require("src.config.look_presets")
        for _ = 1, 8 do world.spawner:spawnGroup() end
        for _ = 1, 60 do wait(1 / 60) end
        for _, lp in ipairs(LP) do
            SS.applyPreset(lp)
            wait(2)
            print(string.format("[selftest] look %-10s %3d fps with %d enemies", lp.id, love.timer.getFPS(), world.enemyCount))
        end
        SS.applyPreset(LP[1])
        for _, kv in ipairs({ { "lightStyle", "soft" }, { "glareGuard", false }, { "rimLight", false }, { "sunShadows", false },
            { "contactShadows", false }, { "actorsPop", false }, { "fallingLeaves", false }, { "shotsOnTop", false } }) do
            local was = Settings.get(kv[1])
            Settings.set(kv[1], kv[2])
            wait(2)
            print(string.format("[selftest] standard minus %-14s %3d fps", kv[1], love.timer.getFPS()))
            Settings.set(kv[1], was)
        end
        for _, s in ipairs(Schema) do
            if (s.category == "Lighting" or s.category == "Camera") then Settings.set(s.key, s.default) end
        end
    end
    local times = os.getenv("VIS") or "night,day,sunset"
    for t in times:gmatch("[^,]+") do
        Settings.set("timeOfDay", t)
        Settings.set("lightStyle", "soft")
        Settings.set("glareGuard", false)
        wait(0.1)
        shot("vis_" .. t .. "_soft")
        Settings.set("lightStyle", "bold")
        Settings.set("glareGuard", true)
        wait(0.1)
        shot("vis_" .. t .. "_bold")
    end
    Settings.set("timeOfDay", "cycle")
    print("[selftest] visuals OK")
end
