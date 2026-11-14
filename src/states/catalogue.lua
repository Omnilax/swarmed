-- Bug catalogue: every enemy in content/enemies, with a live preview, stats and notes.
-- Generated from the content registry, so new enemies show up here automatically.
local State = require("src.core.state")
local Content = require("src.content")
local Theme = require("src.ui.theme")
local Input = require("src.core.input")
local Menu = require("src.ui.menu")
local Sprites = require("src.gfx.sprites")
local util = require("src.core.util")
local Elites = require("src.game.elites")

local Catalogue = {}
Catalogue.__index = Catalogue

local function sorted()
    local list = {}
    for _, def in ipairs(Content.enemies:all()) do list[#list + 1] = def end
    table.sort(list, function(a, b)
        if a.spawn.minWave ~= b.spawn.minWave then return a.spawn.minWave < b.spawn.minWave end
        return a.name < b.name
    end)
    return list
end

local function groupLabel(g)
    if g >= 1.2 then return "Huge columns" elseif g >= 0.8 then return "Columns" elseif g >= 0.3 then return "Small packs" end
    return "Alone or in pairs"
end

function Catalogue.new()
    local self = setmetatable({ t = 0 }, Catalogue)
    local items = {}
    local list = sorted()
    -- one section per enemy family (ants, bees, wasps, termites...), then the queens
    for _, fam in ipairs(require("src.config.families")) do
        local header = false
        for _, def in ipairs(list) do
            if not def.boss and def.family == fam.id then
                if not header then items[#items + 1] = { type = "header", label = fam.label }; header = true end
                items[#items + 1] = { type = "button", label = def.name, enemy = def, onActivate = function() end }
            end
        end
    end
    items[#items + 1] = { type = "header", label = "Queens (bosses)" }
    for _, def in ipairs(list) do
        if def.boss then items[#items + 1] = { type = "button", label = def.name, enemy = def, onActivate = function() end } end
    end
    items[#items + 1] = { type = "header", label = "Elite variants" }
    for _, el in ipairs(Content.elites:all()) do
        items[#items + 1] = { type = "button", label = el.name, elite = el, onActivate = function() end }
    end
    items[#items + 1] = { type = "button", label = "Back", onActivate = function() State.pop() end }
    self.menu = Menu.new({
        items = items,
        onBack = function() State.pop() end,
        rect = function()
            local w, h = love.graphics.getDimensions()
            return Theme.u(60), Theme.u(120), math.min(Theme.u(320), w * 0.3), h - Theme.u(200)
        end,
    })
    return self
end

local function mult(v) return ("x%g"):format(math.floor(v * 100 + 0.5) / 100) end

-- An elite affix: a worker ant wearing it, what it changes, and species with their own twist.
function Catalogue:drawElite(el)
    local lg = love.graphics
    local w, h = lg.getDimensions()
    local u = Theme.u
    local px = math.min(u(320), w * 0.3) + u(110)
    local pw, ph = w - px - u(60), h - u(200)
    Theme.panel(px, u(120), pw, ph)
    local c = Elites.color(el)
    local spr = Sprites.get("soldier_ant")
    local stageH = math.min(u(200), ph * 0.38)
    local cx, cy = px + pw / 2, u(140) + stageH / 2
    local s = math.max(2, math.floor(stageH * 0.55 / spr.w))
    lg.setColor(c[1], c[2], c[3], 0.25 + 0.1 * math.sin(self.t * 5))
    lg.ellipse("fill", cx, cy + s * 2, spr.w * s * 0.7, spr.w * s * 0.3)
    local face = self.t * 0.8
    lg.setColor(0.5 + c[1] * 0.5, 0.5 + c[2] * 0.5, 0.5 + c[3] * 0.5, 1)
    Sprites.draw(spr, math.floor(self.t * spr.fps) + 1, cx, cy, face, false, s * el.scale)
    lg.setBlendMode("add")
    lg.setColor(c[1], c[2], c[3], el.glow * (0.75 + 0.25 * math.sin(self.t * 6)))
    Sprites.draw(spr, math.floor(self.t * spr.fps) + 1, cx, cy, face, false, s * el.scale)
    lg.setBlendMode("alpha")

    local ty = u(150) + stageH
    lg.setFont(Theme.font(30))
    Theme.printShadow(el.name .. " (elite)", px, ty, c, "center", pw)
    lg.setFont(Theme.font(18))
    lg.setColor(Theme.colors.dim)
    lg.printf(el.description, px + u(30), ty + u(42), pw - u(60), "center")
    local _, lines = lg.getFont():getWrap(el.description, pw - u(60))
    local y = ty + u(42) + #lines * lg.getFont():getHeight() + u(16)
    local special = {}
    if el.armor then special[#special + 1] = ("ignores %d%% of each hit"):format(el.armor * 100) end
    if el.venom then special[#special + 1] = "poisonous bites" end
    if el.bonusXP then special[#special + 1] = "+" .. el.bonusXP .. " bonus XP when killed" end
    if el.onDeath then special[#special + 1] = "bursts on death" end
    if next(el.params) then special[#special + 1] = "faster attacks" end
    local rows = {
        { "Health", mult(el.hp) }, { "Damage", mult(el.damage) },
        { "Speed", mult(el.speed) }, { "Size", mult(el.scale) },
        { "First seen", "Wave " .. el.minWave }, { "Special", #special > 0 and special[1] or "-" },
    }
    for i = 2, #special do rows[#rows + 1] = { "", special[i] } end
    lg.setFont(Theme.font(16))
    for i, row in ipairs(rows) do
        local col = (i - 1) % 2
        local rx = px + u(40) + col * (pw / 2)
        local ry = y + math.floor((i - 1) / 2) * u(24)
        lg.setColor(Theme.colors.dim)
        lg.print(row[1], rx, ry)
        lg.setColor(Theme.colors.accent)
        lg.print(row[2], rx + u(130), ry)
    end
    y = y + math.ceil(#rows / 2) * u(24) + u(12)
    local notes = {}
    for _, d in ipairs(Content.enemies:all()) do
        local own = d.elites and d.elites[el.id]
        if own and own.note then notes[#notes + 1] = d.name .. ": " .. own.note end
    end
    if #notes > 0 then
        lg.setColor(Theme.colors.good)
        lg.printf("Species twists\n" .. table.concat(notes, "\n"), px + u(40), y, pw - u(80), "center")
    end
end

function Catalogue:update(dt)
    self.t = self.t + dt
    self.menu:update(dt)
end

function Catalogue:draw()
    local lg = love.graphics
    local w, h = lg.getDimensions()
    local u = Theme.u
    lg.clear(Theme.colors.bg)
    Theme.title("Bug catalogue")
    self.menu:draw()
    Theme.footer(Input.lastDevice == "gamepad" and { { "D-pad", "Browse" }, { "B", "Back" } }
        or { { "Arrows", "Browse" }, { "Esc", "Back" } })

    local it = self.menu:focused()
    if it and it.elite then return self:drawElite(it.elite) end
    local def = it and it.enemy
    if not def then return end
    local px = math.min(u(320), w * 0.3) + u(110)
    local pw, ph = w - px - u(60), h - u(200)
    Theme.panel(px, u(120), pw, ph)

    -- Preview: the bug walking a slow circle on a patch of lit concrete.
    local spr = Sprites.get(def.sprite)
    local stageH = math.min(u(220), ph * 0.42)
    local cx, cy = px + pw / 2, u(120) + u(20) + stageH / 2
    local s = math.max(2, math.floor(stageH * 0.5 / spr.w))
    lg.setColor(0.26, 0.25, 0.23, 1)
    lg.ellipse("fill", cx, cy, stageH * 1.1, stageH * 0.42)
    lg.setColor(0.36, 0.34, 0.31, 1)
    lg.ellipse("fill", cx, cy, stageH * 0.85, stageH * 0.3)
    local a = self.t * 0.6
    local r = stageH * 0.55
    local bx, by = cx + math.cos(a) * r, cy + math.sin(a) * r * 0.45
    -- facing: tangent of the (iso-squashed) circle
    local face = math.atan2(math.cos(a) * 0.45, -math.sin(a))
    lg.setColor(0, 0, 0, 0.3)
    lg.ellipse("fill", bx + s, by + s * 2, spr.w * s * 0.4, spr.w * s * 0.18)
    lg.setColor(1, 1, 1, 1)
    Sprites.draw(spr, math.floor(self.t * spr.fps) + 1, bx, by, face, false, s)

    local ty = u(120) + u(30) + stageH
    lg.setFont(Theme.font(30))
    Theme.printShadow(def.name, px, ty, Theme.colors.text, "center", pw)
    lg.setFont(Theme.font(18))
    lg.setColor(Theme.colors.dim)
    lg.printf(def.description or "", px + u(30), ty + u(42), pw - u(60), "center")
    local descFont = lg.getFont()
    if def.tags and #def.tags > 0 then
        lg.setFont(Theme.font(14))
        lg.setColor(Theme.colors.dim[1], Theme.colors.dim[2], Theme.colors.dim[3], 0.7)
        lg.printf(table.concat(def.tags, "  ·  "):upper(), px, ty - u(20), pw, "center")
    end
    local _, descLines = descFont:getWrap(def.description or "", pw - u(60))
    local y = ty + u(42) + #descLines * descFont:getHeight() + u(14)
    if def.lore then
        lg.setFont(Theme.font(16))
        lg.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], 0.8)
        lg.printf(def.lore, px + u(40), y, pw - u(80), "center")
        local _, lines = lg.getFont():getWrap(def.lore, pw - u(80))
        y = y + #lines * lg.getFont():getHeight() + u(16)
    end

    local behavior = Content.behaviors:get(def.behavior)
    local rows = {
        { "Health", tostring(def.hp) },
        { "Speed", tostring(def.speed) },
        { "Bite damage", tostring(def.damage) },
        { "Size", ("%.1f"):format(def.radius) },
        { "Weight", tostring(def.mass or 1) },
        { "Moves", behavior and behavior.name or def.behavior },
        { "First seen", def.boss and ("Boss waves from " .. def.spawn.minWave) or ("Wave " .. def.spawn.minWave) },
        { "Arrives in", def.boss and ("Lays " .. ((Content.enemies:get(def.behaviorParams.brood or "") or {}).name or "?")) or groupLabel(def.spawn.groupSize or 1) },
    }
    lg.setFont(Theme.font(16))
    for i, row in ipairs(rows) do
        local col = (i - 1) % 2
        local rx = px + u(40) + col * (pw / 2)
        local ry = y + math.floor((i - 1) / 2) * u(24)
        lg.setColor(Theme.colors.dim)
        lg.print(row[1], rx, ry)
        lg.setColor(Theme.colors.accent)
        lg.print(row[2], rx + u(130), ry)
    end
    y = y + math.ceil(#rows / 2) * u(24) + u(12)
    if def.tip then
        lg.setColor(Theme.colors.good)
        lg.printf("Tip: " .. def.tip, px + u(40), y, pw - u(80), "center")
    end
end

function Catalogue:mousemoved(x, y) self.menu:mousemoved(x, y) end
function Catalogue:mousepressed(x, y, b) self.menu:mousepressed(x, y, b) end
function Catalogue:wheelmoved(x, y) self.menu:wheelmoved(x, y) end

return Catalogue
