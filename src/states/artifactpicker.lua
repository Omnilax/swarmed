-- Switch artifacts on or off before a run (src/game/artifacts.lua). Opened from mode select.
-- Artifacts not bought yet show their price in the Burrow.
local State = require("src.core.state")
local Theme = require("src.ui.theme")
local Menu = require("src.ui.menu")
local Content = require("src.content")
local Artifacts = require("src.game.artifacts")

local Picker = {}
Picker.__index = Picker

function Picker.new()
    local self = setmetatable({ t = 0 }, Picker)
    local items = { { type = "header", label = "Run rules" } }
    for _, a in ipairs(Content.artifacts:all()) do
        if Artifacts.owned(a.id) then
            items[#items + 1] = { type = "toggle", label = a.name, artifact = a,
                get = function() return Artifacts.isOn(a.id) end,
                set = function(v) Artifacts.set(a.id, v) end }
        else
            items[#items + 1] = { type = "button", label = a.name, artifact = a, locked = true,
                value = function() return a.cost .. " amber" end,
                onActivate = function() require("src.core.audio").play("ui_back") end }
        end
    end
    items[#items + 1] = { type = "button", label = "All off", onActivate = function()
        for _, a in ipairs(Content.artifacts:all()) do Artifacts.set(a.id, false) end
    end }
    items[#items + 1] = { type = "button", label = "Back", onActivate = function() State.pop() end }
    self.menu = Menu.new({
        items = items,
        onBack = function() State.pop() end,
        rect = function()
            local w, h = love.graphics.getDimensions()
            return Theme.u(60), Theme.u(120), math.min(Theme.u(360), w * 0.36), h - Theme.u(200)
        end,
    })
    return self
end

function Picker:update(dt)
    self.t = self.t + dt
    self.menu:update(dt)
end

function Picker:draw()
    local lg = love.graphics
    local u, c = Theme.u, Theme.colors
    local w, h = lg.getDimensions()
    lg.clear(c.bg)
    Theme.title("Artifacts")
    self.menu:draw()
    local px = math.min(u(360), w * 0.36) + u(100)
    local pw, ph = w - px - u(60), h - u(200)
    Theme.panel(px, u(120), pw, ph)
    local x, y, iw = px + u(32), u(150), pw - u(64)
    local it = self.menu:focused()
    local a = it and it.artifact
    lg.setFont(Theme.font("body"))
    if not a then
        lg.setColor(c.text)
        lg.printf("Artifacts bend the rules of any mode. Switch on as many as you like; they stay on for every run until you switch them off. The daily run and practice ignore them.", x, y, iw)
    else
        lg.setFont(Theme.font("title", "bold"))
        Theme.printShadow(a.name:upper(), x, y, require("src.core.util").hex(a.color))
        y = y + lg.getFont():getHeight() + u(14)
        lg.setFont(Theme.font("body"))
        lg.setColor(c.text)
        local _, dl = lg.getFont():getWrap(a.description, iw)
        lg.printf(a.description, x, y, iw)
        y = y + #dl * lg.getFont():getHeight() + u(20)
        if it.locked then
            lg.setColor(c.dim)
            lg.printf(("Not yours yet. Buy it in the Burrow for %d amber."):format(a.cost), x, y, iw)
        end
    end
    -- what is on right now
    local on = Artifacts.names(Artifacts.active())
    lg.setFont(Theme.font("label"))
    lg.setColor(c.accent)
    lg.printf(on and ("On: " .. on) or "None on: the normal rules.", x, u(120) + ph - u(48), iw)
    lg.setColor(1, 1, 1, 1)
end

function Picker:mousemoved(x, y) self.menu:mousemoved(x, y) end
function Picker:mousepressed(x, y, b) self.menu:mousepressed(x, y, b) end
function Picker:wheelmoved(x, y) self.menu:wheelmoved(x, y) end

return Picker
