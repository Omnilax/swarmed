-- Character select, generated from content/characters.
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
local MovePreview = require("src.ui.movepreview")
local Unlocks = require("src.game.unlocks")
local Danger = require("src.config.danger")
local BugRules = require("src.config.bugrules")
local util = require("src.core.util")

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

-- opts: gameMode (content/modes id, from the mode select screen)
function CharSelect.new(opts)
    local self = setmetatable({ t = 0, focusT = 0 }, CharSelect)
    self.gameMode = opts and opts.gameMode or "colony"
    self.mode = Content.modes:get(self.gameMode)
    local prefs = Prefs.get()
    self.sort = Playstyles.sortById[prefs.sort] and prefs.sort or "default"
    self.filter = prefs.filter or "all"
    self.menu = Menu.new({
        items = {},
        onBack = function() State.pop() end,
        touchConfirm = true,     -- on a phone the first tap previews a bug, the second picks it
        rect = function()
            local w, h = love.graphics.getDimensions()
            return Theme.u(60), Theme.u(120), math.min(Theme.u(360), w * 0.35), h - Theme.u(200)
        end,
    })
    -- open on the bug played last
    self:build(prefs.last and prefs.last.character)
    return self
end

-- The danger level picked for a bug (remembered per bug, never above what it has earned).
function CharSelect.danger(id)
    local d = Prefs.get().danger
    local v = type(d) == "table" and tonumber(d[id]) or 0
    return math.max(0, math.min(v or 0, Unlocks.maxDanger(id)))
end

function CharSelect:shiftDanger(def, dir)
    if not Unlocks.bug(def.id) then return end
    local cur, max = CharSelect.danger(def.id), Unlocks.maxDanger(def.id)
    local v = math.max(0, math.min(max, cur + dir))
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
    local params = { mode = "run", character = def.id, gameMode = self.gameMode, danger = CharSelect.danger(def.id) }
    if self.mode and self.mode.chooseItems then
        State.push(require("src.states.loadout").new(params, self.mode.chooseItems))
    else
        State.switch(require("src.states.game").new(params))
    end
end

