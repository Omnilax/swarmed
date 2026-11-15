-- Item choice: after every wave, pick one of three items (more if you killed a queen; a
-- boss wave guarantees something rare). Items never drop from enemies, so this is where the
-- build comes from. The pick goes into the bag; if it doesn't fit, the inventory opens holding
-- it so you can make room (or eat it). The game is paused while this is open.
-- No accidental picks: input is ignored for a moment after it opens (space / A are also dash,
-- the mouse is also attack), and taking a card needs two presses: one to pick it, one to confirm.
-- SKIP (the button under the cards, Esc / Backspace, or pad B) passes on every card; it is
-- two presses too. The skip slot is focus index #items + 1, REROLL is #items + 2.
--
-- Helpers (src/game/choices.lua, numbers in src/config/itemchoice.lua):
--   REROLL (R / pad X)   new cards for every unlocked card; a few per run, queens give some back
--   LOCK (L / pad RB)    the card comes back in the next item choice; free, toggles
--   BAN (X / Del / pad Y) two presses: the item never shows up again this run; a few per run
-- Cards also show the item's tags (lit when your bag shares them) and what it does to your
-- stats ("Speed 120 » 138").
local State = require("src.core.state")
local Input = require("src.core.input")
local Audio = require("src.core.audio")
local Theme = require("src.ui.theme")
local Rarities = require("src.config.rarities")
local Inventory = require("src.game.inventory")
local Choices = require("src.game.choices")
local InvState = require("src.states.inventory")

local Choice = { transparent = true }
Choice.__index = Choice

local lg = love.graphics

Choice.ARM_TIME = 0.8     -- seconds before the cards accept any input
local LOCK_COL = { 1, 0.82, 0.35 }
local BAN_COL = { 1, 0.45, 0.4 }

-- opts: count (cards), boss (true after a boss wave: one is rare or better), wave
function Choice.new(game, opts)
    local self = setmetatable({ game = game, world = game.world, t = 0, opts = opts }, Choice)
    self.minRarity = opts.boss and "rare" or nil
    self.run = Choices.state(game.world)
    self.items = Choices.deal(game.world, opts.count or 3, self.minRarity)
    self.tags = Choices.bagTags(game.world.player.inventory)
    self:refresh()
    self.focus = 1
    self.armed = nil          -- the card (or skip) picked once, waiting for its confirm
    self.armedBan = nil       -- the card whose BAN was pressed once
    self.flashT = {}          -- [slot] = time a card was just dealt (reroll / ban), for a pop
    return self
end

-- Stat previews per card (after a reroll or ban too).
function Choice:refresh()
    local stats = self.world.player.stats
    self.previews = {}
    for i, it in ipairs(self.items) do self.previews[i] = Choices.preview(stats, it.def) end
end

function Choice:enter()
    love.mouse.setVisible(true)
    Audio.play("ui_confirm", { pitch = 1.2 })
end

function Choice:take(i)
    local item = self.items[i]
    if not item then return end
    item.locked = nil
    Choices.remember(self.world, self.items, item)
    State.pop()
    local inv = self.world.player.inventory
    self.world.events:emit("item_taken", item)
    if inv:give(item) then
        Audio.play("equip")
        self.world:floatText(self.world.player.x, self.world.player.y, item.def.name, InvState.rarityColor(item.def), true)
    else
        -- no room: open the bag holding it, so you can puzzle it in or eat something
        State.push(InvState.new(self.game, { held = item }))
    end
end

-- Pass on every card: nothing goes in the bag (locked cards still come back next time).
function Choice:skip()
    Choices.remember(self.world, self.items, nil)
    State.pop()
    self.world.events:emit("item_skipped")
    Audio.play("ui_back")
    self.world:floatText(self.world.player.x, self.world.player.y, "Skipped", { 0.75, 0.7, 0.65 }, true)
end

-- New cards for every card that isn't locked.
function Choice:reroll()
    if not self:ready() then return false end
    self.armed, self.armedBan = nil, nil
    local old = self.items
    local items, why = Choices.reroll(self.world, self.items, self.minRarity)
    if not items then
        Audio.play("ui_back")
        self.note = { text = why == "locked" and "Every card is locked" or "No rerolls left", t = 0 }
        return false
    end
    self.items = items
    for i, it in ipairs(items) do if it ~= old[i] then self.flashT[i] = self.t end end
    self:refresh()
    if self.focus > #items + 2 then self.focus = 1 end
    Audio.play("ui_confirm", { pitch = 1.4 })
    return true
