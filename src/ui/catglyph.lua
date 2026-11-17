-- Little symbols for item categories (src/config/categories.lua): a fang for Attack, a spark
-- for Elemental, a shield, a heart, a wing, a web, a clover and a skull. Drawn with shapes, so
-- they stay crisp at any size. CatGlyph.badge draws one on a round dark chip.
local Categories = require("src.config.categories")
local util = require("src.core.util")

local lg = love.graphics
local CatGlyph = {}

local function hexOf(cat)
    cat._c = cat._c or util.hex(cat.color)
    return cat._c
end

local function poly(cx, cy, s, pts)
    local out = {}
    for i = 1, #pts, 2 do out[#out + 1] = cx + pts[i] * s; out[#out + 1] = cy + pts[i + 1] * s end
    return out
end

-- Each shape is drawn in a box from -1..1 around (cx, cy), scaled by s.
local SHAPES = {
    fang = function(cx, cy, s)
        lg.polygon("fill", poly(cx, cy, s, { -0.7, -0.8, 0.7, -0.8, 0.45, -0.2, 0.05, 0.95, -0.25, -0.2 }))
    end,
    spark = function(cx, cy, s)
        lg.polygon("fill", poly(cx, cy, s, { 0.15, -1, -0.65, 0.15, -0.05, 0.15 }))
        lg.polygon("fill", poly(cx, cy, s, { 0.05, -0.15, 0.65, -0.15, -0.15, 1 }))
        lg.polygon("fill", poly(cx, cy, s, { -0.65, 0.15, 0.65, -0.15, 0.05, -0.15, -0.05, 0.15 }))
    end,
    shield = function(cx, cy, s)
        lg.polygon("fill", poly(cx, cy, s, { -0.8, -0.85, 0.8, -0.85, 0.75, 0.15, 0, 0.95, -0.75, 0.15 }))
    end,
    heart = function(cx, cy, s)
        lg.circle("fill", cx - s * 0.4, cy - s * 0.3, s * 0.45)
        lg.circle("fill", cx + s * 0.4, cy - s * 0.3, s * 0.45)
        lg.polygon("fill", poly(cx, cy, s, { -0.84, -0.15, 0.84, -0.15, 0, 0.9 }))
    end,
    wing = function(cx, cy, s)
        lg.push()
        lg.translate(cx, cy)
        lg.rotate(-0.6)
        lg.ellipse("fill", 0, 0, s * 1.0, s * 0.42)
        lg.pop()
    end,
    web = function(cx, cy, s)
        local lw = lg.getLineWidth()
        lg.setLineWidth(math.max(1, s * 0.2))
        for k = 0, 2 do
            local a = k * math.pi / 3
            lg.line(cx - math.cos(a) * s, cy - math.sin(a) * s, cx + math.cos(a) * s, cy + math.sin(a) * s)
        end
        lg.circle("line", cx, cy, s * 0.55, 6)
        lg.setLineWidth(lw)
    end,
    clover = function(cx, cy, s)
        for k = 0, 3 do
            local a = k * math.pi / 2 + math.pi / 4
            lg.circle("fill", cx + math.cos(a) * s * 0.45, cy + math.sin(a) * s * 0.45, s * 0.42)
        end
    end,
    skull = function(cx, cy, s)
        lg.circle("fill", cx, cy - s * 0.15, s * 0.78)
        lg.rectangle("fill", cx - s * 0.45, cy + s * 0.3, s * 0.9, s * 0.6)
        local r, g, b, a = lg.getColor()
        lg.setColor(0.08, 0.05, 0.08, a)
        lg.circle("fill", cx - s * 0.32, cy - s * 0.1, s * 0.22)
        lg.circle("fill", cx + s * 0.32, cy - s * 0.1, s * 0.22)
        lg.setColor(r, g, b, a)
    end,
}

-- Just the symbol, in the category's colour (or `color`), r pixels from centre to edge.
function CatGlyph.draw(id, cx, cy, r, alpha, color)
    local cat = Categories.get(id)
    local c = color or hexOf(cat)
    lg.setColor(c[1], c[2], c[3], alpha or 1)
    local f = SHAPES[cat.glyph]
    if f then f(cx, cy, r) end
end

-- The symbol on a round dark chip with a coloured ring; d is the chip's diameter.
function CatGlyph.badge(id, cx, cy, d, alpha)
    alpha = alpha or 1
    local cat = Categories.get(id)
    local c = hexOf(cat)
    local r = d / 2
    lg.setColor(0.07, 0.05, 0.05, 0.85 * alpha)
    lg.circle("fill", cx, cy, r)
    lg.setColor(c[1], c[2], c[3], 0.8 * alpha)
    lg.setLineWidth(1)
    lg.circle("line", cx, cy, r - 0.5)
    CatGlyph.draw(id, cx, cy, r * 0.55, alpha)
end

-- A chip with the symbol and the category's name: returns its width (measure = true only measures).
function CatGlyph.chip(id, x, y, h, font, alpha, measure)
    local cat = Categories.get(id)
    local w = math.floor(h + font:getWidth(cat.label) + h * 0.45)
    if measure then return w end
    alpha = alpha or 1
    local c = hexOf(cat)
    lg.setColor(c[1] * 0.22, c[2] * 0.22, c[3] * 0.22, 0.95 * alpha)
    lg.rectangle("fill", x, y, w, h)
    lg.setColor(c[1], c[2], c[3], 0.8 * alpha)
    lg.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
    CatGlyph.draw(id, x + h * 0.55, y + h / 2, h * 0.3, alpha)
    lg.setFont(font)
    lg.setColor(c[1], c[2], c[3], alpha)
    lg.print(cat.label, math.floor(x + h), math.floor(y + (h - font:getHeight()) / 2))
    return w
end

return CatGlyph
