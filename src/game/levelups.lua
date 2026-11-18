-- Level-up cards. Every level (XP from World:grantXP -> Skills:gainXP) opens a pick of 3 cards
-- right away, mid-wave (setting "levelUpWhen" = "wave" saves them for the wave's reward bloom):
-- global stat cards (content/levelcards) that roll a rarity (common x1 .. legendary x2, Luck tilts
-- the odds). The skill tree is never on the cards: SKIPPING a pick banks one skill point to spend
-- in the bag's SKILLS tab, so each level is a boost now or a step down the tree.
-- Setting "levelUps" = "points" brings back the old way: levels give skill points to spend.
-- Numbers: src/config/levelups.lua (a mode can override them with `levelUps = {...}`).
--
-- Other systems can hand out picks too (brood cell chests, shrines...):
--     require("src.game.levelups").grant(world, n, { source = "chest", minRarity = "rare", now = true })
-- queues n picks. source: shown on the cards screen; minRarity: floor for every stat card's
-- rarity; now: show at the next free moment, even mid-wave (default: like level-ups, per setting).
local Settings = require("src.core.settings")
local Audio = require("src.core.audio")

local LevelUps = {}
LevelUps.__index = LevelUps

local EMPTY = {}

-- The config for a world: src/config/levelups.lua with the mode's `levelUps` overrides on top.
function LevelUps.config(modeDef)
    local base = require("src.config.levelups")
    local over = modeDef and modeDef.levelUps
    if not over then return base end
    local out = {}
    for k, v in pairs(base) do out[k] = v end
    for k, v in pairs(over) do out[k] = v end
    return out
end

-- XP to go from level L-1 to L (used by Skills.xpFor).
function LevelUps.xpFor(level, cfg)
    local x = (cfg or require("src.config.levelups")).xp
    return math.floor(x.base + x.scale * math.max(0, level - 1) ^ x.pow)
end

function LevelUps.new(world)
    local self = setmetatable({ world = world, cfg = LevelUps.config(world.modeDef), queue = {}, mods = {},
        picks = 0, fanfareAt = -1 }, LevelUps)
    return self
end

-- Do levels give cards in this world? (Real runs only, unless something grants picks.)
function LevelUps:enabled()
    local w = self.world
    return not self.disabled and w.mode == "run" and not w.flags.demo and Settings.get("levelUps") ~= "points"
end

function LevelUps:pending() return #self.queue end

----------------------------------------------------------------------------------------------
-- Queueing picks

-- A level was reached (Skills:gainXP, not silent).
function LevelUps:onLevel(level)
    local w = self.world
    local instant = Settings.get("levelUpWhen") == "instant"
    self.queue[#self.queue + 1] = { source = "level", level = level, now = instant or nil,
        at = instant and (w.time + self.cfg.instantDelay) or nil }
    w.events:emit("levelup_queued", level)
end

-- Queue n picks from anything else (chests, shrines...). Returns how many were queued.
-- Works both ways: LevelUps.grant(world, n, opts) and world.levelups:grant(n, opts).
function LevelUps.grant(world, n, opts)
    if getmetatable(world) == LevelUps then return LevelUps.grantSelf(world, n, opts) end
    if not world or not world.levelups then return 0 end
    return LevelUps.grantSelf(world.levelups, n, opts)
end
function LevelUps.grantSelf(self, n, opts)
    opts = opts or EMPTY
    n = math.max(0, math.floor(n or 1))
    local sk = self.world.player and self.world.player.skills
    for _ = 1, n do
        self.queue[#self.queue + 1] = { source = opts.source or "bonus", minRarity = opts.minRarity, now = opts.now or (Settings.get("levelUpWhen") ~= "wave") or nil,
            level = sk and sk.level or 0 }
    end
    if n > 0 then self.world.events:emit("levelup_queued", nil, opts.source) end
    return n
end

-- The next pick to show now, or nil. choiceReady: the wave's item choice is due this frame.
-- Level-ups wait for the end of the wave (or a break between waves); `now` picks don't.
function LevelUps:nextToShow(choiceReady)
    local e = self.queue[1]
    if not e then return nil end
    local w = self.world
    if e.at and w.time < e.at then return nil end
    if e.now or choiceReady then return e end
    local sp = w.spawner
    if w.pendingChoice then return nil end            -- the item choice is a beat away: wait for it
    if not sp or not sp.enabled or sp.phase ~= "wave" then return e end
    return nil
end

-- Drop the first queued pick (it was taken).
function LevelUps:pop(e)
    for i, q in ipairs(self.queue) do
        if q == e then table.remove(self.queue, i) return end
    end
    table.remove(self.queue, 1)
end

----------------------------------------------------------------------------------------------
-- Fanfare: chime, half a second of slow motion and a ring of light

function LevelUps:fanfare(p, text)
    local w = self.world
    if w.flags.demo then return end
    if w.time - self.fanfareAt < 0.25 then return end     -- several levels at once: one fanfare
    self.fanfareAt = w.time
    local f = self.cfg.fanfare
    Audio.play("level_up")
    if w.rewards then w.rewards:slowmo(f.slow, f.slowTime) end
    w:addFx({ kind = "ring", x = p.x, y = p.y, r = f.ring, life = 0.55, color = f.color })
    w:addFx({ kind = "ring", x = p.x, y = p.y, r = f.ring * 0.55, life = 0.4, color = { 1, 1, 1 } })
    w:floatText(p.x, p.y - 10, text or "LEVEL UP!", f.color, true)
    w.events:emit("level_up", p.skills and p.skills.level)
end

----------------------------------------------------------------------------------------------
-- Dealing cards

-- Roll a rarity for a stat card (Luck tilts it; minRarity is a floor).
function LevelUps:rollRarity(minRarity)
    local p = self.world.player
    local luck = math.max(-50, p and p.stats:get("luck") or 0)
    local list = self.cfg.rarities
    local floor = 1
    if minRarity then
        for i, r in ipairs(list) do if r.id == minRarity then floor = i end end
    end
    local total, ws = 0, {}
    for i, r in ipairs(list) do
        local wgt = i >= floor and r.weight * (1 + luck / 100) ^ (i - 1) or 0
        ws[i] = wgt
        total = total + wgt
    end
    local x = love.math.random() * total
    for i, r in ipairs(list) do
        x = x - ws[i]
        if x <= 0 then return r end
    end
    return list[#list]
end

-- Round a rolled number so cards read well (+8%, +1.3 armor, +0.4 HP/s).
local function tidy(v)
    if math.abs(v) >= 5 then return math.floor(v + 0.5) end
    return math.floor(v * 10 + 0.5) / 10
end
local function tidyMult(v) return math.floor(v * 100 + 0.5) / 100 end

-- "+12% Speed, +1 Armor" for a stat card without its own text.
function LevelUps.describe(c)
    local Stats = require("src.game.stats")
    local parts = {}
    for _, d in ipairs(Stats.defs) do
        local a, m = c.stats[d.id], c.statsMult[d.id]
        if a then parts[#parts + 1] = (a >= 0 and "+" or "") .. Stats.format(d.id, a) .. " " .. d.label end
        if m then parts[#parts + 1] = (m >= 0 and "+" or "") .. math.floor(m * 100 + 0.5) .. "% " .. d.label end
    end
    return table.concat(parts, ", ")
end

-- A stat card with its numbers scaled by its rarity.
function LevelUps:statCard(def, rarity)
    local c = { kind = "stat", def = def, id = def.id, name = def.name, rarity = rarity.id, mult = rarity.mult,
        stats = {}, statsMult = {} }
    for k, v in pairs(def.stats or EMPTY) do c.stats[k] = tidy(v * rarity.mult) end
    for k, v in pairs(def.statsMult or EMPTY) do c.statsMult[k] = tidyMult(v * rarity.mult) end
    c.description = def.scaledText and def.scaledText(rarity.mult) or def.description or LevelUps.describe(c)
    return c
end

-- Deal the cards for one pick: { card, ... } (stat cards only; skipping is the skill point).
function LevelUps:deal(entry, count)
    entry = entry or EMPTY
    local Content = require("src.content")
    local p = self.world.player
    local level = entry.level or (p.skills and p.skills.level) or 1
    count = count or self.cfg.cards
    local cards, usedIds = {}, {}
    local function pickStat()
        local total, opts = 0, {}
        for _, d in ipairs(Content.levelcards:all()) do
            if not usedIds[d.id] and (d.minLevel or 1) <= level and (not d.available or d.available(p, self.world)) then
                opts[#opts + 1] = d
                total = total + d.weight
            end
        end
        if #opts == 0 then return nil end
        local x = love.math.random() * total
        for _, d in ipairs(opts) do
            x = x - d.weight
            if x <= 0 then return d end
        end
        return opts[#opts]
    end
    for _ = 1, count do
        local d = pickStat()
        if not d then break end
        local card = self:statCard(d, self:rollRarity(entry.minRarity))
        usedIds[card.id] = true
        cards[#cards + 1] = card
    end
    return cards
end

-- The card a skip takes: one skill point (LevelUp screen's skip button, the balance bot).
function LevelUps.skipCard() return { kind = "point", id = "skill_point", name = "Skill point" } end

----------------------------------------------------------------------------------------------
-- Taking a card

-- Rebuild the "levelup" stat modifiers from every stat card taken this run.
function LevelUps:applyStats()
    local p = self.world.player
    if not p then return end
    p.stats:removeSource("levelup")
    local ids = {}
    for id in pairs(self.mods) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local m = self.mods[id]
        p.stats:addModifier("levelup", id, m.add or 0, m.mult or 0)
    end
    if p.hp then p.hp = math.min(p.hp, p.stats:get("maxHp")) end
end

function LevelUps:take(card)
    local p = self.world.player
    self.picks = self.picks + 1
    if card.kind == "point" then
        p.skills.points = p.skills.points + 1
        p.skills.skipped = (p.skills.skipped or 0) + 1
    else
        local hpBefore = p.stats:get("maxHp")
        for k, v in pairs(card.stats) do
            self.mods[k] = self.mods[k] or {}
            self.mods[k].add = (self.mods[k].add or 0) + v
        end
        for k, v in pairs(card.statsMult) do
            self.mods[k] = self.mods[k] or {}
            self.mods[k].mult = (self.mods[k].mult or 0) + v
        end
        self:applyStats()
        -- more Max HP comes filled in
        local gain = p.stats:get("maxHp") - hpBefore
        if gain > 0 then p.hp = p.hp + gain end
        if card.def and card.def.apply then card.def.apply(p, card.mult or 1, self.world) end
    end
    self.world.events:emit("levelup_taken", card)
end

-- Take a random card for each queued pick (the balance bot, tests); skipChance: how often it
-- skips for a skill point instead (default cfg.botSkip).
function LevelUps:autoPickAll(skipChance)
    local n = 0
    skipChance = skipChance or self.cfg.botSkip or 0
    while #self.queue > 0 and n < 200 do
        local e = self.queue[1]
        local cards = self:deal(e)
        table.remove(self.queue, 1)
        if #cards == 0 or love.math.random() < skipChance then self:take(LevelUps.skipCard())
        else self:take(cards[love.math.random(#cards)]) end
        n = n + 1
    end
    return n
end

----------------------------------------------------------------------------------------------
-- Saves (src/game/runsave.lua)

function LevelUps:snapshot()
    local q = {}
    for i, e in ipairs(self.queue) do q[i] = { source = e.source, level = e.level, minRarity = e.minRarity, now = e.now } end
    local mods = {}
    for k, m in pairs(self.mods) do mods[k] = { add = m.add, mult = m.mult } end
    return { queue = q, mods = mods, picks = self.picks }
end

function LevelUps:restore(snap)
    if not snap then return end
    self.queue, self.mods, self.picks = {}, {}, snap.picks or 0
    for i, e in ipairs(snap.queue or EMPTY) do self.queue[i] = { source = e.source, level = e.level, minRarity = e.minRarity, now = e.now } end
    local Stats = require("src.game.stats")
    for k, m in pairs(snap.mods or EMPTY) do
        if Stats.byId[k] then self.mods[k] = { add = m.add, mult = m.mult } end
    end
    self:applyStats()
end

return LevelUps
