-- Records screen (main menu): lifetime stats per bug, past runs, kills per species and
-- achievements. Four tabs, each a list on the left and details on the right.
local State = require("src.core.state")
local Content = require("src.content")
local Theme = require("src.ui.theme")
local Menu = require("src.ui.menu")
local Sprites = require("src.gfx.sprites")
local Input = require("src.core.input")
local Audio = require("src.core.audio")
local Records = require("src.game.records")

local lg = love.graphics

local RecordsState = {}
RecordsState.__index = RecordsState

local TABS = { "Bugs", "Runs", "Kills", "Recipes", "Achievements" }

local function num(n)
    n = math.floor(n or 0)
    local s = tostring(n)
    while true do
        local r, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        s = r
        if k == 0 then return s end
    end
end

local function clock(sec)
    sec = math.floor(sec or 0)
    local h, m, s = math.floor(sec / 3600), math.floor(sec / 60) % 60, sec % 60
    if h > 0 then return ("%dh %02dm"):format(h, m) end
    return ("%d:%02d"):format(m, s)
end

local function date(t)
    local ok, s = pcall(os.date, "%d %b %Y, %H:%M", t)
    return ok and s or ""
end

local function charName(id)
    local c = Content.characters:get(id)
    return c and c.name or id
end

local function enemyName(id)
    local e = id and Content.enemies:get(id)
    return e and e.name or "-"
end

function RecordsState.new()
    local self = setmetatable({ t = 0, tab = 1 }, RecordsState)
    self.menu = Menu.new({
        onBack = function() State.pop() end,
        touchConfirm = true,
        fontSize = 18,
        rowHeight = 34,
        rect = function()
            local w, h = lg.getDimensions()
            return Theme.u(60), Theme.u(150), math.min(Theme.u(340), w * 0.34), h - Theme.u(200)
        end,
    })
    self:build()
    return self
end

----------------------------------------------------------------------------------------------
-- Lists

