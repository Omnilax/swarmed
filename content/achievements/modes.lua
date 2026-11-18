-- One per game mode (generated from content/modes when that registry exists).
local Content = require("src.content")
local list = {}
local reg = Content.modes
if not reg then return list end
for _, m in ipairs(reg:all()) do
    local id = m.id
    if m.custom then
        -- (Custom Waves can be made as easy as you like, so it has no achievement)
    elseif m.endless or id == "endless" then
        list[#list + 1] = { id = "mode_" .. id, name = m.name .. ": 30", description = "Reach level 30 in " .. m.name .. ".",
            category = "Modes", goal = 30, order = #list + 1,
            value = function(p) return p.modes[id] and p.modes[id].bestWave or 0 end }
    else
        list[#list + 1] = { id = "mode_" .. id, name = m.name .. " Cleared", description = "Win a run in " .. m.name .. ".",
            category = "Modes", order = #list + 1,
            value = function(p) return p.modes[id] and p.modes[id].wins or 0 end }
    end
end
return list
