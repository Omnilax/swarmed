-- Sandbox side panel: a tabbed testing kit for everything in content/.
-- The enemy / queen / character catalogue (V) shows every bug as a picture to click instead of
-- a long list, and "Place" there drops it wherever you click or tap on the arena.
--   Spawn   any enemy (normal, a chosen or random elite), every species at once, every elite of
--           one species, marching columns from the edge, queens; enemy health multiplier
--   Items   the item catalogue (C), quick give/take, a bigger bag, item choices on demand
--   Player  characters, god mode, heal / hurt (fires onHurt procs), every stat on a slider
--   Waves   start any wave, step through them, keep going or stop, item choice after waves
--   World   time of day, time scale, debug views, a DPS meter and a log of item procs
-- Everything is listed straight from the content registries, so new content shows up here
-- the moment its file exists.
local Content = require("src.content")
local Settings = require("src.core.settings")
local State = require("src.core.state")
local Theme = require("src.ui.theme")
local Menu = require("src.ui.menu")
local Stats = require("src.game.stats")
local Inventory = require("src.game.inventory")
local Rarities = require("src.config.rarities")
local Equipment = require("src.config.equipment")

local Sandbox = {}
Sandbox.__index = Sandbox

local AMOUNTS = { 1, 5, 10, 25, 50, 100, 250, 500 }
local HEALTH = { { 0.05, "One hit" }, { 1, "Normal" }, { 5, "x5" }, { 25, "x25" }, { 1000, "Dummy (x1000)" } }
local BAGS = { { Equipment.bag.cols, Equipment.bag.rows }, { 10, 7 }, { 14, 9 } }
local TABS = { "Spawn", "Items", "Player", "Waves", "World" }
local DPS_WINDOW = 5
Sandbox.HEALTH = HEALTH

-- Slider range and step for each stat's base value (percent stats default to -90..500).
local STAT_RANGE = {
    maxHp = { 1, 1000, 10 }, hpRegen = { 0, 20, 0.5 }, armor = { -20, 100, 1 }, dodge = { 0, 60, 5 },
    moveSpeed = { 20, 300, 5 }, critChance = { 0, 100, 5 }, critDamage = { 100, 500, 10 },
    lifesteal = { 0, 100, 5 }, pickupRange = { 0, 400, 10 }, dashCooldown = { 0.2, 5, 0.1 },
}

