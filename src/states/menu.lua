-- Title screen over a live attract-mode arena: a bug fighting off ant columns by itself.
local State = require("src.core.state")
local Settings = require("src.core.settings")
local Theme = require("src.ui.theme")
local Menu = require("src.ui.menu")
local Content = require("src.content")
local Audio = require("src.core.audio")
local Screen = require("src.core.screen")

local MainMenu = {}
MainMenu.__index = MainMenu

local VERSION = "prototype 0.2"

function MainMenu.new()
    local self = setmetatable({ t = 0 }, MainMenu)
    self.menu = Menu.new({
        plain = true,
        fontSize = 26,
        rowHeight = 46,
        rect = function()
            local w, h = love.graphics.getDimensions()
            -- a long list (resume + play again + practice) starts higher so it still fits
            local y = math.floor(h * (#self.menu.items > 8 and 0.34 or 0.42))
            return Theme.u(70), y, math.min(w - Theme.u(90), Theme.u(520)),
                math.min(h - y - Theme.u(70), Theme.u(self.menu.opts.rowHeight) * #self.menu.items)   -- room for the line under it
        end,
    })
    self:buildItems()
    self:newDemo()
    return self
end

-- Attract mode: a real arena in the background where a bug holds off the colony by itself.
function MainMenu:newDemo()
    local World = require("src.game.world")
    local chars = Content.characters:filter(function(c) return not c.custom end)
    self.demo = World.new({ mode = "run", character = chars[love.math.random(#chars)].id })
    self.demo.flags.god, self.demo.flags.demo = true, true
    -- start mid-fight: jump to wave 2 and fast-forward a few seconds
    self.demo.spawner:startWave(2)
    Audio.muted = true
    for _ = 1, 300 do self.demo:update(1 / 30) end
    Audio.muted = false
end

-- Start a run straight away with a bug and mode (the starting items screen still comes first
-- for modes that have one).
function MainMenu.quickStart(character, gameMode)
    local mode = Content.modes:get(gameMode)
    local params = { mode = "run", character = character, gameMode = gameMode }
    if mode and mode.chooseItems then
        State.push(require("src.states.loadout").new(params, mode.chooseItems))
    else
        State.switch(require("src.states.game").new(params))
    end
end

function MainMenu.tutorial()
    State.switch(require("src.states.game").new({ mode = "run", character = "rhino_beetle", gameMode = "tutorial" }))
end

function MainMenu:buildItems()
    local items = {}
    -- a run left with Save & Quit (or closed mid-run) carries on from where it was
    local RunSave = require("src.game.runsave")
    local snap = RunSave.peek()
    if snap then
        local sc = Content.characters:get(snap.character)
        items[#items + 1] = { type = "button", label = "Resume: " .. RunSave.describe(snap), icon = Menu.sprite(sc and sc.sprite, true),
            desc = "Carry on the run you left, from the start of its next wave.", onActivate = function()
            local s = RunSave.peek()
            if s then State.switch(require("src.states.game").new(RunSave.params(s))) end
        end }
    end
    items[#items + 1] = { type = "button", label = "Play", icon = Menu.sprite("rhino_beetle", true),
        desc = "Pick a map and a mode, then a bug, and hold out against the colony.", onActivate = function()
        State.push(require("src.states.modeselect").new())
    end }
    -- the guided tutorial: called out until it has been finished once
    -- (once finished it moves to the Field Guide; Practice lives in mode select)
    if not require("src.game.prefs").get().tutorialDone then
        items[#items + 1] = { type = "button", label = "Tutorial (start here)", icon = Menu.sprite("worker_ant", true),
            desc = "A short guided fight that shows everything, one thing at a time.", onActivate = MainMenu.tutorial }
    end
    -- the last bug and mode played, one press away
    local last = require("src.game.prefs").get().last
    local lc = last and Content.characters:get(last.character)
    local lm = last and Content.modes:get(last.gameMode or "colony")
    if lc and lm then
        items[#items + 1] = { type = "button", label = "Play Again: " .. lc.name .. "  ·  " .. lm.name, icon = Menu.sprite(lc.sprite, true),
            desc = "Straight into another run with the same bug and mode.", onActivate = function()
            MainMenu.quickStart(lc.id, lm.id)
        end }
    end
    -- the Burrow: spend amber on new item packs, maps, modes and artifacts (src/states/burrow.lua)
    local Amber = require("src.game.amber")
    items[#items + 1] = { type = "button", label = "The Burrow  ·  " .. Amber.balance() .. " amber", icon = Menu.sprite("icon_amber"),
        desc = "Spend the amber your runs earn on new maps, modes, items, artifacts and keepsakes.",
        onActivate = function() State.push(require("src.states.burrow").new()) end }
    items[#items + 1] = { type = "button", label = "Bug Creator", icon = Menu.sprite("icon_silk_bundle"),
        desc = "Make your own bug: mix two, paint it, give it moves.", onActivate = function()
        State.push(require("src.states.creator").new())
    end }
    if Settings.get("devMode") then
        items[#items + 1] = { type = "button", label = "Sandbox", icon = Menu.sprite("icon_dung_ball"),
            desc = "Developer playground: spawn anything, test anything.", onActivate = function()
            State.switch(require("src.states.game").new({ mode = "sandbox" }))
        end }
    end
    -- how everything works, plus the bug and item catalogues (src/states/fieldguide.lua)
    items[#items + 1] = { type = "button", label = "Field Guide", icon = Menu.sprite("icon_foragers_leaf"),
        desc = "How everything works, and every bug and item you have met.", onActivate = function()
        State.push(require("src.states.fieldguide").new())
    end }
    items[#items + 1] = { type = "button", label = "Records", icon = Menu.sprite("icon_queens_comb"),
        desc = "Your best runs, stats and achievements.", onActivate = function()
        State.push(require("src.states.records").new())
    end }
    items[#items + 1] = { type = "button", label = "Cosmetics", icon = Menu.sprite("icon_moth_wing"),
        desc = "Skins for your bugs and decorations for the arena.", onActivate = function()
        State.push(require("src.states.cosmetics").new())
    end }
    items[#items + 1] = { type = "button", label = "Settings", icon = Menu.sprite("icon_static_antenna"),
        desc = "Graphics, sound, controls, the HUD and how the game plays.", onActivate = function()
        State.push(require("src.states.settings").new())
    end }
    -- (a browser tab or iPhone app is closed from outside; quitting would just leave it blank)
    local os = love.system.getOS()
    if os ~= "Web" and os ~= "iOS" then
        items[#items + 1] = { type = "button", label = "Quit", desc = "Close the game. A run in progress is saved.",
            onActivate = function() love.event.quit() end }
    end
    -- more rows than usual: a little tighter so the list still fits under the title
    local many = #items > 8
    self.menu.opts.rowHeight, self.menu.opts.fontSize = many and 38 or 46, many and 22 or 26
    self.menu:setItems(items)
end

function MainMenu:resume() self:buildItems() end

function MainMenu:update(dt)
    self.t = self.t + dt
    Audio.muted = true
    self.demo:update(math.min(dt, 1 / 30))
    Audio.muted = false
    if self.demo.time > 150 or self.demo.enemyCount > 700 then self:newDemo() end
    self.menu:update(dt)
end

function MainMenu:draw()
    local lg = love.graphics
    local w, h = lg.getDimensions()
    local u = Theme.u

    self.demo:flushDecals()
    Screen.beginWorld({ 0.09, 0.08, 0.12, 1 })
    self.demo:draw()
    Screen.endWorld()

    -- Darken toward the left so the title and menu read clearly over the fight.
    if not self.shade then
        self.shade = love.graphics.newMesh({
            { 0, 0, 0, 0, 0.04, 0.035, 0.05, 0.85 }, { 1, 0, 0, 0, 0.04, 0.035, 0.05, 0 },
            { 1, 1, 0, 0, 0.04, 0.035, 0.05, 0 }, { 0, 1, 0, 0, 0.04, 0.035, 0.05, 0.85 },
        }, "fan", "static")
    end
    lg.setColor(1, 1, 1, 1)
    lg.draw(self.shade, 0, 0, 0, w * 0.75, h)
    lg.setColor(0.04, 0.035, 0.05, 0.35)
    lg.rectangle("fill", 0, 0, w, u(6))

    lg.setFont(Theme.font(84))
    Theme.printShadow("SWARMED", u(64), h * 0.14, Theme.colors.focus)
    lg.setFont(Theme.font(20))
    Theme.printShadow("hold the patio against the colony", u(70), h * 0.14 + u(96), Theme.colors.dim)

    self.menu:draw()
    -- what the focused entry is for, under the list
    local f = self.menu:focused()
    if f and f.desc then
        local mx, my, mw, mh = self.menu:rect()
        lg.setFont(Theme.font("label"))
        Theme.printShadow(f.desc, mx + u(14), my + mh + u(10), Theme.colors.dim, "left", math.max(mw, u(600)))
    end

    lg.setFont(Theme.font("small"))
    lg.setColor(Theme.colors.dim[1], Theme.colors.dim[2], Theme.colors.dim[3], 0.7)
    lg.print(VERSION, u(16), h - u(28))
    if Settings.get("devMode") then lg.printf("dev mode  ·  F1 hotkeys", 0, h - u(28), w - u(16), "right") end
end

function MainMenu:mousemoved(x, y) self.menu:mousemoved(x, y) end
function MainMenu:mousepressed(x, y, b) self.menu:mousepressed(x, y, b) end

return MainMenu
