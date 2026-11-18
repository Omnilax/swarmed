-- How character select can sort and filter the bugs. A character names its playstyle with
-- `playstyle = "<id>"` (content/characters/_template.lua); a new playstyle is one more row in
-- `styles`, a new sort one more row in `sorts`.
local P = {}

P.styles = {
    { id = "tank", label = "Tanks", desc = "Slow and tough: soak the swarm up and grind it down." },
    { id = "brawler", label = "Brawlers", desc = "Up close and hard hitting." },
    { id = "speedster", label = "Speedsters", desc = "Fast and fragile: hit, run, hit again." },
    { id = "ranged", label = "Ranged", desc = "Spit, spray and shoot from a distance." },
    { id = "control", label = "Control", desc = "Webs, clouds and pools that hold the crowd in place." },
}

P.byId = {}
for _, s in ipairs(P.styles) do P.byId[s.id] = s end

-- Body size names, by character scale (also shown in the detail panel).
function P.sizeName(scale)
    local sc = scale or 1
    return sc < 0.86 and "Tiny" or sc < 0.98 and "Small" or sc < 1.12 and "Medium" or sc < 1.32 and "Large" or "Huge"
end

local function stat(def, id, default) return (def.stats and def.stats[id]) or default end

-- value(def) -> number (sorted high first unless `ascending`); show(def) -> text on the row.
P.sorts = {
    { id = "default", label = "Default" },
    { id = "name", label = "Name", ascending = true, value = function(d) return d.name end },
    { id = "speed", label = "Speed", value = function(d) return stat(d, "moveSpeed", 100) end,
        show = function(d) return tostring(stat(d, "moveSpeed", 100)) end },
    { id = "hp", label = "Health", value = function(d) return stat(d, "maxHp", 50) end,
        show = function(d) return stat(d, "maxHp", 50) .. " HP" end },
    { id = "size", label = "Size", value = function(d) return d.scale or 1 end,
        show = function(d) return P.sizeName(d.scale) end },
    { id = "armor", label = "Armour", value = function(d) return stat(d, "armor", 0) end,
        show = function(d) return tostring(stat(d, "armor", 0)) end },
    { id = "playstyle", label = "Playstyle", ascending = true,
        value = function(d) for i, s in ipairs(P.styles) do if s.id == d.playstyle then return i end end return 99 end,
        show = function(d) local s = P.byId[d.playstyle] return s and s.label or "" end },
}

P.sortById = {}
for _, s in ipairs(P.sorts) do P.sortById[s.id] = s end

-- Filters: everything, favourites, then one per playstyle.
P.filters = { { id = "all", label = "All Bugs" }, { id = "favourites", label = "Favourites" }, { id = "custom", label = "Custom Bugs" } }
for _, s in ipairs(P.styles) do P.filters[#P.filters + 1] = { id = s.id, label = s.label, style = s.id } end

return P
