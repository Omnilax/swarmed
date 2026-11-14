-- Species and families: generated from content/enemies, src/config/families and content/elites,
-- so new enemies, families and affixes get their achievements on their own.
local Content = require("src.content")
local list = {}
local function add(a) a.category = "Species"; list[#list + 1] = a; a.order = #list end

local function countWhere(pred)
    return function()
        local n = 0
        for _, d in ipairs(Content.enemies:all()) do if pred(d) then n = n + 1 end end
        return math.max(1, n)
    end
end

add({ id = "species_all", name = "Field Guide", description = "Kill at least one of every species.",
    goal = countWhere(function(d) return not d.boss end),
    value = function(p)
        local n = 0
        for _, d in ipairs(Content.enemies:all()) do if not d.boss and (p.killsBy[d.id] or 0) > 0 then n = n + 1 end end
        return n
    end })
add({ id = "queens_all", name = "Every Crown", description = "Slay every kind of queen.",
    goal = countWhere(function(d) return d.boss end),
    value = function(p)
        local n = 0
        for _, d in ipairs(Content.enemies:all()) do if d.boss and (p.killsBy[d.id] or 0) > 0 then n = n + 1 end end
        return n
    end })

local names = { ant = "Anteater", bee = "Beekeeper", wasp = "Wasp Swatter", hornet = "Hornet Hunter", termite = "Woodworm" }
for _, f in ipairs(require("src.config.families")) do
    add({ id = "family_" .. f.id, name = names[f.id] or (f.single .. " Hunter"),
        description = ("Kill 1,000 %s."):format(f.label:lower()), goal = 1000,
        value = function(p) return p.killsByFamily[f.id] or 0 end })
end

add({ id = "elites_every", name = "Collector", description = "Kill an elite of every kind.",
    goal = function() return math.max(1, Content.elites:count()) end,
    value = function(p)
        local n = 0
        for _, el in ipairs(Content.elites:all()) do if (p.elitesBy[el.id] or 0) > 0 then n = n + 1 end end
        return n
    end })
return list
