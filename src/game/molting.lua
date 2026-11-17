-- Molting and tag set bonuses: both are about which items TOUCH in the bag (share a cell side).
--
-- Molting (content/molts): when every item of a recipe sits in the bag as one touching group,
-- the group molts into the recipe's `into` item once a queen wave is cleared (World listens for
-- that, see Molting.afterQueenWave). The new item takes the old ones' place. A run's molts are
-- counted in world.molts and in Records (the recipe book).
--
-- Tag sets (src/config/tags.lua `set`): three or more items sharing a tag, all in one touching
-- group, give the tag's bonus stats (twice from five). Inventory:recount asks Molting.sets.
--
-- The bag screen draws "seams" (Molting.seams) on the edges between touching items that will
-- molt (bright, pulsing), that are part of a recipe still missing a piece (dim), or that make up
-- a tag set (the tag's colour).
local Content = require("src.content")
local Config = require("src.config.molting")
local Tags = require("src.config.tags")

local Molting = {}

----------------------------------------------------------------------------------------------
-- Touching

local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

-- For every entry, the set of entries it touches: adj[e] = { [other] = true }.
function Molting.adjacency(inv)
    local adj = {}
    for _, e in ipairs(inv.bag) do adj[e] = {} end
    for _, e in ipairs(inv.bag) do
        for _, c in ipairs(require("src.game.inventory").cells(e.item)) do
            local x, y = e.x + c[1], e.y + c[2]
            for _, d in ipairs(DIRS) do
                local o = inv:entryAt(x + d[1], y + d[2])
                if o and o ~= e and adj[o] then adj[e][o] = true; adj[o][e] = true end
            end
        end
    end
    return adj
end

-- Are all `list` entries one touching group?
local function connected(list, adj)
    if #list <= 1 then return true end
    local inSet, seen, stack, n = {}, { [list[1]] = true }, { list[1] }, 1
    for _, e in ipairs(list) do inSet[e] = true end
    while #stack > 0 do
        local e = table.remove(stack)
        for o in pairs(adj[e]) do
            if inSet[o] and not seen[o] then seen[o] = true; n = n + 1; stack[#stack + 1] = o end
        end
    end
    return n == #list
end

----------------------------------------------------------------------------------------------
-- Recipes

-- Recipes that use this item id.
function Molting.recipesWith(id)
    local out = {}
    for _, r in ipairs(Content.molts:all()) do
        for _, f in ipairs(r.from) do if f == id then out[#out + 1] = r break end end
    end
    return out
end

-- The recipe that makes this (molted) item id, if any.
function Molting.recipeFor(id)
    for _, r in ipairs(Content.molts:all()) do if r.into == id then return r end end
end

-- One touching group of entries matching recipe r, avoiding `used` entries. Returns the list or nil.
local function match(inv, r, adj, used)
    local byId = {}
    for _, e in ipairs(inv.bag) do
        if not used[e] then
            local l = byId[e.item.id]
            if not l then l = {}; byId[e.item.id] = l end
            l[#l + 1] = e
        end
    end
    for _, id in ipairs(r.from) do if not byId[id] then return nil end end
    local pick, taken = {}, {}
    local function try(k)
        if k > #r.from then return connected(pick, adj) end
        for _, e in ipairs(byId[r.from[k]]) do
            -- a piece after the first must touch one already picked or come before one that will
            -- (connectivity is checked at the end; this just prunes the obvious misses early)
            if not taken[e] then
                taken[e], pick[k] = true, e
                if try(k + 1) then return true end
                taken[e], pick[k] = nil, nil
            end
        end
        return false
    end
    if try(1) then return pick end
end

-- Every molt the bag would do right now: { { recipe, entries }, ... } (no entry used twice).
function Molting.ready(inv, adj)
    adj = adj or Molting.adjacency(inv)
    local used, out = {}, {}
    for _, r in ipairs(Content.molts:all()) do
        local found = match(inv, r, adj, used)
        while found do
            for _, e in ipairs(found) do used[e] = true end
            out[#out + 1] = { recipe = r, entries = found }
            found = match(inv, r, adj, used)
        end
    end
    return out
end

-- Touching pairs that are pieces of one recipe still missing something (a 3-piece recipe with
-- two in place): { { a, b, recipe }, ... }. Pairs already in a ready molt are left out.
local function partialPairs(inv, adj, ready)
    local inReady = {}
    for _, m in ipairs(ready) do for _, e in ipairs(m.entries) do inReady[e] = true end end
    local out, seen = {}, {}
    for _, e in ipairs(inv.bag) do
        if not inReady[e] then
            for _, r in ipairs(Molting.recipesWith(e.item.id)) do
                for o in pairs(adj[e]) do
                    if not inReady[o] and not seen[o] then
                        local need = {}
                        for _, f in ipairs(r.from) do need[f] = (need[f] or 0) + 1 end
                        need[e.item.id] = need[e.item.id] - 1
                        if (need[o.item.id] or 0) > 0 then out[#out + 1] = { e, o, r } end
                    end
                end
            end
            seen[e] = true
        end
    end
    return out
end

-- Do the molts. Returns the list of { recipe, item } made. Each group is taken out and the new
-- item goes where the group was (any turn that fits), else anywhere; if it fits nowhere, that
-- group stays as it is.
function Molting.molt(world)
    local p = world.player
    local inv = p.inventory
    local done = {}
    for _, m in ipairs(Molting.ready(inv)) do
        local Inventory = require("src.game.inventory")
        -- the group's top-left-most cell, to try first
        local spots = {}
        for _, e in ipairs(m.entries) do
            for _, c in ipairs(Inventory.cells(e.item)) do spots[#spots + 1] = { e.x + c[1], e.y + c[2] } end
        end
        table.sort(spots, function(a, b) return a[2] * inv.cols + a[1] < b[2] * inv.cols + b[1] end)
        local removed = {}
        for _, e in ipairs(m.entries) do
            removed[#removed + 1] = { item = e.item, x = e.x, y = e.y, rot = e.item.rot }
            for i, o in ipairs(inv.bag) do if o == e then table.remove(inv.bag, i) break end end
        end
        inv:rebuildGrid()
        local item = Inventory.newItem(m.recipe.into)
        local placed = false
        for _, s in ipairs(spots) do
            for k = 0, 3 do
                item.rot = k
                local w, h = Inventory.size(item)
                -- anchor so the item covers this cell (top-left at or before it)
                for oy = 0, h - 1 do
                    for ox = 0, w - 1 do
                        if not placed and inv:fits(item, s[1] - ox, s[2] - oy) then
                            local cover = false
                            for _, c in ipairs(Inventory.cells(item)) do
                                if s[1] - ox + c[1] == s[1] and s[2] - oy + c[2] == s[2] then cover = true end
                            end
                            if cover then
                                inv.bag[#inv.bag + 1] = { item = item, x = s[1] - ox, y = s[2] - oy }
                                placed = true
                            end
                        end
                    end
                end
                if placed then break end
            end
            if placed then break end
        end
        if not placed then
            item.rot = 0
            inv:rebuildGrid()
            local x, y
            for k = 0, 3 do
                item.rot = k
                x, y = inv:findSpace(item)
                if x then break end
            end
            if x then
                inv.bag[#inv.bag + 1] = { item = item, x = x, y = y }
                placed = true
            end
        end
        if not placed then
            -- put the group back as it was
            for _, r in ipairs(removed) do
                r.item.rot = r.rot
                inv.bag[#inv.bag + 1] = { item = r.item, x = r.x, y = r.y }
            end
            inv:rebuildGrid()
            world:floatText(p.x, p.y - 20, "No room to molt", { 1, 0.6, 0.5 }, true)
        else
            inv:recount()
            if item.def.onAdd then item.def.onAdd(p, inv:count(item.id)) end
            done[#done + 1] = { recipe = m.recipe, item = item, from = removed }
            world.molts = (world.molts or 0) + 1
            world.events:emit("item_molted", m.recipe, item)
        end
    end
    inv:recount()
    return done
end

-- A queen wave was cleared: molt, with some fanfare.
function Molting.afterQueenWave(world)
    local p = world.player
    if not p or p.dead then return end
    local done = Molting.molt(world)
    if #done == 0 then return end
    local Audio = require("src.core.audio")
    Audio.play("ui_confirm", { pitch = 0.7 })
    Audio.play("equip", { pitch = 0.8 })
    world.camera:shake(0.25)
    world:hitStop(0.08)
    for i, d in ipairs(done) do
        local names = {}
        for _, id in ipairs(d.recipe.from) do names[#names + 1] = Content.items:require(id).name end
        if world.director then
            world.director:announce("MOLTED: " .. d.item.def.name, table.concat(names, " + "), { 0.5, 1, 0.85 }, i == 1)
        end
        world:floatText(p.x, p.y - 14 - i * 10, d.item.def.name .. "!", { 0.5, 1, 0.85 }, true)
    end
    world.particles:burst(p.x, p.y, 40, { { 0.5, 1, 0.85 }, { 1, 1, 0.9 }, { 0.75, 0.6, 0.35 } }, 160, 110, { glow = true, grav = 80 })
    world:addFx({ kind = "ring", x = p.x, y = p.y, r = 60, life = 0.6, color = { 0.5, 1, 0.85 } })
end

----------------------------------------------------------------------------------------------
-- Tag sets

-- Active sets: { { tag, def (Tags entry), n, tier, entries }, ... } (the biggest group per tag).
function Molting.sets(inv, adj)
    adj = adj or Molting.adjacency(inv)
    local out = {}
    for tag, t in pairs(Tags) do
        if t.set then
            local has = {}
            for _, e in ipairs(inv.bag) do
                for _, tg in ipairs(e.item.def.tags) do if tg == tag then has[e] = true break end end
            end
            local seen, best = {}, nil
            for e in pairs(has) do
                if not seen[e] then
                    local group, stack = {}, { e }
                    seen[e] = true
                    while #stack > 0 do
                        local x = table.remove(stack)
                        group[#group + 1] = x
                        for o in pairs(adj[x]) do
                            if has[o] and not seen[o] then seen[o] = true; stack[#stack + 1] = o end
                        end
                    end
                    if not best or #group > #best then best = group end
                end
            end
            if best and #best >= Config.set.tier1 then
                out[#out + 1] = { tag = tag, def = t, n = #best, tier = #best >= Config.set.tier2 and 2 or 1, entries = best }
            end
        end
    end
    table.sort(out, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return a.tag < b.tag
    end)
    return out
end

-- Words for a set bonus: "+8% Damage" (x tier).
function Molting.setText(set, tier)
    local Stats = require("src.game.stats")
    local parts = {}
    local keys = {}
    for k in pairs(set.stats or {}) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local sd = Stats.byId[k]
        local v = set.stats[k] * (tier or 1)
        local num = (math.floor(v) == v) and tostring(v) or ("%.1f"):format(v)
        parts[#parts + 1] = (v >= 0 and "+" or "") .. num .. (sd and sd.percent and "% " or " ") .. (sd and sd.label or k)
    end
    for k, v in pairs(set.statsMult or {}) do
        local sd = Stats.byId[k]
        parts[#parts + 1] = ("+%d%% %s"):format(math.floor(v * 100 * (tier or 1)), sd and sd.label or k)
    end
    return table.concat(parts, ", ")
end

----------------------------------------------------------------------------------------------
-- Seams for the bag screen

-- { { a, b, kind = "molt" | "partial" | "set", color = {r,g,b} }, ... } for touching pairs.
-- One seam per pair (molt wins over a set). Also returns ready (the molts that will happen).
function Molting.seams(inv)
    local adj = Molting.adjacency(inv)
    local ready = Molting.ready(inv, adj)
    local out, have = {}, {}
    local function key(a, b) return a.item.uid < b.item.uid and (a.item.uid .. ":" .. b.item.uid) or (b.item.uid .. ":" .. a.item.uid) end
    local function add(a, b, kind, color, extra)
        local k = key(a, b)
        if have[k] then return end
        have[k] = true
        out[#out + 1] = { a = a, b = b, kind = kind, color = color, recipe = extra }
    end
    for _, m in ipairs(ready) do
        for i = 1, #m.entries do
            for j = i + 1, #m.entries do
                local a, b = m.entries[i], m.entries[j]
                if adj[a][b] then add(a, b, "molt", { 0.5, 1, 0.85 }, m.recipe) end
            end
        end
    end
    for _, pr in ipairs(partialPairs(inv, adj, ready)) do add(pr[1], pr[2], "partial", { 0.5, 1, 0.85 }, pr[3]) end
    for _, s in ipairs(Molting.sets(inv, adj)) do
        local c = s.def._c
        if not c then c = require("src.core.util").hex(s.def.color); s.def._c = c end
        for i = 1, #s.entries do
            for j = i + 1, #s.entries do
                local a, b = s.entries[i], s.entries[j]
                if adj[a][b] then add(a, b, "set", c, s) end
            end
        end
    end
    return out, ready
end

-- The cell edges shared by two entries: { { x1, y1, x2, y2 }, ... } in cell units.
function Molting.sharedEdges(a, b)
    local Inventory = require("src.game.inventory")
    local mine = {}
    for _, c in ipairs(Inventory.cells(b.item)) do mine[(b.y + c[2]) * 1000 + b.x + c[1]] = true end
    local out = {}
    for _, c in ipairs(Inventory.cells(a.item)) do
        local x, y = a.x + c[1], a.y + c[2]
        if mine[y * 1000 + x + 1] then out[#out + 1] = { x + 1, y, x + 1, y + 1 } end
        if mine[y * 1000 + x - 1] then out[#out + 1] = { x, y, x, y + 1 } end
        if mine[(y + 1) * 1000 + x] then out[#out + 1] = { x, y + 1, x + 1, y + 1 } end
        if mine[(y - 1) * 1000 + x] then out[#out + 1] = { x, y, x + 1, y } end
    end
    return out
end

return Molting
