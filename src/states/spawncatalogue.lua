-- Spawn catalogue (sandbox): every enemy, queen and playable bug as a wall of live pictures,
-- so a test situation takes a few clicks instead of tapping through a long list.
-- Built from the content registries, so new bugs show up here the moment their file exists.
--
-- It sits over the paused arena. Tabs: Enemies (filter by family), Queens, Characters.
--   click picks a bug (it also becomes the sandbox's pick, so middle click spawns it),
--   click it again (or Enter / A) spawns it around you, or plays as it on Characters.
--   The chips on the right set variant (elite), amount and health; "Place" closes the
--   catalogue and every click / tap on the arena drops the bug there until you press Done.
-- Keys: arrows move, Q / E switch tab, F cycles family, / types a name, Esc / B closes.
local State = require("src.core.state")
local Input = require("src.core.input")
local Audio = require("src.core.audio")
local Theme = require("src.ui.theme")
local Content = require("src.content")
local Sprites = require("src.gfx.sprites")
local Families = require("src.config.families")
local Stats = require("src.game.stats")
local util = require("src.core.util")

local Cat = {}
Cat.__index = Cat

local lg = love.graphics

local TABS = {
    { id = "enemies", label = "Enemies" },
    { id = "queens", label = "Queens" },
    { id = "characters", label = "Characters" },
}

local COL = {
    socket = { 0.05, 0.042, 0.04 }, inner = { 0.085, 0.07, 0.065 }, frame = { 0.16, 0.12, 0.1 },
    label = { 0.86, 0.74, 0.55 }, dim = { 0.58, 0.52, 0.46 }, line = { 0.33, 0.25, 0.19 },
}

local HEALTH_SHORT = { [0.05] = "1 hit", [1000] = "Dummy" }

local function familyLabel(id)
    for _, f in ipairs(Families) do if f.id == id then return f.label end end
    return id or "Other"
end

local function familyOrder(id)
    for i, f in ipairs(Families) do if f.id == id then return i end end
    return #Families + 1
end

local function hit(r, x, y) return r and x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h end

-- opts.game: the running sandbox game (required); opts.tab: "enemies" | "queens" | "characters"
function Cat.new(opts)
    local self = setmetatable({ game = opts.game, t = 0, focus = 1, scroll = 0, search = nil, query = "", toasts = {} }, Cat)
    self.transparent = true
    self.world, self.sb = self.game.world, self.game.sandbox
    self.tab = 1
    for i, tb in ipairs(TABS) do if tb.id == opts.tab then self.tab = i end end
    -- family filter: only families that have enemies
    self.families = { { label = "All families" } }
    for _, f in ipairs(Families) do
        for _, def in ipairs(Content.enemies:all()) do
            if def.family == f.id and not def.boss then
                self.families[#self.families + 1] = { id = f.id, label = f.label }
                break
            end
        end
    end
    self.family = 1
    self:refilter(self:currentPick())
    return self
end

function Cat:enter() love.mouse.setVisible(true) end

function Cat:leave()
    if self.game.applyCursor then self.game:applyCursor() end
end

function Cat:kind() return TABS[self.tab].id end

-- The sandbox's current pick on this tab, so the catalogue opens on it.
function Cat:currentPick()
    local k = self:kind()
    local id = (k == "enemies" and self.sb.enemy) or (k == "queens" and self.sb.queen) or self.world.player.def.id
    return id and (k == "characters" and Content.characters:get(id) or Content.enemies:get(id))
end

function Cat:refilter(keep)
    keep = keep or (self.list and self.list[self.focus])
    local k, q = self:kind(), self.query:lower()
    local fam = self.families[self.family].id
    local list = {}
    local src = k == "characters" and Content.characters:all() or Content.enemies:all()
    for _, def in ipairs(src) do
        local ok = true
        if k == "enemies" then ok = not def.boss and (not fam or def.family == fam)
        elseif k == "queens" then ok = def.boss end
        if ok and q ~= "" then ok = def.name:lower():find(q, 1, true) or def.id:find(q, 1, true) end
        if ok then list[#list + 1] = def end
    end
    table.sort(list, function(a, b)
        if k == "characters" then
            if (a.order or 99) ~= (b.order or 99) then return (a.order or 99) < (b.order or 99) end
            return a.name < b.name
        end
        local fa, fb = familyOrder(a.family), familyOrder(b.family)
        if fa ~= fb then return fa < fb end
        local wa, wb = a.spawn and a.spawn.minWave or 0, b.spawn and b.spawn.minWave or 0
        if wa ~= wb then return wa < wb end
        return a.name < b.name
    end)
    self.list = list
    self.focus = math.max(1, math.min(util.indexOf(list, keep) or 1, #list))
    self.layoutCache = nil
end

----------------------------------------------------------------------------------------------
-- Layout: tabs on top, the picture wall on the left (a section per family), details right.

function Cat:layout()
    local w, h = lg.getDimensions()
    if self.layoutCache and self.layoutCache.w == w and self.layoutCache.h == h then return self.layoutCache end
    local u = Theme.u
    local L = { w = w, h = h }
    local margin = u(40)
    L.top = u(122)
    L.detail = { w = math.floor(math.min(u(400), w * 0.4)) }
    L.detail.x = w - margin - L.detail.w
    L.detail.y, L.detail.h = L.top, h - L.top - u(44)
    L.grid = { x = margin, y = L.top, w = L.detail.x - margin - u(24), h = L.detail.h }
    L.T = math.floor(u(66))
    L.gap = math.floor(u(8))
    L.cols = math.max(1, math.floor((L.grid.w + L.gap) / (L.T + L.gap)))
    L.tiles, L.heads = {}, {}
    local grouped = self:kind() ~= "characters"
    local y, col, group = 0, 0, nil
    local headH = math.floor(u(30))
    for i, def in ipairs(self.list) do
        if grouped and def.family ~= group then
            if col > 0 then y = y + L.T + L.gap end
            group, col = def.family, 0
            L.heads[#L.heads + 1] = { y = y, family = group }
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

function Cat:clampScroll()
    local L = self:layout()
    self.scroll = util.clamp(self.scroll, 0, math.max(0, L.contentH - L.grid.h))
end

function Cat:ensureVisible()
    local L = self:layout()
    local t = L.tiles[self.focus]
    if not t then return end
    local headH = Theme.u(30)
    if t.y - headH < self.scroll then self.scroll = t.y - headH end
    if t.y + L.T > self.scroll + L.grid.h then self.scroll = t.y + L.T - L.grid.h end
    self:clampScroll()
end

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
    self:pick(self.list[self.focus])
    Audio.play("ui_move")
    self:ensureVisible()
end

----------------------------------------------------------------------------------------------
-- Actions

function Cat:toast(text, color)
    self.toasts[#self.toasts + 1] = { text = text, color = color or Theme.colors.good, t = 0 }
    if #self.toasts > 4 then table.remove(self.toasts, 1) end
end

-- Focusing a bug also makes it the sandbox's pick (middle click, the Spawn tab rows).
function Cat:pick(def)
    if not def then return end
    local k = self:kind()
    if k == "enemies" then self.sb.enemy = def.id elseif k == "queens" then self.sb.queen = def.id end
end

function Cat:spawnAround(def)
    if not def then return end
    local sb, p = self.sb, self.world.player
    if self:kind() == "queens" then
        local a = love.math.random() * math.pi * 2
        sb:spawn(def.id, p.x + math.cos(a) * 150, p.y + math.sin(a) * 150)
        self:toast("+1 " .. def.name)
    else
        for i = 1, sb.amount do
            local a = (i / sb.amount) * math.pi * 2 + love.math.random() * 0.3
            local r = 130 + love.math.random() * 40
            sb:spawn(def.id, p.x + math.cos(a) * r, p.y + math.sin(a) * r, sb:pickElite())
        end
        self:toast(("+%d %s"):format(sb.amount, def.name))
    end
    Audio.play("ui_confirm")
end

function Cat:playAs(def)
    if not def then return end
    self.sb:setCharacter(def.id)
    self:toast("Playing as " .. def.name)
    Audio.play("equip")
end

-- Close and let clicks / taps on the arena drop this bug until Done.
function Cat:place(def)
    if not def then return end
    self.sb:startPlacing(def.id, self:kind() == "queens")
    State.pop()
end

-- The main action for the bug in focus (double click, Enter).
function Cat:activate(def)
    if self:kind() == "characters" then self:playAs(def) else self:spawnAround(def) end
end

-- Option rows (enemies only): { label, options = { { value, label } }, get, set }
function Cat:optionRows()
    local sb = self.sb
    if self:kind() ~= "enemies" then return {} end
    local variants = { { "none", "Normal" }, { "random", "Random elite" } }
    for _, el in ipairs(Content.elites:all()) do variants[#variants + 1] = { el.id, el.name } end
    local amounts = {}
    for _, n in ipairs({ 1, 5, 10, 25, 50, 100 }) do amounts[#amounts + 1] = { n, tostring(n) } end
    local health = {}
    for _, hp in ipairs(sb.HEALTH) do health[#health + 1] = { hp[1], HEALTH_SHORT[hp[1]] or hp[2] } end
    return {
        { label = "Variant", options = variants, get = function() return sb.elite end, set = function(v) sb.elite = v end },
        { label = "Amount", options = amounts, get = function() return sb.amount end, set = function(v) sb.amount = v end },
        { label = "Health", options = health, get = function() return sb.hpMul end, set = function(v) sb.hpMul = v end },
    }
end

function Cat:buttons()
    local def = self.list[self.focus]
    local k = self:kind()
    if k == "characters" then
        return { { label = "Play as", fn = function() self:playAs(def) end, wide = true } }
    end
    local btns = {
        { label = "Spawn here", fn = function() self:spawnAround(def) end },
        { label = "Place", fn = function() self:place(def) end },
    }
    if k == "enemies" then
        btns[#btns + 1] = { label = "March in", fn = function()
            self.world.spawner:spawnGroup(def, self.sb.amount)
            self:toast(("%d %s marching in"):format(self.sb.amount, def.name))
        end }
        btns[#btns + 1] = { label = "All elites", fn = function()
            local els, p = Content.elites:all(), self.world.player
            for i, el in ipairs(els) do
                local a = i / #els * math.pi * 2
                self.sb:spawn(def.id, p.x + math.cos(a) * 110, p.y + math.sin(a) * 110, el.id)
            end
            self:toast(("+%d elite %s"):format(#els, def.name))
        end }
    end
    return btns
end

----------------------------------------------------------------------------------------------
-- Input

function Cat:close()
    Audio.play("ui_back")
    State.pop()
end

function Cat:setTab(i)
    self.tab = (i - 1) % #TABS + 1
    self.scroll = 0
    self:refilter(self:currentPick())
    self:ensureVisible()
    Audio.play("ui_move")
end

function Cat:setFamily(i)
    self.family = (i - 1) % #self.families + 1
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
    if self.search or self.skipFrame then self.skipFrame = nil return end
    if Input.pressed("ui_back") then return self:close() end
    if Input.pressed("ui_left") then self:step(-1, 0) end
    if Input.pressed("ui_right") then self:step(1, 0) end
    if Input.pressed("ui_up") then self:step(0, -1) end
    if Input.pressed("ui_down") then self:step(0, 1) end
    if Input.pressed("ui_tab_next") then self:setTab(self.tab + 1) end
    if Input.pressed("ui_tab_prev") then self:setTab(self.tab - 1) end
    if Input.pressed("ui_confirm") then self:activate(self.list[self.focus]) end
end

function Cat:keypressed(key)
    if self.search then
        if key == "escape" or key == "return" or key == "kpenter" then
            self.search = nil
            self.skipFrame = true
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
    elseif key == "f" and self:kind() == "enemies" then
        self:setFamily(self.family + (love.keyboard.isDown("lshift", "rshift") and -1 or 1))
    end
end

function Cat:mousemoved() end

function Cat:mousepressed(x, y, b)
    for i, r in ipairs(self.tabRects or {}) do
        if hit(r, x, y) then return self:setTab(i) end
    end
    if self:kind() == "enemies" and hit(self.familyRect, x, y) then
        return self:setFamily(self.family + (b == 2 and -1 or 1))
    end
    if hit(self.searchRect, x, y) then
        if b == 2 then self.query = ""; self:refilter() end
        self.search = true
        return
    end
    if hit(self.closeRect, x, y) then return self:close() end
    self.search = nil
    for _, c in ipairs(self.chipRects or {}) do
        if hit(c, x, y) then
            if c.cycle then
                -- the left half of a compact chip steps back, the right half forward
                local n = #c.row.options
                local i = (c.cycle - 1 + ((x < c.x + c.w / 2 or b == 2) and -1 or 1)) % n + 1
                c.row.set(c.row.options[i][1])
            else
                c.row.set(c.value)
            end
            Audio.play("ui_move")
            return
        end
    end
    for _, btn in ipairs(self.btnRects or {}) do
        if hit(btn, x, y) then
            Audio.play("ui_confirm")
            return btn.fn()
        end
    end
    local i = self:tileAt(x, y)
    if not i or b ~= 1 then return end
    local def = self.list[i]
    if i == self.focus and self.lastClick and self.t - self.lastClick < 0.6 then
        self:activate(def)
        self.lastClick = nil
        return
    elseif i ~= self.focus then
        Audio.play("ui_move")
    end
    self.focus = i
    self:pick(def)
    self.lastClick = self.t
end

function Cat:wheelmoved(_, dy)
    local L = self:layout()
    self.scroll = self.scroll - dy * (L.T + L.gap)
    self:clampScroll()
end

----------------------------------------------------------------------------------------------
-- Drawing

local function chip(x, y, text, on, color, minW)
    local u = Theme.u
    local f = lg.getFont()
    local w, h = math.max(minW or 0, f:getWidth(text) + u(20)), f:getHeight() + u(10)
    lg.setColor(on and { 0.2, 0.15, 0.12, 1 } or { 0.1, 0.08, 0.075, 0.9 })
    lg.rectangle("fill", x, y, w, h)
    local c = color or COL.label
    lg.setColor(c[1], c[2], c[3], on and 1 or 0.3)
    lg.rectangle("fill", x, y + h - 2, w, 2)
    lg.setColor(on and c or COL.dim)
    lg.printf(text, x, y + u(5), w, "center")
    return { x = x, y = y, w = w, h = h }
end

-- A bug's picture fitted into a w x h box, facing up and slowly walking.
local function bugPicture(def, cx, cy, size, t, turning)
    local spr = Sprites.get(def.sprite)
    local s = size / math.max(spr.w, spr.h or spr.w)
    local frame = math.floor(t * (spr.fps or 8)) + 1
    lg.setColor(1, 1, 1, 1)
    if turning and def.model then
        Sprites.drawModel(def.model, frame, cx, cy, math.pi * 0.25 + math.sin(t * 0.7) * 1.4, false, s * 1.2, s * 1.2)
    else
        Sprites.draw(spr, frame, cx, cy, turning and (t * 0.8) or -math.pi / 2, false, s)
    end
end

function Cat:drawTile(def, x, y, T, focused, hover)
    lg.setColor(COL.socket)
    lg.rectangle("fill", x, y, T, T)
    lg.setColor(0, 0, 0, 0.5)
    lg.rectangle("fill", x, y, T, 2)
    lg.rectangle("fill", x, y, 2, T)
    local c = focused and Theme.colors.focus or COL.line
    lg.setColor(c[1], c[2], c[3], focused and 1 or 0.7)
    lg.setLineWidth(focused and 2 or 1)
    lg.rectangle("line", x + 0.5, y + 0.5, T - 1, T - 1)
    lg.setLineWidth(1)
    local sx, sy, sw, sh = lg.getScissor()
    lg.intersectScissor(x + 2, y + 2, T - 4, T - 4)
    -- tiles stand still; the one under the mouse or in focus walks
    bugPicture(def, x + T / 2, y + T / 2, T * 0.78, (focused or hover) and self.t or 0, false)
    lg.setScissor(sx, sy, sw, sh)
end

-- Lay out the option chips from y; draws them (and records their rects) unless dry.
-- compact (small screens): one "< value >" chip per row that steps through the options.
function Cat:flowChips(rows, x, w, y, dry, compact)
    local u = Theme.u
    lg.setFont(Theme.font(13))
    local fh = lg.getFont():getHeight()
    if compact then
        for _, row in ipairs(rows) do
            if not dry then
                local cur, idx = row.get(), 1
                for i, o in ipairs(row.options) do if o[1] == cur then idx = i end end
                lg.setColor(COL.dim)
                lg.print(row.label, x, y + u(5))
                local r = chip(x + w * 0.3, y, "< " .. row.options[idx][2] .. " >", true, Theme.colors.accent, w * 0.7)
                r.row, r.cycle = row, idx
                self.chipRects[#self.chipRects + 1] = r
            end
            y = y + fh + u(14)
        end
        return y
    end
    for _, row in ipairs(rows) do
        if not dry then
            lg.setColor(COL.dim)
            lg.print(row.label, x, y)
        end
        y = y + fh + u(3)
        local cx = x
        local cur = row.get()
        for _, o in ipairs(row.options) do
            local tw = lg.getFont():getWidth(o[2]) + u(20)
            if cx + tw > x + w and cx > x then cx = x; y = y + fh + u(14) end
            if not dry then
                local r = chip(cx, y, o[2], cur == o[1], Theme.colors.accent)
                r.row, r.value = row, o[1]
                self.chipRects[#self.chipRects + 1] = r
            end
            cx = cx + tw + u(4)
        end
        y = y + fh + u(18)
    end
    return y
end

function Cat:drawDetails(def, D)
    local u = Theme.u
    Theme.panel(D.x, D.y, D.w, D.h)
    self.chipRects, self.btnRects = {}, {}
    if not def then
        lg.setFont(Theme.font(16))
        lg.setColor(COL.dim)
        lg.printf("Nothing matches.", D.x, D.y + D.h / 2 - u(10), D.w, "center")
        return
    end
    local k = self:kind()
    local x, w = D.x + u(16), D.w - u(32)

    -- buttons at the bottom
    local btns = self:buttons()
    local bh = math.floor(u(34))
    local perRow = #btns > 2 and 2 or #btns
    local rowsN = math.ceil(#btns / perRow)
    local by0 = D.y + D.h - u(12) - rowsN * bh - (rowsN - 1) * u(6)
    lg.setFont(Theme.font(15, "bold"))
    local mx, my = love.mouse.getPosition()
    local bw = math.floor((w - u(6) * (perRow - 1)) / perRow)
    for i, btn in ipairs(btns) do
        local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
        local r = { x = x + col * (bw + u(6)), y = by0 + row * (bh + u(6)), w = bw, h = bh, fn = btn.fn }
        lg.setColor(hit(r, mx, my) and { 0.26, 0.19, 0.13, 1 } or COL.frame)
        lg.rectangle("fill", r.x, r.y, r.w, r.h)
        lg.setColor(i == 1 and Theme.colors.focus or COL.label)
        lg.rectangle("fill", r.x, r.y + r.h - 2, r.w, 2)
        lg.printf(btn.label, r.x, r.y + math.floor((bh - lg.getFont():getHeight()) / 2), r.w, "center")
        self.btnRects[#self.btnRects + 1] = r
    end

    -- what has to fit above the buttons: name, facts, chips; the picture and the
    -- description take whatever room is left
    local rows = self:optionRows()
    local textH = u(52)
    local chipsH = self:flowChips(rows, x, w, 0, true)
    local compact = by0 - D.y - u(56) - textH - chipsH < 0
    if compact then chipsH = self:flowChips(rows, x, w, 0, true, true) end
    local room = by0 - D.y - u(20) - textH - chipsH
    lg.setFont(Theme.font(14))
    -- characters: what each button does, under the stats
    local moves = {}
    if k == "characters" then
        local touch = Input.lastDevice == "touch"
        local function move(key, touchKey, spec, reg, fallback)
            local t = spec and reg:get(spec.type)
            if t or fallback then moves[#moves + 1] = { (touch and touchKey or key), t and (t.name or spec.type) or fallback } end
        end
        move("Left click", "Attack", def.attack, Content.attacks)
        move("Right click", "Special", def.secondary, Content.attacks)
        move("Shift", "Dash", def.dash or { type = "dash" }, Content.dashes)
    end
    local movesH = #moves * u(20) + (#moves > 0 and u(8) or 0)
    room = room - movesH
    -- the whole description if it fits, else its first sentence, else nothing
    local desc, descH = nil, 0
    local fh = lg.getFont():getHeight()
    local full = def.description or ""
    for _, text in ipairs({ full, full:match("^(.-[%.!?])%s") or "" }) do
        if text ~= "" then
            local _, lines = lg.getFont():getWrap(text, w)
            local hgt = #lines * fh + u(10)
            if room - hgt >= u(70) then desc, descH = text, hgt break end
        end
    end
    local stageH = math.floor(util.clamp(room - descH, u(36), math.min(u(140), D.h * 0.3)))
    local cx, cy = D.x + D.w / 2, D.y + u(10) + stageH / 2
    lg.setColor(0.2, 0.19, 0.17, 0.8)
    lg.ellipse("fill", cx, cy + stageH * 0.22, stageH * 0.75, stageH * 0.22)
    bugPicture(def, cx, cy, stageH * 0.8, self.t, true)
    local y = D.y + u(14) + stageH

    lg.setFont(Theme.font(22, "bold"))
    Theme.printShadow(def.name, D.x, y, Theme.colors.text, "center", D.w)
    y = y + u(28)
    lg.setFont(Theme.font(14))
    local facts
    if k == "characters" then
        local st = Stats.new(def.stats)
        facts = ("%d HP  ·  speed %d"):format(st:get("maxHp"), st:get("moveSpeed"))
    else
        facts = ("%s  ·  %d HP  ·  speed %d  ·  bite %s"):format(familyLabel(def.family), def.hp, def.speed, tostring(def.damage))
    end
    lg.setColor(Theme.colors.accent)
    lg.printf(facts, D.x, y, D.w, "center")
    y = y + u(24)
    if desc then
        lg.setColor(COL.dim)
        lg.printf(desc, x, y, w, "center")
        y = y + descH
    end
    for _, m in ipairs(moves) do
        lg.setColor(COL.dim)
        lg.printf(m[1], x, y, w / 2 - u(6), "right")
        lg.setColor(COL.label)
        lg.print(m[2], x + w / 2 + u(6), y)
        y = y + u(20)
    end
    self:flowChips(rows, x, w, y, false, compact)
    if k == "characters" and def.id == self.world.player.def.id then
        lg.setFont(Theme.font(14))
        lg.setColor(Theme.colors.good)
        lg.printf("Playing now", D.x, by0 - u(24), D.w, "center")
    end
end

function Cat:draw()
    local w, h = lg.getDimensions()
    local u = Theme.u
    local L = self:layout()
    lg.setColor(0.03, 0.025, 0.03, 0.93)
    lg.rectangle("fill", 0, 0, w, h)

    -- tabs, family, search, close on one strip
    lg.setFont(Theme.font(17, "bold"))
    local tx, ty = u(40), u(30)
    self.tabRects = {}
    for i, tab in ipairs(TABS) do
        local r = chip(tx, ty, tab.label, i == self.tab, Theme.colors.focus)
        self.tabRects[i] = r
        tx = tx + r.w + u(6)
    end
    lg.setFont(Theme.font(15))
    local fy = ty + u(46)
    local fx = u(40)
    if self:kind() == "enemies" then
        self.familyRect = chip(fx, fy, "< " .. self.families[self.family].label .. " >", self.family > 1, Theme.colors.accent)
        fx = fx + self.familyRect.w + u(10)
    else
        self.familyRect = nil
    end
    local searchText = (self.query ~= "" or self.search) and (self.query .. (self.search and math.floor(self.t * 2) % 2 == 0 and "_" or "")) or "Search"
    self.searchRect = chip(fx, fy, searchText, self.search or self.query ~= "", Theme.colors.text, u(140))
    lg.setFont(Theme.font(17, "bold"))
    local cw = lg.getFont():getWidth("Close") + u(20)
    self.closeRect = chip(w - u(40) - cw, ty, "Close", false, COL.label)

    -- the picture wall
    local G = L.grid
    lg.setScissor(G.x - 4, G.y - 4, G.w + 8, G.h + 8)
    lg.setFont(Theme.font(15, "bold"))
    for _, hd in ipairs(L.heads) do
        local y = G.y + hd.y - self.scroll
        if y > G.y - u(40) and y < G.y + G.h then
            local n = 0
            for _, d in ipairs(self.list) do if d.family == hd.family then n = n + 1 end end
            lg.setColor(COL.label)
            lg.print(familyLabel(hd.family):upper() .. "  " .. n, G.x, y + u(4))
            lg.setColor(COL.label[1], COL.label[2], COL.label[3], 0.2)
            lg.rectangle("fill", G.x, y + u(24), G.w, 1)
        end
    end
    local mx, my = love.mouse.getPosition()
    local hover = self:tileAt(mx, my)
    for i, t in ipairs(L.tiles) do
        local x, y = G.x + t.x, G.y + t.y - self.scroll
        if y + L.T >= G.y - 4 and y <= G.y + G.h + 4 then
            self:drawTile(self.list[i], x, y, L.T, i == self.focus, i == hover)
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
        lg.print("Nothing matches.", G.x, G.y + u(10))
    end

    self:drawDetails(self.list[self.focus], L.detail)

    -- one short hint line (none on touch: the buttons say it)
    if Input.lastDevice ~= "touch" then
        lg.setFont(Theme.font(13))
        lg.setColor(COL.dim)
        local hint = Input.lastDevice == "gamepad" and "D-pad: browse  ·  LB / RB: tab  ·  A: spawn  ·  B: back"
            or self:kind() == "characters" and "Click twice: play as  ·  Q / E: tab  ·  /: search  ·  Esc: back"
            or ("Click twice: spawn  ·  Q / E: tab  ·  " .. (self:kind() == "enemies" and "F: family  ·  " or "") .. "/: search  ·  Esc: back")
        lg.printf(hint, 0, h - u(28), L.grid.x * 2 + L.grid.w, "center")
    end

    lg.setFont(Theme.font(16, "bold"))
    for i, f in ipairs(self.toasts) do
        local a = math.min(1, (2.2 - f.t) * 2)
        Theme.printShadow(f.text, 0, h - u(56) - (#self.toasts - i) * u(20), { f.color[1], f.color[2], f.color[3], a }, "center", L.grid.x * 2 + L.grid.w)
    end
    lg.setColor(1, 1, 1, 1)
end

return Cat
