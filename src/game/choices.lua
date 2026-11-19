-- Run-wide item choice state and helpers: rolling cards, rerolls, banishes, locks, synergy
-- tags and stat previews. The screen is src/states/itemchoice.lua; numbers live in
-- src/config/itemchoice.lua (a game mode can override them with `itemChoice = { ... }`).
--
-- world.choice = { rerolls, banishes, banned = { [id] = true }, locked = { id, ... } }
local Content = require("src.content")
local Rarities = require("src.config.rarities")
local Tags = require("src.config.tags")
local Config = require("src.config.itemchoice")
local Inventory = require("src.game.inventory")
local Stats = require("src.game.stats")
local util = require("src.core.util")

local Choices = {}

-- The run's choice state (made on first use).
function Choices.state(world)
    local s = world.choice
    if s then return s end
    local over = world.modeDef and world.modeDef.itemChoice or {}
    local function opt(k) if over[k] ~= nil then return over[k] end return Config[k] end
    s = { rerolls = opt("rerolls") or 0, banishes = opt("banishes") or 0, banned = {}, locked = {},
        rerollPerQueen = opt("rerollPerQueen") or 0 }
    world.choice = s
    return s
end

-- A queen fell: some rerolls come back.
function Choices.onQueen(world)
    local s = Choices.state(world)
    if s.rerollPerQueen > 0 then s.rerolls = s.rerolls + s.rerollPerQueen end
end

local function wave(world) return world.spawner and math.max(1, world.spawner.wave) or 1 end

-- One item def, weighted by rarity, that is allowed right now and not in `taken` or banned.
-- pred narrows it further. Falls back to ignoring rarity unlock waves if nothing is left.
function Choices.pickDef(world, taken, pred)
    local banned, w = Choices.state(world).banned, wave(world)
    -- locked items and ones switched off in the item pool never show (src/game/unlocks.lua);
    -- molted items only come from molting
    local inPool = require("src.game.unlocks").inPool
    local function ok(d) return not d.molted and (not d.parasite or require("src.game.parasites").weight(world, d) > 0) and not taken[d.id] and not banned[d.id] and inPool(d.id) and (not pred or pred(d)) end
    -- parasites: once each, a few at most, and the Parasites setting (src/game/parasites.lua)
    local pw = require("src.game.parasites").weight
    -- shore items: more often for their kin (crustaceans) and on the beach (src/game/shore.lua)
    local sw = require("src.game.shore").weight
    return Content.items:pickWeighted(function(d) return Rarities[d.rarity].weight * pw(world, d) * sw(world, d) end,
        function(d) return ok(d) and Rarities[d.rarity].minWave <= w end)
        or Content.items:pickWeighted(function() return 1 end, ok)
end

local function atLeast(minRarity)
    local o = Rarities[minRarity].order
    return function(d) return Rarities[d.rarity].order >= o end
end

