-- Art tour:  love . --selftest --arttour
-- Saves pictures of every bug in the game (catalogue walls and in-arena line-ups by family), so
-- the art can be checked by eye for one consistent style.
local State = require("src.core.state")
local Content = require("src.content")

return function(wait, shot)
    io.stdout:setvbuf("no")
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "sandbox", character = "rhino_beetle" }))
    local world = game.world
    world.flags.god = true
    world.flags.freezeAI = true
    wait(2)
    local only = os.getenv("ARTTOUR")      -- e.g. ARTTOUR=props: just that part
    local Cat = require("src.states.spawncatalogue")
    if not only or only == "walls" then
    for _, tab in ipairs({ "enemies", "queens", "characters" }) do
        local c = Cat.new({ game = game, tab = tab })
        State.push(c)
        for page = 0, 3 do
            c.scroll = page * 400
            if c.clampScroll then c:clampScroll() end
            wait(0.3)
            shot("art_cat_" .. tab .. page)
        end
        State.pop()
    end
    end
    -- line-ups in the arena, a family at a time
    local pl = world.player
    local fams = {}
    for _, d in ipairs(Content.enemies.list) do
        local f = d.family or "other"
        fams[f] = fams[f] or {}
        table.insert(fams[f], d)
    end
    world.camera.targetZoom, world.camera.zoom = 2.2, 2.2
    for f, list in pairs((not only or only == "walls") and fams or {}) do
        world:clearEnemies()
        wait(0.2)
        local n = #list
        local cols = math.ceil(math.sqrt(n * 1.6))
        for i, d in ipairs(list) do
            local cx = ((i - 1) % cols - (cols - 1) / 2) * 34
            local cy = (math.floor((i - 1) / cols) - 1) * 30
            pcall(world.spawnEnemy, world, d.id, pl.x + cx, pl.y + cy)
        end
        wait(0.6)
        shot("art_fam_" .. f)
    end
    -- props and the antlion, close up
    world:clearEnemies()
    if game.sandbox then game.sandbox.visible = false end
    world.camera.targetZoom, world.camera.zoom = 3, 3
    local ids = {}
    for _, f in ipairs(love.filesystem.getDirectoryItems("content/props")) do
        local id = f:match("^([^_].-)%.lua$")
        if id and id ~= "ally" then ids[#ids + 1] = id end
    end
    table.sort(ids)
    for i, id in ipairs(ids) do
        local Iso = require("src.core.iso")
        local cx, cy = Iso.toWorld(((i - 1) % 5 - 2) * 56, (math.floor((i - 1) / 5) - 0.6) * 48)
        print("[arttour] prop " .. id)
        local ok, err = pcall(world.props.spawn, world.props, id, pl.x + cx, pl.y + cy)
        if not ok then print("[arttour] prop " .. id .. ": " .. tostring(err)) end
    end
    wait(0.8)
    shot("art_props")
    if world.props.clear then world.props:clear() end
    world:clearEnemies()
    -- the antlion is a stage hazard now: dig its pit next to the player
    local h = world.director:startBoss("antlion")
    h.st.x, h.st.y = pl.x + 40, pl.y + 40
    h.st.body.x, h.st.body.y = h.st.x, h.st.y
    world.camera.targetZoom, world.camera.zoom = 3, 3
    world.flags.freezeAI = false
    wait(1.5)
    shot("art_antlion")
end
