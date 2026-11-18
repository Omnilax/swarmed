-- Parasites: items that live IN your bug instead of the bag (rarity "parasite", content/items
-- with `parasite = true`). Each is a big change to how you play with a real cost: Flu halves
-- your HP and doubles your damage, Cordyceps walks for you, Head Lice breed every wave...
--
-- Rules
--   * They take no bag space and never touch the grid, so nothing in the bag can eat, scrap,
--     sell, sort, molt or clone them. They still count like bag items (stats, procs,
--     inventory:sum(), the HUD item row) because Inventory:recount adds them in.
--   * One copy each, at most cfg.max different ones (src/config/parasites.lua).
--   * The only cure is a Green Mushroom (content/props/green_mushroom.lua): a rare sprout that
--     shows up while you carry one. Walking into it purges every parasite at once.
--   * Void-style feeding: a parasite def can say `feeds = { ids = {...}, stats = {...} }`. When
--     it gets in, every copy of those items in your bag is devoured and each one adds `stats`
--     for good (until the parasite is purged).
--
-- Parasite defs may also have:
--   steer = function(player, wx, wy, mag, dt, item) -> wx, wy, mag   (bends your walking)
--   item.level: a number the parasite grows (lice, botfly larva); saved with the run.
local Content = require("src.content")
local util = require("src.core.util")

local Parasites = {}
local EMPTY = {}

function Parasites.cfg(world)
    local base = require("src.config.parasites")
    local mode = world and world.modeDef
    if mode and type(mode.parasites) == "table" then
        local out = util.deepcopy(base)
        for k, v in pairs(mode.parasites) do out[k] = v end
        return out
    end
    return base
end

-- Are parasites on? Always in the main game; a mode (Custom Waves) can turn them off with
-- `parasites = false`. Deliberately not a global setting: it changes the game too much.
function Parasites.on(world)
    if world and world.modeDef and world.modeDef.parasites == false then return false end
    return true
end

-- The parasite items (instances) a player's inventory carries.
function Parasites.list(inv) return inv and inv.parasites or EMPTY end

function Parasites.find(inv, id)
    for _, it in ipairs(Parasites.list(inv)) do if it.id == id then return it end end
end

function Parasites.count(inv) return #Parasites.list(inv) end

