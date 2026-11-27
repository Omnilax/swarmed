-- A scrollable list of widgets driven by keyboard, controller or mouse.
--
-- Item types:
--   { type = "button", label, onActivate }
--   { type = "toggle", label, get, set }
--   { type = "slider", label, get, set, min, max, step, format }
--   { type = "choice", label, get, set, options = { {value, label}, ... } }
--   { type = "keybind", label, action, slot }
--   { type = "header", label }   -- not selectable
--   any row: icon = function(cx, cy, size, focused) draws a picture before the label (Menu.sprite)
-- Any item may have: desc (help text), disabled, value (function returning display text),
-- progress (function returning 0..1 or nil: a thin bar along the bottom of the row),
-- star (draws a favourite star before the label).
local Input = require("src.core.input")
local Audio = require("src.core.audio")
local util = require("src.core.util")
local Theme = require("src.ui.theme")

local Menu = {}
Menu.__index = Menu

local function selectable(it) return it.type ~= "header" and not it.disabled end

-- opts: items, rect = function() -> x, y, w, h, rowHeight, fontSize, onBack, mouseOnly, align ("center" | "split"),
--       plain (no row boxes: the focused row is just amber with a marker, for title-style menus)
function Menu.new(opts)
    local self = setmetatable({ opts = opts, items = opts.items or {}, focus = 1, scroll = 0 }, Menu)
    self:fixFocus(1)
    return self
end

