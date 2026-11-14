-- Starting items for modes with chooseItems (endless): spend a point budget on any items from
-- the catalogue, then start the run with them in the bag.
local State = require("src.core.state")
local Content = require("src.content")
local Theme = require("src.ui.theme")
local Input = require("src.core.input")
local Audio = require("src.core.audio")
local Rarities = require("src.config.rarities")
local InvState = require("src.states.inventory")
local util = require("src.core.util")

local Loadout = {}
Loadout.__index = Loadout

local lg = love.graphics

-- Points per item by rarity. Bigger items cost one more (they take more of the bag).
Loadout.COST = { common = 1, uncommon = 2, rare = 3, legendary = 5 }
Loadout.BAG_CELLS = 30

function Loadout.cost(def)
    return (Loadout.COST[def.rarity] or 2) + (#def.cells >= 4 and 1 or 0)
end

-- params: the Game params to start with; opts: the mode's chooseItems ({ budget })
function Loadout.new(params, opts)
    local self = setmetatable({ params = params, budget = opts.budget or 12, picked = {}, t = 0, focus = 1, scroll = 0 }, Loadout)
    self.list = {}
    for _, d in ipairs(Content.items:all()) do self.list[#self.list + 1] = d end
    table.sort(self.list, function(a, b)
        local ra, rb = Rarities[a.rarity].order, Rarities[b.rarity].order
        if ra ~= rb then return ra < rb end
        return a.name < b.name
    end)
    return self
end

function Loadout:spent()
    local n, cells = 0, 0
    for _, d in ipairs(self.picked) do n, cells = n + Loadout.cost(d), cells + #d.cells end
    return n, cells
end

function Loadout:canAdd(def)
    local n, cells = self:spent()
    return n + Loadout.cost(def) <= self.budget and cells + #def.cells <= Loadout.BAG_CELLS
end

function Loadout:add(def)
    if not def then return end
    if self:canAdd(def) then
        self.picked[#self.picked + 1] = def
        Audio.play("ui_confirm")
    else
        Audio.play("ui_back")
        self.denyT = 0.4
    end
end

function Loadout:remove(def)
    for i = #self.picked, 1, -1 do
        if not def or self.picked[i] == def then
            table.remove(self.picked, i)
            Audio.play("ui_move")
            return
        end
    end
end

function Loadout:start()
    local ids = {}
    for i, d in ipairs(self.picked) do ids[i] = d.id end
    local p = {}
    for k, v in pairs(self.params) do p[k] = v end
    p.startItems = ids
    Audio.play("ui_confirm")
    return State.switch(require("src.states.game").new(p))

end

function Loadout:layout()
    local w, h = lg.getDimensions()
    if self.L and self.L.w == w and self.L.h == h then return self.L end
    local u = Theme.u
    local L = { w = w, h = h }
    local margin = u(40)
    L.top = u(130)
    L.side = { w = math.floor(math.min(u(360), w * 0.34)) }
    L.side.x, L.side.y = w - margin - L.side.w, L.top
    L.side.h = h - L.top - u(60)
    L.grid = { x = margin, y = L.top, w = L.side.x - margin - u(24), h = L.side.h }
    L.T = math.floor(u(54))
    L.gap = math.floor(u(8))
    L.cols = math.max(1, math.floor((L.grid.w + L.gap) / (L.T + L.gap)))
    L.rows = math.ceil(#self.list / L.cols)
    L.contentH = L.rows * (L.T + L.gap)
    L.startBtn = { x = L.side.x + u(20), y = L.side.y + L.side.h - u(64), w = L.side.w - u(40), h = u(44) }
    self.L = L
    return L
end

function Loadout:tileRect(i)
    local L = self:layout()
    local c, r = (i - 1) % L.cols, math.floor((i - 1) / L.cols)
    return L.grid.x + c * (L.T + L.gap), L.grid.y + r * (L.T + L.gap) - self.scroll
end

function Loadout:tileAt(mx, my)
    local L = self:layout()
    local G = L.grid
    if mx < G.x or mx > G.x + G.w or my < G.y or my > G.y + G.h then return nil end
    for i = 1, #self.list do
        local x, y = self:tileRect(i)
        if mx >= x and mx < x + L.T and my >= y and my < y + L.T then return i end
    end
end

-- The picked list in the side panel: one row per distinct item, with a count.
function Loadout:pickedRows()
    local rows, byId = {}, {}
    for _, d in ipairs(self.picked) do
        local r = byId[d.id]
        if not r then r = { def = d, n = 0 } byId[d.id] = r rows[#rows + 1] = r end
        r.n = r.n + 1
    end
    return rows
end

function Loadout:ensureVisible()
    local L = self:layout()
    local _, y = self:tileRect(self.focus)
    y = y + self.scroll - L.grid.y
    if y < self.scroll then self.scroll = y end
    if y + L.T > self.scroll + L.grid.h then self.scroll = y + L.T - L.grid.h end
    self.scroll = util.clamp(self.scroll, 0, math.max(0, L.contentH - L.grid.h))
end

function Loadout:update(dt)
    self.t = self.t + dt
    if self.denyT then self.denyT = self.denyT - dt if self.denyT <= 0 then self.denyT = nil end end
    local L = self:layout()
    local n = #self.list
    local f = self.focus
    if Input.pressed("ui_left") then f = f - 1 end
    if Input.pressed("ui_right") then f = f + 1 end
    if Input.pressed("ui_up") then f = f - L.cols end
    if Input.pressed("ui_down") then f = f + L.cols end
    f = util.clamp(f, 1, n)
    if f ~= self.focus then self.focus = f Audio.play("ui_move") self:ensureVisible() end
    if Input.pressed("ui_confirm") then self:add(self.list[self.focus]) end
    if Input.pressed("inventory_alt") then self:remove(self.list[self.focus]) end
    if Input.pressed("ui_tab_next") then self:start() return end
    if Input.pressed("ui_back") then Audio.play("ui_back") State.pop() end
end

function Loadout:mousemoved(x, y)
    local i = self:tileAt(x, y)
    if i then self.focus = i end
end

function Loadout:mousepressed(x, y, b)
    local L = self:layout()
    local s = L.startBtn
    if b == 1 and x >= s.x and x <= s.x + s.w and y >= s.y and y <= s.y + s.h then self:start() return end
    local i = self:tileAt(x, y)
    if i then
        self.focus = i
        if b == 1 then self:add(self.list[i]) else self:remove(self.list[i]) end
        return
    end
    -- a row in the picked list: take one back
    for _, r in ipairs(self.rowRects or {}) do
        if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then self:remove(r.def) return end
    end
end

function Loadout:wheelmoved(_, dy)
    local L = self:layout()
    self.scroll = util.clamp(self.scroll - dy * (L.T + L.gap), 0, math.max(0, L.contentH - L.grid.h))
end

function Loadout:drawTile(def, x, y, T, focused)
    local rc = InvState.rarityColor(def)
    local afford = self:canAdd(def)
    lg.setColor(InvState.COL.socket)
    lg.rectangle("fill", x, y, T, T)
    lg.setColor(rc[1] * 0.25, rc[2] * 0.25, rc[3] * 0.25, 0.6)
    lg.rectangle("fill", x + 2, y + 2, T - 4, T - 4)
    lg.setColor(rc[1], rc[2], rc[3], focused and 1 or 0.4)
    lg.setLineWidth(focused and 2 or 1)
    lg.rectangle("line", x + 0.5, y + 0.5, T - 1, T - 1)
    lg.setLineWidth(1)
    InvState.itemIcon({ def = def }, x + 5, y + 5, T - 10, T - 10, afford and 1 or 0.35)
    -- cost in the corner
    lg.setFont(Theme.font("small", "bold"))
    local txt = tostring(Loadout.cost(def))
    local f = lg.getFont()
    lg.setColor(0, 0, 0, 0.65)
    lg.rectangle("fill", x + T - f:getWidth(txt) - 6, y + T - f:getHeight() - 2, f:getWidth(txt) + 4, f:getHeight())
    lg.setColor(afford and Theme.colors.focus or Theme.colors.dim)
    lg.print(txt, x + T - f:getWidth(txt) - 4, y + T - f:getHeight() - 2)
end

function Loadout:draw()
    local u = Theme.u
    local c = Theme.colors
    local L = self:layout()
    lg.clear(c.bg)
    Theme.title("Starting Items")
    local spent = self:spent()
    lg.setFont(Theme.font("heading", "bold"))
    local col = self.denyT and c.bad or c.focus
    Theme.printShadow(("%d / %d points"):format(spent, self.budget), 0, u(50), col, "right", L.w - u(40))

    -- the catalogue grid
    local G = L.grid
    lg.setScissor(G.x, G.y, G.w, G.h)
    for i, def in ipairs(self.list) do
        local x, y = self:tileRect(i)
        if y + L.T >= G.y and y <= G.y + G.h then self:drawTile(def, x, y, L.T, i == self.focus) end
    end
    lg.setScissor()

    -- side panel: the focused item, then what's packed
    local S = L.side
    Theme.panel(S.x, S.y, S.w, S.h)
    local x, y, iw = S.x + u(20), S.y + u(18), S.w - u(40)
    local def = self.list[self.focus]
    if def then
        local rc = InvState.rarityColor(def)
        lg.setFont(Theme.font("heading", "bold"))
        Theme.printShadow(def.name, x, y, c.text)
        y = y + lg.getFont():getHeight() + u(2)
        lg.setFont(Theme.font("label"))
        lg.setColor(rc)
        lg.print(Rarities[def.rarity].label .. "  ·  " .. Loadout.cost(def) .. " pt", x, y)
        y = y + lg.getFont():getHeight() + u(8)
        lg.setColor(c.dim)
        local _, dl = lg.getFont():getWrap(def.description or "", iw)
        local lines = math.min(#dl, 5)
        lg.setScissor(x, y, iw, lines * lg.getFont():getHeight())
        lg.printf(def.description or "", x, y, iw)
        lg.setScissor()
        y = y + lines * lg.getFont():getHeight() + u(16)
    end
    lg.setColor(c.panelHi)
    lg.rectangle("fill", x, y, iw, 1)
    y = y + u(12)
    lg.setFont(Theme.font("label", "bold"))
    lg.setColor(c.accent)
    lg.print("PACKED", x, y)
    y = y + lg.getFont():getHeight() + u(6)
    lg.setFont(Theme.font("label"))
    self.rowRects = {}
    local rh = lg.getFont():getHeight() + u(6)
    local rows = self:pickedRows()
    if #rows == 0 then
        lg.setColor(c.dim)
        lg.printf("Nothing yet. Pick items on the left.", x, y, iw)
    end
    for _, r in ipairs(rows) do
        if y + rh > L.startBtn.y - u(8) then break end
        lg.setColor(InvState.rarityColor(r.def))
        lg.print(r.def.name .. (r.n > 1 and ("  x" .. r.n) or ""), x, y)
        self.rowRects[#self.rowRects + 1] = { x = x, y = y, w = iw, h = rh, def = r.def }
        y = y + rh
    end

    -- start button
    local B = L.startBtn
    local hover = false
    local mx, my = love.mouse.getPosition()
    if mx >= B.x and mx <= B.x + B.w and my >= B.y and my <= B.y + B.h then hover = true end
    lg.setColor(c.focus[1], c.focus[2], c.focus[3], hover and 0.35 or 0.2)
    lg.rectangle("fill", B.x, B.y, B.w, B.h, u(3))
    lg.setColor(c.focus)
    lg.rectangle("line", B.x + 0.5, B.y + 0.5, B.w - 1, B.h - 1, u(3))
    lg.setFont(Theme.font("body", "bold"))
    lg.printf("START RUN", B.x, B.y + (B.h - lg.getFont():getHeight()) / 2, B.w, "center")

    if not require("src.core.touch").enabled() then
        Theme.footer({ { "Click", "Add" }, { "Right click", "Remove" }, { "Tab", "Start" }, { "Esc", "Back" } })
    end
end

return Loadout
