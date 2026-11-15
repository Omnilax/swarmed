-- Settings screen, generated from the settings schema plus the rebindable input actions.
local State = require("src.core.state")
local Settings = require("src.core.settings")
local Input = require("src.core.input")
local Audio = require("src.core.audio")
local Theme = require("src.ui.theme")
local Menu = require("src.ui.menu")
local Presets = require("src.config.settings_presets")

local SettingsState = {}
SettingsState.__index = SettingsState

function SettingsState.new()
    local self = setmetatable({ tab = 1, transparent = false }, SettingsState)
    self.categories = Settings.schema.categories
    self.menu = Menu.new({
        onBack = function() self:close() end,
        rect = function()
            local w, h = love.graphics.getDimensions()
            local mw = math.min(w - Theme.u(60), Theme.u(780))
            return math.floor((w - mw) / 2), Theme.u(150), mw, h - Theme.u(260)
        end,
    })
    self:build()
    return self
end

function SettingsState:build()
    local cat = self.categories[self.tab]
    local items = {}
    if cat == "Video" then items[#items + 1] = SettingsState.presetItem() end
    for _, s in ipairs(Settings.schema) do
        if s.category == cat then
            local key = s.key
            items[#items + 1] = {
                type = s.type, label = s.label, desc = s.desc,
                min = s.min, max = s.max, step = s.step, format = s.format, options = s.options,
                get = function() return Settings.get(key) end,
                set = function(v) Settings.set(key, v) end,
            }
        end
    end
    if cat == "Controls" then
        items[#items + 1] = { type = "header", label = "Key bindings  (Enter to rebind, Backspace to clear)" }
        for _, a in ipairs(Input.actions) do
            if a.rebind then
                items[#items + 1] = { type = "keybind", label = a.label, action = a.id, slot = 1, desc = "Primary key for " .. a.label .. "." }
                items[#items + 1] = { type = "keybind", label = a.label .. " (alt)", action = a.id, slot = 2, desc = "Alternate key for " .. a.label .. "." }
            end
        end
    end
    items[#items + 1] = { type = "button", label = "Reset " .. cat .. " to defaults", onActivate = function()
        Settings.resetCategory(cat)
    end }
    items[#items + 1] = { type = "button", label = "Back", onActivate = function() self:close() end }
    self.menu:setItems(items)
end

-- The Video tab's preset row (src/config/settings_presets.lua).
function SettingsState.current()
    for _, p in ipairs(Presets) do
        local all = true
        for k, v in pairs(p.values) do if Settings.get(k) ~= v then all = false break end end
        if all then return p end
    end
end

function SettingsState.applyPreset(p)
    for k, v in pairs(p.values) do if Settings.byKey[k] then Settings.set(k, v) end end
end

function SettingsState.presetItem()
    local opts = {}
    for _, p in ipairs(Presets) do opts[#opts + 1] = { value = p.id, label = p.label } end
    local desc = "Sets the graphics options below in one go (changing one after makes it Custom). Performance suits phones and browsers, Pretty a strong PC."
    return {
        type = "choice", label = "Preset", options = opts, desc = desc,
        get = function() local p = SettingsState.current() return p and p.id or "custom" end,
        set = function(v) for _, p in ipairs(Presets) do if p.id == v then SettingsState.applyPreset(p) end end end,
        value = function() local p = SettingsState.current() return p and p.label or "Custom" end,
    }
end

function SettingsState:close()
    Settings.save()
    State.pop()
end

function SettingsState:switchTab(dir)
    self.tab = (self.tab - 1 + dir) % #self.categories + 1
    Audio.play("ui_move")
    self:build()
end

function SettingsState:update(dt)
    if not Input.isCapturing() and not self.menu.capturing then
        if Input.pressed("ui_tab_next") then self:switchTab(1) end
        if Input.pressed("ui_tab_prev") then self:switchTab(-1) end
    end
    self.menu:update(dt)
end

function SettingsState:tabRects()
    local w = love.graphics.getWidth()
    local font = Theme.font(18)
    local pad = Theme.u(16)
    local total = 0
    local widths = {}
    for i, c in ipairs(self.categories) do
        widths[i] = font:getWidth(c) + pad * 2
        total = total + widths[i]
    end
    local x = math.floor((w - total) / 2)
    local rects = {}
    for i = 1, #self.categories do
        rects[i] = { x = x, y = Theme.u(100), w = widths[i], h = Theme.u(38) }
        x = x + widths[i]
    end
    return rects
end

function SettingsState:draw()
    local lg = love.graphics
    local w, h = lg.getDimensions()
    local c = Theme.colors
    lg.setColor(c.bg[1], c.bg[2], c.bg[3], 0.97)
    lg.rectangle("fill", 0, 0, w, h)

    Theme.title("Settings", w)

    lg.setFont(Theme.font(18))
    for i, r in ipairs(self:tabRects()) do
        local active = i == self.tab
        lg.setColor(active and c.focusBg or c.row)
        lg.rectangle("fill", r.x + 2, r.y, r.w - 4, r.h)
        if active then
            lg.setColor(c.focus)
            lg.rectangle("fill", r.x + 2, r.y + r.h - 3, r.w - 4, 3)
        end
        lg.setColor(active and c.focus or c.dim)
        lg.printf(self.categories[i], r.x, r.y + math.floor((r.h - lg.getFont():getHeight()) / 2), r.w, "center")
    end

    self.menu:draw()

    local it = self.menu:focused()
    if it and it.desc then
        lg.setFont(Theme.font(17))
        lg.setColor(c.dim)
        lg.printf(it.desc, Theme.u(40), h - Theme.u(88), w - Theme.u(80), "center")
    end
    Theme.footer(Input.lastDevice == "gamepad" and { { "LB/RB", "Tab" }, { "A", "Change" }, { "B", "Back" } }
        or { { "Q/E", "Tab" }, { "Arrows", "Change" }, { "Esc", "Back" } })
end

function SettingsState:mousemoved(x, y) self.menu:mousemoved(x, y) end

function SettingsState:mousepressed(x, y, b)
    for i, r in ipairs(self:tabRects()) do
        if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
            if i ~= self.tab then
                self.tab = i
                Audio.play("ui_move")
                self:build()
            end
            return
        end
    end
    self.menu:mousepressed(x, y, b)
end

function SettingsState:wheelmoved(x, y) self.menu:wheelmoved(x, y) end

return SettingsState
