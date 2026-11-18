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

-- Nothing is drawn smaller than this (design pixels, before the HUD zoom below); tiny text looked
-- cluttered and was hard to read on phones.
Theme.MIN_TEXT = 14

-- Every piece of text is drawn at this share of its named size (2026-11-17: text was taking up
-- too much of the screen). Layout units (Theme.u) are not affected outside the HUD.
Theme.TEXT_SCALE = 0.9

-- Zoom for whatever is drawn between Theme.pushZoom / Theme.popZoom: the in-run HUD, banners
-- and floating numbers use it (Settings "HUD Size") so the fight keeps most of the screen.
-- It scales both text and layout units, so HUD pieces shrink together and keep their spacing.
Theme.zoom = 1
local zoomStack = {}

function Theme.pushZoom(k)
    zoomStack[#zoomStack + 1] = Theme.zoom
    Theme.zoom = Theme.zoom * (k or 1)
end

function Theme.popZoom()
    Theme.zoom = table.remove(zoomStack) or 1
end

-- The zoom the in-run HUD uses: the HUD Size setting, a little bigger on phones (whose small
-- screens already get a bigger UI through refHeight, see src/core/touch.lua).
function Theme.hudZoom()
    local k = (Settings.get("hudScale") or 75) / 100
    if require("src.core.touch").mobile then k = math.min(1, k * 1.2) end
    return k
end

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
    size = math.max(size, Theme.MIN_TEXT) * Theme.TEXT_SCALE * Theme.zoom
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
    return v * Theme.scale() * Theme.zoom * math.max(0.75, love.graphics.getHeight() / Theme.refHeight)
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

----------------------------------------------------------------------------------------------
-- Controller button icons. Wherever a prompt names a button it can show it instead of a word:
-- coloured face buttons, shoulder tabs, a d-pad cross and the two small middle buttons.

-- Face button colours (the usual green A, red B, blue X, yellow Y).
Theme.padColors = {
    a = { 0.36, 0.72, 0.32 }, b = { 0.86, 0.3, 0.26 }, x = { 0.3, 0.52, 0.9 }, y = { 0.92, 0.74, 0.22 },
}

-- Names a prompt may use for a pad button -> the LÖVE gamepad button.
local PAD_ALIASES = {
    A = "a", B = "b", X = "x", Y = "y", LB = "leftshoulder", RB = "rightshoulder", LT = "triggerleft", RT = "triggerright",
    START = "start", BACK = "back", MENU = "start", VIEW = "back", ["D-PAD"] = "dpad", DPAD = "dpad",
    ["L-STICK"] = "leftstick", ["R-STICK"] = "rightstick", LS = "leftstick", RS = "rightstick",
}
local PAD_TEXT = { leftshoulder = "LB", rightshoulder = "RB", triggerleft = "LT", triggerright = "RT",
    start = "START", back = "BACK", leftstick = "LS", rightstick = "RS", dpup = "", dpdown = "", dpleft = "", dpright = "", dpad = "" }

-- The LÖVE button for a word in a prompt ("A", "RB", "LB/RB" -> list), or nil if it isn't one.
function Theme.padButtons(word)
    local out = {}
    for part in tostring(word):upper():gmatch("[^/]+") do
        part = part:gsub("^%s+", ""):gsub("%s+$", "")
        local b = PAD_ALIASES[part]
        if not b then return nil end
        out[#out + 1] = b
    end
    return #out > 0 and out or nil
end

-- Width of a pad button icon h pixels tall.
function Theme.glyphWidth(button, h)
    if Theme.padColors[button] or button:match("^dp") or button == "dpad" or button:match("stick$") then return h end
    local f = Theme.font("small", "bold")
    return math.max(h * 1.3, f:getWidth(PAD_TEXT[button] or button:upper()) + h * 0.6)
end

-- Draw a pad button icon with its top-left at x, y, h pixels tall. Returns its width.
function Theme.glyph(button, x, y, h, alpha)
    local lg = love.graphics
    local a = alpha or 1
    local c = Theme.colors
    local w = Theme.glyphWidth(button, h)
    local cx, cy, r = x + w / 2, y + h / 2, h / 2
    local face = Theme.padColors[button]
    if face then
        lg.setColor(0, 0, 0, 0.45 * a)
        lg.circle("fill", cx + 1, cy + 1, r)
        lg.setColor(face[1] * 0.55, face[2] * 0.55, face[3] * 0.55, a)
        lg.circle("fill", cx, cy, r)
        lg.setColor(face[1], face[2], face[3], a)
        lg.circle("fill", cx, cy - 1, r - 1.5)
        local f = Theme.font("small", "bold")
        lg.setFont(f)
        lg.setColor(1, 1, 1, a)
        lg.printf(button:upper(), x, cy - f:getHeight() / 2 - 1, w, "center")
    elseif button == "dpad" or button:match("^dp") then
        -- a plus; the pressed arm (for dpup...) lights up
        local t = h / 3
        lg.setColor(0, 0, 0, 0.45 * a)
        lg.rectangle("fill", x + t + 1, y + 1, t, h)
        lg.rectangle("fill", x + 1, y + t + 1, h, t)
        lg.setColor(c.panelHi[1], c.panelHi[2], c.panelHi[3], a)
        lg.rectangle("fill", x + t, y, t, h)
        lg.rectangle("fill", x, y + t, h, t)
        lg.setColor(c.key[1], c.key[2], c.key[3], a)
        local arm = ({ dpup = { x + t, y }, dpdown = { x + t, y + 2 * t }, dpleft = { x, y + t }, dpright = { x + 2 * t, y + t } })[button]
        if arm then lg.rectangle("fill", arm[1], arm[2], t, t) end
    elseif button:match("stick$") then
        lg.setColor(0, 0, 0, 0.45 * a)
        lg.circle("fill", cx + 1, cy + 1, r)
        lg.setColor(c.panelHi[1], c.panelHi[2], c.panelHi[3], a)
        lg.circle("fill", cx, cy, r)
        lg.setColor(c.panelEdge[1], c.panelEdge[2], c.panelEdge[3], a)
        lg.circle("fill", cx, cy, r * 0.55)
        local f = Theme.font("small", "bold")
        lg.setFont(f)
        lg.setColor(c.key[1], c.key[2], c.key[3], a)
        lg.printf(button == "leftstick" and "L" or "R", x, cy - f:getHeight() / 2, w, "center")
    else
        -- shoulders, triggers and the middle buttons: a rounded tab with its name
        local rr = button:match("shoulder") and h * 0.45 or h * 0.3
        lg.setColor(0, 0, 0, 0.45 * a)
        lg.rectangle("fill", x + 1, y + 1, w, h, rr, rr)
        lg.setColor(0.2, 0.18, 0.17, a)
        lg.rectangle("fill", x, y, w, h, rr, rr)
        lg.setColor(c.panelHi[1], c.panelHi[2], c.panelHi[3], a)
        lg.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, rr, rr)
        local f = Theme.font("small", "bold")
        lg.setFont(f)
        lg.setColor(c.text[1], c.text[2], c.text[3], a)
        lg.printf(PAD_TEXT[button] or button:upper(), x, cy - f:getHeight() / 2, w, "center")
    end
    return w
end

-- A key cap with a word on it. Returns its width.
function Theme.keycap(text, x, y, h, alpha)
    local lg = love.graphics
    local c = Theme.colors
    local a = alpha or 1
    local f = lg.getFont()
    local kw = f:getWidth(text) + Theme.u(10)
    lg.setColor(c.panelEdge[1], c.panelEdge[2], c.panelEdge[3], a)
    lg.rectangle("fill", x, y + 1, kw, h)
    lg.setColor(c.panelHi[1] * 0.6, c.panelHi[2] * 0.6, c.panelHi[3] * 0.6, a)
    lg.rectangle("fill", x, y - 1, kw, h)
    lg.setColor(c.key[1], c.key[2], c.key[3], a)
    lg.print(text, x + Theme.u(5), y + math.floor((h - f:getHeight()) / 2))
    return kw
end

local function capWidth(f, text)
    local pads = require("src.core.input").lastDevice == "gamepad" and Theme.padButtons(text)
    local h = f:getHeight() + Theme.u(4)
    if pads then
        local w = 0
        for i, b in ipairs(pads) do w = w + Theme.glyphWidth(b, h) + (i > 1 and Theme.u(3) or 0) end
        return w, pads
    end
    return f:getWidth(text) + Theme.u(10)
end

-- Key hints: a row of little key caps, each followed by a word, centred on cx.
-- hints = { { "Esc", "Back" }, { "Q / E", "Tab" }, ... }. With a controller in use, cap words
-- that name a pad button ("A", "LB/RB", "D-pad") are drawn as button icons. Returns the row's width.
function Theme.hints(hints, cx, y, alpha)
    local lg = love.graphics
    local u = Theme.u
    local c = Theme.colors
    local a = alpha or 1
    local f = Theme.font("small")
    lg.setFont(f)
    local total, parts = 0, {}
    for i, hnt in ipairs(hints) do
        local kw, pads = capWidth(f, hnt[1])
        local lw = f:getWidth(hnt[2])
        parts[i] = { kw, lw, pads }
        total = total + kw + u(6) + lw + (i < #hints and u(22) or 0)
    end
    local x = math.floor(cx - total / 2)
    local kh = f:getHeight() + u(4)
    for i, hnt in ipairs(hints) do
        local kw, lw, pads = parts[i][1], parts[i][2], parts[i][3]
        if pads then
            local gx = x
            for _, b in ipairs(pads) do gx = gx + Theme.glyph(b, gx, y - 1, kh, a) + u(3) end
            lg.setFont(f)
        else
            Theme.keycap(hnt[1], x, y, kh, a)
        end
        lg.setColor(c.dim[1], c.dim[2], c.dim[3], a)
        lg.print(hnt[2], x + kw + u(6), y + u(1))
        x = x + kw + u(6) + lw + u(22)
    end
    lg.setColor(1, 1, 1, 1)
    return total
end

----------------------------------------------------------------------------------------------
-- Prompts with buttons in them. Text may hold {action} tokens (an Input action id, e.g.
-- "Press {dash} to dash"), drawn as the key cap, mouse button or controller icon for the device
-- in use, and wraps like printf. {pad:a} / {key:Esc} name a button or key directly.

local MOUSE_NAMES = { "LEFT CLICK", "RIGHT CLICK", "MIDDLE CLICK" }

-- Split into words and button pieces: { text = "Press" } / { pad = "a" } / { key = "SPACE" }.
local function tokens(text)
    local Input = require("src.core.input")
    local out = {}
    local i = 1
    while i <= #text do
        local s, e, inner = text:find("{([%w_:%-%s]+)}", i)
        local chunk = text:sub(i, (s or #text + 1) - 1)
        for sp, word in chunk:gmatch("(%s*)(%S+)") do out[#out + 1] = { text = word, space = #sp > 0 or #out == 0 } end
        if chunk:match("%s$") then out.trailing = true end
        if not s then break end
        local g
        local kind, val = inner:match("^(%a+):(.+)$")
        if kind == "pad" then g = { pad = val }
        elseif kind == "key" then g = { key = val:upper() }
        else
            g = Input.glyph(inner)
            if g.mouse then g = { key = MOUSE_NAMES[g.mouse] or "CLICK" } end
            local Touch = require("src.core.touch")
            if Touch.enabled() and Input.lastDevice == "touch" then
                g = { key = ({ dash = "DASH", secondary = "SPECIAL", inventory = "BAG", attack = "ATTACK", pause = "II" })[inner] or g.key or "?" }
            end
        end
        g.space = (s > 1 and text:sub(s - 1, s - 1):match("%s") ~= nil) or #out == 0
        out[#out + 1] = g
        out.trailing = false
        i = e + 1
    end
    return out
end

local function pieceWidth(f, p, h)
    if p.text then return f:getWidth(p.text) end
    if p.pad then return Theme.glyphWidth(p.pad, h) end
    return f:getWidth(p.key) + Theme.u(10)
end

-- Lay out rich text in lines no wider than limit: returns lines ({ pieces, width }), line height.
function Theme.richLayout(text, limit)
    local f = love.graphics.getFont()
    local h = f:getHeight()
    local gh = math.floor(h * 0.92)
    local space = f:getWidth(" ")
    local lines, cur, cw = {}, {}, 0
    for _, p in ipairs(tokens(text)) do
        local pw = pieceWidth(f, p, gh)
        local gap = (#cur > 0 and p.space) and space or 0
        if #cur > 0 and limit and cw + gap + pw > limit then
            lines[#lines + 1] = { pieces = cur, width = cw }
            cur, cw, gap = {}, 0, 0
        end
        p.x = cw + gap
        p.w = pw
        cur[#cur + 1] = p
        cw = cw + gap + pw
    end
    lines[#lines + 1] = { pieces = cur, width = cw }
    return lines, h
end

-- Width of the longest line, and the number of lines.
function Theme.richSize(text, limit)
    local lines = Theme.richLayout(text, limit)
    local w = 0
    for _, l in ipairs(lines) do w = math.max(w, l.width) end
    return w, #lines
end

-- printf with buttons: align "left" | "center" | "right" inside width. color = text colour.
function Theme.rich(text, x, y, width, align, color, alpha)
    local lg = love.graphics
    local f = lg.getFont()
    local a = alpha or 1
    local col = color or Theme.colors.text
    local lines, h = Theme.richLayout(text, width)
    local gh = math.floor(h * 0.92)
    for li, line in ipairs(lines) do
        local ox = x
        if align == "center" then ox = x + math.floor((width - line.width) / 2)
        elseif align == "right" then ox = x + width - line.width end
        local ly = y + (li - 1) * h
        for _, p in ipairs(line.pieces) do
            if p.text then
                lg.setColor(col[1], col[2], col[3], (col[4] or 1) * a)
                lg.print(p.text, ox + p.x, ly)
            elseif p.pad then
                Theme.glyph(p.pad, ox + p.x, ly + math.floor((h - gh) / 2), gh, a)
                lg.setFont(f)
            else
                Theme.keycap(p.key, ox + p.x, ly + 1, h - 2, a)
            end
        end
    end
    lg.setColor(1, 1, 1, 1)
    return #lines * h
end

-- Hints along the bottom edge of the screen.
function Theme.footer(hints)
    local w, h = love.graphics.getDimensions()
    Theme.hints(hints, w / 2, h - Theme.u(34))
end

-- The usual footer for a list screen: browse, pick (named by `pick`, default "Select") and back,
-- in the keys of the device in use. Nothing on touch (the rows are tapped).
function Theme.navFooter(pick)
    local Input = require("src.core.input")
    if Input.lastDevice == "touch" then return end
    if Input.lastDevice == "gamepad" then
        Theme.footer({ { "D-pad", "Browse" }, { "A", pick or "Select" }, { "B", "Back" } })
    else
        Theme.footer({ { "Arrows", "Browse" }, { "Enter", pick or "Select" }, { "Esc", "Back" } })
    end
end

return Theme
