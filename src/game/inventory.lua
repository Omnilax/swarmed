-- The player's items, FATE style: a bag grid where items take up several cells. Everything in
-- the bag counts: there is no equipping, copies of one item stack (two Ember Glands = 2 stacks),
-- and the only limit is fitting the shapes (L, T, bars...) into the grid. Items can be turned.
--
-- Proc triggers currently fired: "onHit", "onKill" (ctx from World:procContext), "onHurt",
-- "onDash", "onDodge", "onWaveStart", "onAttack", "onSpecial", "onBlock", "onEat" (ctx.hp = HP the meal heals, procs may raise it)
-- and "onTick" (every frame, ctx.dt; see src/game/itemfx.lua for timers, buffs and patches).
-- Add new trigger names anywhere with inventory:trigger(name, ctx).
local Content = require("src.content")
local Equipment = require("src.config.equipment")

local Inventory = {}
Inventory.__index = Inventory

local nextUid = 0

-- An item instance (one physical item in the bag or on the ground). rot = quarter turns (0..3).
function Inventory.newItem(id)
    nextUid = nextUid + 1
    return { id = id, def = Content.items:require(id), uid = nextUid }
end

function Inventory.new(player)
    local self = setmetatable({ player = player, cols = Equipment.bag.cols, rows = Equipment.bag.rows,
        bag = {}, counts = {}, order = {}, grid = {} }, Inventory)
    return self
end

-- Grow the bag by n rows at the bottom (every 15 waves survived). Cells are keyed y * cols + x,
-- so nothing already in the bag moves.
function Inventory:addRows(n)
    self.rows = self.rows + (n or 1)
    self:rebuildGrid()
end

-- Copies of an item id in the bag (used as "stacks" by procs and stats).
function Inventory:count(id) return self.counts[id] or 0 end

-- Shapes. An item's cells come from its def (`shape` rows like { "XX", "X." }, or a plain
-- `size` rectangle; see src/content.lua). rot = 0..3 quarter turns clockwise.
local function turned(def, rot)
    def._turns = def._turns or {}
    local t = def._turns[rot]
    if t then return t end
    local cells, w, h = def.cells, def.size[1], def.size[2]
    for _ = 1, rot do
        local out = {}
        for i, c in ipairs(cells) do out[i] = { h - 1 - c[2], c[1] } end
        cells, w, h = out, h, w
    end
    t = { cells = cells, w = w, h = h }
    def._turns[rot] = t
    return t
end

-- Bounding box of an item at its current turn: wide, tall.
function Inventory.size(item)
    local t = turned(item.def, item.rot or 0)
    return t.w, t.h
end

-- The cells it covers at its current turn, as { {x, y}, ... } offsets from its top-left.
function Inventory.cells(item) return turned(item.def, item.rot or 0).cells end

-- Turn an item a quarter clockwise (no-op for shapes that look the same turned).
function Inventory.rotate(item)
    item.rot = ((item.rot or 0) + 1) % 4
end

-- Which entry sits on each cell (rebuilt whenever the bag changes).
function Inventory:rebuildGrid()
    local grid = {}
    for _, e in ipairs(self.bag) do
        for _, c in ipairs(Inventory.cells(e.item)) do grid[(e.y + c[2]) * self.cols + e.x + c[1]] = e end
    end
    self.grid = grid
end