end

-- Lock / unlock card i (it comes back in the next item choice).
function Choice:toggleLock(i)
    local it = self.items[i]
    if not self:ready() or not it then return end
    it.locked = not it.locked or nil
    self.armedBan = nil
    Audio.play(it.locked and "equip" or "ui_move", { pitch = it.locked and 1.3 or 1 })
end

-- BAN on card i: the first press arms it, a second press bans the item for the run.
function Choice:ban(i)
    if not self:ready() or not self.items[i] then return false end
    if self.run.banishes <= 0 then
        Audio.play("ui_back")
        self.note = { text = "No bans left", t = 0 }
        return false
    end
    if self.armedBan ~= i then
        self.armedBan, self.armed, self.focus = i, nil, i
        Audio.play("ui_confirm", { pitch = 0.8 })
        return false
    end
    self.armedBan = nil
    local name = self.items[i].def.name
    self.items = Choices.banish(self.world, self.items, i, self.minRarity)
    self.flashT[i] = self.t
    self:refresh()
    self.note = { text = name .. " banned for this run", t = 0 }
    Audio.play("hit", { pitch = 0.7 })
    return true
end

function Choice:ready() return self.t >= Choice.ARM_TIME end

function Choice:skipIndex() return #self.items + 1 end
function Choice:rerollIndex() return #self.items + 2 end

-- One press on card i: the first picks it, a second press on the same card takes it.
-- (The skip slot works the same way; the reroll slot rerolls at once.)
function Choice:activate(i)
    if not self:ready() then return end
    if i == self:rerollIndex() then self:reroll() return end
    if not (self.items[i] or i == self:skipIndex()) then return end
    self.armedBan = nil
    if self.armed == i then
        if i == self:skipIndex() then self:skip() else self:take(i) end
    else
        self.armed, self.focus = i, i
        Audio.play("ui_confirm", { pitch = 0.9 })
    end
end

function Choice:layout()
    local w, h = lg.getDimensions()
    local u = Theme.u
    local n = #self.items
    local cw = math.floor(math.min(u(240), (w - u(60)) / n - u(16)))
    local ch = math.floor(u(372))
    local gap = u(16)
    local total = n * cw + (n - 1) * gap
    local x0 = math.floor((w - total) / 2)
    local y0 = math.floor((h - ch) / 2 - u(8))
    self.cards = {}
    local chipW, chipH = math.floor(math.min(u(64), cw * 0.3)), math.floor(u(22))
    for i = 1, n do
        local c = { x = x0 + (i - 1) * (cw + gap), y = y0, w = cw, h = ch }
        c.ban = { x = c.x + u(6), y = c.y + u(6), w = chipW, h = chipH }
        c.lock = { x = c.x + cw - u(6) - chipW, y = c.y + u(6), w = chipW, h = chipH }
        self.cards[i] = c
    end
    local bw, bh = math.floor(u(170)), math.floor(u(34))
    local by = y0 + ch + u(58)
    self.rerollRect = { x = math.floor(w / 2 - bw - u(8)), y = by, w = bw, h = bh }
    self.skipRect = { x = math.floor(w / 2 + u(8)), y = by, w = bw, h = bh }
    return self.cards
end

local function inside(r, x, y) return r and x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h end

-- What is under a point: "card" | "ban" | "lock" | "skip" | "reroll", and the card slot.
function Choice:hitAt(mx, my)
    for i, c in ipairs(self.cards or self:layout()) do
        if inside(c, mx, my) then
            if inside(c.ban, mx, my) then return "ban", i end
            if inside(c.lock, mx, my) then return "lock", i end
            return "card", i
        end
    end
    if inside(self.skipRect, mx, my) then return "skip", self:skipIndex() end
    if inside(self.rerollRect, mx, my) then return "reroll", self:rerollIndex() end
end

-- Focus slot under a point (cards, skip, reroll), as before.
function Choice:cardAt(mx, my)
    local _, i = self:hitAt(mx, my)
    return i
end

