-- The nectar economy: the shop (the SHOP tab of the inventory window, src/states/shop.lua),
-- savings interest, the scrapper (the SCRAP bin in the bag, src/states/inventory.lua) and the
-- stat boosts the shop sells. Numbers live in src/config/shop.lua; a mode can override them
-- with `shop = { ... }` or turn the economy off with `shop = false`.
--
-- The shop is open the whole run (opening the inventory pauses the game). Its stock restocks
-- every minute of play (cfg.restock seconds of world time); items with `shopSpeed = 0.25` make
-- it restock 25% faster (they add up: 60 / (1 + total) seconds, never under cfg.restockMin).
-- A restock keeps LOCKED offers and replaces the rest; REROLL replaces them now, for nectar.
-- Savings interest is paid the moment a wave is cleared (src/game/rewardflow.lua).
--
-- Nectar itself (beads, the balance) is src/game/nectar.lua: World:addNectar(n, x, y),
-- World:spendNectar(n) -> bool, world.nectar. The wallet helpers below are the only place
-- this file touches it.
--
-- world.economy = { boosts = { [stat] = add }, locked = { "item:<id>" | "boost:<stat>", ... },
--   shop = { offers = { ... }, rerolls, restockAt, stock, seen }, interestPaid, scrapped,
--   growth = { [id] = n } }
local Content = require("src.content")
local Config = require("src.config.shop")
local Rarities = require("src.config.rarities")
local Stats = require("src.game.stats")
local Inventory = require("src.game.inventory")

local Economy = {}

----------------------------------------------------------------------------------------------
-- Wallet

function Economy.nectar(world) return math.floor(world.nectar or 0) end

function Economy.canAfford(world, n) return Economy.nectar(world) >= n end

function Economy.add(world, n, x, y)
    if n <= 0 then return end
    if world.addNectar then
        world:addNectar(n, x, y)
    else
        world.nectar = (world.nectar or 0) + n
        if world.events then world.events:emit("nectar_changed", world.nectar, n) end
    end
end

-- Takes n nectar if there is enough. Returns true if it was paid.
function Economy.spend(world, n)
    if n <= 0 then return true end
    if world.spendNectar then return world:spendNectar(n) end
    if (world.nectar or 0) < n then return false end
    world.nectar = world.nectar - n
    if world.events then world.events:emit("nectar_changed", world.nectar, -n) end
    return true
end

----------------------------------------------------------------------------------------------
-- Settings and run state

-- The economy's numbers for this run (config, then the mode's `shop = { ... }`).
function Economy.cfg(world)
    if world._shopCfg then return world._shopCfg end
    local over = world.modeDef and world.modeDef.shop
    local c = {}
    for k, v in pairs(Config) do c[k] = v end
    if over == false then c.enabled = false
    elseif type(over) == "table" then for k, v in pairs(over) do c[k] = v end end
    world._shopCfg = c
    return c
end

function Economy.enabled(world) return Economy.cfg(world).enabled ~= false end

function Economy.state(world)
    local s = world.economy
    if s then return s end
    s = { boosts = {}, locked = {}, interestPaid = 0, scrapped = 0, growth = {} }
    world.economy = s
    return s
end

local function wave(world) return world.spawner and math.max(1, world.spawner.wave) or 1 end
Economy.wave = wave

-- The total of an item field over the player's bag (0 without a bag).
local function bagSum(world, field)
    local inv = world.player and world.player.inventory
    return inv and inv:sum(field) or 0
end

local function scale(world) return 1 + Economy.cfg(world).perWave * (wave(world) - 1) end

----------------------------------------------------------------------------------------------
-- Prices

