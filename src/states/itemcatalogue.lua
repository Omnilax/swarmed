-- Item catalogue: every item in content/items as a wall of icons, sorted by rarity and filterable
-- by rarity, kind (tags and proc triggers) and name, with the full details of the one in focus.
-- Built from the content registry, so new items show up here the moment their file exists.
--
-- From the main menu it is read only. Opened from the sandbox (button or C) it sits over the
-- paused arena and gives and takes items:
--   click picks an item, click it again (or Enter / A / Give) puts one in your bag,
--   Shift gives 5, right click / Delete / X takes one back out.
-- Keys: arrows move, Q / E or Tab (LB / RB) switch rarity tab, K cycles the kind filter,
-- / starts typing a name, Esc / B closes.
local State = require("src.core.state")
local Input = require("src.core.input")
local Audio = require("src.core.audio")
local Theme = require("src.ui.theme")
local Settings = require("src.core.settings")
local Content = require("src.content")
local Rarities = require("src.config.rarities")
local Inventory = require("src.game.inventory")
local InvState = require("src.states.inventory")
local util = require("src.core.util")

local Cat = {}
Cat.__index = Cat

local lg = love.graphics

-- Proc triggers in words (also used as filters).
local TRIGGERS = {
    { id = "onHit", label = "on hit" }, { id = "onKill", label = "on kill" }, { id = "onHurt", label = "when hurt" },
    { id = "onDash", label = "on dash" }, { id = "onDodge", label = "on dodge" }, { id = "onWaveStart", label = "each wave" },
    { id = "onEat", label = "on eating" }, { id = "onTick", label = "over time" },
}
local triggerLabel = {}
for _, t in ipairs(TRIGGERS) do triggerLabel[t.id] = t.label end

