-- One achievement per locked bug and item (src/config/unlocks.lua): meeting the goal unlocks
-- it (src/game/unlocks.lua reads the achievement). Also mastery achievements for danger levels.
local Content = require("src.content")
local Config = require("src.config.unlocks")
local Unlocks = require("src.game.unlocks")

local list = {}
local function add(a) a.category = "Unlocks"; list[#list + 1] = a; a.order = #list end

for _, c in ipairs(Content.characters:all()) do
    local g = Unlocks.bugGoal(c.id)
    if g then
        add({ id = Unlocks.bugAchievement(c.id), name = "New Bug: " .. c.name, description = g.text,
            goal = g.goal, value = g.value, unlockKind = "bug", unlockId = c.id })
    end
end
for _, d in ipairs(Content.items:all()) do
    local g = Config.items[d.id]
    if g then
        add({ id = Unlocks.itemAchievement(d.id), name = "New Item: " .. d.name, description = g.text,
            goal = g.goal, value = g.value, unlockKind = "item", unlockId = d.id })
    end
end

-- Mastery: danger levels won
local function maxDangerWon(p)
    local best = -1
    for _, c in pairs(p.characters) do best = math.max(best, c.danger or -1) end
    return best
end
local function bugsAt(p, n)
    local k = 0
    for _, c in pairs(p.characters) do if (c.danger or -1) >= n then k = k + 1 end end
    return k
end
for n = 1, #require("src.config.danger") do
    add({ id = "danger_" .. n, name = "Danger " .. n, description = "Win a run at Danger " .. n .. ".",
        value = function(p) return maxDangerWon(p) >= n and 1 or 0 end })
end
add({ id = "mastery_3bugs", name = "Seasoned", description = "Win at Danger 3 with 3 different bugs.", goal = 3,
    value = function(p) return bugsAt(p, 3) end })
add({ id = "final_swarm", name = "Last Bug Standing", description = "Survive the Final Swarm after winning a run.",
    value = function(p) return p.swarmsSurvived or 0 end })
add({ id = "dash_kills", name = "Momentum", description = "Kill 50 ants mid-dash in one run.", goal = 50,
    value = function(_, run) return run and run.dashKills or 0 end })
return list