-- keepFocus: keep the focused row number and the scroll (a rebuilt list doesn't jump).
function Menu:setItems(items, keepFocus)
    self.items = items
    if not keepFocus then self.focus, self.scroll, self.mouseFocus = 1, 0, false end
    self.focus = math.min(self.focus, #items)
    self:fixFocus(1)
end

function Menu:fixFocus(dir)
    local n = #self.items
    if n == 0 then return end
    for _ = 1, n do
        local it = self.items[self.focus]
        if it and selectable(it) then return end
        self.focus = (self.focus - 1 + dir) % n + 1
    end
end

function Menu:move(dir)
    local n = #self.items
    if n == 0 then return end
    local start = self.focus
    repeat
        self.focus = (self.focus - 1 + dir) % n + 1
    until selectable(self.items[self.focus]) or self.focus == start
    self.mouseFocus = false          -- keys / pad moved the focus: scroll it into view
    Audio.play("ui_move")
end

function Menu:focused() return self.items[self.focus] end

function Menu:rect()
    if self.opts.rect then return self.opts.rect() end
    local w, h = love.graphics.getDimensions()
    local mw = math.min(w - Theme.u(40), Theme.u(560))
    return math.floor((w - mw) / 2), Theme.u(170), mw, h - Theme.u(250)
end

function Menu:rowH() return math.floor(Theme.u(self.opts.rowHeight or 38)) end

local function choiceIndex(it)
    local v = it.get()
    for i, o in ipairs(it.options) do if o.value == v then return i end end
    return 1
end

function Menu:adjust(it, dir)
    if it.type == "toggle" then
        it.set(not it.get())
    elseif it.type == "slider" then
        local step = it.step or 1
        local v = util.clamp(it.get() + step * dir, it.min, it.max)
        if v == it.get() then return end
        it.set(v)
    elseif it.type == "choice" then
        local i = (choiceIndex(it) - 1 + dir) % #it.options + 1
        it.set(it.options[i].value)
    else
        return
    end
    Audio.play("ui_move")
end

function Menu:activate(it)
    if it.disabled then return end
    if it.type == "button" then
        Audio.play("ui_confirm")
        it.onActivate()
    elseif (it.type == "toggle" or it.type == "choice") and it.onActivate then
        Audio.play("ui_confirm")         -- a choice that also opens something (Left / Right still pick)
        it.onActivate()
    elseif it.type == "toggle" or it.type == "choice" then
        self:adjust(it, 1)
    elseif it.type == "keybind" then
        Audio.play("ui_confirm")
        self.capturing = it
        Input.captureNext(function(key)
            self.capturing = nil
            if key == "escape" then return end
            Input.setBind(it.action, it.slot, key ~= "backspace" and key or nil)
            Audio.play("ui_confirm")
        end)
    end
end

function Menu:update(dt)
    if self.capturing then return end
    if not self.opts.mouseOnly then
        if Input.pressed("ui_up") then self:move(-1) end
        if Input.pressed("ui_down") then self:move(1) end
        local it = self:focused()
        if it then
            if Input.pressed("ui_left") then self:adjust(it, -1) end
            if Input.pressed("ui_right") then self:adjust(it, 1) end
            if Input.pressed("ui_confirm") then self:activate(it) end
        end
        if Input.pressed("ui_back") and self.opts.onBack then
            Audio.play("ui_back")
            self.opts.onBack()
        end
    end
    if self.dragging then
        if love.mouse.isDown(1) then self:dragTo(self.dragging, love.mouse.getX()) else self.dragging = nil end
    end
    self:ensureVisible()
end

-- Keeps the focused row on screen. A row the mouse picked is NOT scrolled to: scrolling it
-- would slide the list under a still cursor, which then hovers (and clicks) another row
-- (the "clicking moves the screen" bug). The wheel scrolls instead.
function Menu:ensureVisible()
    local _, _, _, h = self:rect()
    local rh = self:rowH()
    if not self.mouseFocus then
        local top = (self.focus - 1) * rh
        if top < self.scroll then self.scroll = top end
        if top + rh > self.scroll + h then self.scroll = top + rh - h end
    end
    self.scroll = util.clamp(self.scroll, 0, math.max(0, #self.items * rh - h))
end

function Menu:itemAt(mx, my)
    local x, y, w, h = self:rect()
    if mx < x or mx > x + w or my < y or my > y + h then return nil end
    local i = math.floor((my - y + self.scroll) / self:rowH()) + 1
    if self.items[i] and selectable(self.items[i]) then return i end
end

function Menu:sliderBar(rowX, rowY, rowW, rh)
    local bw = math.floor(rowW * 0.32)
    return rowX + rowW - bw - Theme.u(110), rowY + math.floor(rh / 2) - 3, bw, 6
end

function Menu:dragTo(it, mx)
    local x, y, w = self:rect()
    local bx, _, bw = self:sliderBar(x, y, w, self:rowH())
    local t = util.clamp((mx - bx) / bw, 0, 1)
    local step = it.step or 1
    local v = it.min + math.floor((it.max - it.min) * t / step + 0.5) * step
    if v ~= it.get() then it.set(v) end
end

function Menu:contains(mx, my)
    local x, y, w, h = self:rect()
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

function Menu:mousemoved(mx, my)
    if self.capturing then return end
    local i = self:itemAt(mx, my)
    if i and i ~= self.focus then self.focus = i self.mouseFocus = true end
end

function Menu:mousepressed(mx, my, button)
    if self.capturing then return false end
    local i = self:itemAt(mx, my)
    if not i then return false end
    local it = self.items[i]
    -- opts.touchConfirm: a tap on a new button only focuses it (to preview), a second tap presses
    if self.opts.touchConfirm and Input.lastDevice == "touch" and i ~= self.focus and it.type == "button" then
        self.focus = i
        self.mouseFocus = true
        Audio.play("ui_move")
        return true
    end
    self.focus = i
    self.mouseFocus = true
    if it.type == "slider" and button == 1 then
        self.dragging = it
        self:dragTo(it, mx)
    elseif (it.type == "choice" or it.type == "toggle") and it.onActivate and button == 1 then
        self:activate(it)
    elseif it.type == "choice" or it.type == "toggle" then
        self:adjust(it, button == 2 and -1 or 1)
    elseif button == 1 then
        self:activate(it)
    end
    return true
end

function Menu:wheelmoved(dx, dy)
    local _, _, _, h = self:rect()
    local rh = self:rowH()
    self.scroll = util.clamp(self.scroll - dy * rh, 0, math.max(0, #self.items * rh - h))
end

function Menu:valueText(it)
    if it.value then return it.value() end
    if it.type == "toggle" then return it.get() and "On" or "Off" end
    if it.type == "slider" then return it.format and it.format(it.get()) or tostring(it.get()) end
    if it.type == "choice" then return it.options[choiceIndex(it)].label end
    if it.type == "keybind" then
        if self.capturing == it then return "press a key..." end
        local k = Input.getBind(it.action, it.slot)
        return k and k:upper() or "-"
    end
end

-- A five-pointed star centred on x, y (favourite marks).
function Menu.star(x, y, r, color)
    local pts = {}
    for i = 0, 9 do
        local a = -math.pi / 2 + i * math.pi / 5
        local rr = (i % 2 == 0) and r or r * 0.45
        pts[#pts + 1] = x + math.cos(a) * rr
        pts[#pts + 1] = y + math.sin(a) * rr
    end
    love.graphics.setColor(color)
    -- a star isn't convex: draw it as triangles from the centre
    for i = 1, 10 do
        local j = i % 10 + 1
        love.graphics.polygon("fill", x, y, pts[i * 2 - 1], pts[i * 2], pts[j * 2 - 1], pts[j * 2])
    end
end

function Menu:draw()
    local lg = love.graphics
    local c = Theme.colors
    local x, y, w, h = self:rect()
    local rh = self:rowH()
    local font = Theme.font(self.opts.fontSize or 20)
    local center = self.opts.align == "center"
    lg.setFont(font)
    lg.setScissor(x, y, w, h)
    local pad = Theme.u(14)
    -- when some rows have icons, every row keeps the room so the labels line up
    local anyIcon = false
    for _, it in ipairs(self.items) do if it.icon then anyIcon = true break end end
    for i, it in ipairs(self.items) do
        local ry = y + (i - 1) * rh - self.scroll
        if ry + rh >= y and ry <= y + h then
            local focused = i == self.focus and selectable(it)
            local ty = ry + math.floor((rh - font:getHeight()) / 2)
            if it.type == "header" then
                lg.setColor(c.accent)
                lg.setFont(Theme.font((self.opts.fontSize or 20) - 3))
                lg.print(it.label:upper(), x + pad, ty + 4)
                lg.setColor(c.accent[1], c.accent[2], c.accent[3], 0.3)
                lg.rectangle("fill", x + pad, ry + rh - 3, w - pad * 2, 1)
                lg.setFont(font)
            else
                if focused and self.opts.plain then
                    -- a small amber arrowhead; the label slides over to make room
                    local mx, my, ms = x + Theme.u(2), ry + rh / 2, Theme.u(7)
                    lg.setColor(c.focus)
                    lg.polygon("fill", mx, my - ms, mx + ms, my, mx, my + ms)
                elseif focused then
                    lg.setColor(c.focusBg)
                    lg.rectangle("fill", x, ry + 1, w, rh - 2)
                    lg.setColor(c.focus)
                    lg.rectangle("fill", x, ry + 1, 3, rh - 2)
                elseif i % 2 == 0 and not center and not self.opts.plain then
                    lg.setColor(c.row)
                    lg.rectangle("fill", x, ry + 1, w, rh - 2)
                end
                local tc = it.disabled and c.dim or (focused and c.focus or c.text)
                lg.setColor(tc)
                if center then
                    lg.printf(it.label, x, ty, w, "center")
                else
                    local lx = x + pad + ((focused and self.opts.plain) and Theme.u(6) or 0)
                    if it.icon or anyIcon then
                        -- a small picture before the label (a bug, an item...): it.icon(cx, cy, size, focused)
                        local isz = math.floor(rh * 0.78)
                        if it.icon then it.icon(lx + isz / 2, ry + rh / 2, isz, focused) end
                        lx = lx + isz + Theme.u(10)
                        lg.setColor(tc)
                    end
                    if it.star then
                        -- favourites: a small amber star before the name
                        Menu.star(lx + Theme.u(6), ry + rh / 2, Theme.u(6), c.focus)
                        lx = lx + Theme.u(18)
                        lg.setColor(tc)
                    end
                    lg.print(it.label, lx, ty)
                    local v = self:valueText(it)
                    if it.type == "slider" then
                        local bx, by, bw, bh = self:sliderBar(x, ry, w, rh)
                        local t = (it.get() - it.min) / (it.max - it.min)
                        lg.setColor(1, 1, 1, 0.15)
                        lg.rectangle("fill", bx, by, bw, bh, 3, 3)
                        lg.setColor(focused and c.focus or c.accent)
                        lg.rectangle("fill", bx, by, bw * t, bh, 3, 3)
                        lg.circle("fill", bx + bw * t, by + bh / 2, Theme.u(6))
                    end
                    local pr = it.progress and it.progress()
                    if pr then
                        local bx, bw = x + pad, w - pad * 2
                        local by = ry + rh - math.max(3, Theme.u(5))
                        lg.setColor(1, 1, 1, 0.08)
                        lg.rectangle("fill", bx, by, bw, math.max(2, Theme.u(3)))
                        lg.setColor(focused and c.focus or c.accent)
                        lg.rectangle("fill", bx, by, bw * math.max(0, math.min(1, pr)), math.max(2, Theme.u(3)))
                    end
                    if v then
                        lg.setColor(focused and c.focus or c.text)
                        local arrows = (it.type == "choice" or it.type == "slider" or it.type == "toggle") and focused
                        local txt = arrows and ("< " .. v .. " >") or v
                        lg.print(txt, x + w - pad - font:getWidth(txt), ty)
                    end
                end
            end
        end
    end
    lg.setScissor()
    -- Scroll hint
    local total = #self.items * rh
    if total > h then
        local bh = h * h / total
        local by = y + (h - bh) * (self.scroll / (total - h))
        lg.setColor(1, 1, 1, 0.2)
        lg.rectangle("fill", x + w + Theme.u(6), by, 3, bh, 2, 2)
    end
    lg.setColor(1, 1, 1, 1)
end

-- An icon function for a row: sprite `id` (an enemy, bug or item sprite) on a round chitin
-- badge, so thin dark bugs still read at a glance; amber-ringed when the row is focused.
-- turn: tip it 45 degrees (bugs drawn side-on fill the badge better that way).
function Menu.sprite(id, turn)
    return function(cx, cy, size, focused)
        local Sprites = require("src.gfx.sprites")
        local s = id and Sprites.byId and Sprites.byId[id]
        local lg = love.graphics
        local c = Theme.colors
        local r = size / 2
        lg.setColor(0.36, 0.28, 0.2, 1)
        lg.circle("fill", cx, cy, r, 24)
        lg.setColor(0.52, 0.41, 0.29, 1)
        lg.circle("fill", cx, cy - r * 0.08, r * 0.86, 24)
        if focused then
            lg.setColor(c.focus)
            lg.setLineWidth(2)
            lg.circle("line", cx, cy, r, 24)
            lg.setLineWidth(1)
        end
        if not s or not Sprites.atlas then return end
        -- the longest side fills most of the badge
        local k = (size * 0.86) / math.max(s.w, s.h)
        lg.setColor(1, 1, 1, 1)
        lg.draw(s.image or Sprites.atlas, s.frames[1][1], math.floor(cx), math.floor(cy), turn and -math.pi / 4 or 0, k, k, s.ox, s.oy)
    end
end

return Menu