local function rarityList()
    local list = {}
    for id, r in pairs(Rarities) do list[#list + 1] = { id = id, label = r.label, order = r.order } end
    table.sort(list, function(a, b) return a.order < b.order end)
    return list
end

local function hasTrigger(def, trig)
    for _, p in ipairs(def.procs) do if p.trigger == trig then return true end end
    return false
end

local function triggersOf(def)
    local out, seen = {}, {}
    for _, p in ipairs(def.procs) do
        if not seen[p.trigger] then seen[p.trigger] = true; out[#out + 1] = triggerLabel[p.trigger] or p.trigger end
    end
    return out
end

-- opts.game: the running sandbox/run (items can be given and taken); nil = read only.
function Cat.new(opts)
    opts = opts or {}
    local self = setmetatable({ game = opts.game, t = 0, focus = 1, scroll = 0, search = nil, query = "", toasts = {} }, Cat)
    self.transparent = self.game ~= nil
    self.inv = self.game and self.game.world.player.inventory
    self.rarities = rarityList()
    -- rarity tabs (plus "In bag" when there is a bag to look at)
    self.tabs = { { id = "all", label = "All" } }
    for _, r in ipairs(self.rarities) do self.tabs[#self.tabs + 1] = { id = r.id, label = r.label } end
    if self.game then self.tabs[#self.tabs + 1] = { id = "owned", label = "In bag" } end
    self.tab = 1
    -- kinds: every tag in use (most common first), then the proc triggers in use
    local count = {}
    for _, def in ipairs(Content.items:all()) do
        for _, tag in ipairs(def.tags) do count[tag] = (count[tag] or 0) + 1 end
    end
    local tags = {}
    for tag in pairs(count) do tags[#tags + 1] = tag end
    table.sort(tags, function(a, b) if count[a] ~= count[b] then return count[a] > count[b] end return a < b end)
    self.kinds = { { label = "any kind" } }
    for _, tag in ipairs(tags) do self.kinds[#self.kinds + 1] = { label = tag, tag = tag } end
    for _, tr in ipairs(TRIGGERS) do
        for _, def in ipairs(Content.items:all()) do
            if hasTrigger(def, tr.id) then self.kinds[#self.kinds + 1] = { label = "procs " .. tr.label, trigger = tr.id }; break end
        end
    end
    self.kind = 1
    self:refilter()
    return self
end

function Cat:enter() love.mouse.setVisible(true) end

function Cat:leave()
    if self.game and self.game.applyCursor then self.game:applyCursor() end
end

-- The items that pass the filters, in rarity order then by name.
function Cat:refilter()
    local keep = self.list and self.list[self.focus]
    local tab, kind, q = self.tabs[self.tab].id, self.kinds[self.kind], self.query:lower()
    local list = {}
    for _, def in ipairs(Content.items:all()) do
        local ok = tab == "all" or def.rarity == tab or (tab == "owned" and self.inv:count(def.id) > 0)
        if ok and kind.tag then ok = util.contains(def.tags, kind.tag) end
        if ok and kind.trigger then ok = hasTrigger(def, kind.trigger) end
        if ok and q ~= "" then ok = def.name:lower():find(q, 1, true) or def.id:find(q, 1, true) end
        if ok then list[#list + 1] = def end
    end
    table.sort(list, function(a, b)
        local ra, rb = Rarities[a.rarity].order, Rarities[b.rarity].order
        if ra ~= rb then return ra < rb end
        return a.name < b.name
    end)
    self.list = list
    self.focus = math.max(1, math.min(util.indexOf(list, keep) or 1, #list))
    self.layoutCache = nil
end

----------------------------------------------------------------------------------------------
-- Layout: tabs on top, the icon wall on the left (a section per rarity), details on the right.

function Cat:layout()
    local w, h = lg.getDimensions()
    if self.layoutCache and self.layoutCache.w == w and self.layoutCache.h == h then return self.layoutCache end
    local u = Theme.u
    local L = { w = w, h = h }
    local margin = u(40)
    L.top = u(142)
    L.detail = { w = math.floor(math.min(u(380), w * 0.36)) }
    L.detail.x = w - margin - L.detail.w
    L.detail.y, L.detail.h = L.top, h - L.top - u(52)
    L.grid = { x = margin, y = L.top, w = L.detail.x - margin - u(24), h = L.detail.h }
    L.T = math.floor(u(58))
    L.gap = math.floor(u(8))
    L.cols = math.max(1, math.floor((L.grid.w + L.gap) / (L.T + L.gap)))
    -- tiles and section headers, in scroll space
    L.tiles, L.heads = {}, {}
    local y, col, rar = 0, 0, nil
    local headH = math.floor(u(30))
    for i, def in ipairs(self.list) do
        if def.rarity ~= rar then
            if col > 0 then y = y + L.T + L.gap end
            rar, col = def.rarity, 0
            L.heads[#L.heads + 1] = { y = y, rarity = rar }
            y = y + headH
        end
        L.tiles[i] = { x = col * (L.T + L.gap), y = y }
        col = col + 1
        if col >= L.cols then col = 0; y = y + L.T + L.gap end
    end
    L.contentH = y + (col > 0 and L.T or 0)
    self.layoutCache = L
    return L
end

function Cat:tileAt(mx, my)
    local L = self:layout()
    local G = L.grid
    if mx < G.x or mx > G.x + G.w or my < G.y or my > G.y + G.h then return nil end
    for i, t in ipairs(L.tiles) do
        local x, y = G.x + t.x, G.y + t.y - self.scroll
        if mx >= x and mx < x + L.T and my >= y and my < y + L.T then return i end
    end
end

function Cat:ensureVisible()
    local L = self:layout()
    local t = L.tiles[self.focus]
    if not t then return end
    local headH = Theme.u(30)
    if t.y - headH < self.scroll then self.scroll = t.y - headH end
    if t.y + L.T > self.scroll + L.grid.h then self.scroll = t.y + L.T - L.grid.h end
    self.scroll = util.clamp(self.scroll, 0, math.max(0, L.contentH - L.grid.h))
end

-- Move the focus by a grid step (left/right one, up/down a row, keeping the column).
function Cat:step(dx, dy)
    local L = self:layout()
    local n = #self.list
    if n == 0 then return end
    if dx ~= 0 then
        self.focus = (self.focus - 1 + dx) % n + 1
    else
        local cur = L.tiles[self.focus]
        local best, bestD
        for i, t in ipairs(L.tiles) do
            if (dy > 0 and t.y > cur.y) or (dy < 0 and t.y < cur.y) then
                local d = math.abs(t.y - cur.y) * 10 + math.abs(t.x - cur.x)
                if not bestD or d < bestD then best, bestD = i, d end
            end
        end
        if not best then return end
        self.focus = best
    end
    Audio.play("ui_move")
    self:ensureVisible()
end

----------------------------------------------------------------------------------------------
-- Giving and taking (sandbox only)

function Cat:toast(text, color)
    self.toasts[#self.toasts + 1] = { text = text, color = color or Theme.colors.good, t = 0 }
    if #self.toasts > 4 then table.remove(self.toasts, 1) end
end

function Cat:give(def, n)
    if not self.game or not def then return end
    local world = self.game.world
    local eaten = world:giveItem(def.id, n)
    Audio.play("equip")
    if eaten > 0 then
        self:toast(("Bag full: ate %d %s"):format(eaten, def.name), Theme.colors.bad)
    else
        self:toast(("+%d %s"):format(n, def.name), InvState.rarityColor(def))
    end
end

function Cat:take(def, all)
    if not self.game or not def then return end
    local have = self.inv:count(def.id)
    if have == 0 then return end
    self.inv:remove(def.id, all and have or 1)
    Audio.play("ui_back")
    self:toast(("-%d %s"):format(all and have or 1, def.name), Theme.colors.dim)
    if self.tabs[self.tab].id == "owned" then self:refilter() end
end

-- Buttons under the details (sandbox): { label, fn } with rects filled in when drawn.
function Cat:buttons()
    if not self.game then return {} end
    local def = self.list[self.focus]
    return {
        { label = "Give", fn = function() self:give(def, 1) end },
        { label = "Give 5", fn = function() self:give(def, 5) end },
        { label = "Take 1", fn = function() self:take(def) end },
        { label = "Take all", fn = function() self:take(def, true) end },
    }
end

----------------------------------------------------------------------------------------------
-- Input

function Cat:close()
    Audio.play("ui_back")
    State.pop()
end

function Cat:setTab(i)
    self.tab = (i - 1) % #self.tabs + 1
    self.scroll = 0
    self:refilter()
    Audio.play("ui_move")
end

function Cat:setKind(i)
    self.kind = (i - 1) % #self.kinds + 1
    self.scroll = 0
    self:refilter()
    Audio.play("ui_move")
end

function Cat:update(dt)
    self.t = self.t + dt
    for i = #self.toasts, 1, -1 do
        local f = self.toasts[i]
        f.t = f.t + dt
        if f.t > 2.2 then table.remove(self.toasts, i) end
    end
    if self.search or self.skipFrame then self.skipFrame = nil return end   -- typing goes to the search box
    if Input.pressed("ui_back") then return self:close() end
    if Input.pressed("ui_left") then self:step(-1, 0) end
    if Input.pressed("ui_right") then self:step(1, 0) end
    if Input.pressed("ui_up") then self:step(0, -1) end
    if Input.pressed("ui_down") then self:step(0, 1) end
    if Input.pressed("ui_tab_next") then self:setTab(self.tab + 1) end
    if Input.pressed("ui_tab_prev") then self:setTab(self.tab - 1) end
    if Input.pressed("ui_confirm") then
        local shift = love.keyboard.isDown("lshift", "rshift")
        self:give(self.list[self.focus], shift and 5 or 1)
    end
    if Input.pressed("inventory_alt") then self:take(self.list[self.focus]) end
end

function Cat:keypressed(key)
    if self.search then
        if key == "escape" or key == "return" or key == "kpenter" then
            self.search = nil
            self.skipFrame = true       -- the same key must not also close or give
        elseif key == "backspace" then
            self.query = self.query:sub(1, -2)
            self:refilter()
        elseif #key == 1 and key:match("[%w]") or key == "space" then
            self.query = self.query .. (key == "space" and " " or key)
            self:refilter()
        end
        return
    end
    if key == "/" or (key == "f" and love.keyboard.isDown("lctrl", "rctrl")) then
        self.search = true
    elseif key == "k" then
        self:setKind(self.kind + (love.keyboard.isDown("lshift", "rshift") and -1 or 1))
    elseif key == "delete" then
        self:take(self.list[self.focus])
    end
end

function Cat:mousemoved() end

function Cat:mousepressed(x, y, b)
    for i, r in ipairs(self.tabRects or {}) do
        if x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h then return self:setTab(i) end
    end
    local k = self.kindRect
    if k and x >= k.x and x < k.x + k.w and y >= k.y and y < k.y + k.h then
        return self:setKind(self.kind + (b == 2 and -1 or 1))
    end
    local s = self.searchRect
    if s and x >= s.x and x < s.x + s.w and y >= s.y and y < s.y + s.h then
        if b == 2 then self.query = ""; self:refilter() end
        self.search = true
        return
    end
    self.search = nil
    for _, btn in ipairs(self.btnRects or {}) do
        if x >= btn.x and x < btn.x + btn.w and y >= btn.y and y < btn.y + btn.h then
            Audio.play("ui_confirm")
            return btn.fn()
        end
    end
    local i = self:tileAt(x, y)
    if not i then return end
    local def = self.list[i]
    if b == 2 then
        self.focus = i
        return self:take(def)
    end
    if b ~= 1 then return end
    -- click picks; clicking the picked one again gives it
    if i == self.focus and self.game and self.lastClick and self.t - self.lastClick < 0.6 then
        self:give(def, love.keyboard.isDown("lshift", "rshift") and 5 or 1)
    elseif i ~= self.focus then
        Audio.play("ui_move")
    end
    self.focus = i
    self.lastClick = self.t
end

function Cat:wheelmoved(_, dy)
    local L = self:layout()
    self.scroll = util.clamp(self.scroll - dy * (L.T + L.gap), 0, math.max(0, L.contentH - L.grid.h))
end

----------------------------------------------------------------------------------------------
-- Drawing

local COL = InvState.COL

local function chip(x, y, text, on, color)
    local u = Theme.u
    local f = lg.getFont()
    local w, h = f:getWidth(text) + u(22), f:getHeight() + u(10)
    lg.setColor(on and { 0.2, 0.15, 0.12, 1 } or { 0.1, 0.08, 0.075, 0.9 })
    lg.rectangle("fill", x, y, w, h)
    local c = color or COL.label
    lg.setColor(c[1], c[2], c[3], on and 1 or 0.35)
    lg.rectangle("fill", x, y + h - 2, w, 2)
    lg.setColor(on and c or COL.dim)
    lg.print(text, x + u(11), y + u(5))
    return { x = x, y = y, w = w, h = h }
end

function Cat:drawTile(def, x, y, T, focused)
    local rc = InvState.rarityColor(def)
    -- recessed socket, rimmed in the rarity colour
    lg.setColor(COL.socket)
    lg.rectangle("fill", x, y, T, T)
    lg.setColor(0, 0, 0, 0.5)
    lg.rectangle("fill", x, y, T, 2)
    lg.rectangle("fill", x, y, 2, T)
    lg.setColor(rc[1] * 0.25, rc[2] * 0.25, rc[3] * 0.25, 0.6)
    lg.rectangle("fill", x + 2, y + 2, T - 4, T - 4)
    lg.setColor(rc[1], rc[2], rc[3], focused and 1 or 0.45)
    lg.setLineWidth(focused and 2 or 1)
    lg.rectangle("line", x + 0.5, y + 0.5, T - 1, T - 1)
    lg.setLineWidth(1)
    InvState.itemIcon({ def = def }, x + 5, y + 5, T - 10, T - 10)
    local have = self.inv and self.inv:count(def.id) or 0
    if have > 0 then
        lg.setFont(Theme.font(13, "bold"))
        local txt = "x" .. have
        local f = lg.getFont()
        lg.setColor(0, 0, 0, 0.7)
        lg.rectangle("fill", x + T - f:getWidth(txt) - 6, y + T - f:getHeight() - 2, f:getWidth(txt) + 4, f:getHeight())
        lg.setColor(COL.label)
        lg.print(txt, x + T - f:getWidth(txt) - 4, y + T - f:getHeight() - 2)
    end
end

function Cat:drawDetails(def, D)
    local u = Theme.u
    InvState.plate(D.x, D.y, D.w, D.h, COL.inner, true)
    if not def then
        lg.setFont(Theme.font(16))
        lg.setColor(COL.dim)
        lg.printf("Nothing matches.", D.x, D.y + D.h / 2 - u(10), D.w, "center")
        return
    end
    local rc = InvState.rarityColor(def)
    lg.setColor(rc)
    lg.rectangle("fill", D.x + 2, D.y + 2, D.w - 4, 3)
    -- the item on its own little grid, so its shape shows
    local item = { def = def }
    local bw, bh = Inventory.size(item)
    local boxH = math.floor(math.min(u(170), D.h * 0.3))
    local cell = math.floor(math.min(u(96), (D.w - u(60)) / math.max(bw, 1), boxH / math.max(bh, 1)))
    local gx = math.floor(D.x + (D.w - bw * cell) / 2)
    local gy = math.floor(D.y + u(22) + (boxH - bh * cell) / 2)
    local bob = math.floor(math.sin(self.t * 2) * u(2))
    InvState.shapeCells(item, gx, gy + bob, cell, { rc[1] * 0.3, rc[2] * 0.3, rc[3] * 0.3, 0.9 }, { rc[1], rc[2], rc[3], 0.8 })
    InvState.itemIcon(item, gx + 3, gy + bob + 3, bw * cell - 6, bh * cell - 6)

    local x, w = D.x + u(18), D.w - u(36)
    local y = D.y + u(34) + boxH
    lg.setFont(Theme.font(24, "bold"))
    Theme.printShadow(def.name, D.x, y, rc, "center", D.w)
    y = y + u(32)
    lg.setFont(Theme.font(14))
    lg.setColor(COL.dim)
    local cells = #def.cells
    local meta = Rarities[def.rarity].label .. "  ·  " .. cells .. (cells == 1 and " cell" or " cells")
        .. "  ·  eat +" .. Inventory.eatValue(item) .. " HP"
    lg.printf(meta, D.x, y, D.w, "center")
    y = y + u(26)

    local function para(text, color, font)
        lg.setFont(font or Theme.font(15))
        lg.setColor(color)
        lg.printf(text, x, y, w, "center")
        local _, lines = lg.getFont():getWrap(text, w)
        y = y + #lines * lg.getFont():getHeight() + u(8)
    end
    local lines = InvState.statLines(def)
    for _, l in ipairs(lines) do
        lg.setFont(Theme.font(15))
        lg.setColor(l[2] and Theme.colors.good or Theme.colors.bad)
        lg.printf(l[1], x, y, w, "center")
        y = y + u(19)
    end
    if #lines > 0 then y = y + u(6) end
    -- what it does in words: its effect, else the description when the stats don't say it all
    local text = def.effect or ((#def.procs > 0 or #lines == 0) and def.description ~= "" and def.description)
    if text then para(text, Theme.colors.text) end
    local trig = triggersOf(def)
    if #trig > 0 then para("Procs " .. table.concat(trig, ", "), Theme.colors.accent, Theme.font(14)) end
    if #def.tags > 0 then
        para(table.concat(def.tags, "  ·  "):upper(), { COL.dim[1], COL.dim[2], COL.dim[3], 0.75 }, Theme.font(13))
    end

    -- sandbox: what you have, and buttons to give and take
    self.btnRects = {}
    local by = D.y + D.h - u(16)
    if self.game then
        local btns = self:buttons()
        local bwid = math.floor((D.w - u(36) - u(8) * (#btns - 1)) / #btns)
        local bh = math.floor(u(32))
        by = by - bh
        lg.setFont(Theme.font(15, "bold"))
        local mx, my = love.mouse.getPosition()
        for i, btn in ipairs(btns) do
            local bx = D.x + u(18) + (i - 1) * (bwid + u(8))
            local hover = mx >= bx and mx < bx + bwid and my >= by and my < by + bh
            local taking = i > 2
            local dim = taking and self.inv:count(def.id) == 0
            InvState.plate(bx, by, bwid, bh, hover and not dim and { 0.24, 0.18, 0.13 } or COL.frame)
            lg.setColor(dim and COL.dim or (taking and Theme.colors.bad or COL.label))
            lg.printf(btn.label, bx, by + math.floor((bh - lg.getFont():getHeight()) / 2), bwid, "center")
            btn.x, btn.y, btn.w, btn.h = bx, by, bwid, bh
            self.btnRects[#self.btnRects + 1] = btn
        end
        local have = self.inv:count(def.id)
        lg.setFont(Theme.font(14))
        lg.setColor(have > 0 and COL.label or COL.dim)
        lg.printf(have > 0 and ("In your bag: " .. have .. (have > 1 and " (stacked)" or "")) or "Not in your bag",
            D.x, by - u(26), D.w, "center")
        by = by - u(26)
    end
    if Settings.get("devMode") then
        lg.setFont(Theme.font("small"))
        lg.setColor(COL.dim[1], COL.dim[2], COL.dim[3], 0.6)
        lg.printf("give " .. def.id, D.x, by - u(22), D.w, "center")
    end
end

function Cat:draw()
    local w, h = lg.getDimensions()
    local u = Theme.u
    local L = self:layout()
    if self.game then
        lg.setColor(0.03, 0.025, 0.03, 0.93)
        lg.rectangle("fill", 0, 0, w, h)
    else
        lg.clear(Theme.colors.bg)
    end

    lg.setFont(Theme.font(34, "bold"))
    Theme.printShadow("ITEM CATALOGUE", u(40), u(26), Theme.colors.focus)
    lg.setFont(Theme.font(14))
    lg.setColor(COL.dim)
    local total = #Content.items:all()
    lg.print(("%d items  ·  %d shown"):format(total, #self.list), u(42), u(72))

    -- tabs, kind filter, search
    lg.setFont(Theme.font(15))
    local tx = u(40)
    self.tabRects = {}
    local ty = L.top - u(42)
    for i, tab in ipairs(self.tabs) do
        local col = Rarities[tab.id] and InvState.rarityColor({ rarity = tab.id }) or COL.label
        local r = chip(tx, ty, tab.label, i == self.tab, col)
        self.tabRects[i] = r
        tx = tx + r.w + u(6)
    end
    tx = tx + u(14)
    self.kindRect = chip(tx, ty, "< " .. self.kinds[self.kind].label .. " >", self.kind > 1, Theme.colors.accent)
    tx = tx + self.kindRect.w + u(14)
    local searchText = (self.query ~= "" or self.search) and (self.query .. (self.search and math.floor(self.t * 2) % 2 == 0 and "_" or "")) or "/ search"
    self.searchRect = chip(tx, ty, searchText, self.search or self.query ~= "", Theme.colors.text)
    self.searchRect.w = math.max(self.searchRect.w, u(140))

    -- the wall of icons
    local G = L.grid
    lg.setScissor(G.x - 4, G.y - 4, G.w + 8, G.h + 8)
    for _, hd in ipairs(L.heads) do
        local y = G.y + hd.y - self.scroll
        if y > G.y - u(40) and y < G.y + G.h then
            local c = InvState.rarityColor({ rarity = hd.rarity })
            lg.setFont(Theme.font(15, "bold"))
            lg.setColor(c)
            local n = 0
            for _, d in ipairs(self.list) do if d.rarity == hd.rarity then n = n + 1 end end
            lg.print(Rarities[hd.rarity].label:upper() .. "  " .. n, G.x, y + u(4))
            lg.setColor(c[1], c[2], c[3], 0.25)
            lg.rectangle("fill", G.x, y + u(24), G.w, 1)
        end
    end
    local mx, my = love.mouse.getPosition()
    local hover = self:tileAt(mx, my)
    for i, t in ipairs(L.tiles) do
        local x, y = G.x + t.x, G.y + t.y - self.scroll
        if y + L.T >= G.y - 4 and y <= G.y + G.h + 4 then
            local focused = i == self.focus
            local lift = (focused or i == hover) and math.floor(u(2)) or 0
            self:drawTile(self.list[i], x, y - lift, L.T, focused)
        end
    end
    lg.setScissor()
    if L.contentH > G.h then
        local bh = G.h * G.h / L.contentH
        local by = G.y + (G.h - bh) * (self.scroll / (L.contentH - G.h))
        lg.setColor(1, 1, 1, 0.2)
        lg.rectangle("fill", G.x + G.w + u(8), by, 3, bh, 2, 2)
    end
    if #self.list == 0 then
        lg.setFont(Theme.font(16))
        lg.setColor(COL.dim)
        lg.print("No items match these filters.", G.x, G.y + u(10))
    end

    self:drawDetails(self.list[self.focus], L.detail)

    -- hints
    local hints
    if Input.lastDevice == "gamepad" then
        hints = self.game and { { "LB/RB", "Rarity" }, { "A", "Give" }, { "X", "Take" }, { "B", "Back" } }
            or { { "D-pad", "Browse" }, { "LB/RB", "Rarity" }, { "B", "Back" } }
    else
        hints = self.game and { { "Click", "Give" }, { "Shift", "Give 5" }, { "RMB", "Take" }, { "Q/E", "Rarity" }, { "K", "Kind" }, { "/", "Search" }, { "Esc", "Back" } }
            or { { "Q/E", "Rarity" }, { "K", "Kind" }, { "/", "Search" }, { "Esc", "Back" } }
    end
    Theme.hints(hints, w / 2, h - u(32))

    -- "+1 Amber" toasts
    lg.setFont(Theme.font(16, "bold"))
    for i, f in ipairs(self.toasts) do
        local a = math.min(1, (2.2 - f.t) * 2)
        Theme.printShadow(f.text, 0, h - u(58) - (#self.toasts - i) * u(20), { f.color[1], f.color[2], f.color[3], a }, "center", L.grid.x * 2 + L.grid.w)
    end
    lg.setColor(1, 1, 1, 1)
end

return Cat
