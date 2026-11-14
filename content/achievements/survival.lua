-- Waves, wins and staying alive.
local list = {}
local function add(a) a.category = "Survival"; list[#list + 1] = a; a.order = #list end

add({ id = "wave_5", name = "Holding On", description = "Reach wave 5.", goal = 5, value = function(p) return p.bestWave end })
add({ id = "wave_10", name = "Dug In", description = "Reach wave 10.", goal = 10, value = function(p) return p.bestWave end })
add({ id = "win", name = "Patio Defended", description = "Beat the final wave of a run. Unlocks the Gilded skin.",
    unlocks = "gilded", value = function(p) return p.wins end })
add({ id = "wins_10", name = "Veteran", description = "Win 10 runs.", goal = 10, value = function(p) return p.wins end })
add({ id = "wave_30", name = "Second Chapter", description = "Keep going and reach wave 30.", goal = 30,
    value = function(p) return p.bestWave end })
add({ id = "wave_45", name = "No End In Sight", description = "Reach wave 45.", goal = 45, value = function(p) return p.bestWave end })
add({ id = "flawless", name = "Untouched", description = "Clear a wave without taking damage.",
    value = function(p) return p.flawlessWaves end })
add({ id = "flawless_run5", name = "Ghost", description = "Clear 5 waves without a scratch in one run.", goal = 5,
    value = function(p, run) return run and run.flawlessWaves or 0 end })
add({ id = "time_10m", name = "Long Haul", description = "Survive 10 minutes in one run.", goal = 600, format = "time",
    value = function(p, run) return math.max(p.longestRun, run and run.time or 0) end })
add({ id = "level_15", name = "Grown Up", description = "Reach skill level 15 in one run.", goal = 15,
    value = function(p, run)
        local s = run and run.world.player.skills
        return math.max(p.bestLevel, s and s.level or 0)
    end })
add({ id = "deaths_25", name = "Compost", description = "Fall 25 times.", goal = 25, value = function(p) return p.deaths end })
add({ id = "wave1_death", name = "Snack", description = "Fall on wave 1.", hidden = true,
    value = function(p, run) return run ~= nil and run.outcome == "died" and run.wave <= 1 end })
add({ id = "nohit_win", name = "Perfect Specimen", description = "Win a run taking under 50 damage.", hidden = true,
    value = function(p, run) return run ~= nil and run.won and run.damageTaken < 50 end })
return list
