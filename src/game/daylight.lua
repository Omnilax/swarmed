-- Time of day: the ambient colour the lighting pass starts from. Setting "Time of Day" picks a
-- fixed Day, Evening or Night look, or a Cycle that moves from morning through sunset, night
-- and dawn over "Day Length" seconds. A stage can override any colour with
-- `ambients = { day = "#...", sunset = ..., evening = ..., night = ..., dawn = ... }`
-- (its plain `ambient` is the Evening colour).
local Settings = require("src.core.settings")
local util = require("src.core.util")

local Daylight = {}

Daylight.COLORS = { day = "#fff6ea", sunset = "#e0a07c", evening = "#7a8090", night = "#4a5274", dawn = "#c9aab8",
    golden = "#ffd8a0", bluehour = "#6c7aa8", moon = "#46557e" }

-- The cycle as keyframes over 0..1 of a day.
local CYCLE = {
    { 0.00, "day" }, { 0.42, "day" }, { 0.50, "sunset" }, { 0.58, "night" },
    { 0.88, "night" }, { 0.94, "dawn" }, { 1.00, "day" },
}
-- Rich Day Palette (setting): a golden hour before sunset, a blue hour after it, cool moonlight
-- in the middle of the night. A stage's `ambients` can set golden / bluehour / moon too.
local RICH = {
    { 0.00, "day" }, { 0.36, "day" }, { 0.44, "golden" }, { 0.50, "sunset" }, { 0.555, "bluehour" },
    { 0.60, "night" }, { 0.73, "moon" }, { 0.86, "night" }, { 0.94, "dawn" }, { 1.00, "day" },
}
local START = 0.05     -- runs start in the morning

local function color(stage, key)
    stage._amb = stage._amb or {}
    local c = stage._amb[key]
    if not c then
        local hex = (stage.ambients and stage.ambients[key]) or (key == "evening" and stage.ambient) or Daylight.COLORS[key]
        c = util.hex(hex)
        stage._amb[key] = c
    end
    return c
end

-- Fraction of the day (0..1) at world time t, or nil when the time of day is fixed.
function Daylight.phase(t)
    if Settings.get("timeOfDay") ~= "cycle" then return nil end
    return (START + t / math.max(10, Settings.get("dayLength"))) % 1
end

-- Ambient r, g, b for this stage at world time t (before the darkness setting).
function Daylight.ambient(stage, t)
    local mode = Settings.get("timeOfDay")
    if mode ~= "cycle" then
        local c = color(stage, mode)
        return c[1], c[2], c[3]
    end
    local f = Daylight.phase(t)
    local cyc = Settings.get("richDay") and RICH or CYCLE
    for i = 1, #cyc - 1 do
        local a, b = cyc[i], cyc[i + 1]
        if f <= b[1] then
            local k = (f - a[1]) / math.max(0.0001, b[1] - a[1])
            local ca, cb = color(stage, a[2]), color(stage, b[2])
            return util.lerp(ca[1], cb[1], k), util.lerp(ca[2], cb[2], k), util.lerp(ca[3], cb[3], k)
        end
    end
    local c = color(stage, "day")
    return c[1], c[2], c[3]
end

-- How bright it is, 0 (night) .. 1 (full day). Desert ants run faster in the heat of the day.
function Daylight.level(stage, t)
    if not Settings.get("lighting") then return 1 end
    local r, g, b = Daylight.ambient(stage, t)
    local lum = (r + g + b) / 3
    local n = color(stage, "night")
    local d = color(stage, "day")
    local ln, ld = (n[1] + n[2] + n[3]) / 3, (d[1] + d[2] + d[3]) / 3
    return util.clamp((lum - ln) / math.max(0.01, ld - ln), 0, 1)
end

-- "Day", "Sunset", "Night", "Dawn" (or the fixed setting's name) for the HUD.
function Daylight.label(t)
    local mode = Settings.get("timeOfDay")
    if mode ~= "cycle" then return mode:sub(1, 1):upper() .. mode:sub(2) end
    local f = Daylight.phase(t)
    if f < 0.46 then return "Day" elseif f < 0.55 then return "Sunset" elseif f < 0.9 then return "Night" end
    return "Dawn"
end

return Daylight
