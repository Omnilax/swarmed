-- The aphid matriarch's cloning screen (content/props/clone_aphid.lua, src/game/duplicate.lua).
-- Your bag is shown as it is. Step 1: pick the item to copy (only items with another of the same
-- rarity in the bag light up). Step 2: pick the item to feed her (same rarity); pressing it a
-- second time confirms. Back steps back, or closes (she waits). The game is paused meanwhile.
-- Mouse / touch: click items. Keys / pad: arrows move, Enter / A picks, Esc / B backs out.
local State = require("src.core.state")
local Input = require("src.core.input")
local Audio = require("src.core.audio")
local Theme = require("src.ui.theme")
local Inventory = require("src.game.inventory")
local Duplicate = require("src.game.duplicate")
local InvState = require("src.states.inventory")

local Dup = { transparent = true }
Dup.__index = Dup

local lg = love.graphics
Dup.ARM_TIME = 0.4

function Dup.new(game, aphid)
    local self = setmetatable({ game = game, world = game.world, aphid = aphid, t = 0 }, Dup)
    self.inv = game.world.player.inventory
    self.cursor = { x = 0, y = 0 }
    self.target, self.food, self.armed = nil, nil, false
    -- start the cursor on the first item that can be copied
    for _, e in ipairs(self.inv.bag) do
        if #Duplicate.partners(self.inv, e) > 0 then self.cursor.x, self.cursor.y = e.x, e.y break end
    end
    return self
end

function Dup:enter() love.mouse.setVisible(true) Audio.play("ui_confirm", { pitch = 1.1 }) end

function Dup:valid(e)
    if not e then return false end
    if not self.target then return #Duplicate.partners(self.inv, e) > 0 end
    return e ~= self.target and e.item.def.rarity == self.target.item.def.rarity
end

function Dup:layout()
    local w, h = lg.getDimensions()
    local u = Theme.u
    local inv = self.inv
    local C = math.floor(math.min(u(64), (w - u(60)) / inv.cols, (h - u(280)) / inv.rows))
    local bw, bh = inv.cols * C, inv.rows * C
    local bx, by = math.floor((w - bw) / 2), math.floor((h - bh) / 2 + u(20))
    self.L = { C = C, bag = { x = bx, y = by, w = bw, h = bh } }
    return self.L
end

function Dup:cellAt(mx, my)
    local L = self.L or self:layout()
    local b = L.bag
    if mx >= b.x and mx < b.x + b.w and my >= b.y and my < b.y + b.h then
        return math.floor((mx - b.x) / L.C), math.floor((my - b.y) / L.C)
    end
end

function Dup:pick(e)
    if self.t < Dup.ARM_TIME then return end
    if not self:valid(e) then
        Audio.play("ui_back")
        if e then self.note = self.target and "She only eats an item of the same rarity" or "Nothing else of that rarity to feed her" end
        return
    end
    self.note = nil
    if not self.target then
        self.target = e
        Audio.play("ui_confirm", { pitch = 1.2 })
        return
    end
    if self.food == e and self.armed then return self:feed() end
    self.food, self.armed = e, true
    Audio.play("ui_confirm", { pitch = 0.9 })
end

function Dup:feed()
    local w = self.world
    local copy, fits = Duplicate.clone(w, self.target, self.food)
    State.pop()
    if not copy then return end
    local o = self.aphid
    o.def.used(w, o)
    Audio.play("equip", { pitch = 1.2 })
    w.particles:burst(o.x, o.y, 24, { { 0.6, 1, 0.5 }, { 1, 1, 0.85 } }, 110, 80, { glow = true, grav = 100 })
    w:floatText(w.player.x, w.player.y - 10, "Cloned " .. copy.def.name .. "!", { 0.6, 1, 0.55 }, true)
    if not fits then
        -- no room for the copy: open the bag holding it (place it, or eat something)
        State.push(InvState.new(self.game, { held = copy }))
    end
end

function Dup:back()
    if self.food then self.food, self.armed = nil, false
    elseif self.target then self.target = nil
    else State.pop() end
    Audio.play("ui_back")
end

function Dup:update(dt)
    self.t = self.t + dt
    local c = self.cursor
    local inv = self.inv
    if Input.pressed("ui_left") then c.x = (c.x - 1) % inv.cols; Audio.play("ui_move") end
    if Input.pressed("ui_right") then c.x = (c.x + 1) % inv.cols; Audio.play("ui_move") end
    if Input.pressed("ui_up") then c.y = (c.y - 1) % inv.rows; Audio.play("ui_move") end
    if Input.pressed("ui_down") then c.y = (c.y + 1) % inv.rows; Audio.play("ui_move") end
    if Input.pressed("ui_confirm") then self:pick(inv:entryAt(c.x, c.y)) end
    if Input.pressed("ui_back") or Input.pressed("pause") then self:back() end
