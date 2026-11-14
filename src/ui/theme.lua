-- Colours, type sizes, fonts and the few drawing pieces every screen shares (panels, screen
-- titles, key hints). Fonts are cached per pixel size and follow UI scale.
-- Style rules for new screens are in the README ("UI style guide").
local Settings = require("src.core.settings")

local Theme = {
    -- One warm palette for the whole game: dark chitin panels, cream text, amber for whatever
    -- is focused or important, leaf green for section labels and good numbers.
    colors = {
        bg = { 0.065, 0.055, 0.05, 1 },
        panel = { 0.12, 0.095, 0.08, 0.96 },
        panelHi = { 0.3, 0.23, 0.17, 1 },      -- bevel light (top / left)
        panelEdge = { 0.04, 0.032, 0.028, 1 }, -- bevel dark (bottom / right) and outline
        rivet = { 0.45, 0.36, 0.26, 1 },
        row = { 1, 0.9, 0.75, 0.025 },
        focus = { 0.98, 0.74, 0.27, 1 },
        focusBg = { 0.98, 0.74, 0.27, 0.13 },
        text = { 0.95, 0.91, 0.83, 1 },
        dim = { 0.6, 0.54, 0.48, 1 },
        good = { 0.55, 0.88, 0.45, 1 },
        bad = { 1, 0.42, 0.36, 1 },
        hp = { 0.88, 0.28, 0.27, 1 },
        accent = { 0.6, 0.8, 0.5, 1 },
        key = { 0.86, 0.74, 0.55, 1 },         -- letters on key caps
    },
    -- The type scale. Use these names instead of raw numbers so screens stay consistent.
    size = {
        logo = 84,      -- the game name on the title screen only
        title = 48,     -- screen titles (SETTINGS, PAUSED, BUG CATALOGUE)
        banner = 56,    -- big in-game announcements (WAVE 5)
        heading = 26,   -- names in detail panels, card titles
        body = 18,      -- menu rows, descriptions
        label = 16,     -- stat names, secondary lines
        small = 14,     -- key hints, footnotes: the smallest text in the game
    },
}

-- Nothing is drawn smaller than this (design pixels); tiny text looked cluttered and was hard
-- to read on phones.
Theme.MIN_TEXT = 14

local cache = {}

-- Window height that UI sizes are designed for. Phones use a smaller one so text and buttons
-- come out big enough for a small screen (set by src/core/touch.lua).
Theme.refHeight = 720

function Theme.scale() return Settings.get("uiScale") / 100 end

-- The pixel font (Pixelify Sans, OFL, assets/fonts) is drawn crisp; "bold" picks its heavy cut.
local FONTS = { regular = "assets/fonts/PixelifySans-Regular.ttf", bold = "assets/fonts/PixelifySans-Bold.ttf" }

-- size: a number in "design pixels" (at 100% UI scale on a 720p-tall window) or a name from
-- Theme.size. weight: nil | "bold"
function Theme.font(size, weight)
    if type(size) == "string" then size = Theme.size[size] or Theme.size.body end
    size = math.max(size, Theme.MIN_TEXT)
    local h = love.graphics.getHeight()
    local px = math.max(8, math.floor(size * Theme.scale() * math.max(0.75, h / Theme.refHeight) + 0.5))
    local pixel = Settings.get("uiFont") ~= "smooth"
    local key = px .. (pixel and (weight or "regular") or "smooth")
    local f = cache[key]
    if not f then
        if pixel then
            -- slightly larger: pixel fonts read small for their point size
            f = love.graphics.newFont(FONTS[weight or "regular"] or FONTS.regular, math.floor(px * 1.12 + 0.5))
            f:setFilter("nearest", "nearest")
        else
            f = love.graphics.newFont(px, "normal")
            f:setFilter("linear", "linear")
        end
        cache[key] = f
    end
    return f
end

-- Layout unit: design pixels -> window pixels.
function Theme.u(v)
    return v * Theme.scale() * math.max(0.75, love.graphics.getHeight() / Theme.refHeight)
end

