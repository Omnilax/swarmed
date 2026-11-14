-- Character select, generated from content/characters.
local State = require("src.core.state")
local Content = require("src.content")
local Theme = require("src.ui.theme")
local Menu = require("src.ui.menu")
local Sprites = require("src.gfx.sprites")
local Stats = require("src.game.stats")
local Input = require("src.core.input")

local CharSelect = {}
CharSelect.__index = CharSelect

-- "Name  ·  12 dmg every 0.5s". Every number is optional: moves like flight, runs or
-- charged attacks may have no flat damage or cooldown, and the panel must never crash on them.
local function moveLine(registry, cfg)
    local def = registry:get(cfg.type)
    local text = (def and def.name) or cfg.type or "?"
    local parts = {}
    if type(cfg.damage) == "number" then parts[#parts + 1] = cfg.damage .. " dmg" end
    if type(cfg.cooldown) == "number" then parts[#parts + 1] = "every " .. cfg.cooldown .. "s" end
    if #parts > 0 then text = text .. "  ·  " .. table.concat(parts, " ") end
    return text
end

-- opts: gameMode (content/modes id, from the mode select screen)
function CharSelect.new(opts)
    local self = setmetatable({ t = 0 }, CharSelect)
    local gameMode = opts and opts.gameMode or "colony"
    local mode = Content.modes:get(gameMode)
    local items = {}
    for _, def in ipairs(Content.characters:all()) do
        items[#items + 1] = { type = "button", label = def.name, character = def, onActivate = function()
            local params = { mode = "run", character = def.id, gameMode = gameMode }
            if mode and mode.chooseItems then
                State.push(require("src.states.loadout").new(params, mode.chooseItems))
            else
                State.switch(require("src.states.game").new(params))
            end
        end }

    end
    items[#items + 1] = { type = "button", label = "Back", onActivate = function() State.pop() end }
    self.menu = Menu.new({
        items = items,
        onBack = function() State.pop() end,
        touchConfirm = true,     -- on a phone the first tap previews a bug, the second picks it
        rect = function()
            local w, h = love.graphics.getDimensions()
            return Theme.u(60), Theme.u(120), math.min(Theme.u(360), w * 0.35), h - Theme.u(200)
        end,
    })
    return self
end

function CharSelect:update(dt)
    self.t = self.t + dt
    self.menu:update(dt)
end

function CharSelect:draw()
    local lg = love.graphics
    local w, h = lg.getDimensions()
    lg.clear(Theme.colors.bg)
    Theme.title("Choose your bug")
    self.menu:draw()
    Theme.footer(Input.lastDevice == "gamepad" and { { "A", "Play" }, { "B", "Back" } }
        or { { "Enter", "Play" }, { "Esc", "Back" } })

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
    if def.model then
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

    local ty = Theme.u(120) + Theme.u(small and 10 or 40) + spr.size * s * (small and 0.75 or 1)
    lg.setFont(Theme.font(30))
    Theme.printShadow(def.name, px, ty, Theme.colors.text, "center", pw)
    lg.setFont(Theme.font(18))
    lg.setColor(Theme.colors.dim)
    lg.printf(def.description, px + Theme.u(30), ty + Theme.u(44), pw - Theme.u(60), "center")
    -- the lines below follow the description down when it wraps onto more lines (small screens)
    local _, descLines = lg.getFont():getWrap(def.description, pw - Theme.u(60))
    ty = math.max(ty, ty + Theme.u(50) + #descLines * lg.getFont():getHeight() - Theme.u(84))

    local touch = Input.lastDevice == "touch"
    local dim = Theme.colors.dim
    lg.setColor(1, 1, 1, 1)
    lg.printf({ dim, touch and "Attack   " or "Left click   ", Theme.colors.text, moveLine(Content.attacks, def.attack) },
        px, ty + Theme.u(84), pw, "center")

    local extra = 0
    if def.secondary then
        lg.printf({ dim, touch and "Special   " or "Right click   ", Theme.colors.text, moveLine(Content.attacks, def.secondary) },
            px, ty + Theme.u(108), pw, "center")
        extra = extra + Theme.u(24)
    end
    local dashCfg = def.dash or { type = "dash" }
    local dash = Content.dashes:get(dashCfg.type)
    lg.printf({ dim, touch and "Dash   " or "Shift   ", Theme.colors.text, ((dash and dash.name) or dashCfg.type or "Dash") .. ((dashCfg.charges or 1) > 1 and (" x" .. dashCfg.charges) or "") },
        px, ty + Theme.u(108) + extra, pw, "center")
    extra = extra + Theme.u(24)

    -- Stats that differ from the defaults.
    local stats = Stats.new(def.stats)
    local col = 0
    local sy = ty + Theme.u(124) + extra
    lg.setFont(Theme.font(16))
    -- body size first: it sets the hitbox and how far the bug gets shoved
    local sc = def.scale or 1
    local sizeName = sc < 0.86 and "Tiny" or sc < 0.98 and "Small" or sc < 1.12 and "Medium" or sc < 1.32 and "Large" or "Huge"
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
end

function CharSelect:mousemoved(x, y) self.menu:mousemoved(x, y) end
function CharSelect:mousepressed(x, y, b) self.menu:mousepressed(x, y, b) end
function CharSelect:wheelmoved(x, y) self.menu:wheelmoved(x, y) end

return CharSelect
