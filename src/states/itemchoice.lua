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
--
-- SHOP tab (Tab / H / pad LB, or the tabs above the cards; src/game/economy.lua): 2 items and
-- a stat boost for nectar, two presses to buy, LOCK carries an offer to the next shop, a reroll
-- that costs more each time. Savings interest is paid as the screen opens. Taking (or skipping)
-- the free pick closes the screen, unless the shop still has something you can afford: then it
-- moves to the SHOP tab and DONE closes it.
local State = require("src.core.state")
local Input = require("src.core.input")
local Audio = require("src.core.audio")
local Theme = require("src.ui.theme")
local Rarities = require("src.config.rarities")
local Inventory = require("src.game.inventory")
local Choices = require("src.game.choices")
local InvState = require("src.states.inventory")
local Economy = require("src.game.economy")

local Choice = { transparent = true }
Choice.__index = Choice

local lg = love.graphics

Choice.ARM_TIME = 0.8     -- seconds before the cards accept any input
local LOCK_COL = { 1, 0.82, 0.35 }
local BAN_COL = { 1, 0.45, 0.4 }
local NECTAR_COL = { 1, 0.8, 0.3 }
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
    self.tab = "pick"
    -- the nectar shop (off in modes with `shop = false`, and in the sandbox's test choices)
    self.hasShop = Economy.enabled(game.world) and not opts.noShop
    if self.hasShop then
        self.interest = Economy.payInterest(game.world)
        self.shop = Economy.shop(game.world, self:cardIds())
    end
    self:refresh()
    self.focus = 1
    self.armed = nil          -- the card (or skip) picked once, waiting for its confirm
    self.armedBan = nil       -- the card whose BAN was pressed once
    self.flashT = {}          -- [slot] = time a card was just dealt (reroll / ban), for a pop
    return self
end

-- Item ids on the free pick's cards (the shop doesn't offer them too).
function Choice:cardIds()
    local ids = {}
    for _, it in ipairs(self.items) do ids[it.id] = true end
    return ids
end

-- What the cards show on this tab: free pick items, or shop offers ({ def, item?, price... }).
function Choice:entries()
    if self.tab == "shop" then return self.shop.offers end
    return self.items
end

-- Stat previews per card (after a reroll or ban too).
function Choice:refresh()
    local stats = self.world.player.stats
    self.previews = {}
    for i, it in ipairs(self:entries()) do self.previews[i] = Choices.preview(stats, it.def) end
    self.cards = nil
end

-- Switch between the free pick and the shop.
function Choice:setTab(tab)
    if tab == self.tab or (tab == "shop" and not self.hasShop) or (tab == "pick" and self.picked) then return end
    self.tab = tab
    self.armed, self.armedBan, self.focus = nil, nil, 1
    self.flashT = {}
    self:refresh()
    Audio.play("ui_move", { pitch = 1.2 })
end