-- A bevelled chitin plate (the same look as the bag): dark outline, light top-left edge,
-- shadowed bottom-right edge. rivets = true adds the four corner studs (big panels only).
function Theme.panel(x, y, w, h, rivets, alpha)
    local lg = love.graphics
    local c = Theme.colors
    local a = alpha or 1
    x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
    lg.setColor(c.panelEdge[1], c.panelEdge[2], c.panelEdge[3], a)
    lg.rectangle("fill", x - 2, y - 2, w + 4, h + 4)
    lg.setColor(c.panel[1], c.panel[2], c.panel[3], c.panel[4] * a)
    lg.rectangle("fill", x, y, w, h)
    lg.setColor(c.panelHi[1], c.panelHi[2], c.panelHi[3], a)
    lg.rectangle("fill", x, y, w, 2)
    lg.rectangle("fill", x, y, 2, h)
    lg.setColor(c.panelEdge[1], c.panelEdge[2], c.panelEdge[3], a)
    lg.rectangle("fill", x, y + h - 2, w, 2)
    lg.rectangle("fill", x + w - 2, y, 2, h)
    if rivets then
        for _, p in ipairs({ { x + 5, y + 5 }, { x + w - 8, y + 5 }, { x + 5, y + h - 8 }, { x + w - 8, y + h - 8 } }) do
            lg.setColor(c.rivet[1], c.rivet[2], c.rivet[3], a)
            lg.rectangle("fill", p[1], p[2], 3, 3)
            lg.setColor(1, 0.9, 0.7, 0.5 * a)
            lg.rectangle("fill", p[1], p[2], 1, 1)
        end
    end
end

function Theme.printShadow(text, x, y, color, align, width)
    love.graphics.setColor(0, 0, 0, 0.6 * (color[4] or 1))
    if align then love.graphics.printf(text, x + 2, y + 2, width, align) else love.graphics.print(text, x + 2, y + 2) end
    love.graphics.setColor(color)
    if align then love.graphics.printf(text, x, y, width, align) else love.graphics.print(text, x, y) end
end

-- A screen title, always in the same place: top-left (or centred when width is given).
function Theme.title(text, width)
    local u = Theme.u
    love.graphics.setFont(Theme.font("title"))
    if width then
        Theme.printShadow(text:upper(), 0, u(36), Theme.colors.focus, "center", width)
    else
        Theme.printShadow(text:upper(), u(60), u(36), Theme.colors.focus)
    end
end

-- Key hints: a row of little key caps, each followed by a word, centred on cx.
-- hints = { { "Esc", "Back" }, { "Q / E", "Tab" }, ... }. Returns the row's width.
function Theme.hints(hints, cx, y, alpha)
    local lg = love.graphics
    local u = Theme.u
    local c = Theme.colors
    local a = alpha or 1
    local f = Theme.font("small")
    lg.setFont(f)
    local total, parts = 0, {}
    for i, hnt in ipairs(hints) do
        local kw, lw = f:getWidth(hnt[1]) + u(10), f:getWidth(hnt[2])
        parts[i] = { kw, lw }
        total = total + kw + u(6) + lw + (i < #hints and u(22) or 0)
    end
    local x = math.floor(cx - total / 2)
    local kh = f:getHeight() + u(4)
    for i, hnt in ipairs(hints) do
        local kw, lw = parts[i][1], parts[i][2]
        lg.setColor(c.panelEdge[1], c.panelEdge[2], c.panelEdge[3], a)
        lg.rectangle("fill", x, y + 1, kw, kh)
        lg.setColor(c.panelHi[1] * 0.6, c.panelHi[2] * 0.6, c.panelHi[3] * 0.6, a)
        lg.rectangle("fill", x, y - 1, kw, kh)
        lg.setColor(c.key[1], c.key[2], c.key[3], a)
        lg.print(hnt[1], x + u(5), y + u(1))
        lg.setColor(c.dim[1], c.dim[2], c.dim[3], a)
        lg.print(hnt[2], x + kw + u(6), y + u(1))
        x = x + kw + u(6) + lw + u(22)
    end
    lg.setColor(1, 1, 1, 1)
    return total
end

-- Hints along the bottom edge of the screen.
function Theme.footer(hints)
    local w, h = love.graphics.getDimensions()
    Theme.hints(hints, w / 2, h - Theme.u(34))
end

return Theme
