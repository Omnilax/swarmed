-- Doc pictures (not part of the game): every map mid-fight, and a big brawl for the covers.
local State = require("src.core.state")
local Content = require("src.content")
return function(wait, shot)
    local Game = require("src.states.game")
    local chars = { "rhino_beetle", "mantis", "tarantula", "scorpion", "lobster", "stag_beetle", "orb_weaver", "bombardier_beetle", "centipede", "wolf_spider" }
    for i, st in ipairs(Content.stages:all()) do
        local g = State.switch(Game.new({ mode = "sandbox", character = chars[(i - 1) % #chars + 1], stage = st.id, seed = 99 + i }))
        local w = g.world
        if g.sandbox then g.sandbox.visible = false end
        w.flags.god = true
        local p = w.player
        local order = {}
        for _, d in ipairs(Content.enemies:all()) do if not d.boss and (d.spawn.weight or 0) > 0 then order[#order + 1] = d.id end end
        for k = 1, 70 do
            local a = love.math.random() * math.pi * 2
            local r = 60 + love.math.random() * 140
            pcall(w.spawnEnemy, w, order[(k * 7 + i * 3) % #order + 1], p.x + math.cos(a) * r, p.y + math.sin(a) * r)
        end
        wait(2.5)
        shot("map_" .. st.id)
    end
    -- close-up brawls for the covers
    local Settings = require("src.core.settings")
    for k, spec in ipairs({ { "backyard", "rhino_beetle", "sunset" }, { "mown_lawn", "mantis", "night" }, { "dune_field", "scorpion", "day" }, { "rainforest_floor", "tarantula", "evening" } }) do
        pcall(Settings.set, "timeOfDay", spec[3])
        local g = State.switch(Game.new({ mode = "sandbox", character = spec[2], stage = spec[1], seed = 7 + k }))
        local w = g.world
        if g.sandbox then g.sandbox.visible = false end
        w.flags.god = true
        local p = w.player
        local ids = { "worker_ant", "fire_ant", "soldier_ant", "army_ant", "leafcutter_ant", "bullet_ant", "green_ant", "trapjaw_ant" }
        for n = 1, 220 do
            local a = love.math.random() * math.pi * 2
            local r = 26 + love.math.random() * 170
            pcall(w.spawnEnemy, w, ids[(n % #ids) + 1], p.x + math.cos(a) * r, p.y + math.sin(a) * r)
        end
        w.camera.targetZoom, w.camera.zoom = 1.9, 1.9
        wait(2.2)
        shot("cover_" .. k)
    end
    pcall(Settings.set, "timeOfDay", "cycle")
    print("[docshots] done")
end
