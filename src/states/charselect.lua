-- Character select, generated from content/characters.
--
-- Layout: family tabs on top (All, Favourites, Beetles, Spiders ... Custom, src/config/bugfamilies.lua),
-- a wall of bug portraits on the left (in "All" a section per family, favourites pinned in their
-- own section first), and the highlighted bug's details on the right: a live preview of its moves,
-- its stats, its rule and the danger level picker. Sort and playstyle filter sit top right.
--
-- Controls: arrows / D-pad browse, Q/E (LB/RB) switch family, Enter (A) plays, F (X) favourites,
-- Z/X (Y) changes danger, T (L-stick) sorts, G (R-stick) filters by playstyle. Mouse: hover
-- highlights, click plays. Touch: the first tap shows a bug, a second tap plays it.
local State = require("src.core.state")
local Content = require("src.content")
local Music = require("src.core.music")
local Theme = require("src.ui.theme")
local Menu = require("src.ui.menu")
local Sprites = require("src.gfx.sprites")
local Stats = require("src.game.stats")
local Input = require("src.core.input")
local Audio = require("src.core.audio")
local Prefs = require("src.game.prefs")
local Playstyles = require("src.config.playstyles")
local Families = require("src.config.bugfamilies")
local MovePreview = require("src.ui.movepreview")
local Unlocks = require("src.game.unlocks")
local Danger = require("src.config.danger")
local BugRules = require("src.config.bugrules")
local util = require("src.core.util")

local lg = love.graphics

local CharSelect = {}
CharSelect.__index = CharSelect