-- Close the screen for good (the shop's DONE, or a pick with nothing left to buy).
function Choice:close()
    if self.hasShop then Economy.remember(self.world) end
    if State.top() == self then State.pop() end
end

-- After the free pick: stay on the shop if there is still something to buy, else close.
function Choice:afterPick()
    self.picked = true
    if self.hasShop and Economy.anyAffordable(self.world) then
        self.tab = "pick"
        self:setTab("shop")
        return true
    end
    self:close()
    return false
end

function Choice:enter()
    love.mouse.setVisible(true)
    Audio.play("ui_confirm", { pitch = 1.2 })
end

-- Put an item in the bag (the free pick, or one bought). No room: the bag opens holding it,
-- on top of this screen if it stays open.
function Choice:stowItem(item)
    local inv = self.world.player.inventory
    if inv:give(item) then
        Audio.play("equip")
        self.world:floatText(self.world.player.x, self.world.player.y, item.def.name, InvState.rarityColor(item.def), true)
    else
        -- no room: open the bag holding it, so you can puzzle it in or eat something
        State.push(InvState.new(self.game, { held = item }))
    end
end

function Choice:take(i)
    local item = self.items[i]
    if not item then return end
    item.locked = nil
    Choices.remember(self.world, self.items, item)
    self.world.events:emit("item_taken", item)
    self:afterPick()
    self:stowItem(item)
end

-- Pass on every card: nothing goes in the bag (locked cards still come back next time).
function Choice:skip()
    Choices.remember(self.world, self.items, nil)
    self:afterPick()
    self.world.events:emit("item_skipped")
    Audio.play("ui_back")
    self.world:floatText(self.world.player.x, self.world.player.y, "Skipped", { 0.75, 0.7, 0.65 }, true)
end

-- The shop's reroll: new offers for every one that isn't locked or sold, for nectar.
function Choice:rerollShop()
    self.armed = nil
    local old = {}
    for i, o in ipairs(self.shop.offers) do old[i] = o end
    local ok, why = Economy.rerollShop(self.world, self:cardIds())
    if not ok then
        Audio.play("ui_back")
        self.note = { text = why == "locked" and "Nothing left to reroll" or "Not enough nectar", t = 0 }
        return false
    end
    for i, o in ipairs(self.shop.offers) do if o ~= old[i] then self.flashT[i] = self.t end end
    self:refresh()
    Audio.play("ui_confirm", { pitch = 1.4 })
    return true
end

-- Buy shop offer i (an item goes in the bag, a boost counts at once).
function Choice:buy(i)
    local o = self.shop.offers[i]
    local ok, item = Economy.buy(self.world, i)
    if not ok then
        Audio.play("ui_back")
        self.note = { text = item == "sold" and "Already bought" or "Not enough nectar", t = 0 }
        return false
    end
    self.armed = nil
    Audio.play("pickup", { pitch = 1.2 })
    if item then
        self:stowItem(item)
    else
        Audio.play("equip", { pitch = 1.3 })
        self.world:floatText(self.world.player.x, self.world.player.y, o.text, NECTAR_COL, true)
    end
    self.tags = Choices.bagTags(self.world.player.inventory)
    self:refresh()
    return true
end

-- New cards for every card that isn't locked.
function Choice:reroll()
    if not self:ready() then return false end
    if self.tab == "shop" then return self:rerollShop() end
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
    if not self:ready() or not it or it.sold then return end
    it.locked = not it.locked or nil
    self.armedBan = nil
    Audio.play(it.locked and "equip" or "ui_move", { pitch = it.locked and 1.3 or 1 })
end

-- BAN on card i: the first press arms it, a second press bans the item for the run.
function Choice:ban(i)
    if self.tab == "shop" or not self:ready() or not self.items[i] then return false end
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

-- The shop's BACK (to the free pick) or DONE (after the pick: close).
function Choice:shopBack()
    if self.picked then self:close() else self:setTab("pick") end
end

-- One press on card i: the first picks it, a second press on the same card takes it.
-- (The skip slot works the same way; the reroll slot rerolls at once.)
function Choice:activate(i)
    if not self:ready() then return end
    if i == self:rerollIndex() then self:reroll() return end
    if self.tab == "shop" then
        if i == self:skipIndex() then self:shopBack() return end
        local o = self.shop.offers[i]
        if not o then return end
        if o.sold then Audio.play("ui_back") return end
        if self.armed == i then self:buy(i)
        elseif not Economy.canAfford(self.world, o.price) then
            Audio.play("ui_back")
            self.note = { text = "Not enough nectar", t = 0 }
        else
            self.armed, self.focus = i, i
            Audio.play("ui_confirm", { pitch = 0.9 })
        end
        return
    end
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
    -- FREE PICK / SHOP tabs, top right of the cards
    self.tabRects = nil
    if self.hasShop then
        local tf = Theme.font(15, "bold")
        local th = math.floor(u(28))
        local w1 = tf:getWidth("FREE PICK") + u(24)
        local w2 = tf:getWidth("SHOP  999 nectar") + u(24)
        local tx = math.floor(w / 2 - (w1 + w2 + u(8)) / 2)
        local ty = math.floor(y0 - u(70) - th - u(10))
        if ty < u(4) then ty = math.floor(u(4)) end
        self.tabRects = { pick = { x = tx, y = ty, w = w1, h = th }, shop = { x = tx + w1 + u(8), y = ty, w = w2, h = th } }
    end
    return self.cards
end

local function inside(r, x, y) return r and x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h end

-- What is under a point: "card" | "ban" | "lock" | "skip" | "reroll" | "tab", and the card
-- slot (or the tab's name).
function Choice:hitAt(mx, my)
    local cards = self.cards or self:layout()
    for name, r in pairs(self.tabRects or {}) do
        if inside(r, mx, my) then return "tab", name end
    end
    for i, c in ipairs(cards) do
        if inside(c, mx, my) then
            if inside(c.ban, mx, my) and self.tab ~= "shop" then return "ban", i end
            if inside(c.lock, mx, my) then return "lock", i end
            return "card", i
        end
    end
    if inside(self.skipRect, mx, my) then return "skip", self:skipIndex() end
    if inside(self.rerollRect, mx, my) then return "reroll", self:rerollIndex() end
end

-- Focus slot under a point (cards, skip, reroll), as before.
function Choice:cardAt(mx, my)
    local what, i = self:hitAt(mx, my)
    if what == "tab" then return nil end
    return i
end

function Choice:update(dt)
    self.t = self.t + dt
    if self.note then
        self.note.t = self.note.t + dt
        if self.note.t > 2 then self.note = nil end
    end
    if not self:ready() then return end
    if Input.pressed("choice_shop") then self:setTab(self.tab == "shop" and "pick" or "shop") end
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
        if self.tab == "shop" then self:shopBack() else self:activate(skipI) end
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
    if what == "tab" then self:setTab(i)
    elseif what == "ban" then self:ban(i)
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
    local shopTab = self.tab == "shop"
    local nectar = self.hasShop and Economy.nectar(self.world) or 0
    lg.setFont(Theme.font(30, "bold"))
    local title = shopTab and "NECTAR SHOP"
        or self.opts.boss and "THE QUEEN FELL. CHOOSE A PRIZE"
        or self.opts.endless and ("LEVEL " .. (self.opts.wave or "") .. " SURVIVED")
        or ("WAVE " .. (self.opts.wave or "") .. " CLEARED")

    local cardsY = cards[1] and cards[1].y or h / 2
    Theme.printShadow(title, 0, cardsY - u(70), shopTab and NECTAR_COL or COL.label, "center", w)
    lg.setFont(Theme.font(16))
    lg.setColor(COL.dim)
    local sub = "Pick one item for your bag, or skip them all"
    if shopTab then
        sub = ("%d nectar  ·  savings earn +%d at the next wave clear (max %d)"):format(nectar,
            Economy.interestPreview(self.world), Economy.interestCap(self.world))
        if self.picked then sub = sub .. "  ·  free pick done" end
    elseif self.hasShop and (self.interest or 0) > 0 then
        sub = sub .. ("  ·  +%d nectar interest"):format(self.interest)
    end
    lg.printf(sub, 0, cardsY - u(34), w, "center")
    -- FREE PICK / SHOP tabs
    if self.tabRects then
        local tf = Theme.font(15, "bold")
        local mx0, my0 = love.mouse.getPosition()
        local pr, sr0 = self.tabRects.pick, self.tabRects.shop
        local afford = Economy.anyAffordable(self.world)
        button(pr, self.picked and "PICK DONE" or "FREE PICK", tf,
            { color = COL.label, lit = not shopTab, hover = inside(pr, mx0, my0), disabled = self.picked })
        button(sr0, "SHOP  " .. nectar .. " nectar", tf,
            { color = NECTAR_COL, lit = shopTab, hover = inside(sr0, mx0, my0) or (afford and not shopTab and math.sin(self.t * 5) > 0.3) })
    end

    local inv = self.world.player.inventory
    local ready = self:ready()
    local mx, my = love.mouse.getPosition()
    local hoverWhat, hoverI = self:hitAt(mx, my)
    local touch = Input.lastDevice == "touch"
    local pad = Input.lastDevice == "gamepad"
    local chipFont = Theme.font(13, "bold")
    for i, entry in ipairs(self:entries()) do
        local c = cards[i]
        local item = shopTab and entry.item or (not shopTab and entry) or nil
        local offer = shopTab and entry or nil
        local def = entry.def
        local rc = InvState.rarityColor(def)
        if offer and offer.kind == "boost" then rc = NECTAR_COL end
        local cursed = def.curse ~= nil or def.rarity == "cursed"
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
            local banLeft = self.run.banishes
            button(ban, self.armedBan == i and "BAN?" or ("BAN " .. banLeft), chipFont,
                { color = BAN_COL, lit = self.armedBan == i, hover = hoverWhat == "ban" and hoverI == i, disabled = banLeft <= 0 })
        end
        if not (offer and offer.sold) then
            button(lock, entry.locked and "LOCKED" or "LOCK", chipFont,
                { color = LOCK_COL, lit = entry.locked, hover = hoverWhat == "lock" and hoverI == i })
        end
        local areaH = u(96)
        if item then
            -- the item drawn on its own little grid, so you can see its shape
            local bw, bh = Inventory.size(item)
            local cell = math.floor(math.min(u(52), (c.w - u(40)) / math.max(bw, 1), areaH / math.max(bh, 1)))
            local gx = math.floor(x + (c.w - bw * cell) / 2)
            local gy = math.floor(y + u(34) + (areaH - bh * cell) / 2)
            InvState.shapeCells(item, gx, gy, cell, { rc[1] * 0.3, rc[2] * 0.3, rc[3] * 0.3, 0.9 }, { rc[1], rc[2], rc[3], 0.8 })
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
        lg.printf(meta, x, ty, c.w, "center")
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
            lg.setColor(0.02, 0.015, 0.02, 0.55 * (1 - self.t / Choice.ARM_TIME))
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

    -- REROLL and SKIP under the cards
    local bf = Theme.font(16, "bold")
    local rr, sr = self.rerollRect, self.skipRect
    local rf, sf = self.focus == self:rerollIndex(), self.focus == self:skipIndex()
    local key = function(k, p) return pad and p or touch and nil or k end
    local rk = key("R", "X")
    local skipKey = key("Esc", "B")
    if shopTab then
        local price = Economy.rerollPrice(self.world)
        button(rr, "REROLL" .. (rk and (" (" .. rk .. ")") or "") .. "  " .. price, bf,
            { color = NECTAR_COL, lit = rf, hover = hoverWhat == "reroll", disabled = nectar < price })
        local word = self.picked and "DONE" or "BACK"
        button(sr, skipKey and (word .. " (" .. skipKey .. ")") or word, bf,
            { color = COL.label, lit = sf, hover = hoverWhat == "skip" })
    else
        button(rr, "REROLL" .. (rk and (" (" .. rk .. ")") or "") .. "  " .. self.run.rerolls, bf,
            { color = { 0.55, 0.85, 1 }, lit = rf, hover = hoverWhat == "reroll", disabled = self.run.rerolls <= 0 })
        button(sr, skipKey and ("SKIP (" .. skipKey .. ")") or "SKIP", bf,
            { color = COL.label, lit = sf, hover = hoverWhat == "skip" })
    end
    if self.armed == self:skipIndex() and not shopTab then
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
    local shopHint = self.hasShop and (pad and "  ·  {pad:leftshoulder} shop" or touch and "" or "  ·  {key:Tab} shop") or ""
    local hint
    if shopTab then
        hint = pad and "{pad:a} to pick, {pad:a} again to buy  ·  {pad:rightshoulder} lock  ·  {pad:leftshoulder} free pick"
            or touch and "Tap an offer to pick it, tap it again to buy it"
            or "Click an offer to pick it, click it again to buy it  ·  {key:L} lock  ·  {key:Tab} free pick"
    else
        hint = (pad and "{pad:dpad} to look, {pad:a} to pick, {pad:a} again to take  ·  {pad:rightshoulder} lock  ·  {pad:y} ban"
            or touch and "Tap an item to pick it, tap it again to take it"
            or "Click an item to pick it, click it again to take it  ·  {key:L} lock  ·  {key:X} ban") .. shopHint
    end
    Theme.rich(hint, 0, cardsY + (cards[1] and cards[1].h or 0) + u(34), w, "center", COL.dim)
    lg.setColor(1, 1, 1, 1)
end

return Choice
