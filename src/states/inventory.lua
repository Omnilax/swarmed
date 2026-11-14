-- Inventory screen (I / B), modelled on FATE: a small grid bag (10x3, +1 row per 15 waves) where items come in shapes
-- (bars, L's, T's, blocks) and only fit if you can puzzle them in. There is nothing to equip:
-- everything in the bag affects your bug and copies stack. The game is paused while it is open.
--
-- Eating an item gets rid of it and heals you (more for rarer, bigger items).
--
-- Mouse:   left click picks an item up / puts it down (swapping with one item underneath),
--          right click or the wheel turns the held item, right click an item to eat it.
-- Keys/pad: arrows move the cursor, Enter / A picks up and places, R / LB turns, F / X eats.
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

-- Eat an item (gone for good, heals you).
function Inv:eatItem(item, x, y)
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

-- Turn the held item a quarter clockwise.
function Inv:rotate()
    if not self.held then return end
    Inventory.rotate(self.held.item)
    Audio.play("ui_move", { pitch = 1.2 })
end

-- Eat the held item, or the one in the bag under the cursor.
function Inv:eat(target)
    if self.held then
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
    for i = #self.flash, 1, -1 do
        local f = self.flash[i]
        f.t = f.t + dt
        if f.t > 1 then table.remove(self.flash, i) end
    end
end

function Inv:mousepressed(x, y, b)
    self:layout()
    local sk = self.L.tabs[2]
    if x >= sk.x and x < sk.x + sk.w and y >= sk.y and y < sk.y + sk.h then
        require("src.states.skilltree").openFrom(self)
        return
    end
    local target = self:hit(x, y)
    if target and target.kind == "bag" then self.cursor = target end
    if b == 1 then self:primary(target, x, y) elseif b == 2 then self:secondary(target) end
end

function Inv:wheelmoved() self:rotate() end

function Inv:mousemoved() self.mouseActive = true end

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
            local good = v > 0
            local txt = (v > 0 and "+" or "") .. Stats.format(sd.id, v) .. " " .. sd.label
            if sd.id == "dashCooldown" then good = v < 0; txt = (v > 0 and "+" or "") .. v .. "s " .. sd.label end
            lines[#lines + 1] = { txt, good }
        end
        local m = def.statsMult[sd.id]
        if m then lines[#lines + 1] = { (m > 0 and "+" or "") .. math.floor(m * 100 + 0.5) .. "% " .. sd.label, m > 0 } end
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
    end
    -- "+12 HP" from eaten items floats up
    lg.setFont(Theme.font(18, "bold"))
    for _, f in ipairs(self.flash) do
        Theme.printShadow(f.text, f.x - u(30), f.y - u(20) - f.t * u(30), { 0.5, 1, 0.5, 1 - f.t })
    end
    lg.setColor(1, 1, 1, 1)
end

-- Key hints under the case: little key caps and a word each.
function Inv:drawHints(x, y, w)
    local u = Theme.u
    local hints = Input.lastDevice == "gamepad" and { { "A", "Move" }, { "LB", "Turn" }, { "X", "Eat" }, { "RB", "Skills" }, { "B", "Close" } }
        or Input.lastDevice == "touch" and { { "Tap", "Pick up / put down" }, { "TURN", "Turn held" }, { "EAT", "Eat held" } }
        or { { "LMB", "Move" }, { "RMB", "Turn / eat" }, { "Tab", "Skills" }, { (Input.getKeys("inventory")[1] or "I"):upper(), "Close" } }
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
    local lh = fSmall:getHeight() + u(2)
    local th = u(10) + fName:getHeight() + u(2) + lh + u(8) + #lines * lh + #descLines * lh + u(6) + lh + u(10)
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
    lg.setColor(COL.dim)
    lg.print("Eat: +" .. Inventory.eatValue(item) .. " HP", x + u(10), cy + u(6))
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
    for i = 1, math.min(#list, maxRows) do
        local sd = list[i]
        local v, base = stats:get(sd.id), stats.base[sd.id]
        local cy = y + (i - 1) * rowH
        if i % 2 == 1 then
            lg.setColor(1, 1, 1, 0.025)
            lg.rectangle("fill", x, cy - 1, w, rowH)
        end
        lg.setColor(COL.dim)
        lg.print(sd.label, x + u(4), cy)
        local better = v > base
        if sd.id == "dashCooldown" then better = v < base end
        lg.setColor(math.abs(v - base) < 0.001 and Theme.colors.text or (better and Theme.colors.good or Theme.colors.bad))
        lg.printf(Stats.format(sd.id, v), x, cy, w - u(4), "right")
    end
end

-- Drawing helpers shared with the item choice screen.
Inv.plate, Inv.itemIcon, Inv.shapeCells, Inv.statLines, Inv.COL, Inv.rarityColor = plate, itemIcon, shapeCells, statLines, COL, rarityColor

return Inv