end

function Dup:mousemoved(x, y)
    local cx, cy = self:cellAt(x, y)
    if cx then self.cursor.x, self.cursor.y = cx, cy end
end

function Dup:mousepressed(x, y, b)
    if b == 2 then return self:back() end
    local cx, cy = self:cellAt(x, y)
    if cx then
        self.cursor.x, self.cursor.y = cx, cy
        self:pick(self.inv:entryAt(cx, cy))
    else
        -- outside the bag: a tap on the bottom strip backs out
        local _, h = lg.getDimensions()
        if y > h - Theme.u(70) then self:back() end
    end
end

function Dup:draw()
    local w, h = lg.getDimensions()
    local u = Theme.u
    local L = self:layout()
    local C, B = L.C, L.bag
    local COL = InvState.COL
    local inv = self.inv
    lg.setColor(0.02, 0.03, 0.02, 0.78)
    lg.rectangle("fill", 0, 0, w, h)
    lg.setFont(Theme.font(30, "bold"))
    Theme.printShadow("APHID MATRIARCH", 0, B.y - u(150), { 0.65, 1, 0.55 }, "center", w)
    lg.setFont(Theme.font(17))
    local step = not self.target and "Pick an item for her to clone."
        or not self.food and ("Feed her a " .. require("src.config.rarities")[self.target.item.def.rarity].label:lower() .. " item to clone " .. self.target.item.def.name .. ".")
        or ("Press " .. self.food.item.def.name .. " again to feed it to her.")
    Theme.printShadow(step, 0, B.y - u(100), COL.label, "center", w)
    if self.note then
        lg.setFont(Theme.font(14))
        Theme.printShadow(self.note, 0, B.y - u(70), { 1, 0.6, 0.5 }, "center", w)
    end
    InvState.plate(B.x - 6, B.y - 6, B.w + 12, B.h + 12, COL.frame, true)
    for cy = 0, inv.rows - 1 do
        for cx = 0, inv.cols - 1 do
            lg.setColor(COL.socket)
            lg.rectangle("fill", B.x + cx * C + 1, B.y + cy * C + 1, C - 2, C - 2)
        end
    end
    local hover = inv:entryAt(self.cursor.x, self.cursor.y)
    local pulse = 0.5 + 0.5 * math.sin(self.t * 6)
    for _, e in ipairs(inv.bag) do
        local c = InvState.rarityColor(e.item.def)
        local ok = self:valid(e) or e == self.target
        local x, y = B.x + e.x * C, B.y + e.y * C
        local a = ok and 1 or 0.25
        local lit = e == hover or e == self.target or e == self.food
        InvState.shapeCells(e.item, x, y, C, { c[1] * 0.3, c[2] * 0.3, c[3] * 0.3, (lit and 0.95 or 0.7) * a }, { c[1], c[2], c[3], (lit and 1 or 0.55) * a })
        local iw, ih = Inventory.size(e.item)
        InvState.itemIcon(e.item, x + 4, y + 4, iw * C - 8, ih * C - 8, ok and 1 or 0.3)
        if e == self.target or e == self.food then
            local col = e == self.target and { 0.6, 1, 0.55, 0.5 + 0.5 * pulse } or { 1, 0.6, 0.4, 0.5 + 0.5 * pulse }
            InvState.shapeCells(e.item, x, y, C, nil, col, 1)
            lg.setFont(Theme.font(12, "bold"))
            Theme.printShadow(e == self.target and "CLONE" or "FEED", x, y + 2, col, "center", iw * C)
        end
    end
    lg.setColor(Theme.colors.focus)
    lg.rectangle("line", B.x + self.cursor.x * C + 1.5, B.y + self.cursor.y * C + 1.5, C - 3, C - 3)
    -- what's under the cursor
    if hover then
        lg.setFont(Theme.font(16, "bold"))
        Theme.printShadow(hover.item.def.name, 0, B.y + B.h + u(18), InvState.rarityColor(hover.item.def), "center", w)
        lg.setFont(Theme.font(14))
        lg.setColor(COL.dim)
        lg.printf(hover.item.def.description, w / 2 - u(260), B.y + B.h + u(42), u(520), "center")
    end
    lg.setFont(Theme.font(13))
    lg.setColor(COL.dim)
    local hint = Input.lastDevice == "gamepad" and "A pick   ·   B back"
        or Input.lastDevice == "touch" and "Tap an item   ·   tap here to go back"
        or "Click / Enter pick   ·   Right click / Esc back"
    lg.printf(hint, 0, h - u(40), w, "center")
    lg.setColor(1, 1, 1, 1)
end

return Dup