-- n cards. `keep` = { [slot] = item } stays where it is (locked cards); other slots are new.
-- minRarity: at least one card (kept ones count) is that tier or better. `avoid` = ids not
-- to roll (the cards a reroll is replacing), dropped again if the pool runs dry.
function Choices.roll(world, n, minRarity, keep, avoid)
    keep = keep or {}
    local taken, out, free = {}, {}, {}
    for id in pairs(avoid or {}) do taken[id] = true end
    for i = 1, n do
        if keep[i] then out[i] = keep[i]; taken[keep[i].id] = true else free[#free + 1] = i end
    end
    local function new(pred)
        local d = Choices.pickDef(world, taken, pred)
        if not d and avoid then
            for id in pairs(avoid) do taken[id] = nil end
            for _, it in pairs(out) do taken[it.id] = true end
            avoid = nil
            d = Choices.pickDef(world, taken, pred)
        end
        -- `rarityBump` items (Ladybug Spots): now and then the card rolls one tier higher
        if d and not pred then
            local inv = world.player and world.player.inventory
            local bump = inv and inv:sum("rarityBump") or 0
            if bump > 0 and love.math.random() < bump then
                local o = Rarities[d.rarity].order
                local up = Choices.pickDef(world, taken, function(x) return Rarities[x.rarity].order > o and x.rarity ~= "cursed" end)
                if up then d = up end
            end
        end
        if d then taken[d.id] = true; return Inventory.newItem(d.id) end
    end
    if minRarity and #free > 0 then
        local need = atLeast(minRarity)
        local have = false
        for _, it in pairs(out) do if need(it.def) then have = true end end
        if not have then
            local k = love.math.random(#free)
            out[free[k]] = new(need) or new()
            table.remove(free, k)
        end
    end
    for _, i in ipairs(free) do out[i] = new() end
    -- close gaps if the whole catalogue ran out (tiny test catalogues)
    local list = {}
    for i = 1, n do if out[i] then list[#list + 1] = out[i] end end
    return list
end

-- The opening hand for an item choice: locked cards from last time first, then new ones.
function Choices.deal(world, n, minRarity)
    local s = Choices.state(world)
    local keep, locked = {}, {}
    for _, id in ipairs(s.locked) do
        if #locked < n and Content.items.byId[id] and not s.banned[id] then
            local it = Inventory.newItem(id)
            it.locked = true
            locked[#locked + 1] = it
        end
    end
    s.locked = {}
    -- locked cards go to random slots, so they don't always sit on the left
    local slots = {}
    for i = 1, n do slots[i] = i end
    for i = n, 2, -1 do local j = love.math.random(i); slots[i], slots[j] = slots[j], slots[i] end
    for k, it in ipairs(locked) do keep[slots[k]] = it end
    local items = Choices.roll(world, n, minRarity, keep)
    if not next(keep) then
        for i = #items, 2, -1 do local j = love.math.random(i); items[i], items[j] = items[j], items[i] end
    end
    Choices.seal(world, items)
    return items
end

-- Sometimes one card comes sealed in a cocoon: rare or better, but you don't see what it is
-- until you take it. Not before wave SEALED.wave, and never a locked card.
Choices.SEALED = { chance = 0.15, wave = 4, rarity = "rare" }
function Choices.seal(world, items, force)
    local S = Choices.SEALED
    if not force and (wave(world) < S.wave or love.math.random() >= S.chance) then return end
    local free = {}
    for i, it in ipairs(items) do if not it.locked then free[#free + 1] = i end end
    if #free == 0 then return end
    local avoid = {}
    for _, it in ipairs(items) do avoid[it.id] = true end
    local got = Choices.roll(world, 1, S.rarity, nil, avoid)[1]
    if not got or Rarities[got.def.rarity].order < Rarities[S.rarity].order then return end
    got.sealed = true
    items[free[love.math.random(#free)]] = got
end

-- Cards the player locked, remembered for the next choice (call when the screen closes).
function Choices.remember(world, items, taken)
    local s = Choices.state(world)
    s.locked = {}
    for _, it in ipairs(items) do
        if it.locked and it ~= taken then s.locked[#s.locked + 1] = it.id end
    end
end

-- New cards for every unlocked slot. Returns the new list, or nil if no reroll is left or
-- every card is locked.
function Choices.reroll(world, items, minRarity)
    local s = Choices.state(world)
    if s.rerolls <= 0 then return nil, "none" end
    local keep, avoid, any = {}, {}, false
    for i, it in ipairs(items) do
        if it.locked then keep[i] = it else any = true; avoid[it.id] = true end
    end
    if not any then return nil, "locked" end
    s.rerolls = s.rerolls - 1
    world.events:emit("item_rerolled")
    return Choices.roll(world, #items, minRarity, keep, avoid)
end

-- Ban card i's item for the rest of the run and put a new card in its place.
function Choices.banish(world, items, i, minRarity)
    local s = Choices.state(world)
    local it = items[i]
    if not it or s.banishes <= 0 then return nil end
    s.banishes = s.banishes - 1
    s.banned[it.id] = true
    world.events:emit("item_banished", it)
    local keep, n = {}, #items
    for k, o in ipairs(items) do if k ~= i then keep[k] = o end end
    local out = Choices.roll(world, n, minRarity, keep)
    return out
end

----------------------------------------------------------------------------------------------
-- Synergy tags

-- How many items in the bag carry each tag (copies count).
function Choices.bagTags(inv)
    local n = {}
    for _, e in ipairs(inv.bag) do
        for _, t in ipairs(e.item.def.tags or {}) do n[t] = (n[t] or 0) + 1 end
    end
    return n
end

-- Display info for a tag: { label, color }.
function Choices.tagInfo(tag)
    local t = Tags[tag]
    if not t then
        t = { label = tag:sub(1, 1):upper() .. tag:sub(2), color = "#a89e92" }
        Tags[tag] = t
    end
    t._c = t._c or util.hex(t.color)
    return t
end

-- Draw a row of tag chips centred in [x, x + w]; tags shared with the bag light up and show
-- how many bag items have them. Returns the height used (0 when the item has no tags).
-- measure = true only works out the height.
function Choices.drawTags(def, counts, x, y, w, font, u, measure)
    local lg = love.graphics
    local tags = def.tags or {}
    if #tags == 0 then return 0 end
    lg.setFont(font)
    local padX, gap, h = u(6), u(4), font:getHeight() + u(4)
    local chips, rows = {}, { { w = 0 } }
    for _, t in ipairs(tags) do
        local info = Choices.tagInfo(t)
        local c = counts and counts[t] or 0
        local text = info.label .. (c > 0 and (" " .. c) or "")
        local cw = font:getWidth(text) + padX * 2
        local row = rows[#rows]
        if row.w > 0 and row.w + gap + cw > w then row = { w = 0 }; rows[#rows + 1] = row end
        row.w = row.w + (row.w > 0 and gap or 0) + cw
        row[#row + 1] = { text = text, w = cw, color = info._c, lit = c > 0 }
    end
    local height = #rows * h + (#rows - 1) * gap
    if measure then return height end
    for r, row in ipairs(rows) do
        local cx = math.floor(x + (w - row.w) / 2)
        local cy = math.floor(y + (r - 1) * (h + gap))
        for _, chip in ipairs(row) do
            local col = chip.color
            if chip.lit then
                lg.setColor(col[1] * 0.35, col[2] * 0.35, col[3] * 0.35, 0.95)
                lg.rectangle("fill", cx, cy, chip.w, h)
                lg.setColor(col)
                lg.rectangle("line", cx + 0.5, cy + 0.5, chip.w - 1, h - 1)
                lg.setColor(col)
            else
                lg.setColor(1, 1, 1, 0.05)
                lg.rectangle("fill", cx, cy, chip.w, h)
                lg.setColor(col[1] * 0.7, col[2] * 0.7, col[3] * 0.7, 0.75)
            end
            lg.print(chip.text, cx + padX, cy + u(2))
            cx = cx + chip.w + gap
        end
    end
    return height
end

-- Number of bag items sharing at least one tag with def.
function Choices.synergy(def, counts)
    local n = 0
    for _, t in ipairs(def.tags or {}) do n = n + (counts[t] or 0) end
    return n
end

----------------------------------------------------------------------------------------------
-- Stat preview

local function better(sd, before, after)
    if sd.lowerIsBetter then return after < before end
    return after > before
end

-- What taking one more `def` does to the player's stats:
-- { { id, label, before, after, text = "Speed 120 » 138", good }, ... } in stat order.
function Choices.preview(stats, def)
    local add, mult = def.stats or {}, def.statsMult or {}
    if stats.owner and def.kin then add, mult = require("src.game.shore").statsFor(def, stats.owner) end
    local after = stats:peek(add, mult)
    local out = {}
    for _, sd in ipairs(Stats.defs) do
        if add[sd.id] or mult[sd.id] then
            local b, a = stats:get(sd.id), after[sd.id]
            out[#out + 1] = { id = sd.id, label = sd.label, before = b, after = a,
                text = sd.label .. "  " .. Stats.format(sd.id, b) .. " » " .. Stats.format(sd.id, a),
                good = math.abs(a - b) < 1e-6 and nil or better(sd, b, a) }
        end
    end
    return out
end

return Choices
