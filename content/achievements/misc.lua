-- Time spent and habits.
local list = {}
local function add(a) a.category = "Habits"; list[#list + 1] = a; a.order = #list end

add({ id = "runs_10", name = "Regular", description = "Start 10 runs.", goal = 10, value = function(p) return p.runs end })
add({ id = "runs_100", name = "Lifer", description = "Start 100 runs.", goal = 100, value = function(p) return p.runs end })
add({ id = "time_1h", name = "Patio Season", description = "Play for an hour in total.", goal = 3600, format = "time",
    value = function(p, run) return p.playTime + (run and not run.ended and run.time or 0) end })
add({ id = "time_10h", name = "Lives Here Now", description = "Play for 10 hours in total.", goal = 36000, format = "time",
    value = function(p, run) return p.playTime + (run and not run.ended and run.time or 0) end })
return list
