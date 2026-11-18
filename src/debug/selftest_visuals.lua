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
    local times = os.getenv("VIS") or "night,day"
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