function Choice:update(dt)
    self.t = self.t + dt
    if self.note then
        self.note.t = self.note.t + dt
        if self.note.t > 2 then self.note = nil end
    end
    if not self:ready() then return end
    local f, n, skipI, rerollI = self.focus, #self.items, self:skipIndex(), self:rerollIndex()
    if self.focus == skipI or self.focus == rerollI then
        if Input.pressed("ui_up") then self.focus = self.lastCard or 1; Audio.play("ui_move")
        elseif Input.pressed("ui_left") or Input.pressed("ui_right") then
            self.focus = self.focus == skipI and rerollI or skipI; Audio.play("ui_move")
        end
    else
        if Input.pressed("ui_left") then self.focus = (self.focus - 2) % n + 1; Audio.play("ui_move") end
        if Input.pressed("ui_right") then self.focus = self.focus % n + 1; Audio.play("ui_move") end
        if Input.pressed("ui_down") then self.lastCard = self.focus; self.focus = skipI; Audio.play("ui_move") end
    end
    if self.focus ~= f then self.armed, self.armedBan = nil, nil end
    local card = self.focus <= n and self.focus or self.lastCard
    if Input.pressed("ui_confirm") then self:activate(self.focus)
    elseif Input.pressed("ui_back") then
        if self.focus <= n then self.lastCard = self.focus end
        self:activate(skipI)
    elseif Input.pressed("choice_reroll") then self:reroll()
    elseif Input.pressed("choice_lock") and card then self:toggleLock(card)
    elseif Input.pressed("choice_ban") and card then self:ban(card)
    end
end

function Choice:mousemoved(x, y)
    local i = self:cardAt(x, y)
    if i and i ~= self.focus and not self.armed and not self.armedBan then
        if self.focus <= #self.items then self.lastCard = self.focus end
        self.focus = i; Audio.play("ui_move")
    end
end

function Choice:mousepressed(x, y, b)
    if b ~= 1 then return end
    local what, i = self:hitAt(x, y)
    if what == "ban" then self:ban(i)
    elseif what == "lock" then self:toggleLock(i)
    elseif what == "reroll" then self:reroll()
    elseif i then self:activate(i)
    else self.armed, self.armedBan = nil, nil end   -- click away to un-pick
end

----------------------------------------------------------------------------------------------
-- Drawing

-- A small labelled button (the BAN / LOCK chips and the bottom row).
local function button(r, text, font, opts)
    local COL = InvState.COL
    local col = opts.color or COL.label
    if opts.lit then
        lg.setColor(col[1] * 0.3, col[2] * 0.3, col[3] * 0.3, 0.95)
    else
        lg.setColor(COL.frameLo[1], COL.frameLo[2], COL.frameLo[3], 0.9)
    end
    lg.rectangle("fill", r.x, r.y, r.w, r.h)
    local a = opts.disabled and 0.35 or 1
    lg.setColor(col[1], col[2], col[3], (opts.lit or opts.hover) and a or a * 0.55)
    lg.rectangle("line", r.x + 0.5, r.y + 0.5, r.w - 1, r.h - 1)
    lg.setFont(font)
    lg.setColor(col[1], col[2], col[3], opts.disabled and 0.35 or ((opts.lit or opts.hover) and 1 or 0.8))
    lg.printf(text, r.x, r.y + math.floor((r.h - font:getHeight()) / 2), r.w, "center")
end

