-- The Field Guide: how everything in the game works (pages in src/config/guide.lua), plus the
-- bug and item catalogues. Pages for systems the player hasn't met yet (Gentle Start,
-- src/game/onramp.lua) read "not met yet" instead of spoiling them. Main menu and pause menu.
local State = require("src.core.state")
local Theme = require("src.ui.theme")
local Menu = require("src.ui.menu")
local Settings = require("src.core.settings")
local Guide = require("src.config.guide")

local FieldGuide = {}
FieldGuide.__index = FieldGuide

-- Has the player met this page's system? (always, with Gentle Start off)
function FieldGuide.known(page)
    if not page.system or Settings.get("gentleStart") == false then return true end
    return require("src.game.onramp").seen(page.system)
end

-- The tags page, written from src/config/tags.lua so it never goes out of date.
local function tagsPage()
    local tags = require("src.config.tags")
    local ids = {}
    for id, t in pairs(tags) do if t.set then ids[#ids + 1] = id end end
    table.sort(ids, function(a, b) return tags[a].label < tags[b].label end)
    local lines = {}
    for _, id in ipairs(ids) do
        local t = tags[id]
        local parts = {}
        for stat, v in pairs(t.set.stats or {}) do
            local def
            for _, s in ipairs(require("src.config.stats")) do if s.id == stat then def = s end end
            parts[#parts + 1] = (v > 0 and "+" or "") .. v .. (def and def.percent and "% " or " ") .. (def and def.label or stat)
        end
        table.sort(parts)
        lines[#lines + 1] = t.label .. ": " .. t.set.name .. " (" .. table.concat(parts, ", ") .. ")"
    end
    return { title = "Set bonuses", text = "Three touching items with one tag give:\n" .. table.concat(lines, "\n") }
end

function FieldGuide.new(opts)
    local self = setmetatable({ t = 0, opts = opts or {} }, FieldGuide)
    local items = {}
    if not self.opts.inRun then
        items[#items + 1] = { type = "button", label = "Play the tutorial", known = true,
            page = { title = "Tutorial", text = "A guided first fight, one lesson at a time: moving, attacking, dashing, specials, nectar, level-ups, items, the bag, the shop, frenzy, elites and a queen." },
            onActivate = function() require("src.states.menu").tutorial() end }
    end
    for _, g in ipairs(Guide) do
        items[#items + 1] = { type = "header", label = g.group }
        for _, page in ipairs(g.pages) do
            local known = FieldGuide.known(page)
            items[#items + 1] = { type = "button", label = known and page.title or "? ? ?", page = page, known = known,
                onActivate = function() end }
        end
        if g.group == "Items" then
            items[#items + 1] = { type = "button", label = "Set bonuses", page = tagsPage(), known = true, onActivate = function() end }
        end
    end
    if not self.opts.inRun then
        items[#items + 1] = { type = "header", label = "Catalogues" }
        items[#items + 1] = { type = "button", label = "Bug Catalogue", link = true,
            page = { title = "Bug Catalogue", text = "Every bug you can play and every enemy you have met, with their moves and stats." },
            known = true, onActivate = function() State.push(require("src.states.catalogue").new()) end }
        items[#items + 1] = { type = "button", label = "Item Catalogue", link = true,
            page = { title = "Item Catalogue", text = "Every item in the game, what it does, its tags and its rarity." },
            known = true, onActivate = function() State.push(require("src.states.itemcatalogue").new()) end }
    end
    items[#items + 1] = { type = "button", label = "Back", onActivate = function() State.pop() end }
    self.menu = Menu.new({
        items = items,
        onBack = function() State.pop() end,
        rect = function()
            local w, h = love.graphics.getDimensions()
            return Theme.u(60), Theme.u(120), math.min(Theme.u(320), w * 0.32), h - Theme.u(200)
        end,
    })
    return self
end

function FieldGuide:update(dt)
    self.t = self.t + dt
    self.menu:update(dt)
end

function FieldGuide:draw()
    local lg = love.graphics
    local u, c = Theme.u, Theme.colors
    local w, h = lg.getDimensions()
    if self.opts.inRun then
        lg.setColor(0, 0, 0, 0.82)
        lg.rectangle("fill", 0, 0, w, h)
    else
        lg.clear(c.bg)
    end
    Theme.title("Field Guide")
    self.menu:draw()
    local it = self.menu:focused()
    local page = it and it.page
    if not page then return end
    local px = math.min(u(320), w * 0.32) + u(100)
    local pw, ph = w - px - u(60), h - u(200)
    Theme.panel(px, u(120), pw, ph)
    local x, y, iw = px + u(32), u(150), pw - u(64)
    lg.setFont(Theme.font("title", "bold"))
    Theme.printShadow((it.known and page.title or "Not met yet"):upper(), x, y, c.focus)
    y = y + lg.getFont():getHeight() + u(14)
    lg.setFont(Theme.font("body"))
    local text = it.known and page.text or "You haven't come across this yet. Keep playing: it shows up in a run soon, and this page fills in once you have met it."
    for para in (text .. "\n"):gmatch("(.-)\n") do
        y = y + Theme.rich(para, x, y, iw, "left", c.text, 1) + u(6)
    end
    if it.link then
        lg.setFont(Theme.font("label"))
        lg.setColor(c.dim)
        lg.print("Press to open", x, u(120) + ph - u(44))
    end
    lg.setColor(1, 1, 1, 1)
end

function FieldGuide:mousemoved(x, y) self.menu:mousemoved(x, y) end
function FieldGuide:mousepressed(x, y, b) self.menu:mousepressed(x, y, b) end
function FieldGuide:wheelmoved(x, y) self.menu:wheelmoved(x, y) end

return FieldGuide