-- What an item costs in the shop right now (before any sale).
function Economy.itemPrice(world, def)
    local c = Economy.cfg(world)
    local base = c.price[def.rarity] or c.price.common
    base = base * (1 + c.perCell * (#def.cells - 1))
    return math.max(1, math.floor(base * scale(world) + 0.5))
end

function Economy.boostPrice(world)
    return math.max(1, math.floor(Economy.cfg(world).boostPrice * scale(world) + 0.5))
end

-- The price of the next shop reroll.
function Economy.rerollPrice(world)
    local c, shop = Economy.cfg(world).reroll, Economy.state(world).shop
    -- free rerolls each restock from `freeShopRerolls` items (Cuckoo Wasp Shell)
    local inv = world.player and world.player.inventory
    if shop and inv and (shop.freeUsed or 0) < inv:sum("freeShopRerolls") then return 0 end
    local n = shop and shop.rerolls or 0
    return math.floor(c.base + c.step * n + c.waveStep * (wave(world) - 1) + 0.5)
end

----------------------------------------------------------------------------------------------
-- The shop

local function boostDef(world, stat)
    for _, b in ipairs(Economy.cfg(world).boostList) do
        if b.stat == stat then return b end
    end
end

-- A boost offer as something the item choice can draw like a card.
local function boostOffer(world, b)
    local sd = Stats.byId[b.stat]
    local v = b.add or 0
    local amount = (v > 0 and "+" or "") .. Stats.format(b.stat, v) .. " " .. sd.label
    return { kind = "boost", boost = b, price = Economy.boostPrice(world), name = b.name,
        text = amount, key = "boost:" .. b.stat,
        def = { name = b.name, rarity = "common", stats = { [b.stat] = b.add }, statsMult = { [b.stat] = b.mult }, tags = {}, procs = {} } }
end

local function itemOffer(world, id)
    local item = Inventory.newItem(id)
    return { kind = "item", item = item, def = item.def, price = Economy.itemPrice(world, item.def), key = "item:" .. id }
end

-- Fill the shop's offers. keep = { [slot] = offer } stays; avoid = { [key] = true } not rolled.
local function roll(world, keep, avoid, notIds)
    local c = Economy.cfg(world)
    local Choices = require("src.game.choices")
    local out, taken = {}, {}
    for id in pairs(notIds or {}) do taken[id] = true end
    for _, o in pairs(keep) do if o.kind == "item" then taken[o.item.id] = true end end
    local usedStats = {}
    for _, o in pairs(keep) do if o.kind == "boost" then usedStats[o.boost.stat] = true end end
    local slot = 0
    for _ = 1, c.items do
        slot = slot + 1
        if keep[slot] then
            out[slot] = keep[slot]
        else
            local d = Choices.pickDef(world, taken, function(d) return not (avoid and avoid["item:" .. d.id]) end)
                or Choices.pickDef(world, taken)
            if d then
                taken[d.id] = true
                out[slot] = itemOffer(world, d.id)
            end
        end
    end
    -- new item offers line up by category (Attack, Elemental, Guard...); locked ones keep their place
    local Categories = require("src.config.categories")
    local free, fresh = {}, {}
    for i = 1, slot do
        if not keep[i] and out[i] then free[#free + 1] = i; fresh[#fresh + 1] = out[i] end
    end
    table.sort(fresh, function(a, b)
        local ka, kb = Categories.rank(a.item.def.category), Categories.rank(b.item.def.category)
        if ka ~= kb then return ka < kb end
        return a.item.id < b.item.id
    end)
    for k, i in ipairs(free) do out[i] = fresh[k] end
    for _ = 1, c.boosts do
        slot = slot + 1
        if keep[slot] then
            out[slot] = keep[slot]
        else
            local pool = {}
            for _, b in ipairs(c.boostList) do
                if not usedStats[b.stat] and not (avoid and avoid["boost:" .. b.stat]) then pool[#pool + 1] = b end
            end
            if #pool == 0 then pool = c.boostList end
            local b = pool[love.math.random(#pool)]
            usedStats[b.stat] = true
            out[slot] = boostOffer(world, b)
        end
    end
    -- a sale now and then on one item that isn't locked
    if love.math.random() < c.sale then
        local cands = {}
        for i, o in pairs(out) do if o.kind == "item" and not keep[i] then cands[#cands + 1] = o end end
        if #cands > 0 then
            local o = cands[love.math.random(#cands)]
            o.sale = true
            o.price = math.max(1, math.floor(o.price * (1 - c.saleOff) + 0.5))
        end
    end
    local list = {}
    for i = 1, slot do if out[i] then list[#list + 1] = out[i] end end
    return list
end

-- Seconds between restocks for this bag (items with `shopSpeed` shorten it).
function Economy.restockTime(world)
    local c = Economy.cfg(world)
    local inv = world.player and world.player.inventory
    local speed = math.max(0, inv and inv:sum("shopSpeed") or 0)
    return math.max(c.restockMin or 15, (c.restock or 60) / (1 + speed))
end

-- Seconds until the next restock.
function Economy.timeLeft(world)
    local shop = Economy.state(world).shop
    if not shop then return Economy.restockTime(world) end
    return math.max(0, (shop.restockAt or 0) - (world.time or 0))
end

-- The shop as it stands (made the first time it is asked for; locked offers from before come
-- back first, at today's price). notIds: item ids not to offer.
function Economy.shop(world, notIds)
    local s = Economy.state(world)
    if s.shop then return s.shop end
    local keep = {}
    local c = Economy.cfg(world)
    local lockedItems, lockedBoosts = {}, {}
    for _, key in ipairs(s.locked) do
        local kind, id = key:match("^(%a+):(.+)$")
        if kind == "item" and Content.items.byId[id] then lockedItems[#lockedItems + 1] = id
        elseif kind == "boost" and boostDef(world, id) then lockedBoosts[#lockedBoosts + 1] = id end
    end
    for i = 1, math.min(c.items, #lockedItems) do
        local o = itemOffer(world, lockedItems[i])
        o.locked = true
        keep[i] = o
    end
    for i = 1, math.min(c.boosts, #lockedBoosts) do
        local o = boostOffer(world, boostDef(world, lockedBoosts[i]))
        o.locked = true
        keep[c.items + i] = o
    end
    s.locked = {}
    s.stock = (s.stock or 0) + 1
    s.shop = { rerolls = 0, offers = roll(world, keep, nil, notIds), stock = s.stock,
        restockAt = (world.time or 0) + Economy.restockTime(world) }
    return s.shop
end

-- New stock now: locked offers stay (at today's price), everything else is replaced.
function Economy.restock(world)
    Economy.remember(world)
    local s = Economy.state(world)
    s.shop = nil
    local shop = Economy.shop(world)
    world.events:emit("shop_restocked", shop)
    return shop
end

-- Every frame (World:update): restock when the timer runs out. A faster bag (a shopSpeed item
-- just picked up) pulls the next restock closer at once.
function Economy.update(world, dt)
    if not Economy.open(world) then return end
    local s = Economy.state(world)
    local shop = s.shop or Economy.shop(world)
    local due = (world.time or 0) + Economy.restockTime(world)
    if shop.restockAt > due then shop.restockAt = due end
    if world.time >= shop.restockAt then Economy.restock(world) end
end

-- Whether this run has a shop at all (real runs with the economy on).
function Economy.open(world)
    return Economy.enabled(world) and world.mode == "run" and not (world.flags and world.flags.demo)
        and require("src.game.onramp").allows(world, "shop")
end

-- Remember locked offers for the next stock (a restock, or a save).
function Economy.remember(world)
    local s = Economy.state(world)
    s.locked = {}
    if not s.shop then return end
    for _, o in ipairs(s.shop.offers) do
        if o.locked and not o.sold then s.locked[#s.locked + 1] = o.key end
    end
end

-- New offers for every slot that isn't locked or sold. Returns true, or false and why
-- ("poor" | "locked").
function Economy.rerollShop(world, notIds)
    local s = Economy.state(world)
    local shop = s.shop
    if not shop then return false, "none" end
    local keep, avoid, any = {}, {}, false
    for i, o in ipairs(shop.offers) do
        if o.locked or o.sold then keep[i] = o else any = true; avoid[o.key] = true end
    end
    if not any then return false, "locked" end
    local price = Economy.rerollPrice(world)
    if price <= 0 then
        shop.freeUsed = (shop.freeUsed or 0) + 1
    elseif not Economy.spend(world, price) then
        return false, "poor"
    else
        shop.rerolls = shop.rerolls + 1
    end
    -- keep slots in place: rebuild with the kept ones where they were
    shop.offers = roll(world, keep, avoid, notIds)
    world.events:emit("shop_rerolled")
    return true
end

-- Make the shop's boosts count: one stats source holding everything bought.
function Economy.applyBoosts(player)
    local world = player.world
    if not world then return end
    local s = Economy.state(world)
    player.stats:removeSource("shop:boosts")
    for stat, v in pairs(s.boosts) do
        if Stats.byId[stat] then player.stats:addModifier("shop:boosts", stat, v.add or 0, v.mult or 0) end
    end
end

-- Buy offer i. For an item, returns true and the item (the caller puts it in the bag); for a
-- boost it counts at once. Returns false and why ("poor" | "sold") otherwise.
function Economy.buy(world, i)
    local s = Economy.state(world)
    local o = s.shop and s.shop.offers[i]
    if not o then return false, "none" end
    if o.sold then return false, "sold" end
    if not Economy.spend(world, o.price) then return false, "poor" end
    o.sold, o.locked = true, nil
    world.events:emit("shop_bought", o)
    if o.kind == "boost" then
        local b = o.boost
        local cur = s.boosts[b.stat] or {}
        cur.add = (cur.add or 0) + (b.add or 0)
        cur.mult = (cur.mult or 0) + (b.mult or 0)
        s.boosts[b.stat] = cur
        Economy.applyBoosts(world.player)
        return true
    end
    o.item.locked = nil
    return true, o.item
end

-- Whether anything not yet sold costs no more than the nectar in hand.
function Economy.anyAffordable(world)
    local shop = Economy.state(world).shop
    if not shop then return false end
    local n = Economy.nectar(world)
    for _, o in ipairs(shop.offers) do if not o.sold and o.price <= n then return true end end
    return false
end

----------------------------------------------------------------------------------------------
-- Savings interest

-- What the banked nectar earns at the next wave clear.
function Economy.interestPreview(world, bank)
    local c = Economy.cfg(world).interest
    if not c or not Economy.enabled(world) then return 0 end
    local cap = Economy.interestCap(world)
    return math.max(0, math.min(cap, math.floor((bank or Economy.nectar(world)) * c.rate)))
end

-- The cap on interest at this wave (shown in the shop).
function Economy.interestCap(world)
    local c = Economy.cfg(world).interest
    return math.floor(c.cap + c.capPerWave * (wave(world) - 1) + bagSum(world, "interestCap"))
end

-- Pay interest once per wave clear (src/game/rewardflow.lua, on wave_cleared). Returns the amount.
function Economy.payInterest(world)
    local s = Economy.state(world)
    local w = wave(world)
    if s.interestWave == w then return 0 end
    s.interestWave = w
    -- `waveNectar` items (Seed Cache) pay a flat bonus at every clear, on top of interest
    local bonus = math.floor(bagSum(world, "waveNectar"))
    if bonus > 0 then
        Economy.add(world, bonus)
        if world.player then world:floatText(world.player.x, world.player.y - 14, "+" .. bonus .. " nectar", { 1, 0.85, 0.35 }) end
    end
    local n = Economy.interestPreview(world)
    if n > 0 then
        Economy.add(world, n)
        s.interestPaid = s.interestPaid + n
        world.events:emit("nectar_interest", n)
    end
    return n
end

----------------------------------------------------------------------------------------------
-- Scrapper

-- What scrapping an item gives: nectar, and whether it also gives back a reroll.
function Economy.scrapValue(world, item)
    local def = item.def
    if def.rarity == "cursed" then return 0, false end
    local c = Economy.cfg(world)
    local nectar = Economy.enabled(world) and math.floor(Economy.itemPrice(world, def) * c.scrap.share + 0.5) or 0
    local from = Rarities[c.scrap.rerollFrom or "rare"]
    local r = Rarities[def.rarity]
    local reroll = from ~= nil and r ~= nil and r.order >= from.order
    return nectar, reroll
end

-- Scrap an item (already out of the bag): pays nectar (and a reroll for rare or better).
-- Returns nectar, reroll.
function Economy.scrap(world, item, x, y)
    local n, reroll = Economy.scrapValue(world, item)
    if n > 0 then Economy.add(world, n, x, y) end
    if reroll then
        local cs = require("src.game.choices").state(world)
        cs.rerolls = cs.rerolls + 1
    end
    local s = Economy.state(world)
    s.scrapped = s.scrapped + 1
    -- growth a curse built up (Parasitoid Egg) goes with the last copy
    local inv = world.player and world.player.inventory
    if inv and inv:count(item.id) == 0 then s.growth[item.id] = nil end
    world.events:emit("item_scrapped", item, n, reroll)
    return n, reroll
end

return Economy
