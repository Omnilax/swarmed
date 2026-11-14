-- Developer tools: performance overlay, console and hotkeys. Active only with Developer Mode on.
local Settings = require("src.core.settings")
local State = require("src.core.state")
local Theme = require("src.ui.theme")
local commands = require("src.debug.commands")

local Dev = { console = { open = false, input = "", lines = {}, history = {}, hist = 0 }, help = false, frameTimes = {}, ft = 1 }

local HOTKEYS = {
    { "F1", "Show this help" },
    { "F2 / Tab", "Toggle sandbox panel (sandbox mode)" },
    { "F3", "Performance overlay" },
    { "F4", "Hitboxes" },
    { "F5", "Spatial grid" },
    { "F6", "God mode" },
    { "F7", "Cycle time scale" },
    { "F8", "Spawn 100 random enemies" },
    { "F9", "Kill all enemies" },
    { "F10", "Open sandbox" },
    { "`", "Console (type 'help')" },
}

local function currentGame()
    return State.find(require("src.states.game"))
end

function Dev.print(text)
    for line in tostring(text):gmatch("[^\n]+") do
        table.insert(Dev.console.lines, line)
    end
    while #Dev.console.lines > 200 do table.remove(Dev.console.lines, 1) end
end

function Dev.run(line)
    local words = {}
    for w in line:gmatch("%S+") do words[#words + 1] = w end
    if #words == 0 then return end
    local name = table.remove(words, 1):lower()
    for _, c in ipairs(commands) do
        if c.name == name then
            local ok, err = pcall(c.run, words, currentGame(), Dev.print)
            if not ok then Dev.print("error: " .. tostring(err)) end
            return
        end
    end
    Dev.print("Unknown command '" .. name .. "'. Type 'help'.")
end

local function toggleSetting(key)
    Settings.set(key, not Settings.get(key))
    Settings.save()
end

-- Returns true if the key was consumed.
function Dev.keypressed(key)
    if not Settings.get("devMode") then return false end
    local con = Dev.console
    if key == "`" then
        con.open = not con.open
        love.keyboard.setTextInput(con.open)
        return true
    end
    if con.open then
        if key == "return" or key == "kpenter" then
            Dev.print("> " .. con.input)
            if con.input ~= "" then table.insert(con.history, con.input) end
            Dev.run(con.input)
            con.input, con.hist = "", 0
        elseif key == "backspace" then
            con.input = con.input:sub(1, -2)
        elseif key == "escape" then
            con.open = false
        elseif key == "up" and #con.history > 0 then
            con.hist = math.min(#con.history, con.hist + 1)
            con.input = con.history[#con.history - con.hist + 1]
        elseif key == "down" then
            con.hist = math.max(0, con.hist - 1)
            con.input = con.hist > 0 and con.history[#con.history - con.hist + 1] or ""
        end
        return true
    end
    local game = currentGame()
    if key == "f1" then Dev.help = not Dev.help return true end
    if key == "f3" then toggleSetting("showOverlay") return true end
    if key == "f4" then toggleSetting("showHitboxes") return true end
    if key == "f5" then toggleSetting("showSpatialGrid") return true end
    if key == "f10" then Dev.run("sandbox") return true end
    if game then
        if key == "f6" then Dev.run("god") return true end
        if key == "f7" then
            local scales = { 1, 0.5, 0.25, 2, 4 }
            local cur = game.world.timeScale
            local nxt = 1
            for i, s in ipairs(scales) do if s == cur then nxt = scales[i % #scales + 1] end end
            game.world.timeScale = nxt
            return true
        end
        if key == "f8" then
            local list = require("src.content").enemies:all()
            local p = game.world.player
            for _ = 1, 100 do
                local def = list[love.math.random(#list)]
                game.world:spawnRing(def, 1, p.x, p.y, 140)
            end
            return true
        end
        if key == "f9" then Dev.run("killall") return true end
    end
    return false
end

function Dev.textinput(t)
    if not Dev.console.open then return false end
    if t ~= "`" then Dev.console.input = Dev.console.input .. t end
    return true
end

function Dev.update(dt)
    Dev.frameTimes[Dev.ft] = dt
    Dev.ft = Dev.ft % 120 + 1
end

function Dev.draw()
    if not Settings.get("devMode") then return end
    local lg = love.graphics
    local w, h = lg.getDimensions()
    if Settings.get("showOverlay") then
        local stats = lg.getStats()
        local game = currentGame()
        local worst = 0
        for _, t in ipairs(Dev.frameTimes) do worst = math.max(worst, t) end
        local lines = {
            ("FPS %d   frame %.1fms   worst %.1fms"):format(love.timer.getFPS(), love.timer.getAverageDelta() * 1000, worst * 1000),
            ("draw calls %d   batched %d   textures %.1fMB"):format(stats.drawcalls, stats.drawcallsbatched, stats.texturememory / 1048576),
            ("lua memory %.1fMB"):format(collectgarbage("count") / 1024),
        }
        if game then
            local wd = game.world
            lines[#lines + 1] = ("enemies %d   particles %d   fx %d   KOs %d   timescale %.2f"):format(
                wd.enemyCount, wd.particles.n, #wd.fx, wd.kos, wd.timeScale)
            local p = wd.player
            lines[#lines + 1] = ("player %.0f, %.0f   hp %.0f   god %s   ai %s"):format(
                p.x, p.y, p.hp, tostring(wd.flags.god), wd.flags.freezeAI and "frozen" or "on")
        end
        lg.setFont(Theme.font(14))
        local lh = lg.getFont():getHeight() + 2
        local bw = 0
        for _, l in ipairs(lines) do bw = math.max(bw, lg.getFont():getWidth(l)) end
        local x, y = 20, h - #lines * lh - 44
        lg.setColor(0, 0, 0, 0.7)
        lg.rectangle("fill", x - 8, y - 6, bw + 16, #lines * lh + 12, 4, 4)
        lg.setColor(0.6, 1, 0.6, 1)
        for i, l in ipairs(lines) do lg.print(l, x, y + (i - 1) * lh) end
    end

    if Dev.help then
        lg.setFont(Theme.font(16))
        local lh = lg.getFont():getHeight() + 4
        local bw, bh = Theme.u(420), #HOTKEYS * lh + 40
        local x, y = math.floor((w - bw) / 2), math.floor((h - bh) / 2)
        Theme.panel(x, y, bw, bh)
        lg.setColor(Theme.colors.focus)
        lg.print("Developer hotkeys", x + 16, y + 10)
        for i, k in ipairs(HOTKEYS) do
            lg.setColor(Theme.colors.accent)
            lg.print(k[1], x + 16, y + 14 + i * lh)
            lg.setColor(Theme.colors.text)
            lg.print(k[2], x + Theme.u(110), y + 14 + i * lh)
        end
    end

    local con = Dev.console
    if con.open then
        lg.setFont(Theme.font(15))
        local lh = lg.getFont():getHeight() + 2
        local ch = math.floor(h * 0.4)
        lg.setColor(0.03, 0.03, 0.05, 0.9)
        lg.rectangle("fill", 0, 0, w, ch)
        lg.setColor(0.98, 0.74, 0.27, 1)
        lg.rectangle("fill", 0, ch, w, 2)
        local maxLines = math.floor((ch - lh * 2) / lh)
        local start = math.max(1, #con.lines - maxLines + 1)
        lg.setColor(0.85, 0.85, 0.8, 1)
        for i = start, #con.lines do
            lg.print(con.lines[i], 10, 6 + (i - start) * lh)
        end
        local cursor = math.floor(love.timer.getTime() * 2) % 2 == 0 and "_" or ""
        lg.setColor(0.98, 0.74, 0.27, 1)
        lg.print("> " .. con.input .. cursor, 10, ch - lh - 4)
    end
    lg.setColor(1, 1, 1, 1)
end

Dev.print("Swarmed dev console. Type 'help' for commands.")

return Dev