-- Entries an item would overlap with its top-left at cell (x, y), and whether it is inside the bag.
function Inventory:overlaps(item, x, y, ignore)
    local inside, hits, seen = true, {}, {}
    for _, c in ipairs(Inventory.cells(item)) do
        local cx, cy = x + c[1], y + c[2]
        if cx < 0 or cy < 0 or cx >= self.cols or cy >= self.rows then
            inside = false
        else
            local e = self.grid[cy * self.cols + cx]
            if e and e ~= ignore and not seen[e] then seen[e] = true; hits[#hits + 1] = e end
        end
    end
    return hits, inside
end

function Inventory:fits(item, x, y)
    local hits, inside = self:overlaps(item, x, y)
    return inside and #hits == 0
end

-- First free spot for an item at its current turn.
function Inventory:findSpace(item)
    local w, h = Inventory.size(item)
    for y = 0, self.rows - h do
        for x = 0, self.cols - w do
            if self:fits(item, x, y) then return x, y end
        end
    end
end

function Inventory:entryAt(cx, cy)
    if cx < 0 or cy < 0 or cx >= self.cols or cy >= self.rows then return nil end
    return self.grid[cy * self.cols + cx]
end

function Inventory:placeInBag(item, x, y)
    local e = { item = item, x = x, y = y }
    self.bag[#self.bag + 1] = e
    self:recount()
    return e
end

function Inventory:removeEntry(e)
    for i, o in ipairs(self.bag) do
        if o == e then
            table.remove(self.bag, i)
            self:recount()
            return e.item
        end
    end
end

-- Put an item anywhere it fits, trying every turn. Returns false if there is no room.
function Inventory:stow(item)
    local rot0 = item.rot or 0
    for k = 0, 3 do
        item.rot = (rot0 + k) % 4
        local x, y = self:findSpace(item)
        if x then
            self:placeInBag(item, x, y)
            return true
        end
    end
    item.rot = rot0
    return false
end

-- Tidy the bag: big items first, then rarest, copies of one item side by side, each packed
-- into the top-left-most spot (trying every turn). Tries a few orders; if none fits everything
-- (the old layout was tighter), nothing moves. Returns true if the bag was sorted.
local function rarityOrder(def)
    local r = require("src.config.rarities")[def.rarity]
    return r and r.order or 0
end

local SORTS = {
    function(a, b)   -- most cells, rarest, by name
        local ca, cb = #a.def.cells, #b.def.cells
        if ca ~= cb then return ca > cb end
        local ra, rb = rarityOrder(a.def), rarityOrder(b.def)
        if ra ~= rb then return ra > rb end
        if a.id ~= b.id then return a.id < b.id end
        return a.uid < b.uid
    end,
    function(a, b)   -- biggest bounding box first (packs awkward shapes better)
        local wa, ha = Inventory.size(a)
        local wb, hb = Inventory.size(b)
        if wa * ha ~= wb * hb then return wa * ha > wb * hb end
        if math.max(wa, ha) ~= math.max(wb, hb) then return math.max(wa, ha) > math.max(wb, hb) end
        if a.id ~= b.id then return a.id < b.id end
        return a.uid < b.uid
    end,
}

function Inventory:autoSort()
    local old = {}
    for i, e in ipairs(self.bag) do old[i] = { e = e, rot = e.item.rot } end
    for _, cmp in ipairs(SORTS) do
        local items = {}
        for i, o in ipairs(old) do items[i] = o.e.item end
        table.sort(items, cmp)
        -- place without recount (that would drop proc bonuses of items not yet placed back)
        self.bag, self.grid = {}, {}
        local ok = true
        for _, item in ipairs(items) do
            local best, bx, by, bk
            for k = 0, 3 do
                item.rot = k
                local x, y = self:findSpace(item)
                if x and (not best or y * self.cols + x < best) then best, bx, by, bk = y * self.cols + x, x, y, k end
            end
            if not best then ok = false break end
            item.rot = bk
            local e = { item = item, x = bx, y = by }
            self.bag[#self.bag + 1] = e
            for _, c in ipairs(Inventory.cells(item)) do self.grid[(by + c[2]) * self.cols + bx + c[1]] = e end
        end
        if ok then
            self:recount()
            return true
        end
    end
    self.bag = {}
    for i, o in ipairs(old) do o.e.item.rot = o.rot; self.bag[i] = o.e end
    self:rebuildGrid()
    return false
end

-- HP from eating an item: its rarity's `eat`, plus a quarter more for every extra cell it fills.
function Inventory.eatValue(item)
    local r = require("src.config.rarities")[item.def.rarity]
    return math.floor((r.eat or 8) * (1 + 0.25 * (#item.def.cells - 1)) + 0.5)
end

-- Eat an item: it is gone and heals the player. Returns the HP healed.
function Inventory:eat(item)
    local p = self.player
    local ctx = { world = p.world, player = p, item = item, hp = Inventory.eatValue(item), procDepth = 0 }
    self:trigger("onEat", ctx)
    p.world.events:emit("item_eaten", item)
    local hp = math.floor(ctx.hp + 0.5)
    p:heal(hp)
    return hp
end

-- Every frame (from Player:update): timed item effects and the "onTick" procs.
function Inventory:update(dt)
    local p = self.player
    require("src.game.itemfx").update(p.world, p, dt)
    local ctx = self.tickCtx
    if not ctx then ctx = { world = p.world, player = p, procDepth = 0 }; self.tickCtx = ctx end
    ctx.dt = dt
    self:trigger("onTick", ctx)
end

-- Cells used by everything in the bag.
function Inventory:usedCells()
    local n = 0
    for _, e in ipairs(self.bag) do n = n + #Inventory.cells(e.item) end
    return n
end

-- Rebuild the grid, stack counts and the stat modifiers they give.
function Inventory:recount()
    self:rebuildGrid()
    local stats = self.player.stats
    local old = self.order
    for _, id in ipairs(old) do stats:removeSource("item:" .. id) end
    self.counts, self.order = {}, {}
    for _, e in ipairs(self.bag) do
        local id = e.item.id
        if not self.counts[id] then self.order[#self.order + 1] = id end
        self.counts[id] = (self.counts[id] or 0) + 1
    end
    for _, id in ipairs(self.order) do
        local def, n = Content.items:require(id), self.counts[id]
        for stat, v in pairs(def.stats) do stats:addModifier("item:" .. id, stat, v * n, 0) end
        for stat, v in pairs(def.statsMult) do stats:addModifier("item:" .. id, stat, 0, v * n) end
    end
    -- bonuses an item's procs keep up (source "fx:<id>") go when the last copy leaves the bag
    for _, id in ipairs(old) do
        if not self.counts[id] then stats:removeSource("fx:" .. id) end
    end
end

----------------------------------------------------------------------------------------------
-- Convenience used by the sandbox and the console

-- Gives n copies. Returns the items that did not fit (so they can be dropped on the ground).
function Inventory:add(id, n)
    local leftover = {}
    for _ = 1, n or 1 do
        local item = Inventory.newItem(id)
        if not self:give(item) then leftover[#leftover + 1] = item end
    end
    return leftover
end

function Inventory:give(item)
    if not self:stow(item) then return false end
    if item.def.onAdd then item.def.onAdd(self.player, self:count(item.id)) end
    return true
end

function Inventory:remove(id, n)
    n = n or 1
    for i = #self.bag, 1, -1 do
        if n > 0 and self.bag[i].item.id == id then table.remove(self.bag, i); n = n - 1 end
    end
    self:recount()
end

function Inventory:clear()
    self.bag = {}
    self:recount()
end

-- Move everything into another inventory (used when the sandbox swaps characters).
function Inventory:transferTo(other)
    other.rows = math.max(other.rows, self.rows)
    for _, e in ipairs(self.bag) do other.bag[#other.bag + 1] = e end
    other:recount()
end

-- proc.chance may be a number or function(stacks) -> chance (0..1). Luck scales it.
-- proc.effect(ctx, stacks) does the work.
function Inventory:trigger(name, ctx)
    -- luck, and the proc snowball: chances grow with every wave (src/config/rewards.lua procs)
    local rw = self.player.world.rewards
    local luck = (1 + self.player.stats:get("luck") / 100) * (rw and rw:procMul() or 1)
    for _, id in ipairs(self.order) do
        local def = Content.items.byId[id]
        local stacks = self.counts[id]
        for _, proc in ipairs(def.procs) do
            if proc.trigger == name then
                local chance = proc.chance
                if type(chance) == "function" then chance = chance(stacks) end
                if chance == nil or love.math.random() < chance * luck then
                    -- the damage it does counts for this item in the run summary
                    local w = ctx.world
                    local prev = w and w.dmgSrc
                    if w then w.dmgSrc = def.name end
                    proc.effect(ctx, stacks)
                    if w then w.dmgSrc = prev end
                    -- the sandbox's proc log listens here (every-frame ticks are left out)
                    if self.onProc and name ~= "onTick" then self.onProc(def, name) end
                end
            end
        end
    end
    -- the bug's skill tree answers the same triggers (src/game/skills.lua)
    local skills = self.player.skills
    if skills then skills:trigger(name, ctx) end
end

return Inventory