-- "Name  ·  12 dmg every 0.5s". Every number is optional: moves like flight, runs or
-- charged attacks may have no flat damage or cooldown, and the panel must never crash on them.
local function moveLine(registry, cfg)
    local def = registry:get(cfg.type)
    local text = cfg.name or (def and def.name) or cfg.type or "?"     -- (scripted moves name themselves)
    local parts = {}
    if type(cfg.damage) == "number" then parts[#parts + 1] = cfg.damage .. " dmg" end
    if type(cfg.cooldown) == "number" then parts[#parts + 1] = "every " .. cfg.cooldown .. "s" end
    if #parts > 0 then text = text .. "  ·  " .. table.concat(parts, " ") end
    return text
end

local FAV_COLOR = { 0.98, 0.74, 0.27 }

-- opts: gameMode (content/modes id, from the mode select screen)
function CharSelect.new(opts)
    local self = setmetatable({ t = 0, focusT = 0, scroll = 0, tabScroll = 0, focus = 1, list = {} }, CharSelect)
    self.gameMode = opts and opts.gameMode or "colony"
    self.mode = Content.modes:get(self.gameMode)
    local prefs = Prefs.get()
    self.sort = Playstyles.sortById[prefs.sort] and prefs.sort or "default"
    -- `filter` used to hold "favourites" / "custom" too (before family tabs): those became tabs
    local f = prefs.filter or "all"
    self.tab = prefs.bugTab or "all"
    if f == "favourites" or f == "custom" then self.tab, f = f, "all" end
    self.style = (f == "all" or Playstyles.byId[f]) and f or "all"
    self:build(prefs.last and prefs.last.character)
    return self
end

----------------------------------------------------------------------------------------------
-- What is listed

-- The tabs: All, Favourites, then every family that has a bug in it.
function CharSelect:tabs()
    local have = {}
    for _, def in ipairs(Content.characters:all()) do have[Families.of(def).id] = true end
    local out = { { id = "all", label = "All" }, { id = "favourites", label = "Favourites", color = FAV_COLOR } }
    for _, fam in ipairs(Families.list) do
        if have[fam.id] then out[#out + 1] = { id = fam.id, label = fam.label, color = fam.color, family = fam } end
    end
    return out
end

-- The section a bug is listed under: its family, or "favourites" when pinned (All tab only).
function CharSelect:sectionOf(def)
    if self.tab == "all" and Prefs.isFavourite(def.id) then return "favourites" end
    return Families.of(def).id
end

-- The bugs shown, in order: filtered by tab and playstyle, grouped into a section per family
-- (in All, favourites get their own section first), favourites first, then sorted.
function CharSelect:entries()
    local sort = Playstyles.sortById[self.sort]
    local out = {}
    for i, def in ipairs(Content.characters:all()) do
        local fam = Families.of(def)
        local fav = Prefs.isFavourite(def.id)
        local keep = (self.tab == "all") or (self.tab == "favourites" and fav) or (fam.id == self.tab)
        if keep and self.style ~= "all" and def.playstyle ~= self.style then keep = false end
        if keep then
            local sec = (self.tab == "all" and fav) and 0 or fam.order
            out[#out + 1] = { def = def, i = i, fav = fav, sec = sec, section = self:sectionOf(def) }
        end
    end
    table.sort(out, function(a, b)
        if a.sec ~= b.sec then return a.sec < b.sec end
        if a.fav ~= b.fav then return a.fav end
        if sort and sort.value then
            local va, vb = sort.value(a.def), sort.value(b.def)
            if va ~= vb then
                if sort.ascending then return va < vb end
                return va > vb
            end
        end
        return a.i < b.i
    end)
    return out
end

-- (Re)build the list, keeping the focus on `focusId` (a character id) or the bug it was on.
function CharSelect:build(focusId)
    local keep = focusId or (self:focused() and self:focused().id)
    self.list = self:entries()
    self.focus = 1
    for i, e in ipairs(self.list) do if e.def.id == keep then self.focus = i end end
    self.layoutCache = nil
    self:ensureVisible(true)
end

-- The highlighted bug (a character def), or nil when nothing is listed.
function CharSelect:focused()
    local e = self.list and self.list[self.focus]
    return e and e.def
end

-- Highlight a bug by id (switching to "All" if it isn't in this tab). Returns true if found.
function CharSelect:focusOn(id)
    for i, e in ipairs(self.list) do
        if e.def.id == id then
            self.focus = i
            self:ensureVisible()
            return true
        end
    end
    if self.tab ~= "all" or self.style ~= "all" then
        self.tab, self.style = "all", "all"
        self:build(id)
        return self:focused() ~= nil and self:focused().id == id
    end
    return false
end

function CharSelect:setTab(id)
    if id == self.tab then return end
    self.tab = id
    Prefs.set("bugTab", id)
    self.scroll = 0
    self:build()
    self.tabFollow = true
    Audio.play("ui_move")
end

function CharSelect:shiftTab(dir)
    local tabs = self:tabs()
    local cur = 1
    for i, t in ipairs(tabs) do if t.id == self.tab then cur = i end end
    self:setTab(tabs[(cur - 1 + dir) % #tabs + 1].id)
end

function CharSelect:setSort(id)
    self.sort = Playstyles.sortById[id] and id or "default"
    Prefs.set("sort", self.sort)
    self:build()
    Audio.play("ui_move")
end

function CharSelect:setStyle(id)
    self.style = (id == "all" or Playstyles.byId[id]) and id or "all"
    Prefs.set("filter", self.style)
    self.scroll = 0
    self:build()
    Audio.play("ui_move")
end

-- Step through a list of { id } rows.
local function cycle(rows, cur, dir)
    local at = 1
    for i, r in ipairs(rows) do if r.id == cur then at = i end end
    return rows[(at - 1 + dir) % #rows + 1].id
end

function CharSelect:cycleSort(dir) self:setSort(cycle(Playstyles.sorts, self.sort, dir or 1)) end

function CharSelect:cycleStyle(dir)
    local rows = { { id = "all" } }
    for _, s in ipairs(Playstyles.styles) do rows[#rows + 1] = s end
    self:setStyle(cycle(rows, self.style, dir or 1))
end

----------------------------------------------------------------------------------------------
-- Danger and picking

-- The danger level picked for a bug (remembered per bug, never above what it has earned).
function CharSelect.danger(id)
    local d = Prefs.get().danger
    local v = type(d) == "table" and tonumber(d[id]) or 0
    return math.max(0, math.min(v or 0, Unlocks.maxDanger(id)))
end

-- dir: -1 / 1; wrap = true goes back to 0 past the highest open level (one-button pads)
function CharSelect:shiftDanger(def, dir, wrap)
    if not Unlocks.bug(def.id) then return end
    local cur, max = CharSelect.danger(def.id), Unlocks.maxDanger(def.id)
    local v = math.max(0, math.min(max, cur + dir))
    if v == cur and wrap and cur > 0 then v = 0 end
    if v == cur then
        if dir > 0 and cur < Danger.MAX then self.dangerFlashT = 1.2 end
        Audio.play("ui_back")
        return
    end
    local d = Prefs.get().danger
    if type(d) ~= "table" then d = {} end
    d[def.id] = v
    Prefs.set("danger", d)
    Audio.play("ui_move", { pitch = 1 + v * 0.06 })
end

function CharSelect:pick(def)
    if not Unlocks.bug(def.id) then
        self.lockFlashT = 1
        Audio.play("ui_back")
        return
    end
    Audio.play("ui_confirm")
    local params = { mode = "run", character = def.id, gameMode = self.gameMode, danger = CharSelect.danger(def.id) }
    if self.mode and self.mode.chooseItems then
        State.push(require("src.states.loadout").new(params, self.mode.chooseItems))
    else
        State.switch(require("src.states.game").new(params))
    end
end

function CharSelect:toggleFavourite(def)
    Prefs.toggleFavourite(def.id)
    Audio.play("ui_confirm", { pitch = 1.2 })
    self:build(def.id)
end

----------------------------------------------------------------------------------------------
-- Layout

function CharSelect:layout()
    local w, h = lg.getDimensions()
    local L = self.layoutCache
    if L and L.w == w and L.h == h then return L end
    local u = Theme.u
    L = { w = w, h = h }
    L.margin = math.floor(u(48))
    L.tabY = math.floor(u(100))
    L.top = math.floor(u(146))
    L.bottom = h - math.floor(u(58))
    -- the details panel: a fixed share of the width on the right
    L.detail = { w = math.floor(math.min(u(470), math.max(w * 0.4, math.min(u(320), w * 0.46)))) }
    L.detail.x = w - L.margin - L.detail.w
    L.detail.y, L.detail.h = L.top, L.bottom - L.top
    L.grid = { x = L.margin, y = L.top, w = L.detail.x - L.margin - math.floor(u(28)), h = L.bottom - L.top }
    -- tiles stretch to fill the row exactly
    L.gap = math.floor(u(8))
    local want = u(104)
    L.cols = math.max(2, math.floor((L.grid.w + L.gap) / (want + L.gap)))
    L.TW = math.floor((L.grid.w - (L.cols - 1) * L.gap) / L.cols)
    L.TH = math.floor(L.TW * 1.02)
    L.headH = math.floor(u(32))
    -- tiles and section headers, in scroll space
    L.tiles, L.heads = {}, {}
    local y, col, sec = 0, 0, nil
    local sections = true
    for i, e in ipairs(self.list) do
        if sections and e.section ~= sec then
            if col > 0 then y = y + L.TH + L.gap end
            sec, col = e.section, 0
            L.heads[#L.heads + 1] = { y = y, key = sec }
            y = y + L.headH
        end
        L.tiles[i] = { x = col * (L.TW + L.gap), y = y }
        col = col + 1
        if col >= L.cols then col = 0; y = y + L.TH + L.gap end
    end
    L.contentH = y + (col > 0 and L.TH or 0)
    self.layoutCache = L
    return L
end

function CharSelect:maxScroll()
    local L = self:layout()
    return math.max(0, L.contentH - L.grid.h)
end

function CharSelect:ensureVisible(snap)
    local L = self:layout()
    local t = L.tiles[self.focus]
    if not t then self.scroll = 0 return end
    -- keep the section heading above the first row of a section in view too
    local top = t.y
    for _, hd in ipairs(L.heads) do if hd.y + L.headH == t.y then top = hd.y end end
    if top < self.scroll then self.scroll = top end
    if t.y + L.TH > self.scroll + L.grid.h then self.scroll = t.y + L.TH - L.grid.h end
    self.scroll = util.clamp(self.scroll, 0, self:maxScroll())
    if snap then self.scrollShown = self.scroll end
end

function CharSelect:tileAt(mx, my)
    local L = self:layout()
    local G = L.grid
    if mx < G.x or mx > G.x + G.w or my < G.y or my > G.y + G.h then return nil end
    local sc = self.scrollShown or self.scroll
    for i, t in ipairs(L.tiles) do
        local x, y = G.x + t.x, G.y + t.y - sc
        if mx >= x and mx < x + L.TW and my >= y and my < y + L.TH then return i end
    end
end

-- Move the focus by a grid step: left / right one tile, up / down a row keeping the column.
function CharSelect:step(dx, dy)
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
-- Update

function CharSelect:update(dt)
    self.t = self.t + dt
    if Input.pressed("ui_back") then
        Audio.play("ui_back")
        State.pop()
        return
    end
    if Input.pressed("ui_left") then self:step(-1, 0) end
    if Input.pressed("ui_right") then self:step(1, 0) end
    if Input.pressed("ui_up") then self:step(0, -1) end
    if Input.pressed("ui_down") then self:step(0, 1) end
    if Input.pressed("ui_tab_next") then self:shiftTab(1) end
    if Input.pressed("ui_tab_prev") then self:shiftTab(-1) end
    if Input.pressed("ui_sort") then self:cycleSort(1) end
    if Input.pressed("ui_style") then self:cycleStyle(1) end
    local def = self:focused()
    if def then
        if Input.pressed("ui_confirm") then self:pick(def) return end
        -- favourite the highlighted bug (F / pad X, or a click on the star in the panel)
        if Input.pressed("ui_favourite") then self:toggleFavourite(def) end
        if Input.pressed("ui_danger_down") then self:shiftDanger(def, -1) end
        if Input.pressed("ui_danger_up") then self:shiftDanger(def, 1, Input.lastDevice == "gamepad") end
    end
    if self.lockFlashT then self.lockFlashT = self.lockFlashT > 0 and self.lockFlashT - dt or nil end
    if self.dangerFlashT then self.dangerFlashT = self.dangerFlashT > 0 and self.dangerFlashT - dt or nil end
    -- smooth scrolling
    self.scrollShown = self.scrollShown or self.scroll
    self.scrollShown = self.scrollShown + (self.scroll - self.scrollShown) * math.min(1, dt * 14)
    if math.abs(self.scroll - self.scrollShown) < 0.5 then self.scrollShown = self.scroll end
    -- the menu music picks up the highlighted bug's signature tune (src/core/music.lua)
    Music.preview(def)
    -- the live move preview starts once a bug has stayed highlighted for a moment
    if def ~= self.focusDef then
        self.focusDef, self.focusT = def, 0
    else
        self.focusT = self.focusT + dt
    end
    if self.preview and (not def or self.preview.id ~= def.id) then
        self.preview:release()
        self.preview = nil
    end
    if def and not self.preview and self.focusT > 0.3 and not CharSelect.noPreview then
        local ok, pv = pcall(MovePreview.new, def.id)
        if ok then self.preview = pv else print("[charselect] preview failed: " .. tostring(pv)) CharSelect.noPreview = true end
    end
    if self.preview then self.preview:update(dt) end
end

function CharSelect:leave()
    if self.preview then self.preview:release() self.preview = nil end
end

----------------------------------------------------------------------------------------------
-- Drawing

-- A flat chip: tabs and the sort / filter buttons. Returns its rect.
local function chip(x, y, text, on, color, h, inset)
    local u = Theme.u
    local f = lg.getFont()
    inset = inset or 0
    local w = f:getWidth(text) + math.floor(u(22)) + inset
    h = h or (f:getHeight() + math.floor(u(10)))
    lg.setColor(on and { 0.2, 0.15, 0.12, 1 } or { 0.1, 0.08, 0.075, 0.9 })
    lg.rectangle("fill", x, y, w, h)
    local c = color or Theme.colors.accent
    lg.setColor(c[1], c[2], c[3], on and 1 or 0.35)
    lg.rectangle("fill", x, y + h - 2, w, 2)
    lg.setColor(on and (color or Theme.colors.text) or Theme.colors.dim)
    lg.print(text, x + math.floor(u(11)) + inset, y + math.floor((h - f:getHeight()) / 2))
    return { x = x, y = y, w = w, h = h }
end

-- A little padlock.
local function padlock(cx, cy, s, color)
    lg.setColor(color)
    lg.setLineWidth(math.max(1, s * 0.22))
    lg.arc("line", "open", cx, cy - s * 0.15, s * 0.42, math.pi, math.pi * 2)
    lg.line(cx - s * 0.42, cy - s * 0.15, cx - s * 0.42, cy + s * 0.1)
    lg.line(cx + s * 0.42, cy - s * 0.15, cx + s * 0.42, cy + s * 0.1)
    lg.setLineWidth(1)
    lg.rectangle("fill", cx - s * 0.62, cy + s * 0.05, s * 1.24, s * 0.9, s * 0.12)
    lg.setColor(0, 0, 0, 0.5)
    lg.rectangle("fill", cx - s * 0.07, cy + s * 0.3, s * 0.14, s * 0.35)
end

-- One bug in a tile: its body, turning a little when highlighted, a silhouette when locked.
local function drawBug(def, cx, cy, size, t, live, locked)
    local spr = Sprites.get(def.sprite)
    -- one scale for every bug (like in a run), a little bigger for big bugs; tiles clip the rest
    local s = size / 30 * (0.8 + 0.2 * math.min(1.5, def.scale or 1))
    local r = (def.radius or 7) * s
    lg.setColor(0, 0, 0, locked and 0.2 or 0.35)
    lg.ellipse("fill", cx, cy + s * 2, r * 1.6, r * 0.6)
    lg.setColor(1, 1, 1, 1)
    local angle = live and (math.pi * 0.25 + math.sin(t * 1.4) * 0.6) or math.pi * 0.25
    local frame = live and (math.floor(t * (spr.fps or 8)) + 1) or 1
    if def.model then
        Sprites.drawModel(def.model, frame, cx, cy, angle, false, s, s, 1,
            locked and { tint = { 0.07, 0.06, 0.055 } } or nil)
    else
        if locked then lg.setColor(0.07, 0.06, 0.055, 1) end
        Sprites.draw(spr, frame, cx, cy, -math.pi / 2, false, s)
    end
    lg.setColor(1, 1, 1, 1)
end

function CharSelect:drawTile(e, x, y, L, focused, hover)
    local u = Theme.u
    local def = e.def
    local TW, TH = L.TW, L.TH
    local fam = Families.of(def)
    local fc = fam.color
    local open = Unlocks.bug(def.id)
    local c = Theme.colors
    -- recessed socket tinted with the family colour
    lg.setColor(0.075, 0.062, 0.055, 1)
    lg.rectangle("fill", x, y, TW, TH)
    lg.setColor(fc[1] * 0.22, fc[2] * 0.22, fc[3] * 0.22, open and 0.75 or 0.35)
    lg.rectangle("fill", x + 2, y + 2, TW - 4, TH - 4)
    -- a soft floor glow behind the bug
    lg.setColor(fc[1], fc[2], fc[3], focused and 0.16 or 0.07)
    lg.ellipse("fill", x + TW / 2, y + TH * 0.44, TW * 0.4, TH * 0.24)
    lg.setColor(0, 0, 0, 0.5)
    lg.rectangle("fill", x, y, TW, 2)
    lg.rectangle("fill", x, y, 2, TH)
    -- the name strip (taller when the name needs two lines)
    local font = Theme.font("small", focused and "bold" or nil)
    local _, lines = font:getWrap(def.name, TW - u(8))
    local nl = math.min(2, #lines)
    local stripH = math.floor(nl * font:getHeight() + u(12))
    lg.setColor(0, 0, 0, 0.35)
    lg.rectangle("fill", x + 2, y + TH - stripH, TW - 4, stripH - 2)
    -- the bug
    local sx, sy, sw, sh = lg.getScissor()
    lg.intersectScissor(x, y, TW, TH - stripH)
    drawBug(def, x + TW / 2, y + (TH - stripH) * 0.56, TW * 0.62, self.t, focused, not open)
    lg.setScissor(sx, sy, sw, sh)
    if not open then padlock(x + TW / 2, y + (TH - stripH) * 0.5, u(11), { 0.75, 0.66, 0.55, 0.9 }) end
    -- name (two lines at most)
    lg.setFont(font)
    local ny = y + TH - stripH / 2 - nl * font:getHeight() / 2 - 1
    lg.setColor(focused and c.focus or open and c.text or c.dim)
    lg.printf(def.name, x + u(4), ny, TW - u(8), "center")
    -- favourite star, top right
    if e.fav then Menu.star(x + TW - u(12), y + u(12), u(6), c.focus) end
    -- mastery: one pip per danger level won, top left
    local best = open and Unlocks.bestDanger(def.id) or 0
    for i = 1, best do
        local dc = util.hex(Danger[i].color)
        lg.setColor(dc)
        lg.rectangle("fill", x + u(6) + (i - 1) * u(7), y + u(7), u(5), u(5))
    end
    -- the sort's number (Speed: 140), bottom right above the name
    local sort = Playstyles.sortById[self.sort]
    if open and sort and sort.show then
        lg.setFont(Theme.font("small"))
        local txt = sort.show(def)
        local f = lg.getFont()
        local tw = f:getWidth(txt)
        lg.setColor(0, 0, 0, 0.55)
        lg.rectangle("fill", x + TW - tw - u(10), y + TH - stripH - f:getHeight() - u(2), tw + u(8), f:getHeight())
        lg.setColor(c.key)
        lg.print(txt, x + TW - tw - u(6), y + TH - stripH - f:getHeight() - u(2))
    end
    -- rim: amber when highlighted, family colour on hover, faint otherwise
    if focused then
        lg.setColor(c.focus)
        lg.setLineWidth(2)
        lg.rectangle("line", x - 1, y - 1, TW + 2, TH + 2)
        lg.setLineWidth(1)
    else
        lg.setColor(fc[1], fc[2], fc[3], hover and 0.8 or (open and 0.3 or 0.15))
        lg.rectangle("line", x + 0.5, y + 0.5, TW - 1, TH - 1)
    end
    lg.setColor(1, 1, 1, 1)
end

function CharSelect:drawHeader(key, x, y, w)
    local u = Theme.u
    local c, label, blurb
    if key == "favourites" then
        c, label, blurb = FAV_COLOR, "Favourites", nil
    else
        local fam = Families.byId[key] or Families.byId.other
        c, label, blurb = fam.color, fam.label, fam.blurb
    end
    local n, open = 0, 0
    for _, e in ipairs(self.list) do
        if e.section == key then
            n = n + 1
            if Unlocks.bug(e.def.id) then open = open + 1 end
        end
    end
    local hx = x
    if key == "favourites" then
        Menu.star(x + u(7), y + u(13), u(7), c)
        hx = x + u(20)
    end
    lg.setFont(Theme.font(15, "bold"))
    lg.setColor(c)
    local head = label:upper() .. "  " .. (open < n and (open .. "/" .. n) or tostring(n))
    lg.print(head, hx, y + u(4))
    local hw = lg.getFont():getWidth(head)
    if blurb then
        lg.setFont(Theme.font("small"))
        local room = w - (hx - x) - hw - u(14)
        if lg.getFont():getWidth(blurb) <= room then
            lg.setColor(Theme.colors.dim)
            lg.print(blurb, hx + hw + u(14), y + u(5))
        end
    end
    lg.setColor(c[1], c[2], c[3], 0.25)
    lg.rectangle("fill", x, y + u(25), w, 1)
end

function CharSelect:drawTabs(L)
    local u = Theme.u
    lg.setFont(Theme.font(15))
    local tabs = self:tabs()
    -- measure, then scroll the row so the current tab is in view on narrow screens
    local f = lg.getFont()
    local widths, total, at = {}, 0, 0
    for i, t in ipairs(tabs) do
        widths[i] = f:getWidth(t.label) + math.floor(u(22)) + (t.id == "favourites" and math.floor(u(16)) or 0)
        if t.id == self.tab then at = total end
        total = total + widths[i] + math.floor(u(6))
    end
    local room = L.w - 2 * L.margin
    if total <= room then
        self.tabScroll = 0
    else
        local cur
        for i, t in ipairs(tabs) do if t.id == self.tab then cur = widths[i] end end
        if at < self.tabScroll then self.tabScroll = at end
        if at + (cur or 0) > self.tabScroll + room then self.tabScroll = at + (cur or 0) - room end
        self.tabScroll = util.clamp(self.tabScroll, 0, total - room)
    end
    lg.setScissor(L.margin - 2, L.tabY - 2, room + 4, u(40))
    local x = L.margin - self.tabScroll
    self.tabRects = {}
    for i, t in ipairs(tabs) do
        local on = t.id == self.tab
        local inset = t.id == "favourites" and math.floor(u(16)) or 0
        local r = chip(x, L.tabY, t.label, on, t.color or Theme.colors.focus, nil, inset)
        if inset > 0 then
            Menu.star(x + u(17), L.tabY + r.h / 2, u(6), on and FAV_COLOR or Theme.colors.dim)
        end
        r.id = t.id
        self.tabRects[#self.tabRects + 1] = r
        x = x + widths[i] + math.floor(u(6))
    end
    lg.setScissor()
    if total > room then
        -- fades at the cut edges
        local bg = Theme.colors.bg
        for k = 0, 7 do
            local a = (1 - k / 8) * 0.9
            lg.setColor(bg[1], bg[2], bg[3], a)
            if self.tabScroll > 0 then lg.rectangle("fill", L.margin + k * u(3), L.tabY, u(3), u(32)) end
            if self.tabScroll < total - room then lg.rectangle("fill", L.margin + room - (k + 1) * u(3), L.tabY, u(3), u(32)) end
        end
    end
end

-- Top right: how many bugs are open, then the sort and the playstyle filter (click to cycle).
function CharSelect:drawTools(L)
    local u = Theme.u
    lg.setFont(Theme.font(15))
    local f = lg.getFont()
    local sort = Playstyles.sortById[self.sort]
    local style = Playstyles.byId[self.style]
    local sortText = "Sort: " .. (sort and sort.label or "Default")
    local styleText = "Style: " .. (style and style.label or "Any")
    local y = math.floor(u(48))
    local x = L.w - L.margin
    local styleW = f:getWidth(styleText) + math.floor(u(22))
    local sortW = f:getWidth(sortText) + math.floor(u(22))
    x = x - styleW
    self.styleRect = chip(x, y, styleText, self.style ~= "all", Theme.colors.accent)
    x = x - math.floor(u(6)) - sortW
    self.sortRect = chip(x, y, sortText, self.sort ~= "default", Theme.colors.focus)
    local nOpen, nAll = Unlocks.bugCount()
    lg.setFont(Theme.font("small"))
    lg.setColor(Theme.colors.dim)
    local txt = nOpen < nAll and ("%d / %d bugs unlocked"):format(nOpen, nAll) or (nAll .. " bugs")
    local tw = lg.getFont():getWidth(txt)
    -- only when there is room beside the title
    lg.setFont(Theme.font("title"))
    local titleEnd = u(60) + lg.getFont():getWidth("CHOOSE YOUR BUG")
    lg.setFont(Theme.font("small"))
    if x - u(14) - tw > titleEnd + u(20) then
        lg.print(txt, x - u(14) - tw, y + math.floor((self.sortRect.h - lg.getFont():getHeight()) / 2))
    end
end

function CharSelect:draw()
    local w, h = lg.getDimensions()
    local u = Theme.u
    lg.clear(Theme.colors.bg)
    Theme.title("Choose your bug")
    local L = self:layout()
    self:drawTools(L)
    self:drawTabs(L)

    -- the wall of bugs
    local G = L.grid
    local sc = math.floor(self.scrollShown or self.scroll)
    lg.setScissor(G.x - 4, G.y - 4, G.w + 8, G.h + 8)
    for _, hd in ipairs(L.heads) do
        local y = G.y + hd.y - sc
        if y > G.y - L.headH - u(10) and y < G.y + G.h then self:drawHeader(hd.key, G.x, y, G.w) end
    end
    local mx, my = love.mouse.getPosition()
    local hover = Input.lastDevice ~= "touch" and self:tileAt(mx, my) or nil
    for i, t in ipairs(L.tiles) do
        local x, y = G.x + t.x, G.y + t.y - sc
        if y + L.TH >= G.y - 4 and y <= G.y + G.h + 4 then
            local focused = i == self.focus
            local lift = (focused or i == hover) and math.floor(u(2)) or 0
            self:drawTile(self.list[i], x, y - lift, L, focused, i == hover)
        end
    end
    lg.setScissor()
    if L.contentH > G.h then
        local bh = G.h * G.h / L.contentH
        local by = G.y + (G.h - bh) * (sc / (L.contentH - G.h))
        lg.setColor(1, 1, 1, 0.2)
        lg.rectangle("fill", G.x + G.w + u(10), by, 3, bh, 2, 2)
    end
    if #self.list == 0 then
        lg.setFont(Theme.font(16))
        lg.setColor(Theme.colors.dim)
        local msg = self.tab == "favourites" and "No favourites yet. Press F (or click the star) on a bug to pin it here."
            or self.tab == "custom" and "No custom bugs yet. Make one in the Bug Creator."
            or "No bugs match. Change the Style filter (top right)."
        lg.printf(msg, G.x, G.y + u(12), G.w, "left")
    end

    -- footer
    local pad = Input.lastDevice == "gamepad"
    local touch = Input.lastDevice == "touch"
    local fav = Input.glyph("ui_favourite")
    if pad then
        Theme.footer({ { "A", "Play" }, { "LB/RB", "Family" }, { (fav.pad or "x"):upper(), "Favourite" }, { "Y", "Danger" }, { "B", "Back" } })
    elseif touch then
        Theme.footer({ { "Tap", "Pick" }, { "Tap again", "Play" } })
    else
        Theme.footer({ { "Enter", "Play" }, { "Q/E", "Family" }, { fav.key or "F", "Favourite" }, { "Z/X", "Danger" }, { "T", "Sort" }, { "G", "Style" }, { "Esc", "Back" } })
    end

    local def = self:focused()
    self.starRect, self.dangerRects = nil, nil
    if def then self:drawDetails(def, L.detail.x, L.detail.y, L.detail.w, L.detail.h) end
end

-- The details panel, laid out top to bottom and fitted to the panel's height: the bug in action
-- (or its turning model until the preview starts), family and playstyle, name, description,
-- moves and stats, then at the bottom its rule, mastery stars and the danger picker (or what
-- unlocks it). When it doesn't all fit (phones, long descriptions) the picture shrinks first,
-- then the description is cut short, then the stats give way.
function CharSelect:drawDetails(def, px, py, pw, ph)
    local u = Theme.u
    local c = Theme.colors
    Theme.panel(px, py, pw, ph)
    local fam = Families.of(def)
    local open = Unlocks.bug(def.id)
    local pad = math.floor(u(14))
    local innerW = pw - 2 * pad

    -- fonts and the text to measure
    local fSmall = Theme.font("small", "bold")
    local fName = Theme.font(28)
    local fDesc = Theme.font(16)
    local fMove = Theme.font(16)
    local fStat = Theme.font(15)
    local fRule = Theme.font(15)
    local fDanger = Theme.font(18, "bold")
    local touch = Input.lastDevice == "touch"
    local padDev = Input.lastDevice == "gamepad"
    local function padName(id)
        local g = Input.glyph(id)
        return (({ a = "A", b = "B", x = "X", y = "Y", rightshoulder = "RB", leftshoulder = "LB" })[g.pad or ""] or "?") .. "   "
    end
    local moves = { { touch and "Attack   " or padDev and padName("attack") or "Left click   ", moveLine(Content.attacks, def.attack) } }
    if def.secondary then
        moves[#moves + 1] = { touch and "Special   " or padDev and padName("secondary") or "Right click   ", moveLine(Content.attacks, def.secondary) }
    end
    local dashCfg = def.dash or { type = "dash" }
    local dash = Content.dashes:get(dashCfg.type)
    moves[#moves + 1] = { touch and "Dash   " or padDev and padName("dash") or "Shift   ",
        ((dash and dash.name) or dashCfg.type or "Dash") .. ((dashCfg.charges or 1) > 1 and (" x" .. dashCfg.charges) or "") }
    local moveH = 0
    for _, m in ipairs(moves) do
        local _, ls = fMove:getWrap(m[1] .. m[2], innerW)
        m.h = #ls * fMove:getHeight()
        moveH = moveH + m.h
    end
    -- stats that differ from the defaults (body size first: it sets the hitbox and the shove)
    local stats = Stats.new(def.stats)
    local statRows = { { "Size", Playstyles.sizeName(def.scale or 1), c.text } }
    for _, sd in ipairs(Stats.defs) do
        if def.stats and def.stats[sd.id] then
            local v = stats:get(sd.id)
            statRows[#statRows + 1] = { sd.label, Stats.format(sd.id, v),
                ((v >= sd.default) ~= (sd.lowerIsBetter == true)) and c.good or c.bad }
        end
    end
    local rowH = math.floor(fStat:getHeight() * 1.25)
    local statsH = math.ceil(#statRows / 2) * rowH
    local _, descLines = fDesc:getWrap(def.description or "", innerW - u(10))
    local lh = fDesc:getHeight()
    -- the bottom block
    local rule = BugRules[def.custom and (def.rules or "") or def.id]
    local ruleLines = {}
    if rule and open then _, ruleLines = fRule:getWrap("RULE  " .. rule.name .. ":  " .. rule.description, innerW) end
    local ruleH = #ruleLines * fRule:getHeight()
    local dangerH = fDanger:getHeight() + fRule:getHeight() + u(8)
    local starsH = u(20)
    local bottomH = open and (dangerH + starsH + (ruleH > 0 and ruleH + u(8) or 0)) or u(82)

    -- fit: fixed pieces first, then share what is left
    local gap = math.floor(u(10))
    local pictureIdeal = math.floor(innerW * 0.42)
    local pictureMin = math.floor(u(64))
    local descMax = #descLines
    local showStats, showMoves, showPicture = true, true, true
    local function fixedH()
        return pad + fSmall:getHeight() + fName:getHeight() + gap + (showMoves and moveH + gap or 0) + bottomH + pad
    end
    local free = ph - fixedH()
    local need = descMax * lh + gap + statsH + gap
    local picture = math.min(pictureIdeal, free - need)
    if picture < pictureMin then
        picture = math.max(free - need, 0) >= pictureMin * 0.7 and math.max(free - need, 0) or pictureMin
        if free - picture - need < 0 then
            -- cut the description, keeping at least two lines
            local room = free - picture - gap - statsH - gap
            descMax = math.max(2, math.min(#descLines, math.floor(room / lh)))
            need = descMax * lh + gap + statsH + gap
            if free - picture - need < 0 then
                showStats = false
                need = descMax * lh + gap
                local more = math.floor((free - picture - need) / lh)
                if more > 0 then descMax = math.min(#descLines, descMax + more) need = descMax * lh + gap end
            end
        end
    end
    -- very short panels (phones): drop the picture and the stars, then the description, then the moves
    if free - picture - need < 0 then
        showPicture, picture = false, 0
        if open then bottomH = bottomH - starsH starsH = 0 end
        free = ph - fixedH()
        descMax = math.max(0, math.min(#descLines, math.floor((free - gap) / lh)))
        need = descMax > 0 and (descMax * lh + gap) or 0
        if descMax < 2 then
            descMax, need = 0, 0
            if free < 0 then showMoves = false free = ph - fixedH() end
            -- a short strip of the bug in action still fits
            if free - gap >= pictureMin * 0.7 then showPicture, picture = true, free - gap end
        end
    end
    -- whatever is left over goes back to the picture
    if showPicture then picture = math.max(picture, math.min(pictureIdeal * 1.25, free - need - (need == 0 and gap or 0))) end

    -- 1. the picture
    local bx, by, bw, bh = px + pad, py + pad, innerW, math.floor(picture)
    if not showPicture then
        -- (no room: nothing)
    elseif self.preview and self.preview.id == def.id and bh >= pictureMin * 0.7 then
        self.preview:draw(bx, by, bw, bh)
        if def.card then CharSelect.drawFrame(def.card, bx, by, bw, bh, self.t) end
    else
        lg.setColor(0, 0, 0, 0.25)
        lg.rectangle("fill", bx, by, bw, bh)
        lg.setScissor(bx, by, bw, bh)
        local spr = Sprites.get(def.sprite)
        local ds = math.min(bh * 0.5, bw * 0.35) / 22 * (def.scale or 1)
        local cx, cy = bx + bw / 2, by + bh * 0.55
        local r = (def.radius or 7) * ds
        lg.setColor(0, 0, 0, 0.35)
        lg.ellipse("fill", cx, cy + ds * 2, r * 1.6, r * 0.6)
        lg.setColor(1, 1, 1, 1)
        if def.model then
            -- in the skin picked in Cosmetics
            local Cos = require("src.game.cosmetics")
            local skin = Cos.skinFor(def.id)
            local skinShader = Cos.shader(skin)
            if skinShader and open then lg.setShader(skinShader) end
            Sprites.drawModel((skin and skin.model) or def.model, math.floor(self.t * spr.fps) + 1, cx, cy,
                math.pi * 0.25 + math.sin(self.t * 0.7) * 1.4, false, ds, ds, 1, (not open) and { tint = { 0.07, 0.06, 0.055 } } or nil)
            lg.setShader()
        else
            if not open then lg.setColor(0.07, 0.06, 0.055, 1) end
            Sprites.draw(spr, math.floor(self.t * (spr.fps or 8)) + 1, cx, cy, -math.pi / 2, false, ds)
        end
        lg.setScissor()
    end
    local y = py + pad
    if showPicture then
        lg.setColor(fam.color[1], fam.color[2], fam.color[3], 0.5)
        lg.rectangle("line", bx + 0.5, by + 0.5, bw - 1, bh - 1)
        y = by + bh + gap
    end

    -- 2. family and playstyle:  BEETLES  ·  TANKS
    local style = Playstyles.byId[def.playstyle or ""]
    lg.setFont(fSmall)
    local famText = fam.label:upper()
    local styleText = style and ("   ·   " .. style.label:upper()) or ""
    local card = def.card     -- a custom bug's card (Bug Creator): its motto and name colour
    if card and card.motto then styleText = styleText .. "   \"" .. card.motto .. "\"" end
    local fw = fSmall:getWidth(famText .. styleText)
    local lx = px + pw / 2 - fw / 2
    lg.setColor(fam.color)
    lg.print(famText, lx, y)
    lg.setColor(c.accent)
    lg.print(styleText, lx + fSmall:getWidth(famText), y)
    y = y + fSmall:getHeight()

    -- 3. name, with the favourite star (click or tap it to pin the bug)
    lg.setFont(fName)
    Theme.printShadow(def.name, px, y, card and card.color and { card.color[1], card.color[2], card.color[3], 1 } or c.text, "center", pw)
    local nw = fName:getWidth(def.name)
    local sr = u(9)
    local sx, sy = px + pw / 2 + nw / 2 + u(20), y + fName:getHeight() / 2
    Menu.star(sx, sy, sr, Prefs.isFavourite(def.id) and c.focus or { 0.4, 0.34, 0.28, 1 })
    self.starRect = { x = sx - sr * 1.6, y = sy - sr * 1.6, w = sr * 3.2, h = sr * 3.2, def = def }
    y = y + fName:getHeight()

    -- 4. description
    lg.setFont(fDesc)
    lg.setColor(c.dim)
    for i = 1, descMax do
        local line = descLines[i]
        if i == descMax and descMax < #descLines then line = line:gsub("%s*%S*$", "") .. " ..." end
        lg.printf(line, px + pad + u(5), y, innerW - u(10), "center")
        y = y + lh
    end
    y = y + gap

    -- 5. moves
    lg.setFont(fMove)
    for _, m in ipairs(showMoves and moves or {}) do
        lg.setColor(1, 1, 1, 1)
        lg.printf({ c.dim, m[1], c.text, m[2] }, px + pad, y, innerW, "center")
        y = y + m.h
    end
    y = y + gap

    -- 6. stats, two columns
    if showStats then
        lg.setFont(fStat)
        local colW = (innerW - u(20)) / 2
        local labelW, valueW = 0, 0
        for _, r in ipairs(statRows) do
            labelW = math.max(labelW, fStat:getWidth(r[1]))
            valueW = math.max(valueW, fStat:getWidth(r[2]))
        end
        local valX = math.min(labelW + u(12), colW - valueW - u(4))
        for i, r in ipairs(statRows) do
            local cx = px + pad + u(10) + ((i - 1) % 2) * colW
            local cy = y + math.floor((i - 1) / 2) * rowH
            lg.setColor(c.dim)
            lg.print(r[1], cx, cy)
            lg.setColor(r[3])
            lg.print(r[2], cx + valX, cy)
        end
    end

    -- 7. rule, mastery and danger (or the lock)
    self:drawMastery(def, px, py + ph - pad - bottomH, pw, bottomH, rule, ruleLines, starsH > 0)
end

-- A custom bug's portrait frame (card = { frame, color }, Bug Creator).
function CharSelect.drawFrame(card, x, y, w, h, t)
    local lg = love.graphics
    local u = Theme.u
    local c = card.color or { 0.9, 0.75, 0.45 }
    local f = card.frame or "plain"
    lg.setLineStyle("rough")
    lg.setColor(c[1], c[2], c[3], 0.9)
    lg.setLineWidth(f == "gold" and 2 or 1)
    lg.rectangle("line", x - 2, y - 2, w + 4, h + 4)
    if f == "gold" then
        lg.setColor(c[1], c[2], c[3], 0.5)
        lg.setLineWidth(1)
        lg.rectangle("line", x - 6, y - 6, w + 12, h + 12)
        for _, p in ipairs({ { x - 6, y - 6 }, { x + w + 6, y - 6 }, { x - 6, y + h + 6 }, { x + w + 6, y + h + 6 } }) do
            lg.setColor(c[1], c[2], c[3], 1)
            lg.polygon("fill", p[1], p[2] - u(6), p[1] + u(6), p[2], p[1], p[2] + u(6), p[1] - u(6), p[2])
        end
    elseif f == "leaf" then
        for i, p in ipairs({ { x, y, 1, 1 }, { x + w, y, -1, 1 }, { x, y + h, 1, -1 }, { x + w, y + h, -1, -1 } }) do
            local sway = math.sin(t * 1.5 + i) * 0.1
            for k = 0, 2 do
                local a = (k * 0.6 + 0.2 + sway) * (math.pi / 2)
                local lx, ly = p[1] + math.cos(a) * u(14) * p[3], p[2] + math.sin(a) * u(14) * p[4]
                lg.setColor(c[1] * 0.7, c[2] * 0.9, c[3] * 0.6, 0.9)
                lg.ellipse("fill", (p[1] + lx) / 2, (p[2] + ly) / 2, u(6), u(3))
            end
        end
    elseif f == "bone" then
        lg.setColor(c[1], c[2], c[3], 0.8)
        for i = 0, 7 do
            local k = i / 7
            lg.circle("fill", x + w * k, y - 2, u(3))
            lg.circle("fill", x + w * k, y + h + 2, u(3))
        end
    elseif f == "web" then
        lg.setColor(c[1], c[2], c[3], 0.45)
        for _, p in ipairs({ { x, y, 1, 1 }, { x + w, y, -1, 1 }, { x, y + h, 1, -1 }, { x + w, y + h, -1, -1 } }) do
            for k = 1, 3 do
                local r = u(10) * k
                lg.line(p[1] + r * p[3], p[2], p[1] + r * 0.7 * p[3], p[2] + r * 0.7 * p[4], p[1], p[2] + r * p[4])
            end
            lg.line(p[1], p[2], p[1] + u(34) * p[3], p[2] + u(34) * p[4])
        end
    elseif f == "shell" then
        lg.setColor(c[1], c[2], c[3], 0.7)
        local n = math.max(4, math.floor(w / u(18)))
        for i = 0, n - 1 do
            local cx = x + (i + 0.5) * w / n
            lg.arc("line", "open", cx, y - 2, w / n / 2, math.pi, math.pi * 2)
            lg.arc("line", "open", cx, y + h + 2, w / n / 2, 0, math.pi)
        end
    end
    lg.setLineWidth(1)
    lg.setColor(1, 1, 1, 1)
end

-- Bottom of the panel (y .. y + bh): the bug's rule, its mastery stars and the danger level
-- picker, or what unlocks it.
function CharSelect:drawMastery(def, px, y, pw, bh, rule, ruleLines, stars)
    local u = Theme.u
    local c = Theme.colors
    self.dangerRects = nil
    if not Unlocks.bug(def.id) then
        local flash = self.lockFlashT and self.lockFlashT > 0
        lg.setColor(0, 0, 0, 0.55)
        lg.rectangle("fill", px + u(8), y, pw - u(16), bh)
        padlock(px + u(30), y + bh / 2 - u(4), u(10), flash and c.bad or c.focus)
        lg.setFont(Theme.font(20, "bold"))
        Theme.printShadow("LOCKED", px, y + u(6), flash and c.bad or c.focus, "center", pw)
        lg.setFont(Theme.font(16))
        lg.setColor(c.text)
        lg.printf(Unlocks.progressText(Unlocks.bugGoal(def.id)), px + u(48), y + u(32), pw - u(96), "center")
        lg.setFont(Theme.font(13))
        lg.setColor(c.dim)
        lg.printf("Or open every bug: Settings > Gameplay > Unlock Everything", px + u(16), y + bh - u(18), pw - u(32), "center")
        lg.setColor(1, 1, 1, 1)
        return
    end
    -- the bug's own item rule
    if rule and #ruleLines > 0 then
        local f = Theme.font(15)
        lg.setFont(f)
        lg.setColor(1, 1, 1, 1)
        lg.printf({ c.accent, "RULE  " .. rule.name .. ":  ", c.text, rule.description }, px + u(14), y, pw - u(28), "center")
        y = y + #ruleLines * f:getHeight() + u(8)
    end
    -- mastery stars: one per danger level won
    local best = Unlocks.bestDanger(def.id)
    local sr = u(7)
    local sx = px + pw / 2 - (Danger.MAX - 1) * u(10)
    for i = 1, stars and Danger.MAX or 0 do
        Menu.star(sx + (i - 1) * u(20), y + u(8), sr, i <= best and util.hex(Danger[i].color) or { 0.3, 0.26, 0.22, 1 })
    end
    if stars then y = y + u(20) end
    -- danger picker:  <  DANGER 2  Hungry  >
    local cur, max = CharSelect.danger(def.id), Unlocks.maxDanger(def.id)
    local lv = Danger[cur]
    local col = lv and util.hex(lv.color) or c.dim
    lg.setFont(Theme.font(18, "bold"))
    local label = cur == 0 and "DANGER 0  Normal" or ("DANGER %d  %s"):format(cur, lv.name)
    local lw = lg.getFont():getWidth(label)
    local ly = y
    Theme.printShadow(label, px, ly, col, "center", pw)
    local ax1, ax2 = px + pw / 2 - lw / 2 - u(26), px + pw / 2 + lw / 2 + u(12)
    lg.setColor(cur > 0 and c.text or c.dim)
    lg.print("<", ax1, ly)
    lg.setColor(cur < max and c.text or c.dim)
    lg.print(">", ax2, ly)
    local fh = lg.getFont():getHeight()
    self.dangerRects = { def = def,
        { x = ax1 - u(10), y = ly - u(6), w = u(34), h = fh + u(12), dir = -1 },
        { x = ax2 - u(10), y = ly - u(6), w = u(34), h = fh + u(12), dir = 1 } }
    lg.setFont(Theme.font(15))
    local desc
    if self.dangerFlashT and self.dangerFlashT > 0 then
        lg.setColor(c.bad)
        desc = ("Win at Danger %d with this bug to open Danger %d."):format(max, max + 1)
    else
        lg.setColor(c.dim)
        local rules = {}
        for i = 1, cur do rules[#rules + 1] = Danger[i].description end
        desc = cur == 0 and "The normal game. Win to open Danger 1." or table.concat(rules, "  ")
    end
    -- one line: the newest rule when several don't fit
    local f = lg.getFont()
    if f:getWidth(desc) > pw - u(28) and cur > 0 then desc = Danger[cur].description end
    lg.printf(desc, px + u(14), ly + fh + u(4), pw - u(28), "center")
    lg.setColor(1, 1, 1, 1)
end

----------------------------------------------------------------------------------------------
-- Mouse and touch

local function inside(r, x, y) return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

function CharSelect:mousemoved(x, y)
    -- the mouse highlights what it rests on (taps on a phone don't: they pick, see below)
    if Input.lastDevice == "touch" then return end
    local i = self:tileAt(x, y)
    if i and i ~= self.focus then
        self.focus = i
        Audio.play("ui_move")
    end
end

function CharSelect:mousepressed(x, y, b)
    if b == 2 then
        -- right click on a bug: favourite it
        local i = self:tileAt(x, y)
        if i then self:toggleFavourite(self.list[i].def) end
        return
    end
    if b ~= 1 then return end
    if inside(self.starRect, x, y) then self:toggleFavourite(self.starRect.def) return end
    for _, dr in ipairs(self.dangerRects or {}) do
        if inside(dr, x, y) then self:shiftDanger(self.dangerRects.def, dr.dir) return end
    end
    for _, r in ipairs(self.tabRects or {}) do
        if inside(r, x, y) then self:setTab(r.id) return end
    end
    if inside(self.sortRect, x, y) then self:cycleSort(1) return end
    if inside(self.styleRect, x, y) then self:cycleStyle(1) return end
    local i = self:tileAt(x, y)
    if not i then return end
    -- on a phone the first tap shows a bug, the second picks it
    if Input.lastDevice == "touch" and i ~= self.focus then
        self.focus = i
        self:ensureVisible()
        Audio.play("ui_move")
        return
    end
    self.focus = i
    self:pick(self.list[i].def)
end

function CharSelect:wheelmoved(_, dy)
    local L = self:layout()
    self.scroll = util.clamp(self.scroll - dy * (L.TH + L.gap) * 0.6, 0, self:maxScroll())
end

return CharSelect
