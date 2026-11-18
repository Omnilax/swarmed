-- The Wiki: every bug, enemy, item, card, map, event, mode and progression piece, with how each
-- one works, written live from the game's content (src/game/wiki.lua). Opened from the Field
-- Guide (main menu and pause). Sections are tabs along the top (Q / E, the shoulder buttons, or a
-- tap). On a wide screen the list sits on the left and the page on the right; on a narrow one
-- (phones held upright) the list fills the screen and a pick opens the page, Back returns.
-- The page scrolls with the wheel, a drag, Page keys, left / right, or the right stick.
local State = require("src.core.state")
local Theme = require("src.ui.theme")
local Menu = require("src.ui.menu")
local Input = require("src.core.input")
local Audio = require("src.core.audio")
local util = require("src.core.util")
local Wiki = require("src.game.wiki")

local WikiState = {}
WikiState.__index = WikiState

local HIDDEN = "You haven't met this one yet. It fills in once you have seen it in a run."

-- opts: section (index or id), inRun, entry (title to open on)
function WikiState.new(opts)
    opts = opts or {}
    local self = setmetatable({ t = 0, opts = opts, section = 1, scroll = 0, open = false }, WikiState)
    if type(opts.section) == "string" then
        for i, s in ipairs(Wiki.SECTIONS) do if s.id == opts.section then self.section = i end end
    elseif type(opts.section) == "number" then
        self.section = util.clamp(opts.section, 1, #Wiki.SECTIONS)
    end
    self.menu = Menu.new({
        items = {},
        rowHeight = 34,
        onBack = function() self:back() end,
        rect = function() return self:listRect() end,
    })
    self:setSection(self.section)
    if opts.entry then self:openTitle(opts.entry) end
    return self
end

function WikiState:narrow()
    local w = love.graphics.getWidth()
    return w < Theme.u(860)
end

function WikiState:top() return Theme.u(150) end

function WikiState:listRect()
    local w, h = love.graphics.getDimensions()
    local u = Theme.u
    local lw = self:narrow() and (w - u(48)) or math.min(u(340), w * 0.32)
    return u(24), self:top(), lw, h - self:top() - u(56)
end

function WikiState:pageRect()
    local w, h = love.graphics.getDimensions()
    local u = Theme.u
    if self:narrow() then return u(16), self:top(), w - u(32), h - self:top() - u(40) end
    local lx, _, lw = self:listRect()
    local px = lx + lw + u(36)
    return px, self:top(), w - px - u(24), h - self:top() - u(40)
end

function WikiState:setSection(i)
    self.section = i
    self.entries = Wiki.entries(i)
    local items, group = {}, nil
    for _, e in ipairs(self.entries) do
        if e.group ~= group then
            group = e.group
            items[#items + 1] = { type = "header", label = group }
        end
        local entry = e
        items[#items + 1] = {
            type = "button", label = e.hidden and "? ? ?" or e.title, entry = e,
            icon = e.icon and not e.hidden and Menu.sprite(e.icon) or nil,
            onActivate = function() self:openEntry(entry) end,
        }
    end
    if #self.entries == 0 then
        items[#items + 1] = { type = "header", label = "Nothing here yet" }
    end
    items[#items + 1] = { type = "button", label = "Back", onActivate = function() State.pop() end }
    self.menu:setItems(items)
    self.shown, self.scroll, self.open = nil, 0, false
end

function WikiState:openEntry(e)
    if self:narrow() then self.open = true end
    self.shown, self.scroll = e, 0
end

function WikiState:openTitle(title)
    for i, it in ipairs(self.menu.items) do
        if it.entry and it.entry.title == title then
            self.menu.focus = i
            self:openEntry(it.entry)
            return true
        end
    end
end

function WikiState:back()
    if self.open then
        self.open = false
        Audio.play("ui_back")
    else
        State.pop()
    end
end

-- The entry the page shows: the focused one (wide), or the opened one (narrow).
function WikiState:current()
    if self:narrow() then return self.open and self.shown or nil end
    local it = self.menu:focused()
    if it and it.entry then
        if self.shown ~= it.entry then self.shown, self.scroll = it.entry, 0 end
        return it.entry
    end
    return nil
end

function WikiState:scrollBy(dy)
    self.scroll = util.clamp(self.scroll + dy, 0, math.max(0, (self.pageH or 0) - (self.viewH or 0)))
end

function WikiState:update(dt)
    self.t = self.t + dt
    if Input.pressed("ui_tab_next") then
        self:setSection(self.section % #Wiki.SECTIONS + 1); Audio.play("ui_move")
    elseif Input.pressed("ui_tab_prev") then
        self:setSection((self.section - 2) % #Wiki.SECTIONS + 1); Audio.play("ui_move")
    end
    local step = Theme.u(60)
    if self.open then
        -- narrow page view: up / down scroll the page, back closes it
        if Input.pressed("ui_down") or Input.pressed("ui_right") then self:scrollBy(step) end
        if Input.pressed("ui_up") or Input.pressed("ui_left") then self:scrollBy(-step) end
        if Input.pressed("ui_back") or Input.pressed("ui_confirm") then self:back() end
    else
        if Input.pressed("ui_right") then self:scrollBy(step) end
        if Input.pressed("ui_left") then self:scrollBy(-step) end
        self.menu:update(dt)
    end
    local _, sy = Input.aimStick()
    if sy and math.abs(sy) > 0.25 then self:scrollBy(sy * dt * Theme.u(700)) end
end

----------------------------------------------------------------------------------------------
-- Drawing

local COLORS = { dim = "dim", good = "good", bad = "bad", accent = "accent" }

function WikiState:drawTabs()
    local lg = love.graphics
    local u, c = Theme.u, Theme.colors
    local w = lg.getWidth()
    lg.setFont(Theme.font("label", "bold"))
    local f = lg.getFont()
    local pad, gap = u(12), u(6)
    local total = 0
    for _, s in ipairs(Wiki.SECTIONS) do total = total + f:getWidth(s.label:upper()) + pad * 2 + gap end
    -- scroll the strip so the current tab is on screen when it doesn't all fit
    local x0 = u(24)
    local avail = w - u(48)
    local cx = 0
    for i, s in ipairs(Wiki.SECTIONS) do
        local tw = f:getWidth(s.label:upper()) + pad * 2
        if i == self.section and total > avail then x0 = u(24) - util.clamp(cx + tw / 2 - avail / 2, 0, total - avail) end
        cx = cx + tw + gap
    end
    self.tabRects = {}
    local x, y, th = x0, u(98), u(36)
    for i, s in ipairs(Wiki.SECTIONS) do
        local tw = f:getWidth(s.label:upper()) + pad * 2
        local on = i == self.section
        lg.setColor(on and c.focus or c.panel)
        lg.rectangle("fill", x, y, tw, th, u(4))
        lg.setColor(on and c.bg or c.text)
        lg.print(s.label:upper(), math.floor(x + pad), math.floor(y + (th - f:getHeight()) / 2))
        self.tabRects[i] = { x, y, tw, th }
        x = x + tw + gap
    end
    lg.setColor(1, 1, 1, 1)
end

-- Lays out and draws the page's blocks; returns the total height (draw = false only measures).
function WikiState:drawBlocks(entry, x, y, iw)
    local lg = love.graphics
    local u, c = Theme.u, Theme.colors
    local y0 = y
    lg.setFont(Theme.font("heading", "bold"))
    Theme.printShadow((entry.hidden and "Not met yet" or entry.title):upper(), x, y, c.focus)
    y = y + lg.getFont():getHeight() + u(4)
    lg.setFont(Theme.font("small"))
    lg.setColor(c.dim)
    lg.print(entry.group or "", x, y)
    y = y + lg.getFont():getHeight() + u(12)
    if entry.hidden then
        lg.setFont(Theme.font("body"))
        return y - y0 + Theme.rich(HIDDEN, x, y, iw, "left", c.text, 1)
    end
    if entry.tint then
        local col = type(entry.tint) == "string" and util.hex(entry.tint) or nil
        if col then
            lg.setColor(col)
            lg.rectangle("fill", x, y, u(48), u(10), u(3))
            y = y + u(20)
        end
    end
    for _, b in ipairs(Wiki.blocks(entry)) do
        if b.h then
            y = y + u(8)
            lg.setFont(Theme.font("label", "bold"))
            Theme.printShadow(b.h:upper(), x, y, c.accent)
            y = y + lg.getFont():getHeight() + u(4)
        elseif b.pic then
            local size = math.min(u(120), iw * 0.4)
            Menu.sprite(b.pic)(x + size / 2, y + size / 2, size, false)
            y = y + size + u(10)
        elseif b.p then
            lg.setFont(Theme.font(b.color == "dim" and "label" or "body"))
            local col = c[COLORS[b.color] or "text"] or c.text
            for para in (b.p .. "\n"):gmatch("(.-)\n") do
                if para ~= "" then y = y + Theme.rich(para, x, y, iw, "left", col, 1) + u(4) end
            end
            y = y + u(4)
        end
    end
    return y - y0
end

function WikiState:drawPage(entry)
    local lg = love.graphics
    local u, c = Theme.u, Theme.colors
    local px, py, pw, ph = self:pageRect()
    Theme.panel(px, py, pw, ph)
    if not entry then
        local s = Wiki.SECTIONS[self.section]
        lg.setFont(Theme.font("heading", "bold"))
        Theme.printShadow(s.label:upper(), px + u(24), py + u(20), c.focus)
        lg.setFont(Theme.font("body"))
        Theme.rich(s.blurb, px + u(24), py + u(64), pw - u(48), "left", c.text, 1)
        return
    end
    local ix, iw = px + u(24), pw - u(48)
    self.viewH = ph - u(32)
    lg.setScissor(px, py + u(8), pw, ph - u(16))
    self.pageH = self:drawBlocks(entry, ix, py + u(20) - self.scroll, iw) + u(16)
    lg.setScissor()
    self.scroll = util.clamp(self.scroll, 0, math.max(0, self.pageH - self.viewH))
    -- a scroll bar when the page is longer than the panel
    if self.pageH > self.viewH then
        local bh = math.max(u(30), ph * self.viewH / self.pageH)
        local by = py + (ph - bh) * (self.scroll / (self.pageH - self.viewH))
        lg.setColor(c.dim[1], c.dim[2], c.dim[3], 0.6)
        lg.rectangle("fill", px + pw - u(8), by, u(4), bh, u(2))
    end
    if self.open then
        -- a Back button for touch (and the mouse) on the narrow page view
        lg.setFont(Theme.font("label", "bold"))
        local f = lg.getFont()
        local bw, bh = f:getWidth("< BACK") + u(24), u(36)
        local bx, by = love.graphics.getWidth() - bw - u(16), u(40)   -- in the title row, clear of the tabs
        self.backRect = { bx, by, bw, bh }
        lg.setColor(c.focus)
        lg.rectangle("fill", bx, by, bw, bh, u(4))
        lg.setColor(c.bg)
        lg.print("< BACK", math.floor(bx + u(12)), math.floor(by + (bh - f:getHeight()) / 2))
    else
        self.backRect = nil
    end
    lg.setColor(1, 1, 1, 1)
end

function WikiState:draw()
    local lg = love.graphics
    local u, c = Theme.u, Theme.colors
    local w, h = lg.getDimensions()
    if self.opts.inRun then
        lg.setColor(0, 0, 0, 0.86)
        lg.rectangle("fill", 0, 0, w, h)
    else
        lg.clear(c.bg)
    end
    Theme.title("Wiki")
    self:drawTabs()
    if self:narrow() then
        if self.open then self:drawPage(self.shown) else self.menu:draw() end
    else
        self.menu:draw()
        self:drawPage(self:current())
    end
    if Input.lastDevice ~= "touch" then
        local hints = Input.lastDevice == "gamepad"
            and { { "LB/RB", "Section" }, { "D-pad", "Browse" }, { "R-stick", "Scroll" }, { "B", "Back" } }
            or { { "Q/E", "Section" }, { "Arrows", "Browse" }, { "Wheel", "Scroll" }, { "Esc", "Back" } }
        Theme.footer(hints)
    end
end

----------------------------------------------------------------------------------------------
-- Mouse and touch

local function inside(r, x, y) return r and x >= r[1] and x <= r[1] + r[3] and y >= r[2] and y <= r[2] + r[4] end

function WikiState:mousepressed(x, y, b)
    for i, r in ipairs(self.tabRects or {}) do
        if inside(r, x, y) then
            if i ~= self.section then self:setSection(i); Audio.play("ui_move") end
            return
        end
    end
    if self.open then
        if inside(self.backRect, x, y) or b == 2 then self:back() end
        return
    end
    self.menu:mousepressed(x, y, b)
end

function WikiState:mousemoved(x, y) if not self.open then self.menu:mousemoved(x, y) end end

function WikiState:wheelmoved(x, y)
    local mx, my = love.mouse.getPosition()
    local px, py, pw, ph = self:pageRect()
    if self.open or (not self:narrow() and inside({ px, py, pw, ph }, mx, my)) then
        self:scrollBy(-y * Theme.u(40))
    else
        self.menu:wheelmoved(x, y)
    end
end

return WikiState
