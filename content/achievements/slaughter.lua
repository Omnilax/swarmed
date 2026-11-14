-- Kill counts, combos and big runs.
local list = {}
local function add(a) list[#list + 1] = a; a.order = #list end

for _, t in ipairs({ { 100, "First Blood", "Squash 100 bugs." }, { 1000, "Pest Control", "Squash 1,000 bugs." },
    { 10000, "Exterminator", "Squash 10,000 bugs." }, { 100000, "Extinction Event", "Squash 100,000 bugs." } }) do
    add({ id = "kills_" .. t[1], name = t[2], description = t[3], category = "Slaughter", goal = t[1],
        value = function(p) return p.kills end })
end
for _, t in ipairs({ { 50, "Combo", "Reach a 50 kill combo." }, { 150, "Chain Reaction", "Reach a 150 kill combo." },
    { 400, "Unstoppable", "Reach a 400 kill combo." } }) do
    add({ id = "combo_" .. t[1], name = t[2], description = t[3], category = "Slaughter", goal = t[1],
        value = function(p, run) return math.max(p.bestCombo, run and run.world.bestCombo or 0) end })
end
for _, t in ipairs({ { 500, "Busy Day", "Squash 500 bugs in one run." }, { 2500, "Massacre", "Squash 2,500 bugs in one run." } }) do
    add({ id = "runkills_" .. t[1], name = t[2], description = t[3], category = "Slaughter", goal = t[1],
        value = function(p, run) return math.max(p.bestKOs, run and run.kills or 0) end })
end
add({ id = "elites_1", name = "Shiny", description = "Kill an elite.", category = "Slaughter",
    value = function(p) return p.elites end })
add({ id = "elites_100", name = "Elite Hunter", description = "Kill 100 elites.", category = "Slaughter", goal = 100,
    value = function(p) return p.elites end })
add({ id = "queens_1", name = "Regicide", description = "Slay a queen.", category = "Slaughter",
    value = function(p) return p.queens end })
add({ id = "queens_25", name = "Queenslayer", description = "Slay 25 queens.", category = "Slaughter", goal = 25,
    value = function(p) return p.queens end })
add({ id = "queens_run3", name = "Royal Flush", description = "Slay 3 queens in one run.", category = "Slaughter", goal = 3,
    value = function(p, run) return run and run.queens or 0 end })
return list
