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
            return Theme.u(70), math.floor(h * 0.42), Theme.u(300), Theme.u(46) * #self.menu.items
        end,
    })
    self:buildItems()
    self:newDemo()
    return self
end

-- Attract mode: a real arena in the background where a bug holds off the colony by itself.
function MainMenu:newDemo()
    local World = require("src.game.world")
    local chars = Content.characters:all()
    self.demo = World.new({ mode = "run", character = chars[love.math.random(#chars)].id })
    self.demo.flags.god, self.demo.flags.demo = true, true
    -- start mid-fight: jump to wave 2 and fast-forward a few seconds
    self.demo.spawner:startWave(2)
    Audio.muted = true
    for _ = 1, 300 do self.demo:update(1 / 30) end
    Audio.muted = false
end

function MainMenu:buildItems()
    local items = {
        { type = "button", label = "Play", onActivate = function()
            State.push(require("src.states.modeselect").new())

        end },
    }
    if Settings.get("devMode") then
        items[#items + 1] = { type = "button", label = "Sandbox", onActivate = function()
            State.switch(require("src.states.game").new({ mode = "sandbox" }))
        end }
    end
    items[#items + 1] = { type = "button", label = "Bug Catalogue", onActivate = function()
        State.push(require("src.states.catalogue").new())
    end }
    items[#items + 1] = { type = "button", label = "Item Catalogue", onActivate = function()
        State.push(require("src.states.itemcatalogue").new())
    end }
    items[#items + 1] = { type = "button", label = "Records", onActivate = function()
        State.push(require("src.states.records").new())
    end }
    items[#items + 1] = { type = "button", label = "Cosmetics", onActivate = function()
        State.push(require("src.states.cosmetics").new())
    end }
    items[#items + 1] = { type = "button", label = "Settings", onActivate = function()
        State.push(require("src.states.settings").new())
    end }
    -- (a browser tab or iPhone app is closed from outside; quitting would just leave it blank)
    local os = love.system.getOS()
    if os ~= "Web" and os ~= "iOS" then
        items[#items + 1] = { type = "button", label = "Quit", onActivate = function() love.event.quit() end }
    end
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

    lg.setFont(Theme.font("small"))
    lg.setColor(Theme.colors.dim[1], Theme.colors.dim[2], Theme.colors.dim[3], 0.7)
    lg.print(VERSION, u(16), h - u(28))
    if Settings.get("devMode") then lg.printf("dev mode  ·  F1 hotkeys", 0, h - u(28), w - u(16), "right") end
end

function MainMenu:mousemoved(x, y) self.menu:mousemoved(x, y) end
function MainMenu:mousepressed(x, y, b) self.menu:mousepressed(x, y, b) end

return MainMenu
