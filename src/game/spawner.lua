-- Wave director. Waves teach the colony one species at a time: wave 1 is plain workers, and each
-- wave after that brings in exactly one new species, which arrives first and alone (with a
-- banner saying what it does) before the rest of the wave mixes it with everything seen so far.
-- Every fifth wave a queen comes instead of a new species. The run is finalWave (15) waves long:
-- the last one is the final boss wave, where crowned queens come one after another, and clearing
-- it wins the run (the player may keep going; every finalWave waves after that is another). Ants pour in from several points
-- around the arena at once (more as the waves go on), and small packs keep slipping in from
-- other sides while the wave runs, so it always feels like being surrounded. Some groups take
-- other ways in: burrowing up, dropping from the sky, nest holes, burrow rings (src/game/entries.lua).
-- Clear the wave (every ant dead), pick an item, then a short breather (Settings "waveBreak":
-- a countdown, none, or wait for the Next Wave key). Next Wave also sends a wave's remaining
-- groups in at once, and the last few ants left in a wave hurry towards the player.
-- Introduction order: enemies' spawn.minWave, then the most common first (spawn.weight).
-- Stage config (stage.spawn): see content/stages/_template.lua.
-- Scripted waves: a mode with a `waves` list (Custom Waves, src/game/customwaves.lua, or a mode
-- file like content/modes/gauntlet.lua) skips all of that and sends exactly what each wave names
-- (Spawner:startScripted); after the last one the script starts over, tougher.
local Content = require("src.content")
local Elites = require("src.game.elites")
local Settings = require("src.core.settings")
local Entries = require("src.game.entries")
local Pacing = require("src.game.pacing")

local Spawner = {}
Spawner.__index = Spawner

local DEFAULTS = { groups = 3, groupsPerWave = 1, group = { 14, 22 }, groupGap = 2.2, breakTime = 3,
    firstBreak = 1.5, maxAlive = 900, growth = 0.15, bossEvery = 5,
    introEvery = 1,             -- waves between new species (1 = a new one every wave)
    entries = { 2, 6 },         -- entry points per wave: first wave, most
    trickle = 5,                -- seconds between stray packs slipping in from other sides (shrinks with waves)
    rushAt = 6, rushSpeed = 1.5,    -- the last rushAt ants of a wave move rushSpeed x faster
    waveHeal = 0.2, bossHeal = 1,   -- share of max HP healed on clearing a wave / a queen's wave
    finalWave = 15,             -- waves in a run; a mode's finalWave overrides it (false = never ends)
    -- the final boss wave: `queens` crowned queens, one after another, each with hpMul x health
    -- (+chapterHp per extra 15 waves survived, and one more queen per chapter), regular groups x groups
    finalBoss = { queens = 2, hpMul = 1.6, scale = 1.25, chapterHp = 0.6, groups = 0.6, gap = 3 },
    -- other ways in (burrows, flyers dropping, nest holes, burrow rings): per-way overrides of
    -- src/game/entries.lua DEFAULTS, e.g. { nest = { chance = 1 }, ring = false }; false = edge only
    entryStyles = nil,
    -- pacing (src/game/pacing.lua); set any of these to false in a stage / mode to switch it off
    earlyBoost = { size = { 2.2, 1.8, 1.4 }, hp = { 0.45, 0.6, 0.8 } },  -- waves 1-3: more, frailer ants
    orderJitter = { scale = 0.6, spread = 5 },      -- species order: minWave x scale + random spread
    modifiers = { from = 3, chance = 0.55, doubleFrom = 9, double = 0.3 },
    overlap = { share = 0.15, min = 3, minTime = 6 },   -- next wave comes when this share is left
    call = { at = 5, far = 170, time = 0.9, near = { 70, 110 } },   -- last `at` ants burrow up near you
    par = { base = 14, perAnt = 0.02, crowdMax = 30, boss = 25, xp = 5, xpPerWave = 1.5 },   -- last group's arrival + base + crowd
    heat = { ramp = 40, speed = 0.35, damage = 0.25 },  -- past par: up to +35% speed, +25% damage
    live = { calm = 5, hp = 0.8, build = 25, ease = 3, speed = 0.12, size = 0.4, trickle = 1, keep = 0.7 },
    early = { perKill = 0.08, max = 6 },            -- early-call XP: kills x perKill x streak
    royalGuard = { count = 6, perChapter = 2, radius = 16, shield = 0.3, elite = "armored" } }

