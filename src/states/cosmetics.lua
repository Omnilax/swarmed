-- Cosmetics: choose the location runs start on, switch map decor on and off, and pick a skin
-- for each bug. Generated from content/stages, content/decor and content/skins.
local State = require("src.core.state")
local Content = require("src.content")
local Theme = require("src.ui.theme")
local Menu = require("src.ui.menu")
local Sprites = require("src.gfx.sprites")
local Ground = require("src.gfx.ground")
local Cosmetics = require("src.game.cosmetics")

local Cos = {}
Cos.__index = Cos

local NATURAL = "natural"

function Cos.new()
    local self = setmetatable({ t = 0 }, Cos)
    local items = { { type = "header", label = "Location" } }
    local locs = {}
    for _, s in ipairs(Cosmetics.locations()) do locs[#locs + 1] = { value = s.id, label = s.name } end
    items[#items + 1] = { type = "choice", label = "Arena", options = locs, preview = "location",
        get = Cosmetics.location, set = Cosmetics.setLocation }

    items[#items + 1] = { type = "header", label = "Map Decor" }
    for _, d in ipairs(Content.decor:all()) do
        if Cosmetics.isUnlocked(d) then
            items[#items + 1] = { type = "toggle", label = d.name, preview = "location", decor = d,
                get = function() return Cosmetics.decorOn(d.id) end,
                set = function(v) Cosmetics.setDecor(d.id, v) end }
        end
    end

    items[#items + 1] = { type = "header", label = "Skins" }
    for _, c in ipairs(Content.characters:all()) do
        local opts = { { value = NATURAL, label = "Natural" } }
        for _, s in ipairs(Cosmetics.skinsFor(c.id)) do opts[#opts + 1] = { value = s.id, label = s.name } end
        items[#items + 1] = { type = "choice", label = c.name, options = opts, character = c,
            get = function() return Cosmetics.data.skins[c.id] or NATURAL end,
            set = function(v) Cosmetics.setSkin(c.id, v ~= NATURAL and v or nil) end }
    end
    items[#items + 1] = { type = "button", label = "Back", onActivate = function() State.pop() end }

    self.menu = Menu.new({
        items = items,
        onBack = function() State.pop() end,
        rect = function()
            local w, h = love.graphics.getDimensions()
            return Theme.u(60), Theme.u(120), math.min(Theme.u(400), w * 0.4), h - Theme.u(200)
        end,
    })
    return self
end

function Cos:update(dt)
    self.t = self.t + dt
    self.menu:update(dt)
end

function Cos:leave() self:dropPreview() end

function Cos:dropPreview()
    if self.ground then
        self.ground.canvas:release()
        self.ground.decals:release()
        self.ground = nil
    end
end

-- The floor of the chosen location with its decor, rebuilt when either changes.
function Cos:groundPreview()
    local stage = Content.stages:require(Cosmetics.location())
    local decor = Cosmetics.activeDecor(stage)
    local key = stage.id
    for _, d in ipairs(decor) do key = key .. "+" .. d.id end
    if self.groundKey ~= key then
        self:dropPreview()
        self.ground = Ground.new(stage)
        Cosmetics.paintDecor(self.ground, stage, decor)
        self.groundKey = key
    end
    return self.ground, stage
end

function Cos:draw()
    local lg = love.graphics
    local w, h = lg.getDimensions()
    lg.clear(Theme.colors.bg)
    lg.setFont(Theme.font(40))
    Theme.printShadow("COSMETICS", Theme.u(60), Theme.u(50), Theme.colors.focus)
    self.menu:draw()

    local it = self.menu:focused()
    if not it or it.type == "button" then return end
    local px = math.min(Theme.u(400), w * 0.4) + Theme.u(110)
    local pw, ph = w - px - Theme.u(60), h - Theme.u(200)
    local py = Theme.u(120)
    Theme.panel(px, py, pw, ph)

    if it.character then
        local def = it.character
        local skin = Cosmetics.skinFor(def.id)
        local spr = Sprites.get(def.sprite)
        local s = math.max(1.5, math.floor(Theme.u(5)))
        local cx, cy = px + pw / 2, py + ph * 0.38
        lg.setColor(0, 0, 0, 0.35)
        lg.ellipse("fill", cx, cy + s * 2, spr.w * s * 0.55, spr.w * s * 0.25)
        if skin and skin.light then
            if not skin.light._c then skin.light._c = require("src.core.util").hex(skin.light.color) end
            local c = skin.light._c
            lg.setBlendMode("add")
            lg.setColor(c[1], c[2], c[3], 0.25)
            lg.draw(Sprites.light, cx, cy, 0, spr.w * s / 48, spr.w * s / 96, 64, 64)
            lg.setBlendMode("alpha")
        end
        lg.setColor(1, 1, 1, 1)
        local sh = Cosmetics.shader(skin)
        if sh then lg.setShader(sh) end
        local model = (skin and skin.model) or def.model
        local angle = math.pi * 0.25 + math.sin(self.t * 0.7) * 1.4
        if model then
            Sprites.drawModel(model, math.floor(self.t * spr.fps) + 1, cx, cy, angle, false, s, s)
        else
            Sprites.draw(spr, math.floor(self.t * spr.fps) + 1, cx, cy, -math.pi / 2, false, s)
        end
        lg.setShader()
        lg.setFont(Theme.font(30))
        Theme.printShadow(skin and skin.name or "Natural", px, py + ph * 0.66, Theme.colors.text, "center", pw)
        lg.setFont(Theme.font(18))
        lg.setColor(Theme.colors.dim)
        lg.printf(skin and skin.description or def.name .. " in its own colours.", px + Theme.u(30), py + ph * 0.66 + Theme.u(44),
            pw - Theme.u(60), "center")
    elseif it.preview == "location" then
        local ground, stage = self:groundPreview()
        local gw, gh = ground.canvas:getDimensions()
        local s = math.min((pw - Theme.u(40)) / gw, (ph * 0.68) / gh)
        lg.setColor(1, 1, 1, 1)
        lg.draw(ground.canvas, px + (pw - gw * s) / 2, py + Theme.u(20), 0, s, s)
        local ty = py + Theme.u(30) + gh * s
        lg.setFont(Theme.font(28))
        local title = it.decor and it.decor.name or stage.name
        Theme.printShadow(title, px, ty, Theme.colors.text, "center", pw)
        lg.setFont(Theme.font(18))
        lg.setColor(Theme.colors.dim)
        local desc = it.decor and it.decor.description or stage.description
        if it.decor and it.decor.stages then
            local fits = false
            for _, id in ipairs(it.decor.stages) do fits = fits or id == stage.id end
            if not fits then desc = desc .. " Not on " .. stage.name .. "." end
        end
        lg.printf(desc, px + Theme.u(30), ty + Theme.u(40), pw - Theme.u(60), "center")
    end
    lg.setColor(1, 1, 1, 1)
end

function Cos:mousemoved(x, y) self.menu:mousemoved(x, y) end
function Cos:mousepressed(x, y, b) self.menu:mousepressed(x, y, b) end
function Cos:wheelmoved(x, y) self.menu:wheelmoved(x, y) end

return Cos
