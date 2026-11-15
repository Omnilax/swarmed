-- Elite ants: rolling an affix for a spawn and building the elite's behaviour params.
-- The affixes themselves are data in content/elites.
local Content = require("src.content")
local Settings = require("src.core.settings")
local util = require("src.core.util")

local Elites = {}

-- Chance for a spawned ant to be elite: none on wave 1, rising to a 9% cap.
-- The "Elite Ants" setting scales it (Off / Rare / Normal / Lots).
function Elites.chance(wave)
    if wave < 2 then return 0 end
    return math.min(0.09, 0.012 + (wave - 2) * 0.006) * (Settings.get("eliteFrequency") or 1)
end

-- mode (optional): a game mode's `elites` table (content/modes/_template.lua).
function Elites.roll(def, wave, mode)
    local chance = mode and mode.chance or Elites.chance(wave) * (mode and mode.mul or 1)
    if def.boss or def.noElites or love.math.random() >= chance then return nil end
    local upTo = mode and mode.anyWave and math.huge or wave
    return Content.elites:pickWeighted(function(d) return d.weight end, function(d) return d.minWave <= upTo end)
end


-- Behaviour params for (species, affix): the species' params with the affix multipliers on top,
-- then the species' own overrides for that affix. Cached, so elites cost no garbage per spawn.
function Elites.params(def, elite)
    def._eliteParams = def._eliteParams or {}
    local cached = def._eliteParams[elite.id]
    if cached then return cached end
    local out = {}
    for k, v in pairs(def.behaviorParams) do if type(k) ~= "string" or k:sub(1, 1) ~= "_" then out[k] = v end end
    for k, m in pairs(elite.params) do
        local v = out[k]
        if type(v) == "number" then out[k] = v * m
        elseif type(v) == "table" and type(v[1]) == "number" then out[k] = { v[1] * m, v[2] * m } end
    end
    local own = def.elites and def.elites[elite.id]
    if own and own.params then for k, v in pairs(own.params) do out[k] = v end end
    def._eliteParams[elite.id] = out
    return out
end

-- Colour of an elite as {r, g, b} (cached on the def). With "Colourblind-Safe Colours" on it is
-- the affix's safeColor (an Okabe-Ito colour), when it has one.
function Elites.color(elite)
    if elite.safeColor and Settings.get("safePalette") then
        elite._cs = elite._cs or util.hex(elite.safeColor)
        return elite._cs
    end
    elite._c = elite._c or util.hex(elite.color)
    return elite._c
end

-- "Aggressive Green Ant"
function Elites.title(def, elite)
    return elite.name .. " " .. def.name
end

return Elites