local function options(registry, pred)
    local out = {}
    for _, def in ipairs(registry:all()) do
        if not pred or pred(def) then out[#out + 1] = { value = def.id, label = def.name } end
    end
    return out
end

-- Enemies grouped by family (ants, then bees, wasps, termites...).
local function enemyOptions()
    local out = {}
    for _, fam in ipairs(require("src.config.families")) do
        for _, def in ipairs(Content.enemies:all()) do
            if not def.boss and def.family == fam.id then out[#out + 1] = { value = def.id, label = def.name } end
        end
    end
    return out
end

-- Items by rarity, then name.
local function itemOptions()
    local list = {}
    for _, def in ipairs(Content.items:all()) do list[#list + 1] = def end
    table.sort(list, function(a, b)
        local ra, rb = Rarities[a.rarity].order, Rarities[b.rarity].order
        if ra ~= rb then return ra < rb end
        return a.name < b.name
    end)
    local out = {}
    for _, def in ipairs(list) do out[#out + 1] = { value = def.id, label = def.name } end
    return out
end

local function isBoss(def) return def.boss end
local function isAnt(def) return not def.boss end

local function pairsOf(list)
    local out = {}
    for _, p in ipairs(list) do out[#out + 1] = { value = p[1], label = p[2] } end
    return out
end

function Sandbox.new(game)
    local self = setmetatable({ game = game, world = game.world, visible = true, tab = 1 }, Sandbox)
    local world = game.world
    self.enemy = Content.enemies:filter(isAnt)[1].id
    self.queen = (Content.enemies:filter(isBoss)[1] or {}).id
    self.elite = "none"
    self.amount = 10
    self.hpMul = 1
    self.item = itemOptions()[1].value
    self.character = world.player.def.id
    self.bag = 1
    self.wave = 1
    self.autoWaves = false
    self.waveChoice = true
    self.showDps = true
    self.showProcs = true
    self:resetMeter()
    self.procs = {}         -- recent item procs: { def, trigger, n, t }

    world.events:on("enemy_hit", function(ctx)
        local m = self.meter
        m.hits[#m.hits + 1] = { t = world.time, d = ctx.damage }
        m.total = m.total + ctx.damage
        if ctx.damage > m.biggest then m.biggest, m.biggestCrit = ctx.damage, ctx.crit end
    end)
    world.events:on("enemy_killed", function() self.meter.kills = self.meter.kills + 1 end)
    world.events:on("player_hurt", function(ctx) self.meter.taken = self.meter.taken + (ctx.damage or 0) end)
    self.procHook = function(def, trigger) self:logProc(def, trigger) end

    self.menu = Menu.new({
        mouseOnly = true,
        fontSize = 15,
        rowHeight = 26,
        rect = function()
            local w, h = love.graphics.getDimensions()
            local top = Theme.u(150)
            return w - Theme.u(380), top, Theme.u(370), math.min(h - top - Theme.u(40), Theme.u(26) * #self.menu.items)
        end,
    })
    self:setTab(1)
    return self
end

----------------------------------------------------------------------------------------------
-- Tabs

function Sandbox:setTab(i)
    self.tab = (i - 1) % #TABS + 1
    local build = ({ self.spawnTab, self.itemsTab, self.playerTab, self.wavesTab, self.worldTab })[self.tab]
    self.menu:setItems(build(self))
end

function Sandbox:spawnTab()
    local world = self.world
    local eliteOpts = { { value = "none", label = "Normal" }, { value = "random", label = "Random elite" } }
    for _, el in ipairs(Content.elites:all()) do eliteOpts[#eliteOpts + 1] = { value = el.id, label = el.name } end
    local amountOpts = {}
    for _, n in ipairs(AMOUNTS) do amountOpts[#amountOpts + 1] = { value = n, label = tostring(n) } end
    return {
        { type = "header", label = "Enemies" },
        { type = "button", label = "Enemy catalogue", value = function() return "V" end, desc = "Every enemy as a picture: pick, spawn or place",
            onActivate = function() self:openSpawnCatalogue("enemies") end },
        { type = "choice", label = "Enemy", options = enemyOptions(), get = function() return self.enemy end, set = function(v) self.enemy = v end },
        { type = "choice", label = "Variant", options = eliteOpts, get = function() return self.elite end, set = function(v) self.elite = v end },
        { type = "choice", label = "Amount", options = amountOpts, get = function() return self.amount end, set = function(v) self.amount = v end },
        { type = "choice", label = "Health", options = pairsOf(HEALTH), get = function() return self.hpMul end, set = function(v) self.hpMul = v end },
        { type = "button", label = "Spawn around me", onActivate = function()
            local p = world.player
            for i = 1, self.amount do
                local a = (i / self.amount) * math.pi * 2 + love.math.random() * 0.3
                local r = 130 + love.math.random() * 40
                self:spawn(self.enemy, p.x + math.cos(a) * r, p.y + math.sin(a) * r, self:pickElite())
            end
        end },
        { type = "button", label = "March in from the edge", desc = "A real column out of the grass, like in a run", onActivate = function()
            world.spawner:spawnGroup(Content.enemies:require(self.enemy), self.amount)
        end },
        { type = "button", label = "Every elite of this ant", onActivate = function()
            local els = Content.elites:all()
            local p = world.player
            for i, el in ipairs(els) do
                local a = i / #els * math.pi * 2
                self:spawn(self.enemy, p.x + math.cos(a) * 110, p.y + math.sin(a) * 110, el.id)
            end
        end },
        { type = "button", label = "Every species at once", desc = "A pack of each (Amount, up to 10)", onActivate = function()
            local list = enemyOptions()
            local p = world.player
            local n = math.min(self.amount, 10)
            for i, o in ipairs(list) do
                local a = i / #list * math.pi * 2
                local cx, cy = p.x + math.cos(a) * 170, p.y + math.sin(a) * 170
                for _ = 1, n do
                    self:spawn(o.value, cx + love.math.random(-14, 14), cy + love.math.random(-14, 14), self:pickElite())
                end
            end
        end },
        { type = "header", label = "Queens (bosses)" },
        { type = "button", label = "Queen catalogue", onActivate = function() self:openSpawnCatalogue("queens") end },
        { type = "choice", label = "Queen", options = options(Content.enemies, isBoss), get = function() return self.queen end, set = function(v) self.queen = v end },
        { type = "button", label = "Spawn queen", onActivate = function()
            local p = world.player
            if self.queen then self:spawn(self.queen, p.x + 150, p.y) end
        end },
        { type = "header", label = "Field" },
        { type = "button", label = "Kill all", onActivate = function()
            for i = 1, world.enemyCount do world:killEnemy(world.enemies[i]) end
        end },
        { type = "button", label = "Clear (no KOs)", onActivate = function() world:clearEnemies() end },
        { type = "toggle", label = "Freeze AI", get = function() return world.flags.freezeAI end, set = function(v) world.flags.freezeAI = v end },
        { type = "button", label = "Alive", value = function() return tostring(world.enemyCount) end, onActivate = function() end },
    }
end

function Sandbox:itemsTab()
    local world = self.world
    return {
        { type = "header", label = "Items" },
        { type = "button", label = "Item catalogue", value = function() return "C" end, onActivate = function() self:openCatalogue() end },
        { type = "button", label = "Open bag", value = function() return "I" end, onActivate = function()
            State.push(require("src.states.inventory").new(self.game))
        end },
        { type = "choice", label = "Item", options = itemOptions(), get = function() return self.item end, set = function(v) self.item = v end },
        { type = "button", label = "Give item", value = function() return "have " .. world.player.inventory:count(self.item) end,
            onActivate = function() world:giveItem(self.item) end },
        { type = "button", label = "Take item", onActivate = function() world.player.inventory:remove(self.item, 1) end },
        { type = "button", label = "Give a random item", onActivate = function()
            local item = world:rollItem()
            world:giveItem(item.id)
            world:floatText(world.player.x, world.player.y, item.def.name, require("src.states.inventory").rarityColor(item.def), true)
        end },
        { type = "button", label = "One of every item", desc = "What doesn't fit lands on the floor: try a bigger bag", onActivate = function()
            for _, def in ipairs(Content.items:all()) do world:giveItem(def.id) end
        end },
        { type = "button", label = "Clear items", onActivate = function() world.player.inventory:clear() end },
        { type = "choice", label = "Bag size", options = (function()
            local out = {}
            for i, b in ipairs(BAGS) do out[i] = { value = i, label = b[1] .. " x " .. b[2] .. (i == 1 and " (normal)" or "") } end
            return out
        end)(), get = function() return self.bag end, set = function(v) self.bag = v; self:applyBag() end },
        { type = "header", label = "Item choice" },
        { type = "button", label = "Choose 1 of 3", onActivate = function() self:itemChoice(false) end },
        { type = "button", label = "Queen's prize (rare+)", onActivate = function() self:itemChoice(true) end },
        { type = "toggle", label = "Choice after waves", get = function() return self.waveChoice end, set = function(v) self.waveChoice = v end },
        { type = "toggle", label = "Proc log", get = function() return self.showProcs end, set = function(v) self.showProcs = v end },
    }
end

function Sandbox:playerTab()
    local world = self.world
    local items = {
        { type = "header", label = "Player" },
        { type = "button", label = "Character catalogue", onActivate = function() self:openSpawnCatalogue("characters") end },
        { type = "choice", label = "Character", options = options(Content.characters), get = function() return self.character end,
            set = function(v) self:setCharacter(v) end },
        { type = "toggle", label = "God mode", get = function() return world.flags.god end, set = function(v) world.flags.god = v end },
        { type = "button", label = "Heal", onActivate = function() world.player.hp = world.player.stats:get("maxHp") end },
        { type = "button", label = "+5 skill points", desc = "Grants XP up to 5 more levels (spend them in the inventory: Tab, then E)", onActivate = function()
            local sk = world.player.skills
            for _ = 1, 5 do world:grantXP(sk.toNext - sk.into) end
        end },
        { type = "button", label = "Level-up card pick", desc = "Opens a level-up card pick now (src/game/levelups.lua)", onActivate = function()
            require("src.game.levelups").grant(world, 1, { source = "sandbox", now = true })
        end },
        { type = "button", label = "Reset skill tree", desc = "Refunds every point spent", onActivate = function()
            local sk = world.player.skills
            sk.points, sk.spent, sk.ranks = sk.points + sk.spent, 0, {}
            sk:apply()
        end },
        { type = "button", label = "Take 10 damage", desc = "Ignores god mode and fires onHurt items (never kills)", onActivate = function()
            local p, god = world.player, world.flags.god
            world.flags.god, p.iframes = false, 0
            p:hurt(math.max(0.5, math.min(10, p.hp - 1)), "sandbox")
            world.flags.god = god
        end },
        { type = "button", label = "Fresh start", desc = "No items, base stats, full HP", onActivate = function()
            local p = world.player
            p.inventory:clear()
            p:setCharacter(p.def)
            self:applyBag()
            p.hp = p.stats:get("maxHp")
        end },
        { type = "header", label = "Stats (slide the base, shows the total)" },
    }
    for _, sd in ipairs(Stats.defs) do
        local r = STAT_RANGE[sd.id] or { -90, 500, 5 }
        items[#items + 1] = { type = "slider", label = sd.label, min = r[1], max = r[2], step = r[3],
            format = function() return Stats.format(sd.id, world.player.stats:get(sd.id)) end,
            get = function() return world.player.stats.base[sd.id] end,
            set = function(v)
                local p = world.player
                p.stats:setBase(sd.id, math.floor(v / r[3] + 0.5) * r[3])
                if sd.id == "maxHp" then p.hp = math.min(p.hp, p.stats:get("maxHp")) end
            end }
    end
    items[#items + 1] = { type = "button", label = "Reset stats", onActivate = function()
        local p = world.player
        local fresh = Stats.new(p.def.stats)
        for id, v in pairs(fresh.base) do p.stats:setBase(id, v) end
        p.hp = math.min(p.hp, p.stats:get("maxHp"))
    end }
    return items
end

function Sandbox:wavesTab()
    local sp = self.world.spawner
    return {
        { type = "header", label = "Waves" },
        { type = "button", label = "Now", value = function()
            if sp.wave == 0 then return "no wave yet" end
            local where = sp.phase == "wave" and (sp:remaining() .. " ants left") or "break"
            return ("wave %d%s, %s"):format(sp.wave, sp.bossWave and " (queen)" or "", where)
        end, onActivate = function() end },
        { type = "slider", label = "Wave", min = 1, max = 50, step = 1, get = function() return self.wave end, set = function(v) self.wave = v end },
        { type = "button", label = "Start this wave", onActivate = function() self:startWave(self.wave) end },
        { type = "button", label = "Next wave", onActivate = function() self:startWave(sp.wave + 1) end },
        { type = "button", label = "Stop waves", desc = "Ants already out stay", onActivate = function()
            sp.enabled, self.autoWaves = false, false
            sp.queue, sp.streams, sp.phase = {}, {}, "break"
        end },
        { type = "toggle", label = "Keep going after a wave", get = function() return self.autoWaves end, set = function(v)
            self.autoWaves = v
            if v then sp.enabled = true end
        end },
        { type = "toggle", label = "Item choice after waves", get = function() return self.waveChoice end, set = function(v) self.waveChoice = v end },
        { type = "button", label = "Species met", value = function() return #sp.knownList .. " / " .. #sp.introOrder end, onActivate = function() end },
    }
end

function Sandbox:worldTab()
    local world = self.world
    local function setting(key)
        return function() return Settings.get(key) end, function(v) Settings.set(key, v) end
    end
    local hbGet, hbSet = setting("showHitboxes")
    local grGet, grSet = setting("showSpatialGrid")
    local ovGet, ovSet = setting("showOverlay")
    return {
        { type = "header", label = "World" },
        { type = "choice", label = "Time of day", options = (function()
            for _, row in ipairs(require("src.config.settings_schema")) do
                if row.key == "timeOfDay" then return row.options end
            end
        end)(), get = function() return Settings.get("timeOfDay") end, set = function(v) Settings.set("timeOfDay", v) end },
        { type = "slider", label = "Time scale", min = 0.1, max = 3, step = 0.1,
            format = function(v) return ("%.1fx"):format(v) end,
            get = function() return world.timeScale end, set = function(v) world.timeScale = v end },
        { type = "button", label = "Clear splats", onActivate = function() world.ground:clearDecals() end },
        { type = "header", label = "Readouts" },
        { type = "toggle", label = "DPS meter", get = function() return self.showDps end, set = function(v) self.showDps = v end },
        { type = "button", label = "Reset meter", onActivate = function() self:resetMeter() end },
        { type = "toggle", label = "Proc log", get = function() return self.showProcs end, set = function(v) self.showProcs = v end },
        { type = "toggle", label = "Hitboxes", get = hbGet, set = hbSet },
        { type = "toggle", label = "Spatial grid", get = grGet, set = grSet },
        { type = "toggle", label = "Perf overlay", get = ovGet, set = ovSet },
    }
end

----------------------------------------------------------------------------------------------
-- Actions

-- Spawn one enemy with the chosen health multiplier.
function Sandbox:spawn(id, x, y, elite)
    local e = self.world:spawnEnemy(id, x, y, elite)
    if e and self.hpMul ~= 1 then
        e.maxHp = math.max(1, math.floor(e.maxHp * self.hpMul + 0.5))
        e.hp = e.maxHp
    end
    return e
end

-- The elite affix for the next sandbox spawn (nil = a normal ant).
function Sandbox:pickElite()
    if self.elite == "none" then return nil end
    if self.elite == "random" then
        local all = Content.elites:all()
        return all[love.math.random(#all)]
    end
    return self.elite
end

function Sandbox:setCharacter(id)
    self.character = id
    self.world.player:setCharacter(Content.characters:require(id))
    self:applyBag()
end

-- tab: "enemies" | "queens" | "characters"
function Sandbox:openSpawnCatalogue(tab)
    self.placing = nil
    State.push(require("src.states.spawncatalogue").new({ game = self.game, tab = tab }))
end

-- Every click / tap on the arena drops `id` there (Amount of them, one queen) until Done.
function Sandbox:startPlacing(id, boss)
    self.placing = { id = id, boss = boss }
    if boss then self.queen = id else self.enemy = id end
end

function Sandbox:placeAt(wx, wy)
    local pl = self.placing
    local n = pl.boss and 1 or self.amount
    local spread = 6 + math.sqrt(n) * 5
    for _ = 1, n do
        local a, r = love.math.random() * math.pi * 2, love.math.random() * spread
        self:spawn(pl.id, wx + math.cos(a) * r, wy + math.sin(a) * r, not pl.boss and self:pickElite() or nil)
    end
end

function Sandbox:openCatalogue()
    State.push(require("src.states.itemcatalogue").new({ game = self.game }))
end

function Sandbox:itemChoice(boss)
    local sp = self.world.spawner
    State.push(require("src.states.itemchoice").new(self.game, { count = 3 + self.world.bonusPicks, boss = boss, wave = math.max(1, sp.wave) }))
end

function Sandbox:startWave(n)
    local sp = self.world.spawner
    sp.enabled = true
    sp:startWave(math.max(1, n))
    self.wave = sp.wave
end

-- Resize the bag (also after a character swap, which rebuilds it at normal size). Growing
-- keeps everything where it is; shrinking repacks it and drops what no longer fits.
function Sandbox:applyBag()
    local p = self.world.player
    local inv, b = p.inventory, BAGS[self.bag]
    local fits = true
    for _, e in ipairs(inv.bag) do
        local w, h = Inventory.size(e.item)
        if e.x + w > b[1] or e.y + h > b[2] then fits = false end
    end
    inv.cols, inv.rows = b[1], b[2]
    if fits then
        inv:rebuildGrid()
        return
    end
    local items = {}
    for _, e in ipairs(inv.bag) do items[#items + 1] = e.item end
    inv.bag = {}
    inv:recount()
    for _, item in ipairs(items) do
        if not inv:stow(item) then self.world:overflowItem(item) end
    end
end

function Sandbox:resetMeter()
    self.meter = { hits = {}, total = 0, biggest = 0, kills = 0, taken = 0, since = self.world.time }
end

function Sandbox:logProc(def, trigger)
    local last = self.procs[#self.procs]
    local now = love.timer.getTime()
    if last and last.def == def and last.trigger == trigger and now - last.t < 1.5 then
        last.n, last.t = last.n + 1, now
        return
    end
    self.procs[#self.procs + 1] = { def = def, trigger = trigger, n = 1, t = now }
    if #self.procs > 8 then table.remove(self.procs, 1) end
end

----------------------------------------------------------------------------------------------
-- Frame

function Sandbox:panelRect()
    local x, y, w, h = self.menu:rect()
    return x - 4, y - Theme.u(64), w + 8, h + Theme.u(70)
end

function Sandbox:hovering()
    if not self.visible then return false end
    local mx, my = love.mouse.getPosition()
    local x, y, w, h = self:panelRect()
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

function Sandbox:update(dt)
    local world, sp = self.world, self.world.spawner
    world.player.inventory.onProc = self.procHook
    -- one wave at a time unless told to keep going
    if not self.autoWaves and sp.enabled and sp.phase == "break" then sp.enabled = false end
    if not self.waveChoice then world.pendingChoice = nil end
    -- the DPS meter only keeps the last few seconds of hits
    local hits, cut = self.meter.hits, world.time - DPS_WINDOW
    local drop = 0
    while hits[drop + 1] and hits[drop + 1].t < cut do drop = drop + 1 end
    if drop > 0 then
        local n = #hits
        for i = 1, n - drop do hits[i] = hits[i + drop] end
        for i = n - drop + 1, n do hits[i] = nil end
    end
    if self.visible then self.menu:update(dt) end
end

local function short(n)
    if n >= 10000 then return ("%.1fk"):format(n / 1000) end
    return tostring(math.floor(n + 0.5))
end

-- Bottom left: the DPS meter, and recent item procs above it.
function Sandbox:drawReadouts()
    local lg = love.graphics
    local u = Theme.u
    local x, y = u(14), lg.getHeight() - u(40)
    lg.setFont(Theme.font(14))
    local lh = lg.getFont():getHeight() + u(2)
    if self.showDps then
        local m = self.meter
        local sum = 0
        for _, hit in ipairs(m.hits) do sum = sum + hit.d end
        local span = math.min(DPS_WINDOW, math.max(0.5, self.world.time - m.since))
        local rows = {
            { "DPS", short(sum / span) },
            { "Damage", short(m.total) },
            { "Biggest hit", short(m.biggest) .. (m.biggestCrit and " crit" or "") },
            { "Kills / taken", m.kills .. " / " .. short(m.taken) },
        }
        local bw, bh = u(200), #rows * lh + u(12)
        y = y - bh
        lg.setColor(0.05, 0.04, 0.05, 0.7)
        lg.rectangle("fill", x, y, bw, bh, 4, 4)
        for i, r in ipairs(rows) do
            local ry = y + u(6) + (i - 1) * lh
            lg.setColor(Theme.colors.dim)
            lg.print(r[1], x + u(8), ry)
            lg.setColor(i == 1 and Theme.colors.focus or Theme.colors.text)
            lg.printf(r[2], x, ry, bw - u(8), "right")
        end
        y = y - u(6)
    end
    if self.showProcs and #self.procs > 0 then
        local now = love.timer.getTime()
        local rarityColor = require("src.states.inventory").rarityColor
        for i = #self.procs, 1, -1 do
            local pr = self.procs[i]
            local a = math.max(0, math.min(1, 1 - (now - pr.t - 4) / 2))
            if a > 0 then
                y = y - lh
                local c = rarityColor(pr.def)
                local txt = pr.def.name .. "  " .. pr.trigger:gsub("^on", ""):lower() .. (pr.n > 1 and ("  x" .. pr.n) or "")
                Theme.printShadow(txt, x + u(4), y, { c[1], c[2], c[3], a })
            end
        end
    end
end

-- Top centre while placing: what drops where you click, and a Done button.
function Sandbox:drawPlacing()
    local lg = love.graphics
    local u = Theme.u
    local def = Content.enemies:get(self.placing.id)
    local text = ("Click to place %s%s"):format(self.placing.boss and "" or (self.amount .. " x "), def and def.name or self.placing.id)
    lg.setFont(Theme.font(16, "bold"))
    local f = lg.getFont()
    local done = "Done"
    local dw = f:getWidth(done) + u(28)
    local w = f:getWidth(text) + u(28) + dw + u(8)
    local h = f:getHeight() + u(14)
    local x, y = math.floor((lg.getWidth() - w) / 2), u(12)
    lg.setColor(0.05, 0.04, 0.05, 0.85)
    lg.rectangle("fill", x, y, w - dw - u(8), h)
    lg.setColor(Theme.colors.text)
    lg.print(text, x + u(14), y + u(7))
    local r = { x = x + w - dw, y = y, w = dw, h = h }
    lg.setColor(0.2, 0.15, 0.12, 0.95)
    lg.rectangle("fill", r.x, r.y, r.w, r.h)
    lg.setColor(Theme.colors.focus)
    lg.rectangle("fill", r.x, r.y + r.h - 2, r.w, 2)
    lg.printf(done, r.x, r.y + u(7), r.w, "center")
    self.doneRect = r
end

function Sandbox:draw()
    local lg = love.graphics
    local u = Theme.u
    self:drawReadouts()
    if self.placing then self:drawPlacing() end
    lg.setFont(Theme.font(14))
    local hint = self.visible and "Middle click: spawn at cursor  |  V: enemies  |  C: items  |  1-5: tabs  |  F2: hide panel  |  F1: hotkeys"
        or "F2: show sandbox panel  |  V: enemies  |  C: items"
    Theme.printShadow(hint, u(14), lg.getHeight() - u(26), Theme.colors.text)
    if not self.visible then return end
    local px, py, pw, ph = self:panelRect()
    Theme.panel(px, py, pw, ph)
    lg.setFont(Theme.font(16))
    lg.setColor(Theme.colors.focus)
    lg.print("SANDBOX", px + u(14), py + u(6))
    -- tab strip
    lg.setFont(Theme.font(14))
    local f = lg.getFont()
    local mx, my = love.mouse.getPosition()
    local tw = (pw - u(16)) / #TABS
    self.tabRects = {}
    for i, name in ipairs(TABS) do
        local r = { x = px + u(8) + (i - 1) * tw, y = py + u(30), w = tw - u(3), h = f:getHeight() + u(8) }
        local on = i == self.tab
        local hover = mx >= r.x and mx < r.x + r.w and my >= r.y and my < r.y + r.h
        lg.setColor(on and Theme.colors.focusBg or (hover and { 1, 1, 1, 0.06 } or { 1, 1, 1, 0.025 }))
        lg.rectangle("fill", r.x, r.y, r.w, r.h, 3, 3)
        if on then
            lg.setColor(Theme.colors.focus)
            lg.rectangle("fill", r.x, r.y + r.h - 2, r.w, 2)
        end
        lg.setColor(on and Theme.colors.focus or Theme.colors.dim)
        lg.printf(name, r.x, r.y + u(4), r.w, "center")
        self.tabRects[i] = r
    end
    self.menu:draw()
    -- help text for the row under the mouse
    local it = self.menu:itemAt(mx, my) and self.menu:focused()
    if it and it.desc then
        lg.setFont(Theme.font(13))
        lg.setColor(Theme.colors.dim)
        lg.printf(it.desc, px, py + ph + u(4), pw, "center")
    end
end

function Sandbox:mousepressed(x, y, b)
    if self.placing then
        local r = self.doneRect
        if b == 2 or (r and x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h) then
            self.placing = nil
            return
        end
    end
    if self.visible then
        for i, r in ipairs(self.tabRects or {}) do
            if x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h then
                self:setTab(i)
                return
            end
        end
        if self.menu:mousepressed(x, y, b) then return end
    end
    if self.placing and b == 1 and not self:hovering() then
        self:placeAt(self.world:mouseWorld())
        return
    end
    if b == 3 and not self:hovering() then
        local wx, wy = self.world:mouseWorld()
        local n = self.amount
        local spread = 6 + math.sqrt(n) * 5
        for _ = 1, n do
            local a, r = love.math.random() * math.pi * 2, love.math.random() * spread
            self:spawn(self.enemy, wx + math.cos(a) * r, wy + math.sin(a) * r, self:pickElite())
        end
    end
end

function Sandbox:mousemoved(x, y)
    if self.visible then self.menu:mousemoved(x, y) end
end

function Sandbox:wheelmoved(x, y)
    if self:hovering() then self.menu:wheelmoved(x, y) end
end

function Sandbox:keypressed(key)
    if key == "f2" then
        self.visible = not self.visible
        self.game:applyCursor()
    elseif key == "c" then
        self:openCatalogue()
    elseif key == "v" then
        self:openSpawnCatalogue("enemies")
    elseif self.visible and TABS[tonumber(key) or 0] then
        self:setTab(tonumber(key))
    end
end

return Sandbox
