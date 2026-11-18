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
    for _, s in ipairs(Schema) do
        if (s.category == "Lighting" or s.category == "Camera") then Settings.set(s.key, s.default) end
    end
    Settings.set("backgroundDim", 0)
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
