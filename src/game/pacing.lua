-- Wave pacing: the things that keep a wave moving and make each one feel different.
--   * Wave modifiers (content/wavemods): Swarm, Armored, Ambush, Shield Wall... rolled ahead
--     per wave (Spawner:modifiersFor(n)), so the HUD can preview the next wave's.
--   * Big early waves: waves 1-3 send far more ants, and they fall to a single hit.
--   * Overlapping waves: once a wave is down to its last ~15%, it counts as broken; you pick
--     your item and the next wave marches in while the stragglers are still about.
--   * Straggler call: the last few ants of a wave, if far away, burrow and pop up beside you.
--   * Par time and heat: every wave has a par time. Clear it under par for bonus XP; go past it
--     and the ants get faster and angrier (heat) until the wave is done.
--   * Live pressure: while you stay healthy and untouched, packs come quicker and bigger and
--     ants a little faster; taking hits eases it off again.
--   * Early call: start the next wave (or send the rest of a wave in) with Next Wave and the
--     wave pays bonus XP, more for every wave in a row you called early.
--   * Royal guard: queens arrive ringed by guards; she shrugs off most damage until they fall.
-- Tuning lives in Spawner DEFAULTS (src/game/spawner.lua), so stages and modes can override it.
local Content = require("src.content")
local Settings = require("src.core.settings")
local Audio = require("src.core.audio")

local Pacing = {}

local SOIL = { { 0.36, 0.26, 0.17 }, { 0.5, 0.38, 0.24 }, { 0.24, 0.17, 0.11 } }

local NO_MOD = { groupSize = 1, groups = 1, hp = 1, speed = 1, damage = 1, elites = 1 }

function Pacing.init(sp)
    sp.rng = love.math.newRandomGenerator(sp.world.seed or os.time())
    sp.modsByWave = {}
    sp.mods, sp.mod = {}, NO_MOD
    sp.pace, sp.dpace = 1, 1
    sp.heat, sp.pressure, sp.calmT = 0, 0, 0
    sp.earlyStreak, sp.calledEarly = 0, false
    sp.waveKills, sp.waveSpawned = 0, 0
    sp.par = 0
    sp.calls = {}
    local ev = sp.world.events
    ev:on("player_hurt", function(ctx) Pacing.onHurt(sp, ctx) end)
    ev:on("enemy_died", function(e) Pacing.onDeath(sp, e) end)
end

----------------------------------------------------------------------------------------------
-- Species order

-- The order this run meets the species: roughly by minWave, but shuffled so every run meets a
-- different mix (bees, wasps and termites can show up early). The first species (plain workers)
-- stays first. Setting "speciesOrder" = "classic" keeps the fixed order.
function Pacing.shuffleOrder(sp, order)
    local jit = sp.cfg.orderJitter
    if Settings.get("speciesOrder") == "classic" or not jit or jit <= 0 or #order < 3 then return order end
    local key = {}
    for i, d in ipairs(order) do
        key[d] = i == 1 and -math.huge or d.spawn.minWave * (jit.scale or 0.6) + sp.rng:random() * (jit.spread or 5)
    end
    local out = {}
    for i, d in ipairs(order) do out[i] = d end
    table.sort(out, function(a, b)
        if key[a] ~= key[b] then return key[a] < key[b] end
        return a.id < b.id
    end)
    return out
end

----------------------------------------------------------------------------------------------
-- Wave modifiers

local function modAllowed(sp, def, n)
    if def.minWave and n < def.minWave then return false end
    if def.maxWave and n > def.maxWave then return false end
    if def.modes and not require("src.core.util").contains(def.modes, sp.mode.id) then return false end
    return true
end