-- Item choice weight multiplier for a def (1 for anything that isn't a parasite).
function Parasites.weight(world, def)
    if not def.parasite then return 1 end
    if not Parasites.on(world) then return 0 end
    local inv = world.player and world.player.inventory
    if inv and (Parasites.find(inv, def.id) or Parasites.count(inv) >= Parasites.cfg(world).max) then return 0 end
    return Parasites.cfg(world).weightMul or 1
end

-- The steering hook Player:update calls (only set while a parasite steers).
local function steer(p, wx, wy, mag, dt)
    for _, it in ipairs(Parasites.list(p.inventory)) do
        if it.def.steer then wx, wy, mag = it.def.steer(p, wx, wy, mag, dt, it) end
    end
    return wx, wy, mag
end

-- Re-apply what parasites keep up outside the normal item stats: the feeding bonuses and the
-- steering hook. Called after any change (infest, purge, restore).
function Parasites.refresh(inv)
    local p = inv.player
    local stats = p.stats
    local any = false
    for _, it in ipairs(Parasites.list(inv)) do
        local src = "parasite_fed:" .. it.id
        stats:removeSource(src)
        local f = it.def.feeds
        if f and (it.fed or 0) > 0 then
            for stat, v in pairs(f.stats or EMPTY) do stats:addModifier(src, stat, v * it.fed, 0) end
            for stat, v in pairs(f.statsMult or EMPTY) do stats:addModifier(src, stat, 0, v * it.fed) end
        end
        if it.def.steer then any = true end
    end
    p.steer = any and steer or nil
end

-- A parasite gets in. Returns true (it never needs bag room).
function Parasites.infest(inv, item, quiet)
    inv.parasites = inv.parasites or {}
    if Parasites.find(inv, item.id) then return true end   -- already got that one: nothing more
    item.level = item.level or 1
    local list = inv.parasites
    list[#list + 1] = item
    local p = inv.player
    local world = p.world
    -- Void-style: it devours its hosts in the bag
    local f = item.def.feeds
    local eaten = 0
    if f and f.ids and not quiet then
        local hosts = {}
        for _, id in ipairs(f.ids) do hosts[id] = true end
        for i = #inv.bag, 1, -1 do
            if hosts[inv.bag[i].item.id] then
                local gone = table.remove(inv.bag, i).item
                eaten = eaten + 1
                if world and world.events then world.events:emit("item_eaten", gone) end
            end
        end
        item.fed = (item.fed or 0) + eaten
    end
    inv:recount()
    Parasites.refresh(inv)
    if item.def.onAdd then item.def.onAdd(p, 1) end
    if world and not quiet then
        world.parasiteWaves = world.parasiteWaves or 0
        world.parasiteSince = world.parasiteSince or (world.spawner and world.spawner.wave or 0)
        local col = util.hex(require("src.config.rarities").parasite.color)
        if world.floatText then
            world:floatText(p.x, p.y - 18, item.def.name:upper() .. "!", col, true)
            if eaten > 0 then world:floatText(p.x, p.y - 30, "devoured " .. eaten .. " host item" .. (eaten > 1 and "s" or ""), col, false) end
        end
        if world.events then world.events:emit("parasite_gained", item) end
    end
    return true
end

-- Rid the player of every parasite (the Green Mushroom). Returns how many left.
function Parasites.purge(world)
    local p = world.player
    local inv = p and p.inventory
    local n = Parasites.count(inv)
    if n == 0 then return 0 end
    for _, it in ipairs(inv.parasites) do
        p.stats:removeSource("parasite_fed:" .. it.id)
        p.stats:removeSource("fx:" .. it.id)
        if p.itemState then p.itemState[it.id] = nil end
        if it.def.onPurge then it.def.onPurge(p, it) end
    end
    inv.parasites = {}
    inv:recount()
    Parasites.refresh(inv)
    p.hp = math.min(p.hp, p.stats:get("maxHp"))
    world.parasiteSince = nil
    world.events:emit("parasites_purged", n)
    return n
end

-- Run save (src/game/runsave.lua): { { id, level, fed }, ... }
function Parasites.save(inv)
    local out = {}
    for _, it in ipairs(Parasites.list(inv)) do out[#out + 1] = { id = it.id, level = it.level, fed = it.fed } end
    return out
end

function Parasites.restore(inv, list)
    inv.parasites = {}
    for _, s in ipairs(list or EMPTY) do
        if Content.items:get(s.id) then
            local item = require("src.game.inventory").newItem(s.id)
            item.level, item.fed = s.level or 1, s.fed or 0
            Parasites.infest(inv, item, true)
        end
    end
    Parasites.refresh(inv)
end

----------------------------------------------------------------------------------------------
-- Helpers for parasite procs

-- A per-wave flag: is a wave being fought right now? (curses that hurt you rest in the break)
function Parasites.live(world)
    return world.spawner and world.spawner.phase == "wave"
end

-- Take HP without killing (drains): never below 1.
function Parasites.drain(p, amount)
    if p.dead or p.world.flags.god then return end
    p.hp = math.max(math.min(p.hp, 1), p.hp - amount)
end

-- Set a parasite's own stat bonus (source "fx:<id>", cleared when it is purged).
function Parasites.setStats(p, id, stats)
    local src = "fx:" .. id
    p.stats:removeSource(src)
    for stat, v in pairs(stats) do p.stats:addModifier(src, stat, v, 0) end
end

-- The middle of the ants near (x, y), and how many there are.
function Parasites.crowd(world, x, y, r)
    local list = require("src.game.combat").collect(world, x, y, r)
    local n = #list
    if n == 0 then return nil, nil, 0 end
    local sx, sy = 0, 0
    for _, e in ipairs(list) do sx, sy = sx + e.x, sy + e.y end
    return sx / n, sy / n, n
end

----------------------------------------------------------------------------------------------
-- The Green Mushroom: rolled when a wave starts, placed a few seconds in

function Parasites.attach(world)
    if world.mode ~= "run" or world.flags.demo then return end
    world.events:on("wave_started", function(n) Parasites.onWaveStart(world, n) end)
end

function Parasites.onWaveStart(world, n)
    -- last wave's mushroom wilts if nobody ate it
    for _, o in ipairs(world.props.list) do
        if o.def.mushroom and not o.dead then o.st.wilt = true end
    end
    local inv = world.player and world.player.inventory
    if Parasites.count(inv) == 0 or not Parasites.on(world) then return end
    local c = Parasites.cfg(world).mushroom
    world.parasiteWaves = (world.parasiteWaves or 0) + 1
    if (n or 0) - (world.parasiteSince or 0) <= c.graceWaves then return end
    local chance = math.min(c.maxChance, c.chance + c.pity * math.max(0, world.parasiteWaves - 1))
    if love.math.random() < chance then
        Parasites.sprout(world, nil, nil, c.arriveAt[1] + love.math.random() * (c.arriveAt[2] - c.arriveAt[1]))
    end
end

-- Put a Green Mushroom on the map (away from the player unless x, y are given). With `delay`
-- it stays underground that many seconds first (the prop pops itself up and calls Parasites.popped).
function Parasites.sprout(world, x, y, delay)
    if not x then x, y = require("src.game.envfx").pointAway(world, Parasites.cfg(world).mushroom.away, 70) end
    world.parasiteWaves = 0
    local o = world.props:spawn("green_mushroom", x, y, { delay = delay or 0 })
    if not delay or delay <= 0 then Parasites.popped(world, o) end
    return o
end

-- The mushroom breaks the surface: a puff of green and a banner.
function Parasites.popped(world, o)
    world.particles:burst(o.x, o.y, 16, { { 0.5, 1, 0.45 }, { 0.85, 1, 0.7 } }, 70, 60, { grav = 120 })
    require("src.core.audio").play("chime", { pitch = 0.9 })
    if world.director then
        world.director:announce("Green Mushroom", "A rare cure sprouted. Eat it to purge every parasite.", { 0.55, 1, 0.5 })
    end
    world.events:emit("mushroom_sprouted", o)
end

return Parasites