function RecordsState:build()
    local p = Records.get()
    local items = {}
    local tab = TABS[self.tab]
    if tab == "Bugs" then
        items[#items + 1] = { type = "button", label = "All bugs", overview = true, onActivate = function() end }
        items[#items + 1] = { type = "header", label = "Bugs" }
        for _, c in ipairs(Content.characters:all()) do
            local r = p.characters[c.id]
            items[#items + 1] = { type = "button", label = c.name, character = c, onActivate = function() end,
                value = function() return r and r.runs > 0 and ("wave " .. r.bestWave) or "" end }
        end
        items[#items + 1] = { type = "header", label = "" }
        items[#items + 1] = { type = "button", label = "Reset all records", reset = true, onActivate = function()
            if self.confirmReset then
                Records.reset()
                self.confirmReset = nil
                self:build()
            else
                self.confirmReset = true
            end
        end, value = function() return self.confirmReset and "press again" or "" end }
    elseif tab == "Runs" then
        if #p.history == 0 then
            items[#items + 1] = { type = "header", label = "No runs yet" }
        end
        for _, r in ipairs(p.history) do
            items[#items + 1] = { type = "button", label = charName(r.character), run = r, onActivate = function() end,
                value = function() return (r.won and "won · " or "") .. "wave " .. r.wave end }
        end
    elseif tab == "Kills" then
        for _, fam in ipairs(require("src.config.families")) do
            local header = false
            for _, d in ipairs(Content.enemies:all()) do
                if not d.boss and d.family == fam.id then
                    if not header then
                        items[#items + 1] = { type = "header", label = fam.label }
                        header = true
                    end
                    local n = p.killsBy[d.id] or 0
                    items[#items + 1] = { type = "button", label = d.name, enemy = d, onActivate = function() end,
                        value = function() return n > 0 and num(n) or "-" end }
                end
            end
        end
        items[#items + 1] = { type = "header", label = "Queens" }
        for _, d in ipairs(Content.enemies:all()) do
            if d.boss then
                local n = p.killsBy[d.id] or 0
                items[#items + 1] = { type = "button", label = d.name, enemy = d, onActivate = function() end,
                    value = function() return n > 0 and num(n) or "-" end }
            end
        end
    elseif tab == "Recipes" then
        -- the recipe book: molting recipes (result hidden until molted once) and tag set bonuses
        items[#items + 1] = { type = "header", label = "Molting" }
        for _, r in ipairs(Content.molts:all()) do
            local known = Records.moltKnown(r.id)
            local into = Content.items:get(r.into)
            local names = {}
            for _, id in ipairs(r.from) do local d = Content.items:get(id) names[#names + 1] = d and d.name or id end
            items[#items + 1] = { type = "button", label = known and into and into.name or table.concat(names, " + "), recipe = r, onActivate = function() end,
                done = known, value = function() return known and ("x" .. num(p.molts[r.id])) or "" end }
        end
        items[#items + 1] = { type = "header", label = "Tag sets" }
        local tags = {}
        for id, t in pairs(require("src.config.tags")) do if t.set then tags[#tags + 1] = { id = id, def = t } end end
        table.sort(tags, function(a, b) return a.def.set.name < b.def.set.name end)
        for _, t in ipairs(tags) do
            items[#items + 1] = { type = "button", label = t.def.set.name, tagSet = t, onActivate = function() end,
                value = function() return t.def.label end }
        end
    else
        local cats, byCat = {}, {}
        for _, a in ipairs(Content.achievements:all()) do
            if not byCat[a.category] then
                byCat[a.category] = {}
                cats[#cats + 1] = a.category
            end
            local l = byCat[a.category]
            l[#l + 1] = a
        end
        for _, cat in ipairs(cats) do
            items[#items + 1] = { type = "header", label = cat }
            for _, a in ipairs(byCat[cat]) do
                local done = p.achievements[a.id] ~= nil
                items[#items + 1] = { type = "button", label = (done or not a.hidden) and a.name or "???", achievement = a,
                    onActivate = function() end, done = done,
                    value = function()
                        if done then return "done" end
                        local v, goal = Records.progress(a, p)
                        if goal <= 1 or a.hidden then return "" end
                        return math.floor(v * 100 / goal) .. "%"
                    end,
                    -- a progress bar under each one still to do
                    progress = (not done and not a.hidden) and function()
                        local v, goal = Records.progress(a, p)
                        if goal <= 1 then return nil end
                        return v / goal
                    end or nil }
            end
        end
    end
    self.menu:setItems(items)
end

function RecordsState:setTab(i)
    i = (i - 1) % #TABS + 1
    if i == self.tab then return end
    self.tab, self.confirmReset = i, nil
    Audio.play("ui_move")
    self:build()
end

----------------------------------------------------------------------------------------------
-- Details

local function drawBug(def, cx, cy, s, t)
    local spr = Sprites.get(def.sprite)
    lg.setColor(0, 0, 0, 0.35)
    lg.ellipse("fill", cx, cy + s * 2, spr.w * s * 0.55, spr.w * s * 0.25)
    lg.setColor(1, 1, 1, 1)
    if def.model then
        Sprites.drawModel(def.model, math.floor(t * spr.fps) + 1, cx, cy, math.pi * 0.25 + math.sin(t * 0.7) * 1.4, false, s, s)
    else
        Sprites.draw(spr, math.floor(t * (spr.fps or 8)) + 1, cx, cy, t * 0.8, false, s)
    end
    lg.setColor(1, 1, 1, 1)
end

-- A grid of big numbers with small labels under them.
local function tiles(list, x, y, w, cols)
    local u = Theme.u
    local cw = w / cols
    local rh = u(66)
    for i, t in ipairs(list) do
        local cx = x + ((i - 1) % cols) * cw
        local cy = y + math.floor((i - 1) / cols) * rh
        lg.setFont(Theme.font(26, "bold"))
        Theme.printShadow(t[2], cx, cy, t[3] or Theme.colors.text, "center", cw)
        lg.setFont(Theme.font(15))
        lg.setColor(Theme.colors.dim)
        lg.printf(t[1], cx, cy + u(34), cw, "center")
    end
    return y + math.ceil(#list / cols) * rh
end

function RecordsState:panel()
    local w, h = lg.getDimensions()
    local u = Theme.u
    local px = Theme.u(60) + math.min(u(340), w * 0.34) + u(40)
    local pw, ph = w - px - u(60), h - u(200)
    Theme.panel(px, u(150), pw, ph)
    return px, u(150), pw, ph
end

function RecordsState:drawOverview(px, py, pw)
    local p = Records.get()
    local u = Theme.u
    local c = Theme.colors
    local y = py + u(24)
    lg.setFont(Theme.font(28))
    Theme.printShadow("All time", px, y, c.text, "center", pw)
    y = y + u(56)
    local nAch, nDone = Content.achievements:count(), 0
    for _ in pairs(p.achievements) do nDone = nDone + 1 end
    local cols = pw > u(520) and 4 or 3
    y = tiles({
        { "runs", num(p.runs) }, { "wins", num(p.wins), c.good }, { "best wave", num(p.bestWave), c.focus },
        { "bugs squashed", num(p.kills) }, { "queens slain", num(p.queens) }, { "elites", num(p.elites) },
        { "best combo", num(p.bestCombo) }, { "waves cleared", num(p.wavesCleared) }, { "flawless waves", num(p.flawlessWaves) },
        { "items eaten", num(p.itemsEaten) }, { "time played", clock(p.playTime) },
        { "achievements", nDone .. "/" .. nAch, c.accent },
    }, px + u(20), y, pw - u(40), cols)
    -- the family split, as one bar
    local total = 0
    for _, n in pairs(p.killsByFamily) do total = total + n end
    if total > 0 then
        y = y + u(10)
        local bx, bw, bh = px + u(40), pw - u(80), u(10)
        local x = bx
        local palette = { ant = { 0.85, 0.45, 0.3 }, bee = { 0.98, 0.78, 0.25 }, wasp = { 0.95, 0.6, 0.2 },
            hornet = { 0.8, 0.3, 0.25 }, termite = { 0.85, 0.8, 0.65 } }
        local labels = {}
        for _, f in ipairs(require("src.config.families")) do
            local n = p.killsByFamily[f.id] or 0
            if n > 0 then
                local fw = bw * n / total
                lg.setColor(palette[f.id] or c.accent)
                lg.rectangle("fill", x, y, fw, bh)
                x = x + fw
                labels[#labels + 1] = { palette[f.id] or c.accent, ("%s %d%%  "):format(f.label, math.floor(n * 100 / total + 0.5)) }
            end
        end
        lg.setFont(Theme.font(15))
        local txt = {}
        for _, l in ipairs(labels) do txt[#txt + 1] = l[1]; txt[#txt + 1] = l[2] end
        lg.setColor(1, 1, 1, 1)
        lg.printf(txt, bx, y + u(18), bw, "center")
    end
end

function RecordsState:drawCharacter(def, px, py, pw)
    local p = Records.get()
    local r = p.characters[def.id] or { runs = 0, wins = 0, kills = 0, bestWave = 0 }
    local u = Theme.u
    local s = math.floor(u(4))
    local spr = Sprites.get(def.sprite)
    drawBug(def, px + pw / 2, py + u(30) + spr.size * s * 0.5, s, self.t)
    local y = py + u(50) + spr.size * s * 0.9
    lg.setFont(Theme.font(28))
    Theme.printShadow(def.name, px, y, Theme.colors.text, "center", pw)
    y = y + u(56)
    y = tiles({ { "runs", num(r.runs) }, { "wins", num(r.wins), Theme.colors.good }, { "best wave", num(r.bestWave), Theme.colors.focus },
        { "kills", num(r.kills) } }, px + u(20), y, pw - u(40), 4)
    -- this bug's last few runs
    local recent = {}
    for _, h in ipairs(p.history) do
        if h.character == def.id then recent[#recent + 1] = h end
        if #recent >= 5 then break end
    end
    if #recent > 0 then
        lg.setFont(Theme.font(15))
        lg.setColor(Theme.colors.dim)
        lg.printf("Recent runs", px, y + u(6), pw, "center")
        y = y + u(30)
        lg.setFont(Theme.font(16))
        for _, h in ipairs(recent) do
            lg.setColor(h.won and Theme.colors.good or Theme.colors.text)
            lg.printf(("Wave %d   %s KOs   %s"):format(h.wave, num(h.kills), clock(h.time)), px, y, pw, "center")
            y = y + u(22)
        end
    end
end

function RecordsState:drawRun(r, px, py, pw)
    local u = Theme.u
    local c = Theme.colors
    local def = Content.characters:get(r.character)
    local y = py + u(20)
    if def then
        local s = math.floor(u(4))
        local spr = Sprites.get(def.sprite)
        drawBug(def, px + pw / 2, y + spr.size * s * 0.5, s, self.t)
        y = y + spr.size * s + u(4)
    end
    lg.setFont(Theme.font(28))
    local title = r.won and "Patio defended" or (r.outcome == "died" and ("Fell on wave " .. r.wave) or ("Left on wave " .. r.wave))
    Theme.printShadow(title, px, y, r.won and c.good or c.text, "center", pw)
    lg.setFont(Theme.font(15))
    lg.setColor(c.dim)
    lg.printf(charName(r.character) .. "   " .. Records.modeName(r.mode) .. "   " .. date(r.date), px, y + u(38), pw, "center")
    y = y + u(70)
    y = tiles({ { "time", clock(r.time) }, { "KOs", num(r.kills) }, { "best combo", num(r.combo) },
        { "waves cleared", num(r.cleared) }, { "queens", num(r.queens) }, { "skill level", num(r.level) } },
        px + u(20), y, pw - u(40), 3)
    if r.top then
        lg.setFont(Theme.font(16))
        lg.setColor(c.dim)
        lg.printf("Most squashed: " .. enemyName(r.top) .. " (" .. num(r.topN) .. ")", px, y, pw, "center")
        y = y + u(30)
    end
    -- the bag it ended with
    local items = r.items or {}
    if #items > 0 then
        local InvState = require("src.states.inventory")
        local T = math.floor(u(34))
        local per = math.max(1, math.floor((pw - u(40)) / (T + 4)))
        local n = math.min(#items, per * 3)
        local rowN = math.min(n, per)
        local x0 = px + (pw - rowN * (T + 4)) / 2
        for i = 1, n do
            local def2 = Content.items:get(items[i])
            if def2 then
                local ix = x0 + ((i - 1) % per) * (T + 4)
                local iy = y + math.floor((i - 1) / per) * (T + 4)
                lg.setColor(0, 0, 0, 0.35)
                lg.rectangle("fill", ix, iy, T, T, 3, 3)
                InvState.itemIcon({ def = def2 }, ix + 2, iy + 2, T - 4, T - 4)
            end
        end
    end
end

function RecordsState:drawEnemy(def, px, py, pw)
    local p = Records.get()
    local u = Theme.u
    local n = p.killsBy[def.id] or 0
    local spr = Sprites.get(def.sprite)
    local s = math.max(2, math.floor(u(110) / spr.w))
    local cx, cy = px + pw / 2, py + u(110)
    lg.setColor(0, 0, 0, 0.3)
    lg.ellipse("fill", cx, cy + s * 2, spr.w * s * 0.45, spr.w * s * 0.2)
    if n > 0 then lg.setColor(1, 1, 1, 1) else lg.setColor(0.05, 0.04, 0.06, 1) end
    Sprites.draw(spr, math.floor(self.t * spr.fps) + 1, cx, cy, self.t * 0.6, false, s)
    local y = py + u(210)
    lg.setFont(Theme.font(28))
    Theme.printShadow(def.name, px, y, Theme.colors.text, "center", pw)
    y = y + u(56)
    if n == 0 then
        lg.setFont(Theme.font(16))
        lg.setColor(Theme.colors.dim)
        lg.printf("None squashed yet.", px, y, pw, "center")
        return
    end
    local fam = 0
    for _, d in ipairs(Content.enemies:all()) do
        if d.family == def.family then fam = fam + (p.killsBy[d.id] or 0) end
    end
    tiles({ { "squashed", num(n), Theme.colors.focus },
        { "of all kills", math.floor(n * 100 / math.max(1, p.kills) + 0.5) .. "%" },
        { "of its family", math.floor(n * 100 / math.max(1, fam) + 0.5) .. "%" } }, px + u(20), y, pw - u(40), 3)
end

function RecordsState:drawAchievement(a, done, px, py, pw)
    local p = Records.get()
    local u = Theme.u
    local c = Theme.colors
    local secret = a.hidden and not done
    local inCat, doneCat = 0, 0
    for _, o in ipairs(Content.achievements:all()) do
        if o.category == a.category then
            inCat = inCat + 1
            if p.achievements[o.id] then doneCat = doneCat + 1 end
        end
    end
    lg.setFont(Theme.font(15))
    lg.setColor(c.dim)
    lg.printf(("%s  %d / %d"):format(a.category, doneCat, inCat), px, py + u(24), pw, "center")
    local y = py + u(60)
    lg.setFont(Theme.font(32, "bold"))
    Theme.printShadow(secret and "???" or a.name, px, y, done and c.focus or c.text, "center", pw)
    y = y + u(54)
    lg.setFont(Theme.font(18))
    lg.setColor(c.dim)
    lg.printf(secret and "A secret. Keep playing." or a.description, px + u(30), y, pw - u(60), "center")
    y = y + u(60)
    if done then
        lg.setFont(Theme.font(16))
        lg.setColor(c.good)
        lg.printf("Unlocked " .. date(p.achievements[a.id]), px, y, pw, "center")
        return
    end
    if secret then return end
    local v, goal = Records.progress(a, p)
    if goal > 1 then
        local bw, bh = math.min(pw - u(80), u(360)), u(12)
        local bx = px + (pw - bw) / 2
        lg.setColor(1, 1, 1, 0.12)
        lg.rectangle("fill", bx, y, bw, bh, 4, 4)
        lg.setColor(c.focus)
        lg.rectangle("fill", bx, y, bw * v / goal, bh, 4, 4)
        lg.setFont(Theme.font(16))
        lg.setColor(c.text)
        local txt = a.format == "time" and (clock(v) .. " / " .. clock(goal)) or (num(v) .. " / " .. num(goal))
        lg.printf(txt, px, y + u(22), pw, "center")
    end
end

-- One molting recipe: the pieces, an arrow, and what they become (a dark shape until molted once).
function RecordsState:drawRecipe(r, px, py, pw)
    local u = Theme.u
    local c = Theme.colors
    local p = Records.get()
    local InvState = require("src.states.inventory")
    local known = Records.moltKnown(r.id)
    local into = Content.items:get(r.into)
    local T = math.floor(u(64))
    local gap = u(34)
    local n = #r.from
    local total = (n + 1) * T + n * gap
    local x = px + (pw - total) / 2
    local y = py + u(60)
    lg.setFont(Theme.font(28, "bold"))
    for i, id in ipairs(r.from) do
        local d = Content.items:get(id)
        lg.setColor(0, 0, 0, 0.35)
        lg.rectangle("fill", x, y, T, T, 6, 6)
        if d then InvState.itemIcon({ def = d }, x + 4, y + 4, T - 8, T - 8) end
        lg.setFont(Theme.font(13))
        lg.setColor(c.dim)
        lg.printf(d and d.name or id, x - u(20), y + T + u(6), T + u(40), "center")
        lg.setFont(Theme.font(28, "bold"))
        x = x + T
        Theme.printShadow(i < n and "+" or ">", x, y + T / 2 - u(18), c.focus, "center", gap)
        x = x + gap
    end
    lg.setColor(0.5, 1, 0.85, 0.25 + 0.15 * math.sin(self.t * 3))
    lg.rectangle("fill", x - 3, y - 3, T + 6, T + 6, 8, 8)
    lg.setColor(0, 0, 0, 0.5)
    lg.rectangle("fill", x, y, T, T, 6, 6)
    if into then
        if known then InvState.itemIcon({ def = into }, x + 4, y + 4, T - 8, T - 8)
        else InvState.itemIcon({ def = into }, x + 4, y + 4, T - 8, T - 8, 0.08) end
    end
    y = y + T + u(56)
    lg.setFont(Theme.font(28))
    Theme.printShadow(known and into and into.name or "???", px, y, known and { 0.5, 1, 0.85 } or c.text, "center", pw)
    y = y + u(46)
    lg.setFont(Theme.font(16))
    lg.setColor(c.dim)
    if r.hint then
        lg.printf(r.hint, px + u(30), y, pw - u(60), "center")
        y = y + u(30)
    end
    lg.setColor(c.text)
    if known and into then
        lg.printf(into.description, px + u(30), y, pw - u(60), "center")
        y = y + u(70)
        lg.setColor(c.dim)
        lg.printf(("Molted %s time%s"):format(num(p.molts[r.id]), p.molts[r.id] == 1 and "" or "s"), px, y, pw, "center")
    else
        lg.printf("Put these in your bag touching each other (side to side). After the next queen wave they molt into something new.",
            px + u(30), y, pw - u(60), "center")
    end
end

-- A tag set bonus: what three and five touching items with the tag give.
function RecordsState:drawTagSet(t, px, py, pw)
    local u = Theme.u
    local c = Theme.colors
    local Molting = require("src.game.molting")
    local Cfg = require("src.config.molting")
    local col = require("src.core.util").hex(t.def.color)
    local y = py + u(50)
    lg.setFont(Theme.font(32, "bold"))
    Theme.printShadow(t.def.set.name, px, y, col, "center", pw)
    y = y + u(50)
    lg.setFont(Theme.font(16))
    lg.setColor(c.dim)
    lg.printf(t.def.label .. " items", px, y, pw, "center")
    y = y + u(50)
    lg.setFont(Theme.font(18))
    lg.setColor(c.text)
    lg.printf(("%d touching:  %s"):format(Cfg.set.tier1, Molting.setText(t.def.set, 1)), px, y, pw, "center")
    y = y + u(32)
    lg.printf(("%d touching:  %s"):format(Cfg.set.tier2, Molting.setText(t.def.set, 2)), px, y, pw, "center")
    y = y + u(60)
    lg.setFont(Theme.font(15))
    lg.setColor(c.dim)
    lg.printf("Items sharing a tag count when they all touch in one group in your bag. The bag draws their seams in the tag's colour.",
        px + u(30), y, pw - u(60), "center")
end

----------------------------------------------------------------------------------------------

function RecordsState:update(dt)
    self.t = self.t + dt
    if Input.pressed("ui_tab_next") or Input.pressed("ui_right") then self:setTab(self.tab + 1) end
    if Input.pressed("ui_tab_prev") or Input.pressed("ui_left") then self:setTab(self.tab - 1) end
    self.menu:update(dt)
    local it = self.menu:focused()
    if self.confirmReset and not (it and it.reset) then self.confirmReset = nil end
end

function RecordsState:tabRects()
    local u = Theme.u
    lg.setFont(Theme.font(18))
    local f = lg.getFont()
    local rects, x = {}, u(60)
    for i, name in ipairs(TABS) do
        local w = f:getWidth(name) + u(28)
        rects[i] = { x = x, y = u(100), w = w, h = f:getHeight() + u(12) }
        x = x + w + u(6)
    end
    return rects
end

function RecordsState:draw()
    local w, h = lg.getDimensions()
    local u = Theme.u
    local c = Theme.colors
    lg.clear(c.bg)
    lg.setFont(Theme.font(40))
    Theme.printShadow("RECORDS", u(60), u(40), c.focus)

    lg.setFont(Theme.font(18))
    for i, r in ipairs(self:tabRects()) do
        local on = i == self.tab
        lg.setColor(on and { 0.2, 0.15, 0.12, 1 } or { 0.1, 0.08, 0.075, 0.9 })
        lg.rectangle("fill", r.x, r.y, r.w, r.h)
        lg.setColor(c.focus[1], c.focus[2], c.focus[3], on and 1 or 0.25)
        lg.rectangle("fill", r.x, r.y + r.h - 2, r.w, 2)
        lg.setColor(on and c.focus or c.dim)
        lg.print(TABS[i], r.x + u(14), r.y + u(6))
    end

    self.menu:draw()
    Theme.navFooter()
    local it = self.menu:focused()
    if not it then return end
    local px, py, pw = self:panel()
    if it.overview or it.reset then self:drawOverview(px, py, pw)
    elseif it.character then self:drawCharacter(it.character, px, py, pw)
    elseif it.run then self:drawRun(it.run, px, py, pw)
    elseif it.enemy then self:drawEnemy(it.enemy, px, py, pw)
    elseif it.achievement then self:drawAchievement(it.achievement, it.done, px, py, pw)
    elseif it.recipe then self:drawRecipe(it.recipe, px, py, pw)
    elseif it.tagSet then self:drawTagSet(it.tagSet, px, py, pw)
    end
end

function RecordsState:mousemoved(x, y) self.menu:mousemoved(x, y) end
function RecordsState:mousepressed(x, y, b)
    for i, r in ipairs(self:tabRects()) do
        if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then return self:setTab(i) end
    end
    self.menu:mousepressed(x, y, b)
end
function RecordsState:wheelmoved(x, y) self.menu:wheelmoved(x, y) end

return RecordsState