-- The modifiers of wave n (rolled once, from the run's seed, then remembered).
function Pacing.modifiersFor(sp, n)
    if sp.modsByWave[n] then return sp.modsByWave[n] end
    local cfg, out = sp.cfg.modifiers, {}
    sp.modsByWave[n] = out
    if not cfg or sp.endless or Settings.get("waveModifiers") == false then return out end
    local boss = sp.cfg.bossEvery > 0 and n % sp.cfg.bossEvery == 0
    if n < (cfg.from or 3) or boss or sp:isFinal(n) then return out end
    local rng = sp.rng
    local count = 0
    if rng:random() < (cfg.chance or 0.55) then count = 1 end
    if count == 1 and n >= (cfg.doubleFrom or 9) and rng:random() < (cfg.double or 0.3) then count = 2 end
    for _ = 1, count do
        local total, pool = 0, {}
        for _, d in ipairs(Content.wavemods:all()) do
            local clash = false
            for _, o in ipairs(out) do
                if o == d or (o.formation and d.formation) or (o.ambush and d.ambush) then clash = true end
            end
            if not clash and modAllowed(sp, d, n) and (d.weight or 0) > 0 then
                pool[#pool + 1] = d
                total = total + d.weight
            end
        end
        if total <= 0 then break end
        local r = rng:random() * total
        for _, d in ipairs(pool) do
            r = r - d.weight
            if r <= 0 then out[#out + 1] = d break end
        end
    end
    return out
end

-- All of a wave's modifiers folded into one table (multipliers multiplied, flags or'd).
function Pacing.combine(mods)
    if #mods == 0 then return NO_MOD end
    local m = { groupSize = 1, groups = 1, hp = 1, speed = 1, damage = 1, elites = 1 }
    for _, d in ipairs(mods) do
        for _, k in ipairs({ "groupSize", "groups", "hp", "speed", "damage", "elites" }) do
            if d[k] then m[k] = m[k] * d[k] end
        end
        m.formation = m.formation or d.formation
        m.ambush = m.ambush or d.ambush
        if d.entryStyles then
            m.entryStyles = m.entryStyles or {}
            for k, v in pairs(d.entryStyles) do m.entryStyles[k] = v end
        end
    end
    return m
end

-- Big early waves: wave 1-3 groups x size[n], ants x hp[n] health.
function Pacing.early(sp, n)
    local eb = sp.cfg.earlyBoost
    if not eb or sp.endless then return 1, 1 end
    n = n or sp.wave
    return eb.size[n] or 1, eb.hp[n] or 1
end

-- Health multiplier for ants spawning now (World:hpScale).
function Pacing.hpMul(sp)
    if not sp.enabled then return 1 end
    local _, hp = Pacing.early(sp)
    return hp * (sp.mod.hp or 1)
end

-- Elite chances for this wave: the mode's, scaled by the modifiers.
function Pacing.eliteCfg(sp)
    local me, mul = sp.mode.elites, sp.mod.elites or 1
    if mul == 1 then return me end
    me = me or {}
    return { mul = (me.mul or 1) * mul, chance = me.chance and math.min(1, me.chance * mul), anyWave = me.anyWave }
end

----------------------------------------------------------------------------------------------
-- Wave start / spawning

function Pacing.startWave(sp)
    sp.mods = Pacing.modifiersFor(sp, sp.wave)
    sp.mod = Pacing.combine(sp.mods)
    sp.nextModifiers = Pacing.modifiersFor(sp, sp.wave + 1)
    sp.eliteCfg = Pacing.eliteCfg(sp)
    sp.heat, sp.waveKills, sp.waveSpawned = 0, 0, 0
    sp.calledEarly, sp.overlapped, sp.calls = sp.callNext or false, false, {}
    sp.callNext = nil
    sp.parAnnounced, sp.heatAnnounced = false, false
    for _, d in ipairs(sp.mods) do sp.world.events:emit("wave_modifier", d, sp.wave) end
end

-- Formations and ambushes reshape the queued groups (called at the end of Spawner:startWave).
function Pacing.shapeGroups(sp)
    local m = sp.mod
    if m.formation == "pincer" then
        local out = {}
        for _, g in ipairs(sp.queue) do
            if g.def.boss or g.crown or g.hole or g.count < 6 then
                out[#out + 1] = g
            else
                local pts = sp:spreadPoints(2)
                local half = math.ceil(g.count / 2)
                out[#out + 1] = { def = g.def, count = half, x = pts[1][1], y = pts[1][2], at = g.at }
                out[#out + 1] = { def = g.def, count = g.count - half, x = pts[2][1], y = pts[2][2], at = g.at }
            end
        end
        sp.queue = out
    elseif m.formation == "wall" then
        for _, g in ipairs(sp.queue) do
            if not g.def.boss and not g.crown and not g.hole then g.formation = "wall" end
        end
    end
    if m.ambush then
        -- half the wave's groups burst up around the player at once, a moment in
        local n, done = 0, 0
        for _, g in ipairs(sp.queue) do if not g.def.boss and not g.crown then n = n + 1 end end
        for _, g in ipairs(sp.queue) do
            if done >= math.ceil(n / 2) then break end
            if not g.def.boss and not g.crown and not g.hole then
                g.ambush, g.at, g.formation = true, 2.6, nil
                done = done + 1
            end
        end
    end
    -- par time for the wave, from how many ants are coming
    local pc = sp.cfg.par
    local planned = 0
    for _, g in ipairs(sp.queue) do planned = planned + g.count end
    sp.planned = planned
    sp.par = pc and math.floor(pc.base + planned * pc.perAnt + (sp.bossWave and pc.boss or 0) + 0.5) or math.huge
end

-- Every ant the spawner (or a behaviour) brings in: this wave's modifiers and the current pace.
function Pacing.onSpawn(sp, e)
    if not sp.enabled then return end
    sp.waveSpawned = sp.waveSpawned + 1
    local m = sp.mod
    e.speed = e.speed * (m.speed or 1) * sp.pace
    e.damage = e.damage * (m.damage or 1) * sp.dpace
    e.pace, e.dpace = sp.pace, sp.dpace
end

-- A group dispatched now: bigger under live pressure.
function Pacing.groupCount(sp, count)
    local lp = sp.cfg.live
    if not lp or sp.pressure <= 0 then return count end
    return math.max(1, math.floor(count * (1 + (lp.size or 0) * sp.pressure) + 0.5))
end

-- An ambush: the group splits into a few burrows (or landing spots, for flyers) in a circle
-- around the player, all warning at once.
function Pacing.ambush(sp, def, count)
    local Entries = require("src.game.entries")
    local p, S = sp.world.player, sp.world.size
    local spots = math.max(2, math.min(5, math.ceil(count / 6)))
    local r = 115 + love.math.random() * 35
    local a0 = love.math.random() * math.pi * 2
    local flying = false
    for _, t in ipairs(def.tags or {}) do if t == "flying" then flying = true end end
    local left = count
    for i = 1, spots do
        local a = a0 + (i - 1) / spots * math.pi * 2
        local x = math.max(20, math.min(S - 20, p.x + math.cos(a) * r))
        local y = math.max(20, math.min(S - 20, p.y + math.sin(a) * r))
        local c = i == spots and left or math.floor(count / spots)
        left = left - c
        if c > 0 then Entries.open(sp, flying and "drop" or "ringspot", def, c, x, y) end
    end
end

-- A shield wall: the whole group steps out of the grass at once, shoulder to shoulder, in ranks
-- facing the player (no marching column).
function Pacing.spawnWall(sp, st)
    local world, Elites = sp.world, require("src.game.elites")
    local p, S = world.player, world.size
    local dx, dy = p.x - st.x, p.y - st.y
    local d = math.sqrt(dx * dx + dy * dy) + 0.0001
    dx, dy = dx / d, dy / d
    local px, py = -dy, dx
    local gap = math.max(7, st.def.radius * 2.4)
    local perRank = math.max(6, math.min(18, math.ceil(math.sqrt(st.left * 3))))
    local n = st.left
    for i = 0, n - 1 do
        local rank, slot = math.floor(i / perRank), i % perRank
        local inRank = math.min(perRank, n - rank * perRank)
        local off = (slot - (inRank - 1) / 2) * gap
        local x = st.x + px * off - dx * rank * gap + dx * 6
        local y = st.y + py * off - dy * rank * gap + dy * 6
        x, y = math.max(8, math.min(S - 8, x)), math.max(8, math.min(S - 8, y))
        local elite = not st.noElites and Elites.roll(st.def, math.max(1, sp.wave), sp.eliteCfg) or nil
        local e = world:spawnEnemy(st.def, x, y, elite)
        if e then e.angle = math.atan2(dy, dx) end
    end
    st.left = 0
end

----------------------------------------------------------------------------------------------
-- During a wave

function Pacing.onHurt(sp, ctx)
    if not sp.enabled or sp.phase ~= "wave" then return end
    sp.calmT = 0
    local lp = sp.cfg.live
    local maxHp = sp.world.player.stats:get("maxHp")
    if lp then sp.pressure = math.max(0, sp.pressure - (ctx.damage or 0) / math.max(1, maxHp) * (lp.ease or 3)) end
end

function Pacing.onDeath(sp, e)
    if not sp.enabled then return end
    sp.waveKills = sp.waveKills + 1
    -- a royal guard down: one less between you and the queen
    local q = e.guardOf
    if q and q.uid == e.guardUid and not q.dead and (q.guards or 0) > 0 then
        q.guards = q.guards - 1
        if q.guards == 0 then
            sp.world.milestone = { text = "GUARD BROKEN", t = 0 }
            Audio.play("ui_confirm", { pitch = 0.7 })
            sp.world.particles:burst(q.x, q.y, 18, { { 1, 0.85, 0.35 }, { 1, 0.95, 0.6 } }, 90, 60, { glow = true })
        end
    end
end

local function adaptive() return Settings.get("adaptiveWaves") ~= false end

-- Rescale every live ant's speed / damage when the pace changes (heat, pressure).
local function setPace(sp, pace, dpace)
    if math.abs(pace - sp.pace) < 0.02 and math.abs(dpace - sp.dpace) < 0.02 then return end
    local w = sp.world
    for i = 1, w.enemyCount do
        local e = w.enemies[i]
        if e and not e.dead then
            e.speed = e.speed * pace / (e.pace or 1)
            e.damage = e.damage * dpace / (e.dpace or 1)
            e.pace, e.dpace = pace, dpace
        end
    end
    sp.pace, sp.dpace = pace, dpace
end

function Pacing.update(sp, dt)
    if sp.phase ~= "wave" or sp.endless then
        Pacing.updateCalls(sp, dt)
        return
    end
    local cfg, w = sp.cfg, sp.world
    local on = adaptive()
    -- heat: past par time the ants grow faster and hit harder
    local hc = cfg.heat
    if hc and on and sp.par < math.huge then
        sp.heat = math.max(0, math.min(1, (sp.waveTime - sp.par) / (hc.ramp or 40)))
        if sp.heat > 0 and not sp.heatAnnounced then
            sp.heatAnnounced = true
            w.events:emit("wave_heat", sp.wave)
        end
    else
        sp.heat = 0
    end
    -- live pressure: builds while you're healthy and untouched
    local lp = cfg.live
    if lp and on then
        sp.calmT = sp.calmT + dt
        local p = w.player
        if not p.dead and sp.calmT > (lp.calm or 5) and p.hp >= p.stats:get("maxHp") * (lp.hp or 0.8) then
            sp.pressure = math.min(1, sp.pressure + dt / (lp.build or 25))
        end
    else
        sp.pressure = 0
    end
    local pace = (1 + (hc and hc.speed or 0) * sp.heat) * (1 + (lp and lp.speed or 0) * sp.pressure)
    local dpace = 1 + (hc and hc.damage or 0) * sp.heat
    setPace(sp, pace, dpace)
    Pacing.updateCalls(sp, dt)
end

-- The last few ants, far away: they burrow and come up close to the player.
function Pacing.callStragglers(sp)
    local cc = sp.cfg.call
    if not cc then return end
    local w, p = sp.world, sp.world.player
    if p.dead then return end
    local far2 = (cc.far or 170) ^ 2
    for i = 1, w.enemyCount do
        local e = w.enemies[i]
        if e and not e.dead and not e.called and not e.def.boss and not e.hidden and not e.held and not e.dropH
            and (e.x - p.x) ^ 2 + (e.y - p.y) ^ 2 > far2 then
            e.called = true
            e.hidden = true
            e.stunT = math.max(e.stunT, (cc.time or 0.9) + 0.1)
            sp.calls[#sp.calls + 1] = { e = e, uid = e.uid, t = cc.time or 0.9 }
            w.particles:burst(e.x, e.y, 6, SOIL, 60, 70, { grav = 300, stain = true })
        end
    end
end

function Pacing.updateCalls(sp, dt)
    local calls = sp.calls
    if not calls or #calls == 0 then return end
    local Entries = require("src.game.entries")
    local w = sp.world
    local cc = sp.cfg.call or {}
    local played = false
    for i = #calls, 1, -1 do
        local c = calls[i]
        c.t = c.t - dt
        local e = c.e
        if e.uid ~= c.uid or e.dead then
            table.remove(calls, i)
        elseif c.t <= 0 then
            table.remove(calls, i)
            local x, y = Entries.nearPoint(sp, cc.near or { 70, 110 })
            e.x, e.y = x, y
            e.hidden, e.stunT, e.squash = false, 0, 0.25
            w.particles:burst(x, y, 10, SOIL, 80, 90, { grav = 300, stain = true })
            if not played then played = true Audio.play("rumble", { volume = 0.6 }) end
        end
    end
end

-- Is the wave ready to overlap into the next (its last ~15%, nothing more coming)?
function Pacing.overlapReady(sp)
    local oc = sp.cfg.overlap
    if not oc or sp.endless or sp.bossWave or sp.finalThisWave or sp.crownE then return false end
    if Settings.get("waveOverlap") == false or Settings.get("waveBreak") == "manual" then return false end
    if sp.world.boss and not sp.world.boss.dead then return false end
    if sp.waveTime < (oc.minTime or 6) then return false end
    local left = sp.world.enemyCount
    if left == 0 then return false end
    return left <= math.max(oc.min or 3, math.floor(sp.waveSpawned * (oc.share or 0.15)))
end

----------------------------------------------------------------------------------------------
-- Wave cleared: par bonus and the early-call streak

function Pacing.cleared(sp)
    local w, p = sp.world, sp.world.player
    if p.dead then return end
    local pc = sp.cfg.par
    local y = p.y - 26
    if pc and sp.waveTime <= sp.par then
        local xp = math.floor((pc.xp or 5) + sp.wave * (pc.xpPerWave or 1.5))
        w:floatText(p.x, y, "UNDER PAR", { 1, 0.86, 0.4 }, true)
        w:grantXP(xp, p.x, y + 10)
        w.events:emit("wave_par", sp.wave, sp.waveTime, sp.par)
        y = y - 14
    end
    local ec = sp.cfg.early
    if ec and sp.calledEarly then
        sp.earlyStreak = math.min(ec.max or 6, sp.earlyStreak + 1)
        local xp = math.max(1, math.floor(sp.waveKills * (ec.perKill or 0.08) * sp.earlyStreak + 0.5))
        w:floatText(p.x, y, "EARLY CALL x" .. sp.earlyStreak, { 1, 0.6, 0.3 }, true)
        w:grantXP(xp, p.x, y + 10)
    else
        sp.earlyStreak = 0
    end
    sp.pressure = sp.pressure * ((sp.cfg.live or {}).keep or 0.7)
end

-- Next Wave pressed: does it count as calling early? (during a wave, or before an auto
-- countdown has run out)
function Pacing.noteCall(sp, duringWave)
    if duringWave then sp.calledEarly = true
    elseif sp.timer ~= math.huge and sp.timer > 0.4 then sp.callNext = true end
end

----------------------------------------------------------------------------------------------
-- Royal guard

function Pacing.royalGuard(sp, q)
    local gc = sp.cfg.royalGuard
    if not gc or q.guards or not q.def.boss then return end
    local w = sp.world
    local def
    local brood = q.def.behaviorParams and q.def.behaviorParams.brood
    brood = brood and Content.enemies:get(brood)
    if brood and not brood.boss then def = brood end
    if not def then
        for _, d in ipairs(sp.knownList) do
            if not d.boss and (d.spawn.weight or 0) > 0 and (not def or d.hp > def.hp) then def = d end
        end
    end
    if not def then return end
    local n = (gc.count or 6) + math.floor(sp.wave / 5) * (gc.perChapter or 2)
    local elite = gc.elite and Content.elites:get(gc.elite)
    local guards = 0
    local r = q.radius + (gc.radius or 16)
    for i = 1, n do
        local a = i / n * math.pi * 2
        local g = w:spawnEnemy(def, q.x + math.cos(a) * r, q.y + math.sin(a) * r, elite)
        if g then
            g.behavior = Content.behaviors:require("royal_guard")
            g.guardOf, g.guardUid, g.guardA = q, q.uid, a
            guards = guards + 1
        end
    end
    q.guards, q.guardMul = guards, gc.shield or 0.3
    if guards > 0 and not w.milestone then w.milestone = { text = "BREAK THE ROYAL GUARD", t = 0 } end
end

-- A ring of gold around a guarded queen (drawn on the ground, Entries.drawGround).
function Pacing.drawGuard(w, time)
    local q = w.boss
    if not q or q.dead or not q.guards or q.guards <= 0 or q.hidden then return end
    local Iso = require("src.core.iso")
    local lg = love.graphics
    local x, y = Iso.toScreen(q.x, q.y)
    local r = q.radius * 2.2 + 6
    lg.setColor(1, 0.85, 0.35, 0.35 + 0.25 * math.sin(time * 6))
    lg.setLineWidth(2)
    lg.ellipse("line", x, y + 1, r, r * 0.5)
    lg.setLineWidth(1)
    lg.ellipse("line", x, y + 1, r + 4, (r + 4) * 0.5)
end

return Pacing