-- The bugs shown: filtered, favourites first, then sorted.
function CharSelect:list()
    local sort = Playstyles.sortById[self.sort]
    local out = {}
    for i, def in ipairs(Content.characters:all()) do
        local f = self.filter
        local keep = f == "all" or (f == "favourites" and Prefs.isFavourite(def.id)) or (f == "custom" and def.custom)
            or def.playstyle == f
        if keep then out[#out + 1] = { def = def, i = i, fav = Prefs.isFavourite(def.id) } end
    end
    table.sort(out, function(a, b)
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

-- (Re)build the list, keeping the focus on `focusId` (a character id) or the row it was on.
function CharSelect:build(focusId, focusRow)
    local items = {}
    local sortOpts, filterOpts = {}, {}
    for _, so in ipairs(Playstyles.sorts) do sortOpts[#sortOpts + 1] = { value = so.id, label = so.label } end
    for _, fo in ipairs(Playstyles.filters) do filterOpts[#filterOpts + 1] = { value = fo.id, label = fo.label } end
    items[1] = { type = "choice", label = "Sort", options = sortOpts, control = "sort",
        get = function() return self.sort end,
        set = function(v) self.sort = v Prefs.set("sort", v) self:build(nil, 1) end }
    items[2] = { type = "choice", label = "Show", options = filterOpts, control = "filter",
        get = function() return self.filter end,
        set = function(v) self.filter = v Prefs.set("filter", v) self:build(nil, 2) end }
    local sort = Playstyles.sortById[self.sort]
    local focus
    for _, e in ipairs(self:list()) do
        local def = e.def
        local open = Unlocks.bug(def.id)
        items[#items + 1] = { type = "button", label = def.name, character = def, star = e.fav, locked = not open,
            value = (not open) and function() return "Locked" end
                or (sort and sort.show and function() return sort.show(def) end)
                or function()
                    local d = CharSelect.danger(def.id)
                    return d > 0 and ("Danger " .. d) or nil
                end,
            onActivate = function() self:pick(def) end }
        if def.id == focusId then focus = #items end
    end
    if #items == 2 then
        items[#items + 1] = { type = "header", label = self.filter == "favourites" and "No favourites yet" or "No bugs here" }
    end
    items[#items + 1] = { type = "button", label = "Back", onActivate = function() State.pop() end }
    self.menu:setItems(items, true)
    -- the sort / filter row just changed, the bug asked for, or else the first bug
    self.menu.focus = focusRow or focus or 3
    self.menu:fixFocus(1)
end

function CharSelect:update(dt)
    self.t = self.t + dt
    self.menu:update(dt)
    local it = self.menu:focused()
    local def = it and it.character
    -- favourite the highlighted bug (F / pad X, or a click on the star in the panel)
    if def and Input.pressed("ui_favourite") then self:toggleFavourite(def) end
    -- Left / Right on a bug: its danger level
    if def and Input.pressed("ui_left") then self:shiftDanger(def, -1) end
    if def and Input.pressed("ui_right") then self:shiftDanger(def, 1) end
    if self.lockFlashT then self.lockFlashT = self.lockFlashT > 0 and self.lockFlashT - dt or nil end
    if self.dangerFlashT then self.dangerFlashT = self.dangerFlashT > 0 and self.dangerFlashT - dt or nil end
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

function CharSelect:toggleFavourite(def)
    Prefs.toggleFavourite(def.id)
    Audio.play("ui_confirm", { pitch = 1.2 })
    self:build(def.id)
end

function CharSelect:leave()
    if self.preview then self.preview:release() self.preview = nil end
end

function CharSelect:draw()
    local lg = love.graphics
    local w, h = lg.getDimensions()
    lg.clear(Theme.colors.bg)
    Theme.title("Choose your bug")
    self.menu:draw()
    local fav = Input.glyph("ui_favourite")
    Theme.footer(Input.lastDevice == "gamepad" and { { "A", "Play" }, { (fav.pad or "x"):upper(), "Favourite" }, { "B", "Back" } }
        or { { "Enter", "Play" }, { fav.key or "F", "Favourite" }, { "Left/Right", "Danger" }, { "Esc", "Back" } })
    local nOpen, nAll = Unlocks.bugCount()
    if nOpen < nAll then
        lg.setFont(Theme.font(15))
        lg.setColor(Theme.colors.dim)
        lg.print(("%d / %d bugs unlocked"):format(nOpen, nAll), Theme.u(60), Theme.u(96))
    end

    local it = self.menu:focused()
    local def = it and it.character
    if not def then return end
    local px = math.min(Theme.u(360), w * 0.35) + Theme.u(110)
    local small = h < 600       -- phones: a smaller model and tighter spacing so it all fits
    local pw, ph = w - px - Theme.u(60), h - Theme.u(small and 140 or 200)
    Theme.panel(px, Theme.u(120), pw, ph)

    local spr = Sprites.get(def.sprite)
    local s = small and 1.5 or math.floor(Theme.u(5))
    lg.setColor(1, 1, 1, 1)
    local ty = Theme.u(120) + Theme.u(small and 10 or 40) + spr.size * s * (small and 0.75 or 1)
    local bx, by, bw, bh = px + Theme.u(24), Theme.u(132), pw - Theme.u(48), ty - Theme.u(140)
    if self.preview and self.preview.id == def.id and bh > Theme.u(60) then
        -- the bug in action: its special and dash on a loop (a wide, short strip so the stats still fit)
        bh = math.min(bh, math.floor(bw * 0.26))
        -- room at the bottom of the panel for the danger picker, mastery and rule (or the lock)
        local reserve = not Unlocks.bug(def.id) and Theme.u(124) or (Theme.u(78) + (BugRules[def.custom and (def.rules or "") or def.id] and Theme.u(24) or 0))
        bh = math.max(Theme.u(50), bh - reserve)
        self.preview:draw(bx, by, bw, bh)
        ty = by + bh + Theme.u(22)
    elseif def.model then
        -- slowly turning 3D model on a soft shadow
        local cx, cy = px + pw / 2, Theme.u(120) + Theme.u(small and 6 or 30) + spr.size * s * (small and 0.45 or 0.6)
        -- drawn at the bug's in-game size so tiny and huge bugs look it next to each other
        local ds = s * (def.scale or 1)
        lg.setColor(0, 0, 0, 0.35)
        lg.ellipse("fill", cx, cy + s * 2, spr.w * ds * 0.55, spr.w * ds * 0.25)
        -- in the skin picked in Cosmetics
        local skin = require("src.game.cosmetics").skinFor(def.id)
        local skinShader = require("src.game.cosmetics").shader(skin)
        if skinShader then love.graphics.setShader(skinShader) end
        Sprites.drawModel((skin and skin.model) or def.model, math.floor(self.t * spr.fps) + 1, cx, cy, math.pi * 0.25 + math.sin(self.t * 0.7) * 1.4, false, ds, ds)
        love.graphics.setShader()
    else
        Sprites.draw(spr, math.floor(self.t * spr.fps) + 1, px + pw / 2, Theme.u(120) + Theme.u(30) + spr.size * s / 2, -math.pi / 2, false, s)
    end
    lg.setColor(1, 1, 1, 1)

    lg.setFont(Theme.font(30))
    Theme.printShadow(def.name, px, ty, Theme.colors.text, "center", pw)
    -- the favourite star: click it (or tap it) to pin the bug to the top of the list
    local nw = lg.getFont():getWidth(def.name)
    local sr = Theme.u(9)
    local sx, sy = px + pw / 2 + nw / 2 + Theme.u(22), ty + lg.getFont():getHeight() / 2
    local on = Prefs.isFavourite(def.id)
    Menu.star(sx, sy, sr, on and Theme.colors.focus or { 0.4, 0.34, 0.28, 1 })
    self.starRect = { x = sx - sr * 1.6, y = sy - sr * 1.6, w = sr * 3.2, h = sr * 3.2, def = def }
    local style = Playstyles.byId[def.playstyle or ""]
    if style then
        lg.setFont(Theme.font("small", "bold"))
        lg.setColor(Theme.colors.accent)
        lg.printf(style.label:upper(), px, ty - Theme.u(18), pw, "center")
    end
    lg.setFont(Theme.font(18))
    lg.setColor(Theme.colors.dim)
    lg.printf(def.description, px + Theme.u(30), ty + Theme.u(44), pw - Theme.u(60), "center")
    -- the lines below follow the description down when it wraps onto more lines (small screens)
    local _, descLines = lg.getFont():getWrap(def.description, pw - Theme.u(60))
    ty = math.max(ty, ty + Theme.u(50) + #descLines * lg.getFont():getHeight() - Theme.u(84))

    local touch = Input.lastDevice == "touch"
    local pad = Input.lastDevice == "gamepad"
    local function padName(id)
        local g = Input.glyph(id)
        return (({ a = "A", b = "B", x = "X", y = "Y", rightshoulder = "RB", leftshoulder = "LB" })[g.pad or ""] or "?") .. "   "
    end
    local dim = Theme.colors.dim
    lg.setColor(1, 1, 1, 1)
    lg.printf({ dim, touch and "Attack   " or pad and padName("attack") or "Left click   ", Theme.colors.text, moveLine(Content.attacks, def.attack) },
        px, ty + Theme.u(84), pw, "center")

    local extra = 0
    if def.secondary then
        lg.printf({ dim, touch and "Special   " or pad and padName("secondary") or "Right click   ", Theme.colors.text, moveLine(Content.attacks, def.secondary) },
            px, ty + Theme.u(108), pw, "center")
        extra = extra + Theme.u(24)
    end
    local dashCfg = def.dash or { type = "dash" }
    local dash = Content.dashes:get(dashCfg.type)
    lg.printf({ dim, touch and "Dash   " or pad and padName("dash") or "Shift   ", Theme.colors.text, ((dash and dash.name) or dashCfg.type or "Dash") .. ((dashCfg.charges or 1) > 1 and (" x" .. dashCfg.charges) or "") },
        px, ty + Theme.u(108) + extra, pw, "center")
    extra = extra + Theme.u(24)

    -- Stats that differ from the defaults.
    local stats = Stats.new(def.stats)
    local col = 0
    local sy = ty + Theme.u(124) + extra
    lg.setFont(Theme.font(16))
    -- body size first: it sets the hitbox and how far the bug gets shoved
    local sc = def.scale or 1
    local sizeName = Playstyles.sizeName(sc)
    lg.setColor(Theme.colors.dim)
    lg.print("Size", px + Theme.u(40), sy)
    lg.setColor(Theme.colors.text)
    lg.print(sizeName, px + Theme.u(40) + Theme.u(150), sy)
    col = 1
    for _, sd in ipairs(Stats.defs) do
        local v = stats:get(sd.id)
        if def.stats and def.stats[sd.id] then
            local cx = px + Theme.u(40) + (col % 2) * (pw / 2)
            local cy = sy + math.floor(col / 2) * Theme.u(24)
            lg.setColor(Theme.colors.dim)
            lg.print(sd.label, cx, cy)
            lg.setColor(((v >= sd.default) ~= (sd.lowerIsBetter == true)) and Theme.colors.good or Theme.colors.bad)
            lg.print(Stats.format(sd.id, v), cx + Theme.u(150), cy)
            col = col + 1
        end
    end
    self:drawMastery(def, px, Theme.u(120), pw, ph)
end

-- Bottom of the panel: the bug's rule, its danger level picker and mastery stars, or what
-- unlocks it.
function CharSelect:drawMastery(def, px, py, pw, ph)
    local lg = love.graphics
    local u = Theme.u
    local c = Theme.colors
    local bottom = py + ph - u(14)
    self.dangerRects = nil
    if not Unlocks.bug(def.id) then
        local flash = self.lockFlashT and self.lockFlashT > 0
        lg.setColor(0, 0, 0, 0.55)
        local text, f = Unlocks.progressText(Unlocks.bugGoal(def.id)), Theme.font(16)
        local _, lines = f:getWrap(text, pw - u(32))
        local extra = math.max(0, #lines - 1) * f:getHeight()    -- a goal that wraps pushes the box up
        lg.rectangle("fill", px + u(8), bottom - u(78) - extra, pw - u(16), u(76) + extra)
        lg.setFont(Theme.font(20, "bold"))
        Theme.printShadow("LOCKED", px, bottom - u(74) - extra, flash and c.bad or c.focus, "center", pw)
        lg.setFont(f)
        lg.setColor(c.text)
        lg.printf(text, px + u(16), bottom - u(46) - extra, pw - u(32), "center")
        lg.setFont(Theme.font(13))
        lg.setColor(c.dim)
        lg.printf("Or open every bug: Settings > Gameplay > Unlock Everything", px + u(16), bottom - u(20), pw - u(32), "center")
        lg.setColor(1, 1, 1, 1)
        return
    end
    -- danger picker:  <  DANGER 2  Hungry  >
    local cur, max = CharSelect.danger(def.id), Unlocks.maxDanger(def.id)
    local lv = Danger[cur]
    local col = lv and util.hex(lv.color) or c.dim
    lg.setFont(Theme.font(18, "bold"))
    local label = cur == 0 and "DANGER 0  Normal" or ("DANGER %d  %s"):format(cur, lv.name)
    local lw = lg.getFont():getWidth(label)
    local ly = bottom - u(44)
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
    lg.printf(desc, px + u(16), bottom - u(20), pw - u(32), "center")
    -- mastery stars: one per danger level won
    local best = Unlocks.bestDanger(def.id)
    local sr = u(7)
    local sx = px + pw / 2 - (Danger.MAX - 1) * u(10)
    for i = 1, Danger.MAX do
        Menu.star(sx + (i - 1) * u(20), ly - u(16), sr, i <= best and util.hex(Danger[i].color) or { 0.3, 0.26, 0.22, 1 })
    end
    -- the bug's own item rule
    local rule = BugRules[def.custom and (def.rules or "") or def.id]
    if rule then
        lg.setFont(Theme.font(15))
        lg.setColor(1, 1, 1, 1)
        lg.printf({ c.accent, "RULE  " .. rule.name .. ":  ", c.text, rule.description }, px + u(16), ly - u(50), pw - u(32), "center")
    end
    lg.setColor(1, 1, 1, 1)
end

function CharSelect:mousemoved(x, y) self.menu:mousemoved(x, y) end
function CharSelect:mousepressed(x, y, b)
    local r = self.starRect
    if b == 1 and r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
        self:toggleFavourite(r.def)
        return
    end
    for _, dr in ipairs(b == 1 and self.dangerRects or {}) do
        if x >= dr.x and x <= dr.x + dr.w and y >= dr.y and y <= dr.y + dr.h then
            self:shiftDanger(self.dangerRects.def, dr.dir)
            return
        end
    end
    self.menu:mousepressed(x, y, b)
end
function CharSelect:wheelmoved(x, y) self.menu:wheelmoved(x, y) end

return CharSelect
