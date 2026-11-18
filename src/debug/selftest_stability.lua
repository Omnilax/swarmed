-- Crash hunt + per-character frame times:  love . --selftest --stability
-- 1. Character select: focuses every bug (keyboard, hover, wheel past both ends) and draws it.
-- 2. Every character fights a ring of mixed enemies for a few seconds, pressing attack,
--    special and dash, and the update/draw cost is printed per bug.
local State = require("src.core.state")
local Content = require("src.content")
local Input = require("src.core.input")

return function(wait, shot)
    local lg = love.graphics
    local function drawState(s)
        lg.origin()
        s:draw()
        lg.flushBatch()
    end

    -- 1. character select
    local cs = State.push(require("src.states.charselect").new())
    local L = cs:layout()
    local G = L.grid
    for _, dev in ipairs({ "keyboard", "touch" }) do
        Input.lastDevice = dev
        for _, tab in ipairs(cs:tabs()) do
            cs:setTab(tab.id)
            for i = 1, #cs.list do
                cs.focus = i
                cs:ensureVisible()
                drawState(cs)
            end
        end
        cs:setTab("all")
        cs.focus, cs.scroll = 1, 0
        for _ = 1, #cs.list + 5 do          -- wheel down past the end, hovering as it goes
            cs:wheelmoved(0, -1)
            for py = G.y, G.y + G.h, 8 do cs:mousemoved(G.x + 10, py) drawState(cs) end
            cs:update(1 / 60)
        end
        for _ = 1, #cs.list + 5 do cs:wheelmoved(0, 1) drawState(cs) end
    end
    Input.lastDevice = "keyboard"
    cs:focusOn("dragonfly")
    wait(0.2)
    shot("charselect_scrolled")
    State.pop()
    print("[selftest] character select OK (" .. #cs.list .. " bugs)")

    -- 2. every character in a fight
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "sandbox", character = "rhino_beetle" }))
    wait(0.5)
    local world = game.world
    local pl = world.player
    local foes = {}
    for _, d in ipairs(Content.enemies:all()) do
        if d.spawn and (d.spawn.weight or 0) > 0 and not d.boss then foes[#foes + 1] = d.id end
    end
    local rows = {}
    for ci, def in ipairs(Content.characters:all()) do
        world:clearEnemies()
        world.hazards:clear()
        pl:setCharacter(def)
        pl.x, pl.y = world.size * 0.5, world.size * 0.5
        pl.hp = pl.stats:get("maxHp")
        world.flags.god = true
        for k = 1, 8 do
            local id = foes[(ci * 7 + k * 13) % #foes + 1]
            local a = k / 8 * math.pi * 2
            world:spawnRing(id, 6, pl.x + math.cos(a) * 90, pl.y + math.sin(a) * 90, 14)
        end
        local upd, drw, frames = 0, 0, 240
        for f = 1, frames do
            -- hold attack, tap special / dash, sweep aim and movement around
            local a = f / 30
            Input.virtualAim = { x = math.cos(a), y = math.sin(a) }
            Input.virtualMove = { x = math.cos(a * 0.7), y = math.sin(a * 0.7) }
            Input.virtualDown = Input.virtualDown or {}
            Input.virtualDown.attack = true
            Input.virtualDown.secondary = (f % 60) < 25
            Input.virtualDown.dash = (f % 90) < 30
            if f % 45 == 0 then Input.press("dash") end
            if f % 50 == 0 then Input.press("secondary") end
            local t0 = love.timer.getTime()
            game:update(1 / 60)
            local t1 = love.timer.getTime()
            if f % 4 == 0 then drawState(game) end
            local t2 = love.timer.getTime()
            Input.endFrame()
            upd, drw = upd + (t1 - t0), drw + (t2 - t1)
        end
        Input.virtualDown, Input.virtualMove, Input.virtualAim = {}, nil, nil
        rows[#rows + 1] = string.format("  %-18s update %.2f ms  draw %.2f ms  enemies %d", def.id, upd / frames * 1000, drw / (frames / 4) * 1000, world.enemyCount)
        wait(0.05)
    end
    print("[selftest] every character fought OK")
    -- hit flash on player sprites (drawn with the silhouette shader, not baked frames)
    world:clearEnemies()
    for _, id in ipairs({ "lobster", "centipede" }) do
        pl:setCharacter(Content.characters:get(id))
        pl.x, pl.y = world.size * 0.5, world.size * 0.5
        world.flags.freezeAI = true
        pl.flash = 10
        wait(0.1)
        shot("flash_" .. id)
        pl.flash = 0
    end
    world.flags.freezeAI = false
    for _, r in ipairs(rows) do print(r) end
end
