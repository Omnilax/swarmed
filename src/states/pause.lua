-- Pause overlay on top of the running game.
local State = require("src.core.state")
local Input = require("src.core.input")
local Theme = require("src.ui.theme")
local Menu = require("src.ui.menu")
local Stats = require("src.game.stats")

local Pause = { transparent = true }
Pause.__index = Pause

function Pause.new(game)
    local self = setmetatable({ game = game }, Pause)
    local RunSave = require("src.game.runsave")
    local items = {
        { type = "button", label = "Resume", onActivate = function() State.pop() end },
        { type = "button", label = "Restart", onActivate = function() game:restart() end },
        { type = "button", label = "Settings", onActivate = function() State.push(require("src.states.settings").new()) end },
    }
    if RunSave.allowed(game) then
        items[#items + 1] = { type = "button", label = "Save & Quit", onActivate = function() game:saveAndQuit() end }
        items[#items + 1] = { type = "button", label = "Abandon Run", onActivate = function() State.switch(require("src.states.menu").new()) end }
    else
        items[#items + 1] = { type = "button", label = "Main Menu", onActivate = function() State.switch(require("src.states.menu").new()) end }
    end
    self.menu = Menu.new({
        align = "center",
        fontSize = 24,
        rowHeight = 46,
        onBack = function() State.pop() end,
        items = items,
        rect = function()
            local w, h = love.graphics.getDimensions()
            local mw = Theme.u(300)
            return math.floor((w - mw) / 2), math.floor(h * 0.32), mw, Theme.u(46) * #items
        end,
    })
    return self
end

function Pause:enter() love.mouse.setVisible(true) end

function Pause:update(dt)
    -- Pause key also resumes (ui_back already covers Escape).
    if Input.pressed("pause") and not Input.pressed("ui_back") then State.pop() return end
    if Input.pressed("quick_restart") then self.game:restart() return end
    self.menu:update(dt)
end

function Pause:draw()
    local lg = love.graphics
    local w, h = lg.getDimensions()
    lg.setColor(0.03, 0.02, 0.05, 0.72)
    lg.rectangle("fill", 0, 0, w, h)
    lg.setFont(Theme.font("title"))
    Theme.printShadow("PAUSED", 0, h * 0.32 - Theme.u(80), Theme.colors.focus, "center", w)
    self.menu:draw()
    Theme.footer(Pause.hints())

    -- Current stats, Brotato style.
    local p = self.game.world.player
    local x, y = Theme.u(20), Theme.u(80)
    Theme.panel(x, y, Theme.u(250), Theme.u(30) + #Stats.defs * Theme.u(20))
    lg.setFont(Theme.font(15))
    for i, sd in ipairs(Stats.defs) do
        local v = p.stats:get(sd.id)
        local yy = y + Theme.u(12) + (i - 1) * Theme.u(20)
        lg.setColor(Theme.colors.dim)
        lg.print(sd.label, x + Theme.u(14), yy)
        local diff = v - sd.default
        lg.setColor(diff > 0 and Theme.colors.good or diff < 0 and Theme.colors.bad or Theme.colors.text)
        local s = Stats.format(sd.id, v)
        lg.print(s, x + Theme.u(236) - lg.getFont():getWidth(s), yy)
    end
end

-- The footer: what each key does here, on the device in use.
function Pause.hints()
    local Input = require("src.core.input")
    local function cap(id)
        local g = Input.glyph(id)
        return g.pad and ({ a = "A", b = "B", x = "X", y = "Y", start = "START", back = "BACK" })[g.pad] or g.key or "?"
    end
    return { { cap("ui_confirm"), "Choose" }, { cap("quick_restart"), "Quick Restart" }, { cap("pause"), "Resume" } }
end

function Pause:mousemoved(x, y) self.menu:mousemoved(x, y) end
function Pause:mousepressed(x, y, b) self.menu:mousepressed(x, y, b) end

return Pause
