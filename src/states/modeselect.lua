-- Game mode select, generated from content/modes. Play -> mode -> bug (-> starting items).
local State = require("src.core.state")
local Content = require("src.content")
local Theme = require("src.ui.theme")
local Menu = require("src.ui.menu")
local Families = require("src.config.families")

local ModeSelect = {}
ModeSelect.__index = ModeSelect

local lastMode = "colony"       -- the menu opens on whatever was played last

local function familyNames(list)
    local out = {}
    for _, f in ipairs(Families) do
        for _, id in ipairs(list) do if id == f.id then out[#out + 1] = f.label end end
    end
    return table.concat(out, ", ")
end

local function percent(v) return math.floor(v * 100 + 0.5) .. "%" end

-- The handful of facts that tell modes apart, worked out from the mode's own data.
function ModeSelect.facts(m)
    local Amber = require("src.game.amber")
    if m.facts then return m.facts end
    if m.name == "Artifacts" and not m.id then
        local on = require("src.game.artifacts").names(require("src.game.artifacts").active())
        return { { "On now", on or "None" } }
    end
    if not m.daily and not Amber.modeOpen(m.id) then
        local u = Amber.modeUnlock(m.id)
        return { { "Locked", ("Unlock it in the Burrow for %d amber (you have %d)."):format(u.cost, Amber.balance()) } }
    end
    if m.daily then
        local f = {}
        for _, x in ipairs(m.dailyFacts) do f[#f + 1] = x end
        local b = require("src.game.daily").best(m.daily.key)
        f[#f + 1] = { "Today's best", b and (("Wave %d, %d KOs%s"):format(b.wave, b.kos, b.won and ", won" or "")) or "Not played yet" }
        return f
    end
    local f = {}
    if m.endless then
        f[#f + 1] = { "Length", "No waves, no end" }
    elseif m.custom then
        local set = require("src.game.customwaves").active()
        f[#f + 1] = { "Your set", set.name .. " (" .. #set.waves .. " waves)" }
        f[#f + 1] = { "Enemies", "Whatever you put in" }
        return f
    elseif m.waves then
        f[#f + 1] = { "Length", #m.waves .. " scripted waves, then again, tougher" }
    elseif m.finalWave then
        f[#f + 1] = { "Length", m.finalWave .. " waves, then keep going" }
    else
        f[#f + 1] = { "Length", "No end" }
    end
    f[#f + 1] = { "Enemies", m.families and familyNames(m.families) or "Every family" }
    local el = m.elites
    if el and el.chance == 0 then f[#f + 1] = { "Elites", "None" }
    elseif el and el.chance and el.chance >= 1 then f[#f + 1] = { "Elites", "Every enemy" }
    elseif el and el.mul then f[#f + 1] = { "Elites", el.mul .. "x as often" }
    else f[#f + 1] = { "Elites", "Now and then" } end
    if m.enemyHp ~= 1 or m.enemyDamage ~= 1 then
        f[#f + 1] = { "Enemy strength", percent(m.enemyHp) .. " health, " .. percent(m.enemyDamage) .. " damage" }
    end
    if m.spawn and m.spawn.bossEvery == 1 then f[#f + 1] = { "Queens", "Every wave" } end
    local mc = m.spawn and m.spawn.modifiers
    if mc and mc.chance and mc.chance >= 1 then f[#f + 1] = { "Wave modifiers", "Every wave, from the first" } end
    if m.director and m.director.eventBonus then f[#f + 1] = { "Events", "Constant" } end
    if m.chooseItems then f[#f + 1] = { "Start", "Pick your own items" } end
    return f
end

-- The map row's panel: the chosen location and who lives there (content/stages `fauna`).
function ModeSelect.mapInfo()
    local Cosmetics = require("src.game.cosmetics")
    local st = Content.stages:get(Cosmetics.location())
    local f = st.fauna or {}
    local list = {}
    for k, v in pairs(f) do
        if k ~= "first" and k ~= "other" and type(v) == "number" and v > 1 then list[#list + 1] = { k, v } end
    end
    table.sort(list, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end return a[1] < b[1] end)
    local names = {}
    for i = 1, math.min(5, #list) do
        local id = list[i][1]
        local e = Content.enemies:get(id)
        local fam
        for _, x in ipairs(Families) do if x.id == id then fam = x.label end end
        names[#names + 1] = e and e.name or fam or id
    end
    local facts = { { "Lives here", #names > 0 and table.concat(names, ", ") or "A bit of everything" } }
    local open, all = #Cosmetics.locations(), #Content.stages:all()
    if open < all then facts[#facts + 1] = { "More maps", ("%d more in the Burrow"):format(all - open) } end
    return { name = st.name, tagline = "Where the run is fought. Left and right to change.", description = st.description or "", facts = facts }
end

-- The info panel for the Keepsake row.
function ModeSelect.keepsakeInfo()
    local k = require("src.game.keepsakes").get(require("src.game.keepsakes").chosen())
    return { name = k and k.name or "No keepsake", tagline = "One small trade carried into the run. Left and right to change.",
        description = k and k.description or "Your bug as it is. Keepsakes are bought in the Burrow; each trades a little of one thing for another.",
        facts = {} }
end

function ModeSelect.new()
    local self = setmetatable({ t = 0 }, ModeSelect)
    local items, focus = {}, 2
    -- the map: any open location (bought in the Burrow); also in Cosmetics > Location
    do
        local Cosmetics = require("src.game.cosmetics")
        local opts = {}
        for _, s in ipairs(Cosmetics.locations()) do opts[#opts + 1] = { value = s.id, label = s.name } end
        items[#items + 1] = { type = "choice", label = "Map", options = opts, map = true,
            get = Cosmetics.location, set = Cosmetics.setLocation }
    end
    -- a keepsake: one small trade carried into the run, bought in the Burrow (src/game/keepsakes.lua)
    do
        local Keepsakes = require("src.game.keepsakes")
        local opts = { { value = "none", label = "None" } }
        for _, k in ipairs(Keepsakes.list) do
            if Keepsakes.owned(k.id) then opts[#opts + 1] = { value = k.id, label = k.name } end
        end
        if #opts > 1 then
            items[#items + 1] = { type = "choice", label = "Keepsake", options = opts, keepsake = true,
                get = function() return Keepsakes.chosen() or "none" end,
                set = function(v) Keepsakes.choose(v ~= "none" and v or nil) end }
            focus = focus + 1
        end
    end
    for _, m in ipairs(Content.modes:filter(function(d) return not d.hidden end)) do
        local Amber = require("src.game.amber")
        local open = Amber.modeOpen(m.id)
        items[#items + 1] = { type = "button", label = m.name, mode = m, locked = not open,
            value = not open and function() return "locked" end or nil, onActivate = function()
            -- not bought yet: the Burrow sells it for amber (src/game/amber.lua)
            if not Amber.modeOpen(m.id) then require("src.core.audio").play("ui_back") return end
            lastMode = m.id
            if m.custom then
                State.push(require("src.states.wavebuilder").new())     -- build or pick a set first
            else
                State.push(require("src.states.charselect").new({ gameMode = m.id }))
            end
        end }
        if m.id == lastMode then focus = #items end
    end
    -- the daily run: today's seed picks the bug, stage, species order and wave modifiers
    local Daily = require("src.game.daily")
    local d = Daily.info()
    local dc, ds = Content.characters:get(d.character), Content.stages:get(d.stage)
    local dailyMode = { name = "Daily Run", daily = d,
        tagline = "Same bug, same waves, for everyone today.",
        description = "Today's seed picks your bug, the stage, the order the species arrive in and every wave modifier. Colony rules. A new run every day.",
        dailyFacts = { { "Date", d.key }, { "Bug", dc and dc.name or d.character }, { "Stage", ds and ds.name or d.stage } } }
    items[#items + 1] = { type = "button", label = "Daily Run", mode = dailyMode, onActivate = function()
        State.switch(require("src.states.game").new(Daily.params()))
    end }
    -- the weekly challenge: a week's seed, with two artifacts on (src/game/daily.lua)
    do
        local wk = Daily.weekInfo()
        local wc, ws = Content.characters:get(wk.character), Content.stages:get(wk.stage)
        local arts = require("src.game.artifacts").names(wk.artifacts) or "None"
        local b = Daily.best(wk.key)
        local weekMode = { name = "Weekly Challenge",
            tagline = "A new challenge every Monday, with two artifacts on.",
            description = "This week's seed picks your bug, the map and two artifacts, which are on whether you own them or not. Colony rules, one map all run.",
            facts = { { "Week", wk.key }, { "Bug", wc and wc.name or wk.character }, { "Map", ws and ws.name or wk.stage },
                { "Artifacts", arts },
                { "Your best", b and (("Wave %d, %d KOs%s"):format(b.wave, b.kos, b.won and ", won" or "")) or "Not played yet" } } }
        items[#items + 1] = { type = "button", label = "Weekly Challenge", mode = weekMode, onActivate = function()
            State.switch(require("src.states.game").new(Daily.weekParams()))
        end }
    end
    -- a run code from a friend, read from the clipboard (src/game/runcode.lua)
    do
        local codeInfo = { name = "Play a Run Code", tagline = "The same run a friend played.",
            description = "Copy a run code (from the game over or victory screen), then press this. You get the same bug, map, mode, danger, seed and artifacts.",
            facts = {} }
        local it
        it = { type = "button", label = "Play a Run Code", mode = codeInfo, onActivate = function()
            local ok, text = pcall(love.system.getClipboardText)
            local params, why = require("src.game.runcode").decode(ok and text or nil)
            if not params then
                codeInfo.facts = { { "Clipboard", why } }
                require("src.core.audio").play("ui_back")
                return
            end
            State.switch(require("src.states.game").new(params))
        end }
        items[#items + 1] = it
    end
    -- artifacts: run rules for any mode, bought with amber (src/states/artifactpicker.lua)
    local Artifacts = require("src.game.artifacts")
    local artifactInfo = { name = "Artifacts", tagline = "Bend the rules of any mode.",
        description = "Artifacts change how a run plays: glass shells, giant ants, twin queens and more. Buy them in the Burrow with amber, then switch them on here. They stay on until you switch them off." }
    items[#items + 1] = { type = "button", label = "Artifacts", mode = artifactInfo,
        value = function() local n = #Artifacts.active() return n > 0 and (n .. " on") or "" end,
        onActivate = function() State.push(require("src.states.artifactpicker").new()) end }
    -- practice: any bug, mode, wave and species, nothing counts (src/states/practice.lua)
    items[#items + 1] = { type = "button", label = "Practice", mode = { name = "Practice",
        tagline = "Try anything. Nothing counts.",
        description = "Pick a bug, mode, starting wave and one species (or a boss), with the items a real run would have by then, and invincibility if you like. Practice never counts toward records and is never saved.",
        facts = {} }, onActivate = function() State.push(require("src.states.practice").new()) end }
    items[#items + 1] = { type = "button", label = "Back", onActivate = function() State.pop() end }
    self.menu = Menu.new({
        items = items,
        onBack = function() State.pop() end,
        touchConfirm = true,     -- first tap shows a mode, the second picks it
        rect = function()
            local w, h = love.graphics.getDimensions()
            return Theme.u(60), Theme.u(120), math.min(Theme.u(320), w * 0.32), h - Theme.u(200)
        end,
    })
    self.menu.focus = focus
    return self
end

function ModeSelect:update(dt)
    self.t = self.t + dt
    self.menu:update(dt)
end

function ModeSelect:draw()
    local lg = love.graphics
    local u = Theme.u
    local c = Theme.colors
    local w, h = lg.getDimensions()
    lg.clear(c.bg)
    Theme.title("Game Mode")
    self.menu:draw()

    local it = self.menu:focused()
    local m = it and (it.map and ModeSelect.mapInfo() or it.keepsake and ModeSelect.keepsakeInfo() or it.mode)
    if not m then return end
    local px = math.min(u(320), w * 0.32) + u(100)
    local pw, ph = w - px - u(60), h - u(200)
    Theme.panel(px, u(120), pw, ph)
    local x, y, iw = px + u(32), u(150), pw - u(64)

    lg.setFont(Theme.font("title", "bold"))
    Theme.printShadow(m.name:upper(), x, y, c.focus)
    y = y + lg.getFont():getHeight() + u(6)
    lg.setFont(Theme.font("body"))
    lg.setColor(c.accent)
    local _, tl = lg.getFont():getWrap(m.tagline, iw)
    lg.printf(m.tagline, x, y, iw)
    y = y + #tl * lg.getFont():getHeight() + u(18)
    lg.setColor(c.text)
    local _, dl = lg.getFont():getWrap(m.description, iw)
    lg.printf(m.description, x, y, iw)
    y = y + #dl * lg.getFont():getHeight() + u(28)

    -- facts: a thin rule, then label / value rows
    lg.setColor(c.panelHi)
    lg.rectangle("fill", x, y, iw, 1)
    y = y + u(16)
    lg.setFont(Theme.font("label"))
    local lw = u(150)
    for _, f in ipairs(ModeSelect.facts(m)) do
        if y > u(120) + ph - u(40) then break end
        lg.setColor(c.dim)
        lg.print(f[1], x, y)
        lg.setColor(c.text)
        lg.printf(f[2], x + lw, y, iw - lw)
        local _, vl = lg.getFont():getWrap(f[2], iw - lw)
        y = y + math.max(1, #vl) * lg.getFont():getHeight() + u(8)
    end
end

function ModeSelect:mousemoved(x, y) self.menu:mousemoved(x, y) end
function ModeSelect:mousepressed(x, y, b) self.menu:mousepressed(x, y, b) end
function ModeSelect:wheelmoved(x, y) self.menu:wheelmoved(x, y) end

return ModeSelect
