-- Colour helpers for the accessibility options.
--
-- "Colourblind-Safe Colours" (Settings safePalette): elites use their `safeColor` (content/elites,
-- Okabe-Ito colours that stay apart with any colour vision) and enemy ground hazards are
-- recoloured by what they do: harmful = orange, slowing = blue, healing enemies = yellow.
-- "High-Contrast Warnings" (Settings telegraphContrast): telegraphs (mounds, holes, drop
-- shadows, landing rings, attack wind-ups) get a dark outline and bright, thicker rings.
local Settings = require("src.core.settings")
local util = require("src.core.util")

local Palette = {}

-- Okabe-Ito (Wong 2011, Nature Methods): distinct for protan, deutan and tritan vision.
Palette.OKABE_ITO = {
    orange = "#e69f00", sky = "#56b4e9", green = "#009e73", yellow = "#f0e442",
    blue = "#0072b2", vermillion = "#d55e00", purple = "#cc79a7", grey = "#999999",
}
local OI = {}
for k, v in pairs(Palette.OKABE_ITO) do OI[k] = util.hex(v) end
Palette.oi = OI

-- What a hazard does -> its safe colour.
Palette.HAZARD = { harm = OI.vermillion, slow = OI.sky, heal = OI.yellow, other = OI.purple }

-- Warning rings in high-contrast mode.
Palette.WARN = { 1, 0.95, 0.3 }
Palette.WARN_EDGE = { 0, 0, 0 }

function Palette.safe() return Settings.get("safePalette") == true end
function Palette.contrast() return Settings.get("telegraphContrast") == true end

-- Colour of an enemy hazard zone (honey puddles, acid pools, webs): its own colour, or with
-- safe colours on, the colour of what it does.
function Palette.zone(z)
    if not Palette.safe() or z.kind == "item" or not z.color then return z.color end
    if z.damage then return Palette.HAZARD.harm end
    if z.heal then return Palette.HAZARD.heal end
    if z.slow or z.pull then return Palette.HAZARD.slow end
    return z.color
end

-- Colour of an enemy projectile: harmful orange in safe mode.
function Palette.shot(s)
    if s.friendly or not Palette.safe() then return s.color end
    return Palette.HAZARD.harm
end

-- Draw an iso ellipse ring as a warning: plain (color, alpha) normally; outlined in black and
-- bright yellow, twice as thick, with High-Contrast Warnings on.
function Palette.ring(x, y, rx, ry, color, alpha)
    local lg = love.graphics
    if Palette.contrast() then
        local lw = lg.getLineWidth()
        lg.setLineWidth(3)
        lg.setColor(0, 0, 0, math.min(1, alpha + 0.3))
        lg.ellipse("line", x, y, rx, ry)
        lg.setLineWidth(1.5)
        lg.setColor(Palette.WARN[1], Palette.WARN[2], Palette.WARN[3], math.min(1, alpha + 0.35))
        lg.ellipse("line", x, y, rx, ry)
        lg.setLineWidth(lw)
    else
        lg.setColor(color[1], color[2], color[3], alpha)
        lg.ellipse("line", x, y, rx, ry)
    end
end

return Palette
