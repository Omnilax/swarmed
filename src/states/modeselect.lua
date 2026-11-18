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

function ModeSelect.new()
    local self = setmetatable({ t = 0 }, ModeSelect)
    local items, focus = {}, 1
    for _, m in ipairs(Content.modes:filter(function(d) return not d.hidden end)) do
        items[#items + 1] = { type = "button", label = m.name, mode = m, onActivate = function()
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
    local m = it and it.mode
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