function Spawner.new(world, stage)
    local cfg = {}
    for k, v in pairs(DEFAULTS) do cfg[k] = v end
    for k, v in pairs(stage.spawn or {}) do cfg[k] = v end
    -- the game mode (content/modes) reshapes the waves on top of the stage
    local mode = world.modeDef or {}
    for k, v in pairs(mode.spawn or {}) do cfg[k] = v end
    local self = setmetatable({ world = world, cfg = cfg, wave = 0, phase = "break", timer = cfg.firstBreak,
        enabled = true, streams = {}, queue = {}, waveTime = 0, usedQueens = {}, known = {}, knownList = {},
        trickleT = 0, mode = mode, endless = mode.endless, portals = {}, holes = {},
        script = not mode.endless and type(mode.waves) == "table" and #mode.waves > 0 and mode.waves or nil }, Spawner)
    Pacing.init(self)
    -- every species that spawns on its own (and that the mode lets in), in the order the player meets them
    local order = {}
    for _, d in ipairs(Content.enemies:all()) do
        if not d.boss and (d.spawn.weight or 0) > 0 and self:allows(d) then order[#order + 1] = d end
    end
    table.sort(order, function(x, y)
        if x.spawn.minWave ~= y.spawn.minWave then return x.spawn.minWave < y.spawn.minWave end
        if x.spawn.weight ~= y.spawn.weight then return x.spawn.weight > y.spawn.weight end
        return x.id < y.id
    end)
    self.introOrder = Pacing.shuffleOrder(self, order)
    -- a stage can name the species that opens its first wave (content/stages `fauna.first`)
    local first = self.world.stage and self.world.stage.fauna and self.world.stage.fauna.first
    if first then
        for i, d in ipairs(self.introOrder) do
            if d.id == first then table.insert(self.introOrder, 1, table.remove(self.introOrder, i)) break end
        end
    end
    return self
end

-- Whether the game mode lets this species take part (its families / enemies / exclude lists).
-- The stage's own wildlife (content/stages `fauna`): how much more often a species turns up
-- here (1 = normal, 0 = never; keys are enemy ids or family ids, the id wins).
function Spawner:faunaMul(d)
    local f = self.world.stage and self.world.stage.fauna
    if not d then return 1 end
    -- water creatures (spawn.habitat = "water": shrimp, krill, plankton) only live on maps
    -- whose fauna names them or their family
    if d.spawn.habitat == "water" and not (f and (f[d.id] or f[d.family])) then return 0 end
    if not f then return 1 end
    local m = f[d.id]
    if m == nil then m = f[d.family] end
    if m == nil then m = f.other end
    return m or 1
end

function Spawner:allows(d)
    local m, util = self.mode, require("src.core.util")
    if m.exclude and util.contains(m.exclude, d.id) then return false end
    -- a stage can leave a species out entirely, unless the mode names it
    if self:faunaMul(d) <= 0 and not (m.enemies and util.contains(m.enemies, d.id)) then return false end
    if not m.families and not m.enemies then return true end
    return (m.families ~= nil and util.contains(m.families, d.family)) or (m.enemies ~= nil and util.contains(m.enemies, d.id))
end

-- The scripted wave n (nil when the mode has no script). Past the end it loops round.
function Spawner:scriptWave(n)
    local s = self.script
    if not s or not n or n < 1 then return nil end
    return s[(n - 1) % #s + 1]
end

-- Ants still to come this wave (queued groups + streams still pouring out) plus those alive.
function Spawner:remaining()
    local n = self.world.enemyCount
    for _, g in ipairs(self.queue) do n = n + g.count end
    for _, st in ipairs(self.streams) do n = n + st.left end
    return n + Entries.pending(self)
end

function Spawner:learn(def)
    if self.known[def.id] then return end
    self.known[def.id] = true
    self.knownList[#self.knownList + 1] = def
end

-- The next species nobody has met yet (none while practice holds the waves to one species).
function Spawner:nextSpecies()
    if self.only then return nil end
    for _, d in ipairs(self.introOrder) do
        if not self.known[d.id] then return d end
    end
end

function Spawner:groupSize(def, mul)
    local g, cfg = self.cfg.group, self.cfg
    local route = self.world.route         -- a route gate taken into this wave (src/game/routes.lua)
    local early = Pacing.early(self)
    return math.max(1, math.floor(love.math.random(g[1], g[2]) * (def.spawn.groupSize or 1) * (1 + (self.wave - 1) * cfg.growth)
        * (mul or 1) * early * (self.mod.groupSize or 1) * (route and route.groupMul or 1)
        * (self.world.danger and self.world.danger.groupMul or 1)))
end

-- The modifiers (content/wavemods) of wave n, rolled ahead from the run's seed.
function Spawner:modifiersFor(n) return Pacing.modifiersFor(self, n) end

-- Jumping ahead (dev "wave" command, the menu demo): meet everything earlier waves would have
-- introduced.
function Spawner:catchUp(n)
    local cfg = self.cfg
    for w = 1, n - 1 do
        if #self.knownList == 0 or not (cfg.bossEvery > 0 and w % cfg.bossEvery == 0) and (w - 1) % cfg.introEvery == 0 then
            local d = self:nextSpecies()
            if d then self:learn(d) end
        end
    end
end

-- The run's last wave (nil = it never ends). Mode first, then the stage's spawn config.
function Spawner:finalWave()
    local m = self.world.modeDef
    if m and m.finalWave ~= nil then return m.finalWave or nil end
    return self.cfg.finalWave or nil
end

-- Is wave n a final boss wave (15, and every 15 after for players who keep going)?
function Spawner:isFinal(n)
    local fw = self:finalWave()
    return fw ~= nil and fw > 0 and (n or self.wave) % fw == 0
end

-- Queue the next crowned queen of a final wave, `delay` s from now.
function Spawner:queueCrowned(delay)
    local queen = self:pickQueen()
    if not queen then self.crownLeft = 0 return false end
    local fb = self.cfg.finalBoss
    local chapter = math.floor(self.wave / math.max(1, self:finalWave() or 15))
    local e = self:spreadPoints(1)[1]
    self.crownLeft = self.crownLeft - 1
    self.crownE = nil
    self.queue[#self.queue + 1] = { def = queen, count = 1, x = e[1], y = e[2], at = self.waveTime + delay,
        crown = { hpMul = fb.hpMul + (chapter - 1) * fb.chapterHp, scale = fb.scale } }
    return true
end

function Spawner:startWave(n)
    local cfg, world = self.cfg, self.world
    -- the run moves to its next act's map first (src/game/acts.lua; Game sets holdWave)
    if not n and self.holdWave and self.holdWave(self.wave + 1) then return end
    if n and n > self.wave + 1 then self:catchUp(n) end
    self.wave = n or self.wave + 1
    self.finalThisWave, self.crownLeft, self.crownE = false, 0, nil
    self.phase, self.waveTime, self.trickleT = "wave", 0, 3
    self.queue = {}
    self.newSpecies = nil
    Pacing.startWave(self)
    -- Entry points spread around the arena, more each wave.
    local nEntries = math.min(cfg.entries[2], cfg.entries[1] + math.floor((self.wave - 1) / 2))
    local entries = self:spreadPoints(nEntries)
    self.entries = entries
    Entries.openNests(self)     -- some waves also open nest holes in the floor
    self.waveSpecies = nil
    local sw = self:scriptWave(self.wave)
    if sw then return self:startScripted(sw) end
    local groups = cfg.groups + math.floor((self.wave - 1) * cfg.groupsPerWave)
    local gap = math.max(1, cfg.groupGap * 0.95 ^ (self.wave - 1))
    local start = 0
    -- Boss wave: a queen arrives and the wave lasts until she falls (fewer regular groups).
    self.bossWave = cfg.bossEvery > 0 and self.wave % cfg.bossEvery == 0
    -- Final boss wave: crowned queens one after another (the next comes when the last falls).
    if self:isFinal() then
        local fb = cfg.finalBoss
        self.finalThisWave = true
        self.crownLeft = fb.queens + math.floor(self.wave / self:finalWave()) - 1 + (world.danger and world.danger.extraQueens or 0)
        if self:queueCrowned(2) then
            self.bossWave = true
            groups = math.ceil(groups * fb.groups)
        else
            self.bossWave = false     -- no queen fits this mode: still the final wave, just no boss
        end
    elseif self.bossWave then
        local queen = self:pickQueen()
        if queen then
            local e = entries[1]
            self.queue[#self.queue + 1] = { def = queen, count = 1, x = e[1], y = e[2], at = 2 }
            -- the Twin Queens artifact (content/artifacts): a second queen from another side
            for i = 1, (world.danger and world.danger.twinQueens or 0) do
                local q2, e2 = self:pickQueen() or queen, entries[1 + (i % #entries)] or e
                self.queue[#self.queue + 1] = { def = q2, count = 1, x = e2[1], y = e2[2], at = 6 }
            end
            groups = math.ceil(groups * 0.5)
        else
            self.bossWave = false
        end
    end
    -- A new species: it comes first, on its own, so you can see what it does.
    local intro = #self.knownList == 0 or ((not self.bossWave or self.mode.introOnBoss) and (self.wave - 1) % cfg.introEvery == 0)
    local fresh = intro and self:nextSpecies()
    if fresh then
        self:learn(fresh)
        self.newSpecies = fresh
        if #self.knownList > 1 then
            local e = entries[love.math.random(#entries)]
            self.queue[#self.queue + 1] = { def = fresh, count = self:groupSize(fresh, 0.7), x = e[1], y = e[2], at = 1 }
            start = 4     -- give it the stage for a few seconds
        end
        world.events:emit("species_introduced", fresh)
        -- modes that bring in more than one species a wave (Blitz): the others just join the mix
        for _ = 2, self.mode.introCount or 1 do
            local more = self:nextSpecies()
            if not more then break end
            self:learn(more)
        end
    end
    -- The rest: species already met, from every entry in turn; later waves send pairs of
    -- groups at once from opposite sides.
    for i = 1, groups do
        local def = self:pickEnemy()
        if def then
            local at = start + (i - 1) * gap
            local e = entries[(i - 1) % #entries + 1]
            local hole = Entries.holeFor(self)
            local g = { def = def, count = self:groupSize(def), x = e[1], y = e[2], at = at, hole = hole }
            if hole then g.x, g.y = hole.x, hole.y end
            self.queue[#self.queue + 1] = g
            if self.wave >= 4 and i % 3 == 0 then
                local o = entries[(i - 1 + math.floor(#entries / 2)) % #entries + 1]
                local d2 = self:pickEnemy()
                self.queue[#self.queue + 1] = { def = d2, count = self:groupSize(d2, 0.6), x = o[1], y = o[2], at = at }
            end
        end
    end
    Pacing.shapeGroups(self)
    world.events:emit("wave_started", self.wave)
    world.player.inventory:trigger("onWaveStart", { world = world, player = world.player, wave = self.wave, procDepth = 0 })
end

-- A scripted wave: exactly the groups it names, split into columns from every entry in turn,
-- its queen (if any) two seconds in. A species met for the first time gets its banner.
function Spawner:startScripted(sw)
    local cfg, world = self.cfg, self.world
    local entries = self.entries
    self.finalThisWave = self:isFinal()
    self.bossWave = false
    if sw.queen then
        local q = Content.enemies:get(sw.queen)
        if q then
            local e = entries[1]
            self.queue[#self.queue + 1] = { def = q, count = 1, x = e[1], y = e[2], at = 2 }
            self.bossWave = true
            self.usedQueens[q.id] = true
        end
    end
    local pack = math.max(6, cfg.group[2] or 22)
    local gap = math.max(0.8, cfg.groupGap * 0.95 ^ math.min(20, self.wave - 1)) * 0.75
    local t, k, species = 0.5, 0, {}
    for _, g in ipairs(sw.groups or {}) do
        local def = Content.enemies:get(g[1] or g.enemy)
        local total = math.floor(tonumber(g[2] or g.count) or 0)
        if def and total > 0 then
            species[#species + 1] = def
            if not self.known[def.id] then
                self:learn(def)
                if not self.newSpecies then
                    self.newSpecies = def
                    world.events:emit("species_introduced", def)
                end
            end
            local packs = math.ceil(total / pack)
            for i = 1, packs do
                local n = math.min(pack, total - (i - 1) * pack)
                k = k + 1
                local e = entries[(k - 1) % #entries + 1]
                local hole = Entries.holeFor(self)
                local q = { def = def, count = n, x = e[1], y = e[2], at = t, hole = hole, exact = true }
                if hole then q.x, q.y = hole.x, hole.y end
                self.queue[#self.queue + 1] = q
                t = t + gap
            end
        end
    end
    self.waveSpecies = #species > 0 and species or nil
    Pacing.shapeGroups(self)
    world.events:emit("wave_started", self.wave)
    world.player.inventory:trigger("onWaveStart", { world = world, player = world.player, wave = self.wave, procDepth = 0 })
end

function Spawner:update(dt)
    self:updateStreams(dt)
    Entries.update(self, dt)
    if not self.enabled then return end
    Pacing.update(self, dt)
    if self.endless then return self:updateEndless(dt) end
    local cfg = self.cfg
    if self.phase == "break" then
        -- the break waits while the wave's rewards do (the reward bloom, src/game/rewardflow.lua)
        if self.world.pendingChoice then return end
        self.timer = self.timer - dt
        -- an overlapped wave marches in as soon as the item is picked
        if self.timer <= 0 and not (self.overlapped and self.world.pendingChoice) then self:startWave() end
        return
    end
    self.waveTime = self.waveTime + dt
    for i = #self.queue, 1, -1 do
        local g = self.queue[i]
        if self.waveTime >= g.at and self.world.enemyCount < cfg.maxAlive then
            if g.crown then
                local st = self:spawnGroup(g.def, g.count, g.x, g.y, { noElites = true })
                if st then st.crown = g.crown end
                table.remove(self.queue, i)
            elseif g.hole then
                -- out of a nest hole, once it has opened (and the player isn't standing on it)
                if Entries.holeReady(self, g.hole, self.waveTime - g.at) then
                    local st = self:spawnGroup(g.def, g.count, g.x, g.y)
                    if st then st.style = "nest" end
                    g.hole.puff = 1
                    table.remove(self.queue, i)
                end
            elseif g.def.boss then
                self:spawnGroup(g.def, g.count, g.x, g.y)
                table.remove(self.queue, i)
            elseif g.ambush then
                Pacing.ambush(self, g.def, g.exact and g.count or Pacing.groupCount(self, g.count))
                table.remove(self.queue, i)
            elseif g.formation == "wall" then
                local st = self:spawnGroup(g.def, g.exact and g.count or Pacing.groupCount(self, g.count), g.x, g.y)
                if st then st.formation = "wall" end
                table.remove(self.queue, i)
            else
                Entries.send(self, g.def, g.exact and g.count or Pacing.groupCount(self, g.count), g.x, g.y)
                table.remove(self.queue, i)
            end
        end
    end
    -- Stray packs keep slipping in from other sides while the main groups are still coming.
    if self.wave >= 2 and #self.queue > 0 and not self.script then
        self.trickleT = self.trickleT - dt
        if self.trickleT <= 0 then
            self.trickleT = math.max(2, cfg.trickle - self.wave * 0.3) * (0.7 + love.math.random() * 0.6)
                / (1 + (cfg.live and cfg.live.trickle or 0) * self.pressure)
            local def = self:pickEnemy()
            if def and not Entries.ring(self, def) then
                local e = self:edgePoint()
                Entries.send(self, def, self:groupSize(def, 0.35), e[1], e[2])
            end
        end
    end
    -- final wave: when a crowned queen falls, the next one is on her way
    local ce = self.crownE
    if ce and (ce.dead or ce.uid ~= self.crownUid) then
        self.crownE = nil
        if self.crownLeft > 0 then
            self:queueCrowned(cfg.finalBoss.gap)
        end
    end
    -- the last few ants stop dawdling and come for the player (no hunting down stragglers)
    local w0 = self.world
    if #self.queue == 0 and #self.streams == 0 and #self.portals == 0 and w0.enemyCount > 0 and w0.enemyCount <= cfg.rushAt then
        for i = 1, w0.enemyCount do
            local e = w0.enemies[i]
            if e and not e.dead and not e.rushed and not e.def.boss and not e.def.encounter then
                e.rushed = true
                e.speed = (e.speed or 0) * cfg.rushSpeed
            end
        end
    end
    -- the last few, far away: they dig up next to the player
    local idle = #self.queue == 0 and #self.streams == 0 and #self.portals == 0
    if idle and cfg.call and w0.enemyCount > 0 and w0.enemyCount <= cfg.call.at then Pacing.callStragglers(self) end
    -- overlapping waves: the last ~15% of a normal wave are left to mingle with the next one
    local overlap = idle and Pacing.overlapReady(self)
    -- the wave only ends once everything in it (and anything it hatched) is dead
    if overlap or (idle and self.world.enemyCount == 0 and not self.crownE) then
        self.phase, self.timer = "break", self:breakLength()
        if overlap then self.overlapped, self.timer = true, 0 end
        Pacing.cleared(self)
        Entries.closeNests(self)
        self.world.events:emit("wave_cleared", self.wave)
        -- reward: choose one of three items (one more for each queen slain, a rare one after a queen)
        local w = self.world
        local pl = w.player
        if not pl.dead then
            local heal = (self.bossWave and cfg.bossHeal or cfg.waveHeal) * pl.stats:get("maxHp") * (w.danger and w.danger.healMul or 1)
            if heal > 0 and pl.hp < pl.stats:get("maxHp") then
                local before = pl.hp
                pl:heal(heal)
                w:floatText(pl.x, pl.y - 12, ("+%d HP"):format(math.floor(pl.hp - before + 0.5)), { 0.55, 1, 0.55 }, true)
            end
        end
        if self.finalThisWave and not pl.dead then self:chapterCleared() end
        if not w.player.dead then
            w.pendingChoice = { count = 3 + w.bonusPicks, boss = self.bossWave, wave = self.wave, at = w.time + 0.8,
                minRarity = w.rewards and w.rewards:takeMinRarity() }
            w.bonusPicks = 0
        end
    end
end

-- What the next wave will bring, for the HUD's next-wave preview during a break:
-- { wave, boss, final, newSpecies (def or nil), modifiers = { def with name, description?, color? } }.
-- Wave modifiers come from self:modifiersFor(n) when the spawner has it, else self.nextModifiers.
-- nil in endless mode (no waves).
function Spawner:preview()
    if self.endless then return nil end
    local n, cfg = self.wave + 1, self.cfg
    local final = self:isFinal(n)
    local boss = final or (cfg.bossEvery > 0 and n % cfg.bossEvery == 0)
    local fresh
    local sw = self:scriptWave(n)
    if sw then
        boss = sw.queen ~= nil
        for _, g in ipairs(sw.groups or {}) do
            local d = Content.enemies:get(g[1] or g.enemy)
            if d and not self.known[d.id] then fresh = d break end
        end
    elseif #self.knownList == 0 or ((not boss or self.mode.introOnBoss) and (n - 1) % cfg.introEvery == 0) then
        fresh = self:nextSpecies()
    end
    local mods = (self.modifiersFor and self:modifiersFor(n)) or self.nextModifiers or {}
    return { wave = n, boss = boss, final = final, newSpecies = fresh, modifiers = mods }
end

-- Seconds of breather after a wave (and its item choice), from Settings "waveBreak".
function Spawner:breakLength()
    local mode = Settings.get("waveBreak")
    if mode == "instant" then return 0 end
    if mode == "manual" then return math.huge end
    return self.cfg.breakTime
end

-- Whether the break is waiting for the player to press Next Wave.
function Spawner:waiting()
    return self.phase == "break" and self.timer == math.huge
end

-- The Next Wave key: during a break, start the wave now; during a wave, send every group
-- still queued in at once. Returns true if it did something.
function Spawner:nextWave()
    if self.endless or not self.enabled or self.world.pendingChoice then return false end
    if self.phase == "break" then
        Pacing.noteCall(self, false)
        self:startWave()
        return true
    end
    local sent = false
    for _, g in ipairs(self.queue) do
        if not g.crown and g.at > self.waveTime then g.at, sent = self.waveTime, true end
    end
    if sent then Pacing.noteCall(self, true) end
    return sent
end

-- The final wave is down: the run is won (the first time), the bag grows a row, and the game
-- shows the victory screen (src/states/victory.lua) before the item choice.
function Spawner:chapterCleared()
    local w = self.world
    local first = not w.won
    w.won = true
    w.player.inventory:addRows(1)
    w.pendingVictory = { wave = self.wave, first = first }
    w.events:emit(first and "run_won" or "chapter_cleared", self.wave)
end

-- Endless mode (mode.endless): no waves and no breaks, just a stream of packs from every side
-- that comes faster and bigger as the level climbs. `wave` doubles as the level, so enemy
-- health, elites and item rarity scale with it like they do with waves.
function Spawner:updateEndless(dt)
    local en, world = self.endless, self.world
    if self.phase == "break" then           -- the short "get ready" before the first level
        self.timer = self.timer - dt
        if self.timer <= 0 then self.phase, self.packT = "wave", 0 self:endlessLevel() end
        return
    end
    self.waveTime = self.waveTime + dt
    self.levelT = self.levelT - dt
    if self.levelT <= 0 then self:endlessLevel() end
    for i = #self.queue, 1, -1 do
        local g = self.queue[i]
        if self.waveTime >= g.at then
            if g.def.boss then self:spawnGroup(g.def, g.count, g.x, g.y) else Entries.send(self, g.def, g.count, g.x, g.y) end
            table.remove(self.queue, i)
        end
    end
    self.packT = self.packT - dt
    if self.packT <= 0 and world.enemyCount < self.cfg.maxAlive then
        self.packT = math.max(en.minGap or 0.5, (en.packGap or 2.4) * 0.93 ^ (self.wave - 1)) * (0.7 + love.math.random() * 0.6)
        local def = self:pickEnemy()
        if def and not Entries.ring(self, def) then
            local e = self:edgePoint()
            Entries.send(self, def, self:groupSize(def, en.packSize or 0.6), e[1], e[2])
        end
    end
end

function Spawner:endlessLevel()
    local en, world = self.endless, self.world
    self.wave = self.wave + 1
    self.waveTime, self.levelT = 0, en.levelTime or 40
    self.newSpecies = nil
    local fresh = self:nextSpecies()
    if fresh then
        self:learn(fresh)
        self.newSpecies = fresh
        world.events:emit("species_introduced", fresh)
        if #self.knownList > 1 then
            local e = self:edgePoint()
            self.queue[#self.queue + 1] = { def = fresh, count = self:groupSize(fresh, 0.7), x = e[1], y = e[2], at = 1 }
        end
    end
    local every = en.bossEvery or 5
    if every > 0 and self.wave % every == 0 then
        local queen = self:pickQueen()
        if queen then
            local e = self:edgePoint()
            self.queue[#self.queue + 1] = { def = queen, count = 1, x = e[1], y = e[2], at = 2 }
        end
    end
    world.events:emit("wave_started", self.wave)
    world.player.inventory:trigger("onWaveStart", { world = world, player = world.player, wave = self.wave, procDepth = 0 })
    -- every few levels, an item choice (it pauses the fight while you choose)
    local reward = en.rewardEvery or 0
    if reward > 0 and self.wave > 1 and (self.wave - 1) % reward == 0 and not world.player.dead then
        world.pendingChoice = { count = 3 + world.bonusPicks, wave = self.wave - 1, endless = true, at = world.time + 0.5 }
        world.bonusPicks = 0
    end
end

-- A queen whose brood species is already in the mix, preferring ones not fought yet.

function Spawner:pickQueen()
    if self.onlyQueen then return self.onlyQueen end      -- practice: the boss picked
    local wave = self.mode.queensAnyWave and math.huge or self.wave
    local options, fresh = {}, {}
    for _, d in ipairs(Content.enemies:all()) do
        if d.boss and d.spawn.minWave <= wave and self:allows(d) then
            local brood = d.behaviorParams.brood and Content.enemies:get(d.behaviorParams.brood)
            if not brood or self.known[brood.id] or self.mode.queensAnyBrood then
                options[#options + 1] = d
                if not self.usedQueens[d.id] then fresh[#fresh + 1] = d end
            end
        end
    end
    -- families without queens (bees, wasps): the mode names its biggest hunters instead
    if #options == 0 then
        for _, id in ipairs(self.mode.bossPool or {}) do
            local d = Content.enemies:get(id)
            options[#options + 1] = d
            if not self.usedQueens[id] then fresh[#fresh + 1] = d end
        end
    end
    local list = #fresh > 0 and fresh or options
    if #list == 0 then return nil end
    local q = list[love.math.random(#list)]
    self.usedQueens[q.id] = true
    return q
end

-- A species the player has already met (the newest one a little more often, so it sinks in).
-- Before any have been met (sandbox), anything that spawns on its own.
function Spawner:pickEnemy()
    if self.only then return self.only end                -- practice: the one species picked
    local util = require("src.core.util")
    -- a scripted wave: only the species it names
    if self.waveSpecies then return self.waveSpecies[love.math.random(#self.waveSpecies)] end
    if #self.knownList == 0 then
        return Content.enemies:pickWeighted(function(d) return d.spawn.weight end, function(d) return not d.boss and d.spawn.weight > 0 end)
    end
    local newest = self.knownList[#self.knownList]
    return util.weightedPick(self.knownList, function(d)
        local wgt = d.spawn.weight * self:faunaMul(d)
        if d == newest and #self.knownList > 1 then wgt = math.max(wgt * 1.5, 25) end
        return wgt
    end)
end

-- n points spread evenly around the arena edge (random rotation), skipping any too close to
-- the player.
function Spawner:spreadPoints(n)
    local S, p = self.world.size, self.world.player
    local out = {}
    local a0 = love.math.random() * math.pi * 2
    for i = 1, n do
        local a = a0 + (i - 1) / n * math.pi * 2 + (love.math.random() - 0.5) * 0.4
        -- from the centre outward to the edge along that direction
        local dx, dy = math.cos(a), math.sin(a)
        local t = (S / 2 - 4) / math.max(math.abs(dx), math.abs(dy))
        local x, y = S / 2 + dx * t, S / 2 + dy * t
        if (x - p.x) ^ 2 + (y - p.y) ^ 2 < 160 * 160 then x, y = S - x, S - y end
        out[i] = { x, y }
    end
    return out
end

-- A random point on the arena edge, away from the player.
function Spawner:edgePoint()
    local S, p = self.world.size, self.world.player
    local x, y
    for _ = 1, 8 do
        local side, t = love.math.random(4), love.math.random() * S
        if side == 1 then x, y = t, 4 elseif side == 2 then x, y = t, S - 4
        elseif side == 3 then x, y = 4, t else x, y = S - 4, t end
        if (x - p.x) ^ 2 + (y - p.y) ^ 2 > 220 * 220 then break end
    end
    return { x, y }
end

-- A group arrives as a stream: ants pour out of the grass at one point over a second or two,
-- linked nose to tail so the "column" behaviour turns them into a marching line.
-- opts.noElites: no elite rolls (queens' broods).
function Spawner:spawnGroup(def, count, x, y, opts)
    def = def or self:pickEnemy()
    if not def then return end
    count = count or math.max(1, math.floor(love.math.random(self.cfg.group[1], self.cfg.group[2]) * (def.spawn.groupSize or 1)))
    if not x and def.aquatic and self.world.stage and self.world.stage.shore then
        -- sea creatures swim in from the sea (the beach's x = size edge, content/mechanics/tide.lua)
        local S = self.world.size
        x, y = S - 6, S * (0.1 + 0.8 * love.math.random())
    end
    if not x then x, y = unpack(self:edgePoint()) end
    local st = { def = def, x = x, y = y, left = count, timer = 0, rate = math.max(0.03, math.min(0.12, 2.2 / count)),
        noElites = opts and opts.noElites }
    -- escort = { enemy id, count }: these follow behind the group in the same column
    -- (e.g. workers marching in the shelter of a turtle ant's shield head).
    local esc = def.spawn.escort
    if esc and Content.enemies:get(esc[1]) then st.escort, st.escortLeft = Content.enemies:get(esc[1]), esc[2] end
    self.streams[#self.streams + 1] = st
    return st
end

-- The mode's elite settings, with the current route's elite multiplier on top.
local NO_ELITES = { chance = 0 }
function Spawner:eliteMode()
    -- the wave's elite chances (wave modifiers, src/game/pacing.lua), scaled by a route gate
    -- Gentle Start (src/game/onramp.lua): no elites in a new player's first waves
    if not require("src.game.onramp").allows(self.world, "elites", self.wave) then return NO_ELITES end
    local m, route = self.eliteCfg or self.mode.elites, self.world.route
    local dk = self.world.danger and self.world.danger.eliteMul or 1     -- danger levels (src/config/danger.lua)
    if (not route or route.eliteMul == 1) and dk == 1 then return m end
    local k = (route and route.eliteMul or 1) * dk
    self._eliteMode = self._eliteMode or {}
    local out = self._eliteMode
    out.mul = (m and m.mul or 1) * k
    out.chance = m and m.chance and math.min(1, m.chance * k) or nil
    out.anyWave = m and m.anyWave
    return out
end

function Spawner:updateStreams(dt)
    local world = self.world
    for i = #self.streams, 1, -1 do
        local st = self.streams[i]
        st.timer = st.timer - dt
        if st.formation == "wall" and st.left > 0 then Pacing.spawnWall(self, st) end
        while st.timer <= 0 and st.left > 0 do
            st.timer = st.timer + st.rate
            st.left = st.left - 1
            local elite = not st.noElites and Elites.roll(st.def, math.max(1, self.wave), self:eliteMode()) or nil
            local e = world:spawnEnemy(st.def, st.x + (love.math.random() - 0.5) * 4, st.y + (love.math.random() - 0.5) * 4, elite)
            -- Link into a follow-the-leader column (used by the "column" behaviour).
            if e and st.style then Entries.arrive(world, e, st.style, st) end
            if e and e.def.boss then Pacing.royalGuard(self, e) end
            if e then
                if st.prev and st.prev.uid == st.prevUid then e.leader, e.leaderUid = st.prev, st.prevUid end
                st.prev, st.prevUid = e, e.uid
            end
        end
        if st.crown and st.prev and not st.crowned then
            -- a crowned queen: bigger, much tougher, and she owns the boss bar
            local q = st.prev
            st.crowned = true
            q.maxHp = math.floor(q.maxHp * st.crown.hpMul + 0.5)
            q.hp, q.scale, q.baseScale = q.maxHp, q.scale * st.crown.scale, q.baseScale * st.crown.scale
            q.radius = q.radius * st.crown.scale ^ 0.5
            q.title = "Crowned " .. q.def.name
            world.boss = q
            -- her title card comes from src/game/bosses.lua (the last one is the Empress)
            self.crownE, self.crownUid = q, q.uid
        end
        if st.left <= 0 then
            if st.escort and st.escortLeft > 0 then
                st.def, st.left, st.escortLeft = st.escort, st.escortLeft, 0
                st.rate = math.max(0.06, st.rate)
            else
                table.remove(self.streams, i)
            end
        end
    end
end

return Spawner
