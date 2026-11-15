-- Inventory screen (I / B), modelled on FATE: a small grid bag (10x3, +1 row per 15 waves) where items come in shapes
-- (bars, L's, T's, blocks) and only fit if you can puzzle them in. There is nothing to equip:
-- everything in the bag affects your bug and copies stack. The game is paused while it is open.
--
-- Eating an item gets rid of it and heals you (more for rarer, bigger items).
--
-- Mouse:   left click picks an item up / puts it down (swapping with one item underneath),
--          right click or the wheel turns the held item, right click an item to eat it.
--          Drag an item: let go over the bag to place it, outside the case to eat it (discard).
--          SORT (T / pad left stick click) packs the bag tidily (see Inventory:autoSort).
-- Keys/pad: arrows move the cursor, Enter / A picks up and places, R / LB turns, F / X eats.
-- SCRAP (the button in the header, G / pad right stick click, or drag onto it) turns the held
-- item, or the one under the cursor, into nectar (rare or better also give back a reroll;
-- src/game/economy.lua). Cursed items can't be eaten, only scrapped (for nothing).
-- Opened with opts.held (an item just chosen that didn't fit): place it, or eat something to
-- make room; closing while still holding it eats it.
local State = require("src.core.state")
local Input = require("src.core.input")
local Audio = require("src.core.audio")
local Theme = require("src.ui.theme")
local Sprites = require("src.gfx.sprites")
local Stats = require("src.game.stats")
local Rarities = require("src.config.rarities")
local Inventory = require("src.game.inventory")
local util = require("src.core.util")

local Inv = { transparent = true, touchControls = "inventory", noTouchScroll = true }
Inv.__index = Inv

-- Palette: warm dark chitin for the case, recessed sockets for the cells.
local COL = {
    frame = { 0.16, 0.12, 0.1 }, frameHi = { 0.33, 0.25, 0.19 }, frameLo = { 0.06, 0.045, 0.04 },
    inner = { 0.085, 0.07, 0.065 }, socket = { 0.05, 0.042, 0.04 }, socketHi = { 0.14, 0.115, 0.1 },
    rivet = { 0.45, 0.36, 0.26 }, label = { 0.86, 0.74, 0.55 }, dim = { 0.58, 0.52, 0.46 },
}

local function rarityColor(def)
    local r = Rarities[def.rarity]
    r._c = r._c or util.hex(r.color)
    return r._c
end

function Inv.new(game, opts)
    local self = setmetatable({ game = game, world = game.world, t = 0 }, Inv)
    self.inv = game.world.player.inventory
    self.cursor = { kind = "bag", x = 0, y = 0 }
    self.held = nil         -- { item, from = { x, y, rot } | nil (new item) }
    if opts and opts.held then
        self.held = { item = opts.held }
        self.newItem = opts.held
    end
    self.flash = {}         -- "+12 HP" pops from eaten items
    return self
end

function Inv:enter() love.mouse.setVisible(true) end

function Inv:close()
    self:returnHeld()
    State.pop()
end

-- Put a held item back where it came from (or anywhere it fits; failing that, it is eaten).
function Inv:returnHeld()
    local h = self.held
    if not h then return end
    self.held = nil
    local inv, item = self.inv, h.item
    if h.from then
        local rot = item.rot
        item.rot = h.from.rot
        if inv:fits(item, h.from.x, h.from.y) then inv:placeInBag(item, h.from.x, h.from.y) return end
        item.rot = rot
    end
    if not inv:stow(item) then self:eatItem(item) end
end

-- Scrap an item (gone for good, pays nectar; see Economy.scrap).
function Inv:scrapItem(item, x, y)
    local Economy = require("src.game.economy")
    local n, reroll = Economy.scrap(self.world, item)
    Audio.play("equip", { pitch = 0.6 })
    Audio.play("pickup", { pitch = 1.3, volume = 0.7 })
    local mx, my = love.mouse.getPosition()
    local text = n > 0 and ("+" .. n .. " nectar") or "Scrapped"
    if reroll then text = text .. "  +1 reroll" end
    self.flash[#self.flash + 1] = { text = text, x = x or mx, y = y or my, t = 0, color = { 1, 0.85, 0.35 } }
    if item == self.newItem then self.newItem = nil end
end

-- "Cursed: scrap it" when something tries to eat a cursed item.
function Inv:refuseEat(x, y)
    Audio.play("ui_back")
    local mx, my = love.mouse.getPosition()
    self.flash[#self.flash + 1] = { text = "Cursed: scrap it", x = x or mx, y = y or my, t = 0, color = { 0.8, 0.5, 1 } }
end

-- Eat an item (gone for good, heals you). A cursed item can't be eaten: when there is no other
-- way out (closing the bag while holding it, no room) it goes to the scrapper instead.
function Inv:eatItem(item, x, y)
    if not Inventory.edible(item) then return self:scrapItem(item, x, y) end
    local hp = self.inv:eat(item)
    Audio.play("pickup", { pitch = 0.7 + love.math.random() * 0.2 })
    Audio.play("hit", { pitch = 0.6, volume = 0.6 })
    local mx, my = love.mouse.getPosition()
    self.flash[#self.flash + 1] = { text = "+" .. hp .. " HP", x = x or mx, y = y or my, t = 0 }
    if item == self.newItem then self.newItem = nil end
end

----------------------------------------------------------------------------------------------
-- Layout (recomputed each frame so UI scale and window size changes just work)

function Inv:layout()
    local w, h = love.graphics.getDimensions()
    local u = Theme.u
    local inv = self.inv
    local C = math.floor(math.min(u(68), (w - u(80)) / (inv.cols + 4.6), (h - u(190)) / (inv.rows + 0.9)))
    local pad = math.floor(C * 0.3)
    local sideW = math.floor(C * 3.6)
    local bagW, bagH = inv.cols * C, inv.rows * C
    local panelW = pad + sideW + pad + bagW + pad
    local panelH = pad + math.floor(C * 0.45) + bagH + pad
    local px = math.floor((w - panelW) / 2)
    local py = math.floor((h - panelH) / 2 - u(10))
    local top = py + pad + math.floor(C * 0.45)
    self.L = {
        C = C, pad = pad,
        panel = { x = px, y = py, w = panelW, h = panelH },
        side = { x = px + pad, y = top, w = sideW, h = bagH },
        bag = { x = px + pad + sideW + pad, y = top, w = bagW, h = bagH },
    }
    -- BAG / SKILLS tabs in the header (the skill tree is src/states/skilltree.lua)
    local f = Theme.font(18, "bold")
    local tx, ty = px + pad, py + math.floor(pad * 0.25)
    local th = math.min(f:getHeight() + u(6), top - ty - u(4))
    self.L.tabs = { { id = "bag", x = tx, y = ty, w = f:getWidth("BAG") + u(20), h = th } }
    self.L.tabs[2] = { id = "skills", x = tx + self.L.tabs[1].w + u(6), y = ty, w = f:getWidth("SKILLS") + u(20), h = th }
    -- SORT button in the header, left of the cell meter
    local sf = Theme.font(14, "bold")
    local sw = sf:getWidth("SORT") + u(20)
    local mw = math.floor(C * 2.2)
    self.L.sort = { x = math.floor(px + panelW - pad - mw - u(80) - sw), y = ty, w = sw, h = th }
    -- SCRAP bin left of SORT (drop or click a held item on it)
    local cw = sf:getWidth("SCRAP +999") + u(20)
    self.L.scrap = { x = self.L.sort.x - u(8) - cw, y = ty, w = cw, h = th }
    return self.L
end

-- What is under a window position: { kind = "bag", x, y } | { kind = "panel" } | nil (outside)
function Inv:hit(mx, my)
    local L = self.L
    local b = L.bag
    if mx >= b.x and mx < b.x + b.w and my >= b.y and my < b.y + b.h then
        return { kind = "bag", x = math.floor((mx - b.x) / L.C), y = math.floor((my - b.y) / L.C) }
    end
    local p = L.panel
    if mx >= p.x and mx < p.x + p.w and my >= p.y and my < p.y + p.h then return { kind = "panel" } end
    return nil
end

-- Top-left bag cell for placing the held item with the cursor on cell (cx, cy): centred on it.
function Inv:placeCell(cx, cy, mx, my)
    local w, h = Inventory.size(self.held.item)
    if mx then
        local L = self.L
        return math.floor((mx - L.bag.x) / L.C - w / 2 + 0.5), math.floor((my - L.bag.y) / L.C - h / 2 + 0.5)
    end
    return cx, cy
end

----------------------------------------------------------------------------------------------
-- Actions

function Inv:primary(target, mx, my)
    local inv = self.inv
    if not target or target.kind ~= "bag" then return end
    if self.held then
        local x, y = self:placeCell(target.x, target.y, mx, my)
        local hits, inside = inv:overlaps(self.held.item, x, y)
        if not inside or #hits > 1 then Audio.play("ui_back") return end
        local swap = hits[1]
        if swap then inv:removeEntry(swap) end
        inv:placeInBag(self.held.item, x, y)
        self.held = swap and { item = swap.item, from = { x = swap.x, y = swap.y, rot = swap.item.rot } } or nil
        Audio.play(swap and "equip" or "drop")
    else
        local e = inv:entryAt(target.x, target.y)
        if e then
            inv:removeEntry(e)
            self.held = { item = e.item, from = { x = e.x, y = e.y, rot = e.item.rot } }
            Audio.play("ui_move")
        end
    end
end

-- Pack the bag tidily (not while holding something).
function Inv:sort()
    if self.held then Audio.play("ui_back") return false end
    local ok = self.inv:autoSort()
    if ok then
        Audio.play("equip", { pitch = 1.2 })
        self.world.events:emit("bag_sorted")
    else
        Audio.play("ui_back")
        local L = self.L or self:layout()
        self.flash[#self.flash + 1] = { text = "Can't pack it tighter", x = L.sort.x, y = L.sort.y + Theme.u(40), t = 0, color = { 1, 0.8, 0.5 } }
    end
    return ok
end

-- Turn the held item a quarter clockwise.
function Inv:rotate()
    if not self.held then return end
    Inventory.rotate(self.held.item)
    Audio.play("ui_move", { pitch = 1.2 })
end

-- Scrap the held item, or the one in the bag under the cursor.
function Inv:scrap(target)
    if self.held then
        self:scrapItem(self.held.item)
        self.held = nil
        return true
    end
    if not target or target.kind ~= "bag" then return false end
    local e = self.inv:entryAt(target.x, target.y)
    if not e then return false end
    local L = self.L
    local w = Inventory.size(e.item)
    local x, y = L and L.bag.x + (e.x + w / 2) * L.C, L and L.bag.y + e.y * L.C
    self:scrapItem(self.inv:removeEntry(e), x, y)
    return true
end

-- Eat the held item, or the one in the bag under the cursor.
function Inv:eat(target)
    if self.held then
        if not Inventory.edible(self.held.item) then self:refuseEat() return end
        self:eatItem(self.held.item)
        self.held = nil
        return
    end
    if not target or target.kind ~= "bag" then return end
    local e = self.inv:entryAt(target.x, target.y)
    if e then
        local L = self.L
        local w, h = Inventory.size(e.item)
        local x, y = L and L.bag.x + (e.x + w / 2) * L.C, L and L.bag.y + e.y * L.C
        if not Inventory.edible(e.item) then self:refuseEat(x, y) return end
        self:eatItem(self.inv:removeEntry(e), x, y)
    end
end

-- Right click: turn the held item, or eat the one under the cursor.
function Inv:secondary(target)
    if self.held then self:rotate() else self:eat(target) end
end

----------------------------------------------------------------------------------------------
-- Input

function Inv:moveCursor(dx, dy)
    local c = self.cursor
    c.x, c.y = util.clamp(c.x + dx, 0, self.inv.cols - 1), util.clamp(c.y + dy, 0, self.inv.rows - 1)
    Audio.play("ui_move")
end

function Inv:update(dt)
    self.t = self.t + dt
    if Input.pressed("inventory") or Input.pressed("ui_back") or Input.pressed("pause") then
        Input.consume("pause")
        self:close()
        return
    end
    if Input.pressed("ui_tab_next") then require("src.states.skilltree").openFrom(self) return end
    if Input.pressed("ui_left") then self:moveCursor(-1, 0) end
    if Input.pressed("ui_right") then self:moveCursor(1, 0) end
    if Input.pressed("ui_up") then self:moveCursor(0, -1) end
    if Input.pressed("ui_down") then self:moveCursor(0, 1) end
    if Input.pressed("ui_confirm") then self:primary(self.cursor) end
    if Input.pressed("inventory_rotate") then self:rotate() end
    if Input.pressed("inventory_alt") then self:eat(self.cursor) end
    if Input.pressed("inventory_sort") then self:sort() end
    if Input.pressed("inventory_scrap") then self:scrap(self.cursor) end
    for i = #self.flash, 1, -1 do
        local f = self.flash[i]
        f.t = f.t + dt
        if f.t > 1 then table.remove(self.flash, i) end
    end
end

function Inv:mousepressed(x, y, b, istouch)
    self:layout()
    local sk = self.L.tabs[2]
    if x >= sk.x and x < sk.x + sk.w and y >= sk.y and y < sk.y + sk.h then
        require("src.states.skilltree").openFrom(self)
        return
    end
    local so = self.L.sort
    if b == 1 and x >= so.x and x < so.x + so.w and y >= so.y and y < so.y + so.h then self:sort() return end
    local sc = self.L.scrap
    if b == 1 and self.held and x >= sc.x and x < sc.x + sc.w and y >= sc.y and y < sc.y + sc.h then self:scrap() return end
    local target = self:hit(x, y)
    if target and target.kind == "bag" then self.cursor = target end
    local wasHeld = self.held
    if b == 1 then self:primary(target, x, y) elseif b == 2 then self:secondary(target) end
    -- picked something up with the mouse: it can be dragged (let go somewhere else to drop it)
    if b == 1 and self.held and not wasHeld and not istouch then
        self.drag = { x = x, y = y, moved = false }
    end
end

function Inv:mousereleased(x, y, b)
    local d = self.drag
    self.drag = nil
    if b ~= 1 or not d or not d.moved or not self.held then return end
    self:layout()
    local sc = self.L.scrap
    if x >= sc.x and x < sc.x + sc.w and y >= sc.y and y < sc.y + sc.h then self:scrap() return end
    local target = self:hit(x, y)
    if not target then
        -- dragged out of the case: eat it (items never go on the ground); cursed ones go back
        if not Inventory.edible(self.held.item) then self:refuseEat(x, y); self:returnHeld() return end
        self:eatItem(self.held.item, x, y)
        self.held = nil
    elseif target.kind == "bag" then
        local held = self.held
        self:primary(target, x, y)
        if self.held == held then self:returnHeld() end   -- didn't fit there: back where it was
    end
end

function Inv:wheelmoved() self:rotate() end

function Inv:mousemoved(x, y)
    self.mouseActive = true
    local d = self.drag
    if d and not d.moved and math.abs(x - d.x) + math.abs(y - d.y) > Theme.u(12) then d.moved = true end
end

----------------------------------------------------------------------------------------------
-- Drawing helpers

local lg = love.graphics

-- A bevelled chitin plate: dark edge, light top-left, shadowed bottom-right, rivets in corners.
local function plate(x, y, w, h, fill, rivets)
    lg.setColor(COL.frameLo)
    lg.rectangle("fill", x - 2, y - 2, w + 4, h + 4)
    lg.setColor(fill or COL.frame)
    lg.rectangle("fill", x, y, w, h)
    lg.setColor(COL.frameHi)
    lg.rectangle("fill", x, y, w, 2)
    lg.rectangle("fill", x, y, 2, h)
    lg.setColor(COL.frameLo)
    lg.rectangle("fill", x, y + h - 2, w, 2)
    lg.rectangle("fill", x + w - 2, y, 2, h)
    if rivets then
        for _, p in ipairs({ { x + 5, y + 5 }, { x + w - 8, y + 5 }, { x + 5, y + h - 8 }, { x + w - 8, y + h - 8 } }) do
            lg.setColor(COL.rivet)
            lg.rectangle("fill", p[1], p[2], 3, 3)
            lg.setColor(1, 0.9, 0.7, 0.5)
            lg.rectangle("fill", p[1], p[2], 1, 1)
        end
    end
end

-- A recessed socket for one bag cell.
local function socket(x, y, C)
    lg.setColor(COL.socket)
    lg.rectangle("fill", x + 1, y + 1, C - 2, C - 2)
    lg.setColor(0, 0, 0, 0.5)
    lg.rectangle("fill", x + 1, y + 1, C - 2, 2)
    lg.rectangle("fill", x + 1, y + 1, 2, C - 2)
    lg.setColor(COL.socketHi)
    lg.rectangle("fill", x + 1, y + C - 2, C - 2, 1)
    lg.rectangle("fill", x + C - 2, y + 1, 1, C - 2)
end

-- The icon, turned with the item, filling its bounding box.
local function itemIcon(item, x, y, w, h, alpha)
    local icon = Sprites.get(item.def.icon)
    local rot = item.rot or 0
    local iw, ih = icon.w, icon.h
    if rot % 2 == 1 then iw, ih = ih, iw end
    local s = math.min(w / iw, h / ih)
    s = s >= 1 and math.floor(s) or s
    lg.setColor(1, 1, 1, alpha or 1)
    lg.draw(Sprites.atlas, icon.frames[1][1], math.floor(x + w / 2), math.floor(y + h / 2), rot * math.pi / 2, s, s, icon.ox, icon.oy)
end

-- Fill an item's cells and trace the outline of its shape.
local function shapeCells(item, x, y, C, fill, edge, inset)
    inset = inset or 2
    local cells = Inventory.cells(item)
    local set = {}
    for _, c in ipairs(cells) do set[c[1] .. "," .. c[2]] = true end
    for _, c in ipairs(cells) do
        local cx, cy = x + c[1] * C, y + c[2] * C
        -- reach into neighbouring cells of the same item so the shape reads as one piece
        local l = set[(c[1] - 1) .. "," .. c[2]] and 0 or inset
        local r = set[(c[1] + 1) .. "," .. c[2]] and 0 or inset
        local t = set[c[1] .. "," .. (c[2] - 1)] and 0 or inset
        local b = set[c[1] .. "," .. (c[2] + 1)] and 0 or inset
        if fill then
            lg.setColor(fill)
            lg.rectangle("fill", cx + l, cy + t, C - l - r, C - t - b)
        end
        if edge then
            lg.setColor(edge)
            if l > 0 then lg.rectangle("fill", cx + l, cy + t, 1, C - t - b) end
            if r > 0 then lg.rectangle("fill", cx + C - r - 1, cy + t, 1, C - t - b) end
            if t > 0 then lg.rectangle("fill", cx + l, cy + t, C - l - r, 1) end
            if b > 0 then lg.rectangle("fill", cx + l, cy + C - b - 1, C - l - r, 1) end
        end
    end
end

local function shapeLabel(def)
    local n = #def.cells
    if n == 1 then return "1 cell" end
    return n .. " cells"
end

local function statLines(def)
    local lines = {}
    for _, sd in ipairs(Stats.defs) do
        local v = def.stats[sd.id]
        if v then
            local good = (v > 0) ~= (sd.lowerIsBetter == true)
            lines[#lines + 1] = { (v > 0 and "+" or "") .. Stats.format(sd.id, v) .. " " .. sd.label, good }
        end
        local m = def.statsMult[sd.id]
        if m then lines[#lines + 1] = { (m > 0 and "+" or "") .. math.floor(m * 100 + 0.5) .. "% " .. sd.label, (m > 0) ~= (sd.lowerIsBetter == true) } end
    end
    return lines
end

----------------------------------------------------------------------------------------------
-- Drawing

function Inv:draw()
    local w, h = lg.getDimensions()
    local u = Theme.u
    local L = self:layout()
    local C = L.C
    local mx, my = love.mouse.getPosition()
    local hover = self:hit(mx, my)
    local useMouse = Input.lastDevice == "mouse" or Input.lastDevice == "touch" or Input.lastDevice == "keyboard" and self.mouseActive
    local focus = (useMouse and hover and hover.kind == "bag") and hover or (not useMouse and self.cursor) or nil
    local inv = self.inv
    local hoverEntry0 = (not self.held and focus and focus.kind == "bag") and inv:entryAt(focus.x, focus.y) or nil

    lg.setColor(0.02, 0.015, 0.02, 0.72)
    lg.rectangle("fill", 0, 0, w, h)

    -- The case
    local P = L.panel
    plate(P.x, P.y, P.w, P.h, COL.frame, true)
    -- header: name on the left, a meter of used cells on the right
    require("src.states.skilltree").drawTabs(L.tabs, "bag", self.world.player.skills and self.world.player.skills.points)
    local used, total = inv:usedCells(), inv.cols * inv.rows
    local mw = math.floor(C * 2.2)
    local mxp = L.bag.x + L.bag.w - mw
    local myp = P.y + math.floor(L.pad * 0.5 + u(8))
    lg.setColor(COL.frameLo)
    lg.rectangle("fill", mxp - 1, myp - 1, mw + 2, math.floor(u(8)) + 2)
    local seg = mw / total
    for i = 0, total - 1 do
        lg.setColor(i < used and { 0.86, 0.68, 0.38 } or COL.socket)
        lg.rectangle("fill", math.floor(mxp + i * seg), myp, math.max(1, math.floor(seg) - 1), math.floor(u(8)))
    end
    lg.setFont(Theme.font(14))
    lg.setColor(COL.dim)
    lg.printf(used .. "/" .. total, mxp - u(70), myp - u(4), u(62), "right")
    local so = L.sort
    local soHover = mx >= so.x and mx < so.x + so.w and my >= so.y and my < so.y + so.h
    lg.setColor(soHover and COL.frameHi or COL.frameLo)
    lg.rectangle("fill", so.x, so.y, so.w, so.h)
    lg.setColor(COL.label[1], COL.label[2], COL.label[3], self.held and 0.35 or (soHover and 1 or 0.7))
    lg.rectangle("line", so.x + 0.5, so.y + 0.5, so.w - 1, so.h - 1)
    lg.setFont(Theme.font(14, "bold"))
    lg.printf("SORT", so.x, so.y + math.floor((so.h - lg.getFont():getHeight()) / 2), so.w, "center")
    -- SCRAP: lights up while holding something, and says what it pays
    local sc = L.scrap
    local scHover = mx >= sc.x and mx < sc.x + sc.w and my >= sc.y and my < sc.y + sc.h
    local SCRAP_COL = { 1, 0.82, 0.35 }
    local scrapText = "SCRAP"
    local target = self.held and self.held.item or (hoverEntry0 and hoverEntry0.item)
    if target then
        local n, rr = require("src.game.economy").scrapValue(self.world, target)
        scrapText = "SCRAP +" .. n .. (rr and " +R" or "")
    end
    lg.setColor((self.held and scHover) and { 0.35, 0.27, 0.1 } or COL.frameLo)
    lg.rectangle("fill", sc.x, sc.y, sc.w, sc.h)
    lg.setColor(SCRAP_COL[1], SCRAP_COL[2], SCRAP_COL[3], self.held and (scHover and 1 or 0.85) or 0.4)
    lg.rectangle("line", sc.x + 0.5, sc.y + 0.5, sc.w - 1, sc.h - 1)
    lg.printf(scrapText, sc.x, sc.y + math.floor((sc.h - lg.getFont():getHeight()) / 2), sc.w, "center")

    -- Left: your bug in a little window, and its stats
    local S = L.side
    local viewH = math.floor(S.h * 0.46)
    plate(S.x, S.y, S.w, viewH, COL.inner)
    local p = self.world.player
    if p.model then
        local s = math.max(2, math.floor(C / 14))
        local cx, cy = S.x + S.w / 2, S.y + viewH * 0.62
        lg.setColor(0, 0, 0, 0.4)
        lg.ellipse("fill", cx, cy + s * 2, S.w * 0.3, S.w * 0.1)
        Sprites.drawModel(p.model, 1, cx, cy, math.pi * 0.25 + math.sin(self.t * 0.6) * 0.7, false, s, s, 1,
            { phase = (self.t * 0.9) % 1 })
    end
    self:drawStats(S.x, S.y + viewH + u(10), S.w, S.h - viewH - u(10))

    -- Right: the grid
    local B = L.bag
    plate(B.x - 3, B.y - 3, B.w + 6, B.h + 6, COL.frameLo)
    for cy = 0, inv.rows - 1 do
        for cx = 0, inv.cols - 1 do socket(B.x + cx * C, B.y + cy * C, C) end
    end
    local preview
    if self.held and focus and focus.kind == "bag" then
        local px, py = self:placeCell(focus.x, focus.y, useMouse and mx or nil, useMouse and my or nil)
        local hits, inside = inv:overlaps(self.held.item, px, py)
        preview = { x = px, y = py, ok = inside and #hits <= 1, swap = hits[1] }
    end
    local hoverEntry = (not self.held and focus and focus.kind == "bag") and inv:entryAt(focus.x, focus.y) or nil
    for _, e in ipairs(inv.bag) do
        local c = rarityColor(e.item.def)
        local x, y = B.x + e.x * C, B.y + e.y * C
        local lit = (e == hoverEntry) or (preview and preview.swap == e)
        shapeCells(e.item, x, y, C, { c[1] * 0.3, c[2] * 0.3, c[3] * 0.3, lit and 0.95 or 0.7 },
            { c[1], c[2], c[3], lit and 1 or 0.55 })
        local iw, ih = Inventory.size(e.item)
        itemIcon(e.item, x + 4, y + 4, iw * C - 8, ih * C - 8)
    end
    if preview then
        local col = preview.ok and { 0.45, 1, 0.5, 0.3 } or { 1, 0.3, 0.3, 0.3 }
        shapeCells(self.held.item, B.x + preview.x * C, B.y + preview.y * C, C, col, { col[1], col[2], col[3], 0.9 }, 1)
    elseif focus and focus.kind == "bag" and not hoverEntry then
        lg.setColor(Theme.colors.focus)
        lg.rectangle("line", B.x + focus.x * C + 1.5, B.y + focus.y * C + 1.5, C - 3, C - 3)
    end

    self:drawHints(P.x, P.y + P.h + u(14), P.w)

    -- Held item follows the cursor; otherwise a tooltip for what is under it
    if self.held then
        local iw, ih = Inventory.size(self.held.item)
        local hx, hy
        if useMouse then hx, hy = mx - iw * C / 2, my - ih * C / 2
        else hx, hy = B.x + self.cursor.x * C + 6, B.y + self.cursor.y * C - 6 end
        local c = rarityColor(self.held.item.def)
        shapeCells(self.held.item, hx, hy, C, { c[1] * 0.3, c[2] * 0.3, c[3] * 0.3, 0.5 }, { c[1], c[2], c[3], 0.8 })
        itemIcon(self.held.item, hx + 4, hy + 4, iw * C - 8, ih * C - 8, 0.95)
        if self.held.item == self.newItem then
            lg.setFont(Theme.font(14))
            Theme.printShadow("No room? Eat something to make space.", P.x, P.y - u(26), COL.label, "center", P.w)
        end
    elseif hoverEntry then
        local tx, ty
        local iw = Inventory.size(hoverEntry.item)
        if useMouse then tx, ty = mx + u(18), my + u(12)
        else tx, ty = B.x + (hoverEntry.x + iw) * C + u(8), B.y + hoverEntry.y * C end
        self:tooltip(hoverEntry.item, tx, ty)
    elseif useMouse then
        -- a stat under the mouse: what its number means
        for _, r in ipairs(self.statRows or {}) do
            if mx >= r.x and mx < r.x + r.w and my >= r.y and my < r.y + r.h then
                local st = self.world.player.stats
                Inv.statTip(r.sd, st:get(r.sd.id), st.base[r.sd.id], mx + u(16), my + u(10))
            end
        end
    end
    -- dragging an item out of the case: letting go eats it
    if self.held and self.drag and self.drag.moved and not self:hit(mx, my) then
        lg.setFont(Theme.font(15, "bold"))
        local tx = math.max(u(4), math.min(mx - u(120), w - u(244)))
        local ty = my + u(28) > h - u(30) and my - u(48) or my + u(28)
        Theme.printShadow(Inventory.edible(self.held.item) and ("Let go to eat it (+" .. Inventory.eatValue(self.held.item) .. " HP)")
            or "Cursed: drop it on SCRAP", tx, ty,
            { 1, 0.6, 0.45, 0.9 + 0.1 * math.sin(self.t * 8) }, "center", u(240))
    end
    -- "+12 HP" from eaten items floats up
    lg.setFont(Theme.font(18, "bold"))
    for _, f in ipairs(self.flash) do
        local c = f.color or { 0.5, 1, 0.5 }
        Theme.printShadow(f.text, f.x - u(30), f.y - u(20) - f.t * u(30), { c[1], c[2], c[3], 1 - f.t })
    end
    lg.setColor(1, 1, 1, 1)
end

-- Key hints under the case: little key caps and a word each.
function Inv:drawHints(x, y, w)
    local u = Theme.u
    local hints = Input.lastDevice == "gamepad" and { { "A", "Move" }, { "LB", "Turn" }, { "X", "Eat" }, { "R3", "Scrap" }, { "L3", "Sort" }, { "RB", "Skills" }, { "B", "Close" } }
        or Input.lastDevice == "touch" and { { "Tap", "Pick up / put down" }, { "TURN", "Turn held" }, { "EAT", "Eat held" }, { "SCRAP", "For nectar" }, { "SORT", "Tidy up" } }
        or { { "LMB", "Move" }, { "RMB", "Turn / eat" }, { "Drag out", "Eat" }, { (Input.getKeys("inventory_scrap")[1] or "G"):upper(), "Scrap" }, { "T", "Sort" }, { "Tab", "Skills" }, { (Input.getKeys("inventory")[1] or "I"):upper(), "Close" } }
    local f = Theme.font(13)
    lg.setFont(f)
    local parts, total = {}, 0
    for i, hnt in ipairs(hints) do
        local kw = f:getWidth(hnt[1]) + u(10)
        local lw = f:getWidth(hnt[2])
        parts[i] = { kw, lw }
        total = total + kw + u(6) + lw + (i < #hints and u(22) or 0)
    end
    local cx = math.floor(x + (w - total) / 2)
    local kh = f:getHeight() + u(4)
    for i, hnt in ipairs(hints) do
        local kw, lw = parts[i][1], parts[i][2]
        lg.setColor(COL.frameLo)
        lg.rectangle("fill", cx, y + 1, kw, kh)
        lg.setColor(COL.frame)
        lg.rectangle("fill", cx, y - 1, kw, kh)
        lg.setColor(COL.label)
        lg.print(hnt[1], cx + u(5), y + u(1))
        lg.setColor(COL.dim)
        lg.print(hnt[2], cx + kw + u(6), y + u(1))
        cx = cx + kw + u(6) + lw + u(22)
    end
end

-- Draws an item tooltip card; keeps itself on screen. Stats are listed as numbers; special
-- effects (procs) are explained in words (item `effect`, or the description if it has no stats).
function Inv:tooltip(item, x, y)
    local u = Theme.u
    local def = item.def
    local tw = u(230)
    local fName, fSmall = Theme.font(17, "bold"), Theme.font(14)
    local lines = statLines(def)
    local descLines = {}
    local effect = def.effect or (#def.procs > 0 and #lines == 0 and def.description)
    if effect then _, descLines = fSmall:getWrap(effect, tw - u(20)) end
    -- a curse's cost, in purple
    local curseLines = {}
    if def.curse then _, curseLines = fSmall:getWrap("Curse: " .. def.curse, tw - u(20)) end
    -- what each chance proc rolls with right now (luck, the snowball and copies, on the curve)
    local chanceLines = {}
    local stacks = math.max(1, self.inv:count(item.id))
    for _, proc in ipairs(def.procs) do
        local ch = proc.chance and self.inv:procChance(proc, stacks)
        if ch then chanceLines[#chanceLines + 1] = ("Chance now: %d%%"):format(math.floor(ch * 100 + 0.5)) end
    end
    local lh = fSmall:getHeight() + u(2)
    local Choices = require("src.game.choices")
    local tagCounts = Choices.bagTags(self.inv)
    local fTag = Theme.font(13)
    local tagH = Choices.drawTags(def, tagCounts, 0, 0, tw - u(20), fTag, u, true)
    local th = u(10) + fName:getHeight() + u(2) + lh + u(8) + #lines * lh + #descLines * lh + u(6) + lh * 2 + u(10)
        + (#curseLines + #chanceLines) * lh
        + (tagH > 0 and tagH + u(8) or 0)
    local W, H = lg.getDimensions()
    x = math.min(x, W - tw - u(6))
    y = math.min(y, H - th - u(6))
    local c = rarityColor(def)
    plate(x, y, tw, th, COL.inner)
    lg.setColor(c)
    lg.rectangle("fill", x + 2, y + 2, tw - 4, 2)
    local cy = y + u(9)
    lg.setFont(fName)
    Theme.printShadow(def.name, x + u(10), cy, c)
    local n = self.inv:count(item.id)
    if n > 1 then
        lg.setFont(fSmall)
        lg.setColor(COL.label)
        lg.printf("x" .. n, x, cy + u(2), tw - u(10), "right")
    end
    cy = cy + fName:getHeight() + u(2)
    lg.setFont(fSmall)
    lg.setColor(COL.dim)
    lg.print(Rarities[def.rarity].label .. "  ·  " .. shapeLabel(def), x + u(10), cy)
    cy = cy + lh + u(8)
    if tagH > 0 then
        Choices.drawTags(def, tagCounts, x + u(10), cy, tw - u(20), fTag, u)
        cy = cy + tagH + u(8)
        lg.setFont(fSmall)
    end
    for _, l in ipairs(lines) do
        lg.setColor(l[2] and Theme.colors.good or Theme.colors.bad)
        lg.print(l[1], x + u(10), cy)
        cy = cy + lh
    end
    lg.setColor(Theme.colors.text)
    for _, l in ipairs(descLines) do
        lg.print(l, x + u(10), cy)
        cy = cy + lh
    end
    lg.setColor(0.8, 0.55, 1)
    for _, l in ipairs(curseLines) do
        lg.print(l, x + u(10), cy)
        cy = cy + lh
    end
    lg.setColor(0.95, 0.85, 0.55)
    for _, l in ipairs(chanceLines) do
        lg.print(l, x + u(10), cy)
        cy = cy + lh
    end
    lg.setColor(COL.dim)
    local nectar, reroll = require("src.game.economy").scrapValue(self.world, item)
    local scrap = "Scrap: +" .. nectar .. " nectar" .. (reroll and ", +1 reroll" or "")
    lg.print(Inventory.edible(item) and ("Eat: +" .. Inventory.eatValue(item) .. " HP") or "Cursed: can't be eaten", x + u(10), cy + u(6))
    lg.print(scrap, x + u(10), cy + u(6) + lh)
end

-- A tooltip for one stat: its value, where it started, and what the number means.
function Inv.statTip(sd, v, base, x, y)
    local u = Theme.u
    local tw = u(260)
    local fName, fSmall = Theme.font(16, "bold"), Theme.font(14)
    local info = Stats.explain(sd.id, v)
    local _, wrapped = fSmall:getWrap(info, tw - u(20))
    local lh = fSmall:getHeight() + u(2)
    local th = u(10) + fName:getHeight() + u(4) + lh + (#wrapped > 0 and u(6) + #wrapped * lh or 0) + u(8)
    local W, H = lg.getDimensions()
    x = math.max(u(4), math.min(x, W - tw - u(6)))
    y = math.max(u(4), math.min(y, H - th - u(6)))
    plate(x, y, tw, th, COL.inner)
    local cy = y + u(9)
    lg.setFont(fName)
    Theme.printShadow(sd.label, x + u(10), cy, COL.label)
    lg.setFont(fSmall)
    local diff = v - base
    local better = (diff > 0) ~= (sd.lowerIsBetter == true)
    lg.setColor(math.abs(diff) < 0.001 and Theme.colors.text or (better and Theme.colors.good or Theme.colors.bad))
    lg.printf(Stats.format(sd.id, v), x, cy + u(2), tw - u(10), "right")
    cy = cy + fName:getHeight() + u(4)
    lg.setColor(COL.dim)
    local delta = math.abs(diff) < 0.001 and "no change" or ((diff > 0 and "+" or "") .. Stats.format(sd.id, diff))
    lg.print("Base " .. Stats.format(sd.id, base) .. "  ·  " .. delta, x + u(10), cy)
    cy = cy + lh + u(6)
    lg.setColor(Theme.colors.text)
    for _, l in ipairs(wrapped) do
        lg.print(l, x + u(10), cy)
        cy = cy + lh
    end
end

-- Your bug's stats: the ones your items changed come first and are coloured.
function Inv:drawStats(x, y, w, h)
    local u = Theme.u
    local stats = self.world.player.stats
    local f = Theme.font(14)
    lg.setFont(f)
    local rowH = f:getHeight() + u(3)
    local list = {}
    for _, sd in ipairs(Stats.defs) do
        if math.abs(stats:get(sd.id) - stats.base[sd.id]) > 0.001 then list[#list + 1] = sd end
    end
    for _, sd in ipairs(Stats.defs) do
        if math.abs(stats:get(sd.id) - stats.base[sd.id]) <= 0.001 then list[#list + 1] = sd end
    end
    local maxRows = math.max(1, math.floor(h / rowH))
    self.statRows = {}
    for i = 1, math.min(#list, maxRows) do
        local sd = list[i]
        local v, base = stats:get(sd.id), stats.base[sd.id]
        local cy = y + (i - 1) * rowH
        self.statRows[i] = { sd = sd, x = x, y = cy - 1, w = w, h = rowH }
        if i % 2 == 1 then
            lg.setColor(1, 1, 1, 0.025)
            lg.rectangle("fill", x, cy - 1, w, rowH)
        end
        lg.setColor(COL.dim)
        lg.print(sd.label, x + u(4), cy)
        local better = (v > base) ~= (sd.lowerIsBetter == true)
        lg.setColor(math.abs(v - base) < 0.001 and Theme.colors.text or (better and Theme.colors.good or Theme.colors.bad))
        lg.printf(Stats.format(sd.id, v), x, cy, w - u(4), "right")
    end
end

-- Drawing helpers shared with the item choice screen.
Inv.plate, Inv.itemIcon, Inv.shapeCells, Inv.statLines, Inv.COL, Inv.rarityColor = plate, itemIcon, shapeCells, statLines, COL, rarityColor

return Inv
