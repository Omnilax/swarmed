-- Weather, zoom, locations, map decor and skins: every weather spell, every location with all
-- decor on, every skin on its bug, the Cosmetics screen and zoom / pinch maths.
-- Never writes the real cosmetics save.
--   love . --selftest --cosmetics   runs just this part
local State = require("src.core.state")
local Content = require("src.content")
local Settings = require("src.core.settings")
local Screen = require("src.core.screen")
local Cosmetics = require("src.game.cosmetics")
local Iso = require("src.core.iso")

return function(wait, shot)
    local realSave, saved = Cosmetics.save, Cosmetics.data
    Cosmetics.save = function() end
    Cosmetics.data = { decor = {}, skins = {}, unlocked = {} }
    local Game = require("src.states.game")

    -- zoom: wheel notches change the view size and the mouse still maps to the right spot
    local game = State.switch(Game.new({ mode = "run", character = "rhino_beetle" }))
    local world = game.world
    world.spawner.enabled = false
    world.flags.god = true
    wait(0.2)
    for _ = 1, 4 do game:wheelmoved(0, 1) end
    wait(0.6)
    assert(world.camera.zoom > 1.4, "wheel did not zoom in: " .. world.camera.zoom)
    assert(Screen.viewW < Screen.VW, "zoomed view is not smaller")
    local p = world.player
    local wx, wy = world:toWindow(p.x, p.y)
    love.mouse.setPosition(wx, wy)
    local mx, my = world:mouseWorld()
    assert(math.abs(mx - p.x) < 3 and math.abs(my - p.y) < 3, ("mouse maps to %.1f,%.1f not %.1f,%.1f"):format(mx, my, p.x, p.y))
    for _ = 1, 12 do game:wheelmoved(0, -1) end
    wait(0.6)
    assert(math.abs(world.camera.zoom - 0.6) < 0.01, "zoom out did not clamp: " .. world.camera.zoom)
    world:spawnRing("worker_ant", 60, p.x, p.y, 200)
    world.flags.freezeAI = true
    wait(0.3)
    shot("zoom_out")
    game:pinch(4)
    wait(0.8)
    assert(math.abs(world.camera.zoom - 2) < 0.01, "pinch did not zoom in: " .. world.camera.zoom)
    shot("zoom_in")
    world.camera:zoomBy(0, 0.5)
    wait(0.8)
    -- one finger dragging on the screen scrolls, it never zooms
    local Touch = require("src.core.touch")
    local z = world.camera.targetZoom
    Touch.dragging = true
    game:wheelmoved(0, 3)
    Touch.dragging = false
    assert(world.camera.targetZoom == z, "a finger drag zoomed the camera")
    world.camera.zoom, world.camera.targetZoom = 1, 1
    require("src.game.camera").lastZoom = 1

    -- every weather spell, by day and at night
    local Weather = require("src.game.weather")
    for _, def in ipairs(Content.weather:all()) do
        for _, tod in ipairs({ "day", "night" }) do
            Settings.set("timeOfDay", tod)
            world.weather:set(def, 60)
            wait(def.id == "storm" and 6 or 4.5)
            assert(world.weather:strength() > 0.9, def.id .. " did not fade in")
            if (tod == "night") == (def.night == true) or def.id == "rain" or def.id == "storm" or def.id == "fog" then
                shot("weather_" .. def.id .. "_" .. tod)
            end
        end
    end
    Settings.set("weather", "off")
    wait(0.2)
    assert(world.weather:strength() == 0, "weather off still shows weather")
    Settings.set("weather", "random")
    -- spells end and pick another
    world.weather:set(Content.weather:get("rain"), 1)
    world:update(1.2)
    world:update(0.1)
    assert(world.weather.def.id ~= "rain", "weather did not move on")
    Settings.set("timeOfDay", "cycle")

    -- every location, with all decor on, at dusk so decor lights show
    for _, d in ipairs(Content.decor:all()) do Cosmetics.data.decor[d.id] = true end
    Settings.set("timeOfDay", "night")
    for _, stage in ipairs(Content.stages:all()) do
        Cosmetics.data.location = stage.id
        game = State.switch(Game.new({ mode = "run", character = "rhino_beetle" }))
        assert(game.world.stage.id == stage.id, "chosen location not used")
        game.world.spawner.enabled = false
        game.world.weather:set(Content.weather:get("clear"), 60)
        game.world.camera:zoomBy(0, 0.6)
        wait(1)
        shot("location_" .. stage.id)
        if os.getenv("SWARMED_DUMP_GROUND") then
            game.world.ground.canvas:newImageData():encode("png", "ground_" .. stage.id .. ".png")
        end
    end
    Settings.set("timeOfDay", "cycle")
    Cosmetics.data.decor, Cosmetics.data.location = {}, nil

    -- skins: each one on its bug in a run, and the locked one hidden until unlocked
    for _, skin in ipairs(Content.skins:all()) do
        local char = skin.character or "rhino_beetle"
        Cosmetics.data.skins[char] = skin.id
        game = State.switch(Game.new({ mode = "run", character = char }))
        local expect = Cosmetics.isUnlocked(skin) and skin or nil
        assert(game.world.player.skin == expect, "skin " .. skin.id .. " not applied correctly")
        wait(0.15)
        Cosmetics.data.skins[char] = nil
    end
    -- (with Unlock Everything off: under --selftest Unlocks.free opens everything)
    local Unlocks = require("src.game.unlocks")
    local savedFree = Unlocks.free
    Unlocks.free = false
    local hidden = 0
    for _, s in ipairs(Content.skins:all()) do
        if s.locked and not Cosmetics.isUnlocked(s) and (not s.character or s.character == "rhino_beetle") then hidden = hidden + 1 end
    end
    local before = #Cosmetics.skinsFor("rhino_beetle")
    for _, s in ipairs(Content.skins:all()) do if s.locked then Cosmetics.unlock(s.id) end end
    assert(#Cosmetics.skinsFor("rhino_beetle") == before + hidden, "unlocking did not reveal locked skins")
    Unlocks.free = savedFree

    -- the Cosmetics screen: walk every row (location previews, decor, every bug's skin)
    local Cos = require("src.states.cosmetics")
    local scr = State.switch(Cos.new())
    local m = scr.menu
    for i, it in ipairs(m.items) do
        if it.type ~= "header" then
            m.focus = i
            if it.type == "choice" then
                for _ = 1, #it.options do m:adjust(it, 1) wait(0.02) end
            elseif it.type == "toggle" then
                m:adjust(it, 1) wait(0.05) m:adjust(it, 1)
            end
            if it.label == "Orchid" or (it.character and it.character.id == "mantis") then
                it.set("orchid_mantis")
                wait(0.1)
                shot("cosmetics_skin")
            end
            if it.decor and it.decor.id == "stringlights" then
                Cosmetics.data.decor.fairyring, Cosmetics.data.decor.stringlights = true, true
                wait(0.1)
                shot("cosmetics_location")
            end
        end
    end
    for _ = 1, #m.items + 3 do scr:wheelmoved(0, -1) wait(0.01) end
    State.switch(require("src.states.menu").new())
    wait(0.2)

    Cosmetics.data, Cosmetics.save = saved, realSave
    print("[selftest] cosmetics OK (" .. Content.weather:count() .. " weather, " .. Content.stages:count() .. " locations, "
        .. Content.decor:count() .. " decor, " .. Content.skins:count() .. " skins)")
end
