-- Item choice: after every wave, pick one of three items (more if you killed a queen; a
-- boss wave guarantees something rare). It is the last step of the wave's reward bloom
-- (src/game/rewardflow.lua): the strip at the top shows the level-ups before it. The pick flies
-- out of the bloom into the bag; if it doesn't fit, the inventory opens holding it so you can
-- make room (or eat it). The game is paused while this is open. (The nectar shop is a tab of
-- the inventory window now: src/states/shop.lua.)
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
local CatGlyph = require("src.ui.catglyph")

local Choice = { transparent = true }
Choice.__index = Choice

local lg = love.graphics

Choice.ARM_TIME = 0.8     -- seconds before the cards accept any input
local LOCK_COL = { 1, 0.82, 0.35 }
local NECTAR_COL = { 1, 0.8, 0.3 }
local SEALED_COL = { 0.93, 0.86, 0.66 }   -- a sealed cocoon card (Choices.seal)
Choice.NECTAR_COL = NECTAR_COL
local BAN_COL = { 1, 0.45, 0.4 }
local CURSE_COL = { 0.8, 0.5, 1 }

-- opts: count (cards), boss (true after a boss wave: one is rare or better), wave
function Choice.new(game, opts)
    local self = setmetatable({ game = game, world = game.world, t = 0, opts = opts }, Choice)
    -- minRarity: a hard route's prize (src/game/routes.lua); a queen's wave: rare at least
    local minR = opts.minRarity
    if opts.boss and (not minR or require("src.config.rarities")[minR].order < 3) then minR = "rare" end
    self.minRarity = minR
    self.run = Choices.state(game.world)
    -- curses and blessings in the bag change how many cards there are (Fool's Gold Scarab...)
    local count = opts.count or 3
    local delta = game.world.player.inventory:sum("cardsDelta")
    if delta ~= 0 then count = math.max(2, math.min(6, count + delta)) end
    self.items = Choices.deal(game.world, count, self.minRarity)
    self.tags = Choices.bagTags(game.world.player.inventory)
    self:refresh()
    self.focus = 1
    self.armed = nil          -- the card (or skip) picked once, waiting for its confirm
    self.armedBan = nil       -- the card whose BAN was pressed once
    self.flashT = {}          -- [slot] = time a card was just dealt (reroll / ban), for a pop
    return self
end

-- What the cards show (one entry per card).
function Choice:entries() return self.items end

-- Stat previews per card (after a reroll or ban too).
function Choice:refresh()
    local stats = self.world.player.stats
    self.previews = {}
    for i, it in ipairs(self:entries()) do self.previews[i] = Choices.preview(stats, it.def) end
    self.cards = nil
end

-- Close the screen (the pick was taken or skipped): the bloom's steps are done.
function Choice:close()
    if self.world.rewardFlow then self.world.rewardFlow:finish() end
    if State.top() == self then State.pop() end
end

function Choice:enter()
    love.mouse.setVisible(true)
    Audio.play("ui_confirm", { pitch = 1.2 })
end

-- Put the item in the bag: it flies out of the bloom into your bug, and a card on the left
-- of the screen says what it does. No room: the bag opens holding it.
function Choice:stowItem(item)
    local inv = self.world.player.inventory
    if inv:give(item) then
        local flow = self.world.rewardFlow
        if flow then
            flow:gain({ title = "NEW ITEM", name = item.def.name, item = item, color = InvState.rarityColor(item.def),
                line = flow.itemLine(item.def), fromBloom = true })
        else
            Audio.play("equip")
        end
    else
        -- no room: open the bag holding it, so you can puzzle it in or eat something
        State.push(InvState.new(self.game, { held = item }))
    end
end

function Choice:take(i)
    local item = self.items[i]
    if not item then return end
    item.locked, item.sealed = nil, nil
    Choices.remember(self.world, self.items, item)
    self.world.events:emit("item_taken", item)
    self:close()
    self:stowItem(item)
end

-- Pass on every card: nothing goes in the bag (locked cards still come back next time).
function Choice:skip()
    Choices.remember(self.world, self.items, nil)
    self:close()
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
    local it = self:entries()[i]
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

function Choice:skipIndex() return #self:entries() + 1 end
function Choice:rerollIndex() return #self:entries() + 2 end

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
    local n = math.max(1, #self:entries())
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
    local cards = self.cards or self:layout()
    for i, c in ipairs(cards) do
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
    local f, n, skipI, rerollI = self.focus, #self:entries(), self:skipIndex(), self:rerollIndex()
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
        if self.focus <= #self:entries() then self.lastCard = self.focus end
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

-- A sealed card: a silk cocoon and a promise, no name, shape or stats.

function Choice.drawSealed(self, i, x, y, c, areaH, rc, ready, ctx, pad, touch)
    local u = Theme.u
    local cx, cy = x + c.w / 2, y + u(34) + areaH / 2
    local wob = math.sin(self.t * 2.4 + i) * u(2)
    lg.setColor(0.25, 0.22, 0.18, 0.9)
    lg.ellipse("fill", cx, cy + u(4), u(26), u(40))
    lg.setColor(0.86, 0.8, 0.66, 1)
    lg.ellipse("fill", cx + wob * 0.3, cy, u(24), u(38))
    lg.setColor(0.7, 0.62, 0.48, 1)
    for k = -3, 3 do lg.line(cx - u(22), cy + k * u(9), cx + u(22), cy + k * u(9) + u(4)) end
    lg.setColor(1, 0.95, 0.75, 0.35 + 0.2 * math.sin(self.t * 3))
    lg.ellipse("line", cx, cy, u(28), u(42))
    local ty = y + u(138)
    lg.setFont(Theme.font(19, "bold"))
    Theme.printShadow("Sealed Cocoon", x, ty, rc, "center", c.w)
    lg.setFont(Theme.font(14))
    lg.setColor(InvState.COL.dim)
    lg.printf("Rare or better  ·  ? cells", x, ty + u(26), c.w, "center")
    lg.setColor(Theme.colors.text)
    lg.printf("Something good is wrapped up inside. You'll only see what once it's yours.", x + u(10), ty + u(56), c.w - u(20), "center")
    if self.armed == i then
        lg.setFont(Theme.font(16, "bold"))
        local text = pad and "PRESS {pad:a} AGAIN TO TAKE" or touch and "TAP AGAIN TO TAKE" or "CLICK AGAIN TO TAKE"
        Theme.rich(text, x - u(20), y + c.h + u(10), c.w + u(40), "center", rc, 0.75 + 0.25 * math.sin(self.t * 8))
    end
    if not ready then
        lg.setColor(0.02, 0.015, 0.02, 0.55 * (1 - self.t / (ctx.armTime or Choice.ARM_TIME)))
        lg.rectangle("fill", x, y, c.w, c.h)
    end
end

-- One card: an item (the free pick) or a shop offer (src/states/shop.lua draws its stock with
-- this too). self is the screen: focus, t, armed, armedBan, flashT, previews, tags, world, run
-- (bans; nil in the shop), ready(). c: the card's rect with .ban / .lock chips.
-- ctx: { shop = true for offers, nectar, hoverWhat, hoverI, armTime }
function Choice.drawCard(self, i, entry, c, ctx)
    local u = Theme.u
    local COL = InvState.COL
    local inv = self.world.player.inventory
    local ready = self:ready()
    local hoverWhat, hoverI = ctx.hoverWhat, ctx.hoverI
    local touch = Input.lastDevice == "touch"
    local pad = Input.lastDevice == "gamepad"
    local chipFont = Theme.font(13, "bold")
    local nectar = ctx.nectar or 0
    local offer = ctx.shop and entry or nil
    local item = offer and entry.item or (not offer and entry) or nil
    local def = entry.def
    local rc = InvState.rarityColor(def)
    if offer and offer.kind == "boost" then rc = NECTAR_COL end
    local sealed = entry.sealed and not offer        -- a sealed cocoon (Choices.seal): nothing shows
    if sealed then rc = SEALED_COL end
    local cursed = not sealed and (def.curse ~= nil or def.rarity == "cursed")
    local focus = i == self.focus
    local lift = focus and math.floor(u(8) * math.min(1, self.t * 6)) or 0
    local x, y = c.x, c.y - lift
    InvState.plate(x, y, c.w, c.h, focus and { 0.2, 0.15, 0.12 } or COL.frame, true)
    lg.setColor(rc)
    lg.rectangle("fill", x + 2, y + 2, c.w - 4, 3)
    if cursed then
        lg.setColor(CURSE_COL[1], CURSE_COL[2], CURSE_COL[3], 0.5 + 0.2 * math.sin(self.t * 3))
        lg.rectangle("line", x + 3.5, y + 3.5, c.w - 7, c.h - 7)
    end
    if entry.locked then
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
    if offer then
        if offer.sale and not offer.sold then button(ban, "SALE", chipFont, { color = NECTAR_COL, lit = true }) end
    else
        local banLeft = self.run and self.run.banishes or 0
        button(ban, self.armedBan == i and "BAN?" or ("BAN " .. banLeft), chipFont,
            { color = BAN_COL, lit = self.armedBan == i, hover = hoverWhat == "ban" and hoverI == i, disabled = banLeft <= 0 })
    end
    if not (offer and offer.sold) then
        button(lock, entry.locked and "LOCKED" or "LOCK", chipFont,
            { color = LOCK_COL, lit = entry.locked, hover = hoverWhat == "lock" and hoverI == i })
    end
    local areaH = u(96)
    if sealed then return Choice.drawSealed(self, i, x, y, c, areaH, rc, ready, ctx, pad, touch) end
    if item then
        -- the item drawn on its own little grid, so you can see its shape
        local bw, bh = Inventory.size(item)
        local cell = math.floor(math.min(u(72), (c.w - u(40)) / math.max(bw, 1), areaH / math.max(bh, 1)))
        local gx = math.floor(x + (c.w - bw * cell) / 2)
        local gy = math.floor(y + u(34) + (areaH - bh * cell) / 2)
        local kc = InvState.catColor(def)
        InvState.shapeCells(item, gx, gy, cell, { kc[1] * 0.26, kc[2] * 0.26, kc[3] * 0.26, 0.9 }, { rc[1], rc[2], rc[3], 0.8 })
        InvState.itemIcon(item, gx + 3, gy + 3, bw * cell - 6, bh * cell - 6)
    else
        -- a stat boost: the amount, big
        local bf0 = Theme.font(22, "bold")
        local _, bl = bf0:getWrap(offer.text, c.w - u(16))
        lg.setFont(bf0)
        Theme.printShadow(offer.text, x + u(8), math.floor(y + u(34) + (areaH - #bl * bf0:getHeight()) / 2), rc, "center", c.w - u(16))
    end
    local ty = y + u(138)
    lg.setFont(Theme.font(19, "bold"))
    Theme.printShadow(def.name, x, ty, rc, "center", c.w)
    ty = ty + u(26)
    lg.setFont(Theme.font(14))
    lg.setColor(cursed and CURSE_COL or COL.dim)
    local meta = item and (Rarities[def.rarity].label .. "  ·  " .. #def.cells .. (#def.cells == 1 and " cell" or " cells"))
        or "Stat boost  ·  no bag space"
    if item then
        -- what it is for (its category chip), then rarity and size, centred as one line
        local f = lg.getFont()
        local ch = f:getHeight() + u(2)
        local cw = CatGlyph.chip(def.category, 0, 0, ch, f, 1, true)
        local total = cw + u(8) + f:getWidth(meta)
        local lx = math.floor(x + (c.w - total) / 2)
        CatGlyph.chip(def.category, lx, ty - u(1), ch, f)
        lg.setColor(cursed and CURSE_COL or COL.dim)
        lg.print(meta, lx + cw + u(8), ty)
    else
        lg.printf(meta, x, ty, c.w, "center")
    end
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
    local bottom = y + c.h - u(30)
    if def.curse then
        -- the curse's cost, in purple, just above the footer
        local cf = Theme.font(14, "bold")
        local _, cl = cf:getWrap("Curse: " .. def.curse, c.w - u(20))
        bottom = bottom - #cl * cf:getHeight()
        lg.setFont(cf)
        lg.setColor(CURSE_COL)
        for k, l in ipairs(cl) do lg.printf(l, x + u(10), bottom + (k - 1) * cf:getHeight(), c.w - u(20), "center") end
        bottom = bottom - u(4)
    end
    if effect then
        -- fit the words above the card's footer: smaller text, then cut with "..."
        local room = bottom - (ty + u(4))
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
            text, col = pad and "PRESS {pad:y} AGAIN TO BAN" or touch and "TAP BAN AGAIN TO BAN" or "PRESS BAN AGAIN TO BAN", BAN_COL
        elseif offer then
            text, col = pad and "PRESS {pad:a} AGAIN TO BUY" or touch and "TAP AGAIN TO BUY" or "CLICK AGAIN TO BUY", NECTAR_COL
        else
            text, col = pad and "PRESS {pad:a} AGAIN TO TAKE" or touch and "TAP AGAIN TO TAKE" or "CLICK AGAIN TO TAKE", rc
        end
        Theme.rich(text, x - u(20), y + c.h + u(10), c.w + u(40), "center", col, pulse)
    end
    if not ready then
        lg.setColor(0.02, 0.015, 0.02, 0.55 * (1 - self.t / (ctx.armTime or Choice.ARM_TIME)))
        lg.rectangle("fill", x, y, c.w, c.h)
    end
    if offer then
        -- price (or SOLD) in the footer
        lg.setFont(Theme.font(15, "bold"))
        if offer.sold then
            lg.setColor(0.02, 0.015, 0.02, 0.6)
            lg.rectangle("fill", x, y, c.w, c.h)
            Theme.printShadow("SOLD", x, y + c.h / 2 - u(12), COL.label, "center", c.w)
        else
            local ok = nectar >= offer.price
            lg.setColor(ok and NECTAR_COL or Theme.colors.bad)
            local have = item and inv:count(item.id) or 0
            lg.printf((offer.sale and "SALE  " or "") .. offer.price .. " nectar" .. (have > 0 and ("  ·  have " .. have) or ""),
                x, y + c.h - u(26), c.w, "center")
        end
    end
    local have = (not offer) and inv:count(item.id) or 0
    if not offer and (have > 0 or item.locked) then
        lg.setFont(Theme.font(13))
        lg.setColor(item.locked and LOCK_COL or COL.label)
        local s = have > 0 and ("You have " .. have .. " (stacks)") or ""
        if item.locked then s = s .. (have > 0 and "  ·  " or "") .. "Comes back next time" end
        lg.printf(s, x, y + c.h - u(24), c.w, "center")
    end
end

Choice.button, Choice.inside = button, inside

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

    local cardsY = cards[1] and cards[1].y or h / 2
    Theme.printShadow(title, 0, cardsY - u(70), COL.label, "center", w)
    -- the wave's rewards, step by step (src/game/rewardflow.lua)
    require("src.game.rewardflow").drawSteps(self.world, "item", math.max(u(8), cardsY - u(110)))
    lg.setFont(Theme.font(16))
    lg.setColor(COL.dim)
    lg.printf("Pick one item for your bag, or skip them all", 0, cardsY - u(34), w, "center")

    local ready = self:ready()
    local mx, my = love.mouse.getPosition()
    local hoverWhat, hoverI = self:hitAt(mx, my)
    local touch = Input.lastDevice == "touch"
    local pad = Input.lastDevice == "gamepad"
    local ctx = { hoverWhat = hoverWhat, hoverI = hoverI }
    for i, entry in ipairs(self:entries()) do Choice.drawCard(self, i, entry, cards[i], ctx) end

    -- REROLL and SKIP under the cards
    local bf = Theme.font(16, "bold")
    local rr, sr = self.rerollRect, self.skipRect
    local rf, sf = self.focus == self:rerollIndex(), self.focus == self:skipIndex()
    local key = function(k, p) return pad and p or touch and nil or k end
    local rk = key("R", "X")
    local skipKey = key("Esc", "B")
    button(rr, "REROLL" .. (rk and (" (" .. rk .. ")") or "") .. "  " .. self.run.rerolls, bf,
        { color = { 0.55, 0.85, 1 }, lit = rf, hover = hoverWhat == "reroll", disabled = self.run.rerolls <= 0 })
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
    local hint = pad and "{pad:dpad} to look, {pad:a} to pick, {pad:a} again to take  ·  {pad:rightshoulder} lock  ·  {pad:y} ban"
        or touch and "Tap an item to pick it, tap it again to take it"
        or "Click an item to pick it, click it again to take it  ·  {key:L} lock  ·  {key:X} ban"
    Theme.rich(hint, 0, cardsY + (cards[1] and cards[1].h or 0) + u(34), w, "center", COL.dim)
    lg.setColor(1, 1, 1, 1)
end

return Choice
