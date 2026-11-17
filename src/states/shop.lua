-- The nectar shop: the SHOP tab of the inventory window (src/states/bagtabs.lua). Open it any
-- time with TAB (pad Y, touch BAG), then E / RB or a click on the tab; the game is paused while
-- it is open. The stock (3 items and a stat boost by default) restocks every minute of play;
-- items with `shopSpeed` make that faster (src/game/economy.lua, numbers in src/config/shop.lua).
--
--   Click / A an offer to pick it, again to buy it (two presses, like the item choice).
--   LOCK (L, pad up, or the card's chip) keeps an offer through restocks; it is free.
--   REROLL (R / pad X) replaces every offer that isn't locked or sold now, for nectar; the
--   price climbs with each reroll and resets when the shop restocks.
-- A bought item goes in the bag; if it doesn't fit, the BAG tab opens holding it.
local State = require("src.core.state")
local Input = require("src.core.input")
local Audio = require("src.core.audio")
local Theme = require("src.ui.theme")
local Economy = require("src.game.economy")
local Choices = require("src.game.choices")
local InvState = require("src.states.inventory")
local Choice = require("src.states.itemchoice")
local Tabs = require("src.states.bagtabs")

local Shop = { transparent = true, touchControls = "menu", noTouchScroll = true }
Shop.__index = Shop

local lg = love.graphics
local NECTAR_COL = Choice.NECTAR_COL
local ARM_TIME = 0.25

function Shop.new(game)
    local self = setmetatable({ game = game, world = game.world, t = 0, focus = 1, flashT = {} }, Shop)
    self.shop = Economy.shop(self.world)
    self.shop.seen = true
    self.stock = self.shop.stock
    self.tags = Choices.bagTags(self.world.player.inventory)
    self:refresh()
    return self
end

function Shop:enter() love.mouse.setVisible(true) end

function Shop:ready() return self.t >= ARM_TIME end
function Shop:entries() return self.shop.offers end
function Shop:rerollIndex() return #self.shop.offers + 1 end

function Shop:refresh()
    local stats = self.world.player.stats
    self.previews = {}
    for i, o in ipairs(self.shop.offers) do self.previews[i] = Choices.preview(stats, o.def) end
    self.tags = Choices.bagTags(self.world.player.inventory)
end

function Shop:say(text) self.note = { text = text, t = 0 } end

-- Buy offer i: an item goes in the bag (or the BAG tab opens holding it), a boost counts now.
function Shop:buy(i)
    local o = self.shop.offers[i]
    local ok, item = Economy.buy(self.world, i)
    self.armed = nil
    if not ok then
        Audio.play("ui_back")
        self:say(item == "sold" and "Already bought" or "Not enough nectar")
        return false
    end
    Audio.play("pickup", { pitch = 1.2 })
    local flow = self.world.rewardFlow
    if item then
        local inv = self.world.player.inventory
        if inv:give(item) then
            if flow then
                flow:gain({ title = "BOUGHT", name = item.def.name, item = item, color = InvState.rarityColor(item.def),
                    line = flow.itemLine(item.def) })
            end
        else
            -- no room: the bag, holding it, so it can be puzzled in (or something eaten)
            State.pop()
            State.push(InvState.new(self.game, { held = item }))
            return true
        end
    else
        Audio.play("equip", { pitch = 1.3 })
        if flow then flow:gain({ title = "BOUGHT", name = o.name, color = NECTAR_COL, line = o.text }) end
    end
    self:refresh()
    return true
end

function Shop:reroll()
    if not self:ready() then return false end
    self.armed = nil
    local old = {}
    for i, o in ipairs(self.shop.offers) do old[i] = o end
    local ok, why = Economy.rerollShop(self.world)
    if not ok then
        Audio.play("ui_back")
        self:say(why == "locked" and "Nothing left to reroll" or "Not enough nectar")
        return false
    end
    for i, o in ipairs(self.shop.offers) do if o ~= old[i] then self.flashT[i] = self.t end end
    self:refresh()
    Audio.play("ui_confirm", { pitch = 1.4 })
    return true
end

function Shop:toggleLock(i)
    local o = self.shop.offers[i]
    if not self:ready() or not o or o.sold then return end
    o.locked = not o.locked or nil
    Audio.play(o.locked and "equip" or "ui_move", { pitch = o.locked and 1.3 or 1 })
end

-- One press picks an offer, a second press on it buys it; the reroll slot rerolls at once.
function Shop:activate(i)
    if not self:ready() then return end
    if i == self:rerollIndex() then self:reroll() return end
    local o = self.shop.offers[i]
    if not o then return end
    if o.sold then Audio.play("ui_back") return end
    if self.armed == i then
        self:buy(i)
    elseif not Economy.canAfford(self.world, o.price) then
        Audio.play("ui_back")
        self:say(("%d more nectar"):format(o.price - Economy.nectar(self.world)))
    else
        self.armed, self.focus = i, i
        Audio.play("ui_confirm", { pitch = 0.9 })
    end
end

----------------------------------------------------------------------------------------------
-- Layout

function Shop:layout()
    local w, h = lg.getDimensions()
    local u = Theme.u
    local pw = math.min(w - u(40), u(1060))
    local ph = math.min(h - u(40), u(620))
    local px, py = math.floor((w - pw) / 2), math.floor((h - ph) / 2 - u(6))
    local pad = math.floor(u(16))
    local f = Theme.font(18, "bold")
    local L = { panel = { x = px, y = py, w = pw, h = ph }, pad = pad }
    L.tabs = Tabs.layout(self.game, px + pad, py + math.floor(u(10)), f:getHeight() + u(6))
    local headH = math.floor(u(96))
    local footH = math.floor(u(96))
    local n = math.max(1, #self.shop.offers)
    local gap = u(14)
    local cw = math.floor(math.min(u(230), (pw - pad * 2 - (n - 1) * gap) / n))
    local ch = math.floor(math.min(u(360), ph - headH - footH))
    local total = n * cw + (n - 1) * gap
    local x0 = math.floor(px + (pw - total) / 2)
    local y0 = py + headH
    local chipW, chipH = math.floor(math.min(u(64), cw * 0.3)), math.floor(u(22))
    L.cards = {}
    for i = 1, n do
        local c = { x = x0 + (i - 1) * (cw + gap), y = y0, w = cw, h = ch }
        c.ban = { x = c.x + u(6), y = c.y + u(6), w = chipW, h = chipH }
        c.lock = { x = c.x + cw - u(6) - chipW, y = c.y + u(6), w = chipW, h = chipH }
        L.cards[i] = c
    end
    local bw, bh = math.floor(u(220)), math.floor(u(34))
    L.reroll = { x = math.floor(px + pw / 2 - bw / 2), y = y0 + ch + u(40), w = bw, h = bh }
    L.timer = { x = px + pad, y = py + u(50), w = pw - pad * 2, h = math.floor(u(6)) }
    self.L = L
    return L
end

local inside = Choice.inside

-- "card" | "lock" | "reroll" | "tab", and the slot (or tab id).
function Shop:hitAt(x, y)
    local L = self.L or self:layout()
    local tab = Tabs.hit(L.tabs, x, y)
    if tab then return "tab", tab end
    for i, c in ipairs(L.cards) do
        if inside(c, x, y) then
            if inside(c.lock, x, y) then return "lock", i end
            return "card", i
        end
    end
    if inside(L.reroll, x, y) then return "reroll", self:rerollIndex() end
end

----------------------------------------------------------------------------------------------
-- Input

function Shop:update(dt)
    self.t = self.t + dt
    if self.note then
        self.note.t = self.note.t + dt
        if self.note.t > 2 then self.note = nil end
    end
    if Tabs.closing() then State.pop() return end
    if Tabs.cycle(self, "shop") then return end
    -- the stock can't change while the game is paused, but a save restore or a test might
    local shop = Economy.shop(self.world)
    if shop ~= self.shop then
        self.shop, self.armed = shop, nil
        shop.seen = true
        self:refresh()
    end
    local n = #self.shop.offers
    local f = self.focus
    if self.focus > n then
        if Input.pressed("ui_up") then self.focus = self.lastCard or 1 end
    else
        if Input.pressed("ui_left") then self.focus = (self.focus - 2) % n + 1 end
        if Input.pressed("ui_right") then self.focus = self.focus % n + 1 end
        if Input.pressed("ui_down") then self.lastCard = self.focus; self.focus = self:rerollIndex() end
    end
    if self.focus ~= f then self.armed = nil; Audio.play("ui_move") end
    if Input.pressed("ui_confirm") then self:activate(self.focus)
    elseif Input.pressed("choice_reroll") then self:reroll()
    elseif Input.pressed("choice_lock") and self.focus <= n then self:toggleLock(self.focus)
    -- on a pad, RB / LB switch tabs here, so up on a card locks it
    elseif f <= n and Input.lastDevice == "gamepad" and Input.pressed("ui_up") then self:toggleLock(f)
    end
end

function Shop:mousemoved(x, y)
    local what, i = self:hitAt(x, y)
    if (what == "card" or what == "lock" or what == "reroll") and i ~= self.focus and not self.armed then
        if self.focus <= #self.shop.offers then self.lastCard = self.focus end
        self.focus = i
        Audio.play("ui_move")
    end
end

function Shop:mousepressed(x, y, b)
    if b ~= 1 then return end
    self:layout()
    local what, i = self:hitAt(x, y)
    if what == "tab" then
        if i ~= "shop" then Tabs.open(self, i) end
    elseif what == "lock" then self:toggleLock(i)
    elseif what == "reroll" then self:reroll()
    elseif what == "card" then self:activate(i)
    else self.armed = nil end
end

----------------------------------------------------------------------------------------------
-- Drawing

function Shop:draw()
    local w, h = lg.getDimensions()
    local u = Theme.u
    local COL = InvState.COL
    lg.setColor(0.02, 0.015, 0.02, 0.72)
    lg.rectangle("fill", 0, 0, w, h)
    local L = self:layout()
    local P = L.panel
    InvState.plate(P.x, P.y, P.w, P.h, COL.frame, true)
    Tabs.draw(L.tabs, "shop", self.game)
    local world = self.world
    local nectar = Economy.nectar(world)

    -- header: the nectar in hand (right), interest, and the restock clock
    lg.setFont(Theme.font(22, "bold"))
    local nt = nectar .. " nectar"
    local nw = Theme.font(22, "bold"):getWidth(nt)
    local nx = P.x + P.w - L.pad - nw
    local ty = L.tabs[1].y
    lg.setColor(0.72, 0.42, 0.08)
    lg.circle("fill", nx - u(14), ty + u(13), u(8), 16)
    lg.setColor(1, 0.78, 0.22)
    lg.circle("fill", nx - u(14), ty + u(13), u(6.5), 16)
    Theme.printShadow(nt, nx, ty, NECTAR_COL)
    local lastTab = L.tabs[#L.tabs]
    lg.setFont(Theme.font(14))
    lg.setColor(COL.dim)
    local ip, cap = Economy.interestPreview(world), Economy.interestCap(world)
    lg.print(("Savings earn +%d at the next wave clear (max %d)"):format(ip, cap), lastTab.x + lastTab.w + u(24), ty + u(5))
    -- restock clock: a bar that fills up to the next stock
    local left = Economy.timeLeft(world)
    local every = Economy.restockTime(world)
    local T = L.timer
    lg.setColor(COL.frameLo)
    lg.rectangle("fill", T.x - 1, T.y - 1, T.w + 2, T.h + 2)
    lg.setColor(1, 0.75, 0.25, 0.85)
    lg.rectangle("fill", T.x, T.y, T.w * math.max(0, math.min(1, 1 - left / math.max(1, every))), T.h)
    lg.setFont(Theme.font(15, "bold"))
    local secs = math.ceil(left)
    local clock = ("NEW STOCK IN %d:%02d"):format(math.floor(secs / 60), secs % 60)
    local base = Economy.cfg(world).restock or 60
    local faster = every < base - 0.5 and ("  ·  restocks %d%% faster"):format(math.floor((base / every - 1) * 100 + 0.5)) or ""
    Theme.printShadow(clock .. faster, T.x, T.y + u(12), { 1, 0.85, 0.5 })
    lg.setFont(Theme.font(14))
    lg.setColor(COL.dim)
    lg.printf("Locked offers stay when it restocks", T.x, T.y + u(14), T.w, "right")

    -- the offers
    local mx, my = love.mouse.getPosition()
    local hoverWhat, hoverI = self:hitAt(mx, my)
    local ctx = { shop = true, nectar = nectar, hoverWhat = hoverWhat, hoverI = hoverI, armTime = ARM_TIME }
    for i, o in ipairs(self.shop.offers) do Choice.drawCard(self, i, o, L.cards[i], ctx) end

    -- REROLL under them
    local pad = Input.lastDevice == "gamepad"
    local touch = Input.lastDevice == "touch"
    local rk = pad and "X" or (not touch and "R") or nil
    local price = Economy.rerollPrice(world)
    Choice.button(L.reroll, "REROLL" .. (rk and (" (" .. rk .. ")") or "") .. "  " .. price .. " nectar", Theme.font(16, "bold"),
        { color = NECTAR_COL, lit = self.focus == self:rerollIndex(), hover = hoverWhat == "reroll", disabled = nectar < price })
    if self.note then
        lg.setFont(Theme.font(14, "bold"))
        Theme.printShadow(self.note.text, P.x, L.reroll.y + L.reroll.h + u(8), { 1, 0.85, 0.6, math.min(1, 2 - self.note.t) }, "center", P.w)
    end
    lg.setFont(Theme.font(13))
    local hint = pad and "{pad:a} pick, {pad:a} again to buy  ·  {pad:dpup} lock  ·  {pad:leftshoulder}/{pad:rightshoulder} tabs  ·  {pad:b} close"
        or touch and "Tap an offer to pick it, tap it again to buy it"
        or "Click an offer to pick it, click again to buy  ·  {key:L} lock  ·  {key:E} / {key:Q} tabs  ·  {key:Tab} close"
    Theme.rich(hint, P.x, P.y + P.h - u(26), P.w, "center", COL.dim)
    lg.setColor(1, 1, 1, 1)
end

return Shop