function Choice:draw()
    local w, h = lg.getDimensions()
    local u = Theme.u
    local COL = InvState.COL
    lg.setColor(0.02, 0.015, 0.02, 0.75)
    lg.rectangle("fill", 0, 0, w, h)
    local cards = self:layout()
    lg.setFont(Theme.font(30, "bold"))
    local title = self.opts.boss and "THE QUEEN FELL. CHOOSE A PRIZE"
        or self.opts.endless and ("LEVEL " .. (self.opts.wave or "") .. " SURVIVED")
        or ("WAVE " .. (self.opts.wave or "") .. " CLEARED")

    Theme.printShadow(title, 0, cards[1].y - u(70), COL.label, "center", w)
    lg.setFont(Theme.font(16))
    lg.setColor(COL.dim)
    lg.printf("Pick one item for your bag, or skip them all", 0, cards[1].y - u(34), w, "center")

    local inv = self.world.player.inventory
    local ready = self:ready()
    local mx, my = love.mouse.getPosition()
    local hoverWhat, hoverI = self:hitAt(mx, my)
    local touch = Input.lastDevice == "touch"
    local pad = Input.lastDevice == "gamepad"
    local chipFont = Theme.font(13, "bold")
    for i, item in ipairs(self.items) do
        local c = cards[i]
        local def = item.def
        local rc = InvState.rarityColor(def)
        local focus = i == self.focus
        local lift = focus and math.floor(u(8) * math.min(1, self.t * 6)) or 0
        local x, y = c.x, c.y - lift
        InvState.plate(x, y, c.w, c.h, focus and { 0.2, 0.15, 0.12 } or COL.frame, true)
        lg.setColor(rc)
        lg.rectangle("fill", x + 2, y + 2, c.w - 4, 3)
        if item.locked then
            lg.setColor(LOCK_COL[1], LOCK_COL[2], LOCK_COL[3], 0.9)
            lg.setLineWidth(2)
            lg.rectangle("line", x - 1, y - 1, c.w + 2, c.h + 2)
            lg.setLineWidth(1)
        end
        if focus then
            lg.setColor(rc[1], rc[2], rc[3], 0.8)
            lg.setLineWidth(2)
            lg.rectangle("line", x - 4, y - 4, c.w + 8, c.h + 8)
            lg.setLineWidth(1)
        end
        -- a fresh card (reroll / ban) pops in
        local ft = self.flashT[i] and (self.t - self.flashT[i]) or 1
        if ft < 0.35 then
            lg.setColor(1, 1, 1, 0.35 * (1 - ft / 0.35))
            lg.rectangle("fill", x, y, c.w, c.h)
        end
        -- BAN / LOCK chips
        local ban = { x = c.ban.x, y = c.ban.y - lift, w = c.ban.w, h = c.ban.h }
        local lock = { x = c.lock.x, y = c.lock.y - lift, w = c.lock.w, h = c.lock.h }
        local banLeft = self.run.banishes
        button(ban, self.armedBan == i and "BAN?" or ("BAN " .. banLeft), chipFont,
            { color = BAN_COL, lit = self.armedBan == i, hover = hoverWhat == "ban" and hoverI == i, disabled = banLeft <= 0 })
        button(lock, item.locked and "LOCKED" or "LOCK", chipFont,
            { color = LOCK_COL, lit = item.locked, hover = hoverWhat == "lock" and hoverI == i })
        -- the item drawn on its own little grid, so you can see its shape
        local bw, bh = Inventory.size(item)
        local areaH = u(96)
        local cell = math.floor(math.min(u(52), (c.w - u(40)) / math.max(bw, 1), areaH / math.max(bh, 1)))
        local gx = math.floor(x + (c.w - bw * cell) / 2)
        local gy = math.floor(y + u(34) + (areaH - bh * cell) / 2)
        InvState.shapeCells(item, gx, gy, cell, { rc[1] * 0.3, rc[2] * 0.3, rc[3] * 0.3, 0.9 }, { rc[1], rc[2], rc[3], 0.8 })
        InvState.itemIcon(item, gx + 3, gy + 3, bw * cell - 6, bh * cell - 6)
        local ty = y + u(138)
        lg.setFont(Theme.font(19, "bold"))
        Theme.printShadow(def.name, x, ty, rc, "center", c.w)
        ty = ty + u(26)
        lg.setFont(Theme.font(14))
        lg.setColor(COL.dim)
        lg.printf(Rarities[def.rarity].label .. "  ·  " .. #def.cells .. (#def.cells == 1 and " cell" or " cells"), x, ty, c.w, "center")
        ty = ty + u(24)
        -- tags: lit ones are shared with items already in your bag
        local th = Choices.drawTags(def, self.tags, x + u(8), ty, c.w - u(16), Theme.font(13), u)
        if th > 0 then ty = ty + th + u(8) end
        -- what it does to your stats, as real numbers
        lg.setFont(Theme.font(14))
        for _, l in ipairs(self.previews[i] or {}) do
            lg.setColor(l.good == nil and Theme.colors.text or l.good and Theme.colors.good or Theme.colors.bad)
            lg.printf(l.text, x + u(8), ty, c.w - u(16), "center")
            ty = ty + u(18)
        end
        local effect = def.effect or (#def.procs > 0 and #(self.previews[i] or {}) == 0 and def.description)
        if effect then
            -- fit the words above the card's footer: smaller text, then cut with "..."
            local room = y + c.h - u(30) - (ty + u(4))
            local ef = Theme.font(14)
            local _, lines = ef:getWrap(effect, c.w - u(24))
            if #lines * ef:getHeight() > room then
                ef = Theme.font(13)
                _, lines = ef:getWrap(effect, c.w - u(20))
            end
            local fit = math.max(1, math.floor(room / ef:getHeight()))
            if #lines > fit then
                lines[fit] = lines[fit]:gsub("%s*%S*$", "") .. "…"
                for k = #lines, fit + 1, -1 do lines[k] = nil end
            end
            lg.setFont(ef)
            lg.setColor(Theme.colors.text)
            for k, l in ipairs(lines) do
                lg.printf(l, x + u(10), ty + u(4) + (k - 1) * ef:getHeight(), c.w - u(20), "center")
            end
        end
        if self.armed == i or self.armedBan == i then
            lg.setFont(Theme.font(16, "bold"))
            local pulse = 0.75 + 0.25 * math.sin(self.t * 8)
            local text, col
            if self.armedBan == i then
                text, col = pad and "PRESS Y AGAIN TO BAN" or touch and "TAP BAN AGAIN TO BAN" or "PRESS BAN AGAIN TO BAN", BAN_COL
            else
                text, col = pad and "PRESS A AGAIN TO TAKE" or touch and "TAP AGAIN TO TAKE" or "CLICK AGAIN TO TAKE", rc
            end
            Theme.printShadow(text, x - u(20), y + c.h + u(10), { col[1], col[2], col[3], pulse }, "center", c.w + u(40))
        end
        if not ready then
            lg.setColor(0.02, 0.015, 0.02, 0.55 * (1 - self.t / Choice.ARM_TIME))
            lg.rectangle("fill", x, y, c.w, c.h)
        end
        local have = inv:count(item.id)
        if have > 0 or item.locked then
            lg.setFont(Theme.font(13))
            lg.setColor(item.locked and LOCK_COL or COL.label)
            local s = have > 0 and ("You have " .. have .. " (stacks)") or ""
            if item.locked then s = s .. (have > 0 and "  ·  " or "") .. "Comes back next time" end
            lg.printf(s, x, y + c.h - u(24), c.w, "center")
        end
    end

    -- REROLL and SKIP under the cards
    local bf = Theme.font(16, "bold")
    local rr, sr = self.rerollRect, self.skipRect
    local rf, sf = self.focus == self:rerollIndex(), self.focus == self:skipIndex()
    local key = function(k, p) return pad and p or touch and nil or k end
    local rk = key("R", "X")
    button(rr, "REROLL" .. (rk and (" (" .. rk .. ")") or "") .. "  " .. self.run.rerolls, bf,
        { color = { 0.55, 0.85, 1 }, lit = rf, hover = hoverWhat == "reroll", disabled = self.run.rerolls <= 0 })
    local skipKey = key("Esc", "B")
    button(sr, skipKey and ("SKIP (" .. skipKey .. ")") or "SKIP", bf,
        { color = COL.label, lit = sf, hover = hoverWhat == "skip" })
    if self.armed == self:skipIndex() then
        lg.setFont(Theme.font(14, "bold"))
        local pulse = 0.75 + 0.25 * math.sin(self.t * 8)
        local again = touch and "TAP AGAIN TO SKIP ALL" or "PRESS AGAIN TO SKIP ALL"
        Theme.printShadow(again, 0, sr.y + sr.h + u(8), { 1, 0.75, 0.6, pulse }, "center", w)
    elseif self.note then
        lg.setFont(Theme.font(14, "bold"))
        Theme.printShadow(self.note.text, 0, sr.y + sr.h + u(8), { 1, 0.85, 0.6, math.min(1, 2 - self.note.t) }, "center", w)
    end
    if not ready then
        lg.setColor(0.02, 0.015, 0.02, 0.55 * (1 - self.t / Choice.ARM_TIME))
        lg.rectangle("fill", rr.x, rr.y, sr.x + sr.w - rr.x, rr.h)
    end
    lg.setFont(Theme.font(13))
    lg.setColor(COL.dim)
    lg.printf(pad and "Left / right to look, A to pick, A again to take  ·  RB lock  ·  Y ban"
        or touch and "Tap an item to pick it, tap it again to take it"
        or "Click an item to pick it, click it again to take it  ·  L lock  ·  X ban",
        0, cards[1].y + cards[1].h + u(34), w, "center")
    lg.setColor(1, 1, 1, 1)
end

return Choice
