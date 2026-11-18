-- The arena director: everything that happens in a run besides the ants walking in.
--
--   * Mid-wave events (content/events): honeydew rain, an anteater's tongue, a boot stomping
--     down, a flood, colony wars, dew drops rolling through, falling acorns, a lawnmower, web
--     cocoons with a bug to free, a merchant beetle. A few are scheduled into each wave from
--     wave 2 on (Settings "Mid-Wave Events"); they never hold a wave up, and whatever is still
--     going when the last ant falls ends with the wave.
--   * Boss encounters (content/bosses): every 5th wave (not the final one) something big joins
--     the queen. Bugs (the antlion in its pit) are real enemies: the wave lasts until it is
--     killed. Animals far too big to fight (the sparrow, the giant anteater) are stage hazards
--     instead (def.hazard): godly attacks sweeping the arena that eat ants and hurt you alike.
--     You can't hit them; they hunt until the wave is cleared, then leave. Settings "Boss
--     Encounters".
--   * Stage mechanics (content/mechanics): a stage's `mechanic` changes how it plays (a rising
--     puddle, a lawn that shrinks in, patches of sun and shade).
--   * Weather effects: a spell's `effects` (content/weather) push and slow or speed things up.
--   * Props (src/game/props.lua): pebbles and twigs to shove into ants, cocoons, allies, the
--     merchant.
--   * Map gambles (src/game/gambles.lua): a dewdrop shrine, a challenge bell or a gamble flower
--     may pop up in a wave (Settings "Map Gambles").
--   * Nest holes (src/game/entries.lua) can be collapsed: hit one three times (or dash over it)
--     and the groups still waiting in it never come out.
--
-- Everything that changes movement goes through world.env, rebuilt every frame:
--   playerSpeed, enemySpeed (multipliers), driftX, driftY (world units/s pushing everything,
--   lighter bugs more), inset (the player is kept this far in from the walls) and field(x, y, who)
--   (a speed multiplier at a spot: who is "player" or the enemy).
local Content = require("src.content")
local Settings = require("src.core.settings")
local Audio = require("src.core.audio")
local Iso = require("src.core.iso")
local util = require("src.core.util")
local Env = require("src.game.envfx")
local Props = require("src.game.props")
local Gambles = require("src.game.gambles")
local Beasts = require("src.gfx.beasts")

local Director = {}
Director.__index = Director

Director.DEFAULTS = {
    eventsFrom = 2,             -- first wave with mid-wave events
    eventAt = { 6, 24 },        -- seconds into a wave an event may start
    eventGap = 9,               -- at least this many seconds between two events' starts
    encounterEvery = 5,         -- a boss encounter on every 5th wave (0 = never)
    encounterAt = 5,            -- seconds into the wave it arrives
    props = { pebble = 5, twig = 3 },   -- shovable props when the stage names none
}

local function envReset(env)
    env.playerSpeed, env.enemySpeed, env.driftX, env.driftY, env.inset = 1, 1, 0, 0, 0
    env.field = nil
    return env
end

function Director.new(world)
    local self = setmetatable({ world = world, active = {}, schedule = {}, banners = {}, recent = {},
        usedBosses = {}, encounter = nil, holeHits = {} }, Director)
    local cfg = {}
    for k, v in pairs(Director.DEFAULTS) do cfg[k] = v end
    for k, v in pairs(world.stage.director or {}) do cfg[k] = v end
    for k, v in pairs((world.modeDef or {}).director or {}) do cfg[k] = v end
    self.cfg = cfg
    world.env = envReset({})
    world.props = Props.new(world)
    -- map gambles: dewdrop shrines, challenge bells, gamble flowers (src/game/gambles.lua)
    self.gambles = Gambles.new(world)
    world.gambles = self.gambles
    -- the stage's own rule (a rising puddle, a shrinking lawn...)
    local m = world.stage.mechanic
    if m then
        local def = Content.mechanics:require(m.type)
        self.mechanic = { def = def, params = m, st = {}, t = 0 }
        if def.start then def.start(world, self.mechanic) end
    end
    -- scattered pebbles and twigs (not in the sandbox, which places its own)
    if world.mode == "run" then
        local list = world.stage.props or cfg.props
        local ids = {}
        for id in pairs(list) do ids[#ids + 1] = id end
        table.sort(ids)
        for _, id in ipairs(ids) do
            for _ = 1, list[id] do
                local x, y = Env.pointAway(world, 70, 50)
                world.props:spawn(id, x, y, { angle = love.math.random() * math.pi })
            end
        end
    end
    local ev = world.events
    ev:on("wave_started", function(n) self:onWaveStart(n) end)
    ev:on("wave_cleared", function(n) self:onWaveCleared(n) end)
    return self
end

----------------------------------------------------------------------------------------------
-- Settings / mode switches

function Director:eventsOn()
    local w = self.world
    if w.mode ~= "run" or w.flags.demo then return false end
    if w.modeDef and w.modeDef.events == false then return false end
    return Settings.get("midWaveEvents") ~= "off"
end

function Director:encountersOn()
    local w = self.world
    if w.mode ~= "run" or w.flags.demo or self.cfg.encounterEvery <= 0 then return false end
    if w.modeDef and w.modeDef.encounters == false then return false end
    return Settings.get("bossEncounters") ~= false
end

----------------------------------------------------------------------------------------------
-- Events

local function eventWeight(self, def, wave)
    if def.minWave and wave < def.minWave then return 0 end
    if def.maxWave and wave > def.maxWave then return 0 end
    local stage = self.world.stage
    local w = def.weight or 10
    if stage.events and stage.events[def.id] ~= nil then w = stage.events[def.id] or 0
    elseif def.stages and not util.contains(def.stages, stage.id) then w = 0 end
    local mode = self.world.modeDef
    if mode and mode.eventWeights and mode.eventWeights[def.id] ~= nil then w = mode.eventWeights[def.id] or 0 end
    if def.allowed and not def.allowed(self.world) then w = 0 end
    -- not the same one twice in a row, and not one already lined up this wave
    if self.recent[def.id] then w = w * 0.25 end
    for _, s in ipairs(self.schedule) do if s.def == def then w = 0 end end
    return w
end

-- How many events this wave gets (Settings "Mid-Wave Events": often / normal / off).
function Director:eventCount(wave)
    local often = Settings.get("midWaveEvents") == "often"
    if wave < self.cfg.eventsFrom then return 0 end
    -- Gentle Start (src/game/onramp.lua): none at first, then one at a time, never beside a visitor
    local OnRamp = require("src.game.onramp")
    if not OnRamp.allows(self.world, "events", wave) then return 0 end
    if OnRamp.calm(self.world) then return self.pendingBoss and 0 or 1 end
    local n = 0
    if often or love.math.random() < math.min(0.9, 0.55 + wave * 0.03) then n = 1 end
    if wave >= (often and 3 or 6) and love.math.random() < (often and 0.7 or 0.35) then n = n + 1 end
    if often and wave >= 8 and love.math.random() < 0.4 then n = n + 1 end
    return n + (self.cfg.eventBonus or 0)      -- a mode can add more (Mayhem)
end

function Director:onWaveStart(n)
    self.schedule = {}
    local world = self.world
    local sp = world.spawner
    if self.mechanic and self.mechanic.def.onWaveStart then self.mechanic.def.onWaveStart(world, self.mechanic, n) end
    self.gambles:onWaveStart(n)
    -- a scripted wave (Custom Waves, content/modes `waves`) names its own events and encounter
    local sw = sp and sp.scriptWave and sp:scriptWave(n)
    if sw then return self:scriptedWave(sw) end
    -- a predator joins the queen on boss waves (not the run's final wave)
    local every = self.cfg.encounterEvery
    if self:encountersOn() and every > 0 and n % every == 0 and not (sp.isFinal and sp:isFinal(n))
        and require("src.game.onramp").allows(world, "encounters", n) then
        local boss = self:pickBoss(n)
        if boss then
            self.pendingBoss = { def = boss, at = boss.arrive or self.cfg.encounterAt }
            -- paint the hazard's pictures now rather than on the frame it arrives
            if boss.hazard and boss.pictures then Beasts.prepare(boss.pictures) end
        end
    end
    if self:eventsOn() then
        local count = self:eventCount(n)
        -- a stage hazard is a wave's worth of trouble on its own: no other events with it
        if self.pendingBoss and self.pendingBoss.def.hazard then count = 0 end
        local at = self.cfg.eventAt
        for i = 1, count do
            local def = util.weightedPick(Content.events:all(), function(d) return eventWeight(self, d, n) end)
            if not def then break end
            local t = at[1] + love.math.random() * (at[2] - at[1])
            for _, s in ipairs(self.schedule) do
                if math.abs(s.at - t) < self.cfg.eventGap then t = s.at + self.cfg.eventGap end
            end
            self.schedule[#self.schedule + 1] = { def = def, at = t }
        end
    end
end

-- The events and encounter a scripted wave names, spread through the wave. They come whatever
-- the Mid-Wave Events / Boss Encounters settings say: the wave's maker asked for them.
function Director:scriptedWave(sw)
    local w = self.world
    if w.mode ~= "run" or w.flags.demo then return end
    -- (the first one early, so even a small wave gets to see it, the rest eventGap apart)
    for i, id in ipairs(sw.events or {}) do
        local def = Content.events:get(id)
        if def then
            local t = 2 + (i - 1) * self.cfg.eventGap
            self.schedule[#self.schedule + 1] = { def = def, at = t }
        end
    end
    local boss = sw.encounter and Content.bosses:get(sw.encounter)
    if boss then
        -- early, like the first event: a small scripted wave can be cleared before a stage
        -- hazard's usual arrival time, and the wave's maker asked to see it
        local at = math.min(boss.arrive or self.cfg.encounterAt, 3)
        self.pendingBoss = { def = boss, at = at }
        if boss.hazard and boss.pictures then Beasts.prepare(boss.pictures) end
    end
end

function Director:onWaveCleared()
    self.schedule, self.pendingBoss = {}, nil
    if self.hazard and not self.hazard.leaving then self:endHazard(true) end
    self.recent = {}
    for i = #self.active, 1, -1 do
        local ev = self.active[i]
        self.recent[ev.def.id] = true
        self:stop(ev)
    end
end

-- Start an event now (the dev console's `event <id>` and the tests use this too).
function Director:start(id, opts)
    local def = type(id) == "table" and id or Content.events:require(id)
    local ev = { def = def, t = 0, st = {}, opts = opts or {}, life = def.duration }
    self.active[#self.active + 1] = ev
    if def.start then def.start(self.world, ev) end
    if def.banner ~= false and not (opts and opts.quiet) then
        self:announce(def.name, def.description, def.color)
    end
    if def.sound then Audio.play(def.sound[1], def.sound[2]) end
    self.world.events:emit("event_started", def.id)
    return ev
end

function Director:stop(ev)
    for i = #self.active, 1, -1 do
        if self.active[i] == ev then table.remove(self.active, i) end
    end
    if ev.def.finish and not ev.finished then
        ev.finished = true
        ev.def.finish(self.world, ev)
    end
end

function Director:isActive(id)
    for _, ev in ipairs(self.active) do if ev.def.id == id then return ev end end
end

----------------------------------------------------------------------------------------------
-- Boss encounters

function Director:pickBoss(wave)
    local options, fresh = {}, {}
    for _, b in ipairs(Content.bosses:all()) do
        if (b.minWave or 1) <= wave and (b.weight or 10) > 0 then
            options[#options + 1] = b
            if not self.usedBosses[b.id] then fresh[#fresh + 1] = b end
        end
    end
    local list = #fresh > 0 and fresh or options
    if #list == 0 then return nil end
    local b = util.weightedPick(list, function(d) return d.weight or 10 end)
    self.usedBosses[b.id] = true
    return b
end

-- Bring a boss encounter in now. Returns the boss enemy (or the hazard, for def.hazard ones).
function Director:startBoss(id)
    local def = type(id) == "table" and id or Content.bosses:require(id)
    if def.hazard then return self:startHazard(def) end
    local world = self.world
    local x, y
    if def.entry then x, y = def.entry(world) else x, y = Env.pointAway(world, 220, 60) end
    local e = world:spawnEnemy(def.enemy, x, y)
    if not e then return nil end
    e.title = def.title or def.name
    self.encounter = { def = def, e = e, uid = e.uid, t = 0 }
    if def.start then def.start(world, e, self.encounter) end
    self:announce(def.name, def.description, def.color or { 1, 0.45, 0.3 }, true)
    Audio.play("queen", { pitch = def.pitch or 0.7 })
    world.camera:shake(0.3)
    world.events:emit("encounter_started", def.id)
    return e
end

-- A stage hazard: no enemy, nothing to hit. Its own hooks run it (content/bosses/sparrow.lua):
-- start(world, h), update(world, h, dt), leave(world, h, dt) once the wave is cleared (set
-- h.gone when it is out of sight), env(world, h, env), drawGround / drawAir(world, h).
-- h.label is the HUD line saying what it is doing ("SWOOPING!").
function Director:startHazard(id)
    local def = type(id) == "table" and id or Content.bosses:require(id)
    local world = self.world
    if self.hazard then self.hazard = nil end
    if def.pictures then Beasts.prepare(def.pictures) end
    local h = { def = def, t = 0, st = {}, label = nil }
    self.hazard = h
    if def.start then def.start(world, h) end
    self:announce(def.name, def.description, def.color or { 1, 0.45, 0.3 }, true)
    Audio.play("queen", { pitch = def.pitch or 0.5 })
    world.camera:shake(0.35)
    world.events:emit("encounter_started", def.id)
    return h
end

-- The hazard leaves: survived = the wave was cleared under it (bonus XP and a popup).
function Director:endHazard(survived)
    local h = self.hazard
    if not h then return end
    local world = self.world
    if not survived then self.hazard = nil return end
    h.leaving, h.label = 0, nil
    local def = h.def
    world.milestone = { text = def.survived or (def.title or def.name):upper() .. " MOVES ON", t = 0 }
    Audio.play("boom", { pitch = 0.45 })
    local p = world.player
    if def.xp and p then world:grantXP(def.xp, p.x, p.y) end
    world.events:emit("encounter_won", def.id)
end

----------------------------------------------------------------------------------------------
-- Banners: a title and a line under it at the bottom of the screen

function Director:announce(title, sub, color, big)
    local list = self.banners
    list[#list + 1] = { title = title, sub = sub, color = color or { 1, 0.85, 0.45 }, t = 0, life = big and 4.5 or 3.6, big = big }
    while #list > 3 do table.remove(list, 1) end
end

----------------------------------------------------------------------------------------------
-- Update

-- A speed field: the product of every active event's and the stage mechanic's field.
local function makeField(self)
    local fns = {}
    for _, ev in ipairs(self.active) do
        if ev.def.field then fns[#fns + 1] = { ev.def.field, ev } end
    end
    local m = self.mechanic
    if m and m.def.field then fns[#fns + 1] = { m.def.field, m } end
    if #fns == 0 then return nil end
    local world = self.world
    if #fns == 1 then
        local f, o = fns[1][1], fns[1][2]
        return function(x, y, who) return f(world, o, x, y, who) end
    end
    return function(x, y, who)
        local k = 1
        for i = 1, #fns do k = k * fns[i][1](world, fns[i][2], x, y, who) end
        return k
    end
end

function Director:weatherEffects(env)
    local w = self.world.weather
    local eff = w and w.def.effects
    if not eff or Settings.get("weatherEffects") == false then return end
    local k = w:strength()
    if k <= 0 then return end
    if eff.playerSpeed then env.playerSpeed = env.playerSpeed * util.lerp(1, eff.playerSpeed, k) end
    if eff.enemySpeed then env.enemySpeed = env.enemySpeed * util.lerp(1, eff.enemySpeed, k) end
    if eff.drift and w.def.wind then
        -- the wind blows across the screen; turn that into a push along the ground
        local sx, sy = w.def.wind[1], w.def.wind[2]
        local gust = 0.75 + 0.25 * math.sin(self.world.time * 0.9) + 0.15 * math.sin(self.world.time * 2.3)
        env.driftX = env.driftX + (sy + sx * 0.5) * eff.drift * k * gust
        env.driftY = env.driftY + (sy - sx * 0.5) * eff.drift * k * gust
    end
    -- say so once when a spell that changes things settles in
    if k >= 0.5 and self.weatherSeen ~= w.def then
        self.weatherSeen = w.def
        if self.world.mode == "run" and not self.world.flags.demo then
            self:announce(w.def.name, eff.note, eff.color or { 0.6, 0.85, 1 })
        end
    end
end

function Director:update(dt)
    local world = self.world
    local sp = world.spawner
    local env = envReset(world.env)
    -- scheduled events and the boss come in as the wave goes on
    if sp.phase == "wave" then
        for i = #self.schedule, 1, -1 do
            local s = self.schedule[i]
            if sp.waveTime >= s.at then
                table.remove(self.schedule, i)
                self:start(s.def)
            end
        end
        local pb = self.pendingBoss
        if pb and sp.waveTime >= pb.at then
            self.pendingBoss = nil
            self:startBoss(pb.def)
        end
    end
    for i = #self.active, 1, -1 do
        local ev = self.active[i]
        if ev then
            ev.t = ev.t + dt
            Env.current = ev.def.id
            if ev.def.update then ev.def.update(world, ev, dt) end
            Env.current = nil
            if ev.def.env then ev.def.env(world, ev, env) end
            if ev.done or (ev.life and ev.t >= ev.life) then self:stop(ev) end
        end
    end
    local m = self.mechanic
    if m then
        m.t = m.t + dt
        Env.current = m.def.id
        if m.def.update then m.def.update(world, m, dt) end
        Env.current = nil
        if m.def.env then m.def.env(world, m, env) end
    end
    -- the stage hazard (sparrow, anteater): hunts until the wave is cleared, then leaves
    local h = self.hazard
    if h then
        h.t = h.t + dt
        Env.current = h.def.id
        if h.leaving then
            h.leaving = h.leaving + dt
            if h.def.leave then h.def.leave(world, h, dt) end
            if h.gone or h.leaving >= (h.def.leaveTime or 3) then self.hazard = nil end
        else
            if h.def.update then h.def.update(world, h, dt) end
            if h.def.env then h.def.env(world, h, env) end
            -- it only stays a while: after `stay` seconds it has eaten its fill and moves on
            if h.def.stay and h.t >= h.def.stay and not h.leaving then self:endHazard(true) end
        end
        Env.current = nil
    end
    self:weatherEffects(env)
    env.field = makeField(self)
    -- the encounter boss: its own update hook, and the bar goes when it falls
    local enc = self.encounter
    if enc then
        enc.t = enc.t + dt
        if enc.e.dead or enc.e.uid ~= enc.uid then
            self.encounter = nil
            if enc.def.finish then enc.def.finish(world, enc) end
            world.milestone = { text = (enc.def.slain or (enc.def.name:upper() .. " DRIVEN OFF")), t = 0 }
            world:hitStop(0.1)
            world.camera:shake(0.5)
            Audio.play("boom", { pitch = 0.55 })
            if enc.def.xp then world:grantXP(enc.def.xp, enc.e.x, enc.e.y) end
            world.events:emit("encounter_won", enc.def.id)
        elseif enc.def.update then
            enc.def.update(world, enc.e, enc, dt)
        end
    end
    self:updateHoles(dt)
    self.gambles:update(dt)
    world.props:update(dt)
    world.props:dashHits()
    for i = #self.banners, 1, -1 do
        local b = self.banners[i]
        b.t = b.t + dt
        if b.t >= b.life then table.remove(self.banners, i) end
    end
end

----------------------------------------------------------------------------------------------
-- The player's attacks: props in reach get batted, nest holes in reach take a hit.

-- params: the move's params, if known (its damage sets how hard props are batted).
function Director:playerAttacked(ax, ay, params)
    local world = self.world
    local p = world.player
    if p.dead then return end
    local range = p:attackRange()
    local power = params and params.damage and math.max(0.75, math.min(1.7, 0.7 + params.damage / 30)) or 1
    world.props:attacked(p.x, p.y, ax or p.aimX, ay or p.aimY, range, power)
    local sp = world.spawner
    for _, h in ipairs(sp.holes or {}) do
        if not h.closing then
            local dx, dy = h.x - p.x, h.y - p.y
            local d = math.sqrt(dx * dx + dy * dy)
            if d <= range + 12 and (d < 20 or (dx * (ax or 0) + dy * (ay or 0)) / (d + 0.001) > -0.2) then
                self:hitHole(h, 1)
            end
        end
    end
end

Director.HOLE_HP = 3

function Director:hitHole(h, n)
    if h.closing or h.sealed then return end
    local world = self.world
    h.hp = (h.hp or Director.HOLE_HP) - (n or 1)
    h.puff = 0.3
    world.particles:burst(h.x, h.y, 8, { { 0.42, 0.31, 0.2 }, { 0.3, 0.21, 0.14 } }, 60, 60, { grav = 300 })
    Audio.play("hit", { pitch = 0.6 })
    if h.hp > 0 then
        world:floatText(h.x, h.y - 6, ("%d more"):format(h.hp), { 1, 0.8, 0.5 })
        return
    end
    self:collapseHole(h)
end

-- Seal a nest hole: groups still waiting in it never come out.
function Director:collapseHole(h)
    local world, sp = self.world, self.world.spawner
    h.sealed, h.closing = true, 0.5
    local saved = 0
    for i = #sp.queue, 1, -1 do
        local g = sp.queue[i]
        if g.hole == h then
            saved = saved + g.count
            table.remove(sp.queue, i)
        end
    end
    world.particles:burst(h.x, h.y, 20, { { 0.42, 0.31, 0.2 }, { 0.6, 0.5, 0.35 }, { 0.3, 0.21, 0.14 } }, 110, 100, { grav = 300, stain = true })
    world.camera:shake(0.25)
    Audio.play("rumble", { pitch = 1.3 })
    world:floatText(h.x, h.y - 10, saved > 0 and ("NEST SEALED  -" .. saved .. " ants") or "NEST SEALED", { 1, 0.85, 0.4 }, true)
    world:grantXP(3 + math.floor(saved / 10), h.x, h.y)
    world.events:emit("nest_sealed", saved)
end

-- Dashing over an open hole stamps it in one go.
function Director:updateHoles()
    local world = self.world
    local p = world.player
    local dashing = not p.dead and p.dashT > 0
    if dashing and not self.wasDashing then self.dashNo = (self.dashNo or 0) + 1 end
    self.wasDashing = dashing
    if not dashing then return end
    for _, h in ipairs(world.spawner.holes or {}) do
        if not h.closing and (h.x - p.x) ^ 2 + (h.y - p.y) ^ 2 < (p.radius + 12) ^ 2 and h.stampedBy ~= self.dashNo then
            h.stampedBy = self.dashNo
            self:hitHole(h, Director.HOLE_HP)
        end
    end
end

----------------------------------------------------------------------------------------------
-- Drawing

function Director:drawGround()
    local world = self.world
    local m = self.mechanic
    if m and m.def.drawGround then m.def.drawGround(world, m) end
    for _, ev in ipairs(self.active) do
        if ev.def.drawGround then ev.def.drawGround(world, ev) end
    end
    local enc = self.encounter
    if enc and enc.def.drawGround then enc.def.drawGround(world, enc.e, enc) end
    local hz = self.hazard
    if hz and hz.def.drawGround then hz.def.drawGround(world, hz) end
    -- cracks on nest holes that have been hit
    local lg = love.graphics
    for _, h in ipairs(world.spawner.holes or {}) do
        if h.hp and h.hp < Director.HOLE_HP and not h.closing then
            local x, y = Iso.toScreen(h.x, h.y)
            lg.setColor(0.85, 0.7, 0.45, 0.9)
            for s = 1, Director.HOLE_HP - h.hp do
                local a = s * 2.1 + h.seed
                lg.line(x, y + 1, x + math.cos(a) * 16, y + 1 + math.sin(a) * 8)
            end
        end
    end
    lg.setColor(1, 1, 1, 1)
end

function Director:drawProps()
    self.world.props:draw()
end

function Director:drawAir()
    local world = self.world
    local m = self.mechanic
    if m and m.def.drawAir then m.def.drawAir(world, m) end
    for _, ev in ipairs(self.active) do
        if ev.def.drawAir then ev.def.drawAir(world, ev) end
    end
    local enc = self.encounter
    if enc and enc.def.drawAir then enc.def.drawAir(world, enc.e, enc) end
    world.props:drawAir()
    local hz = self.hazard
    if hz and hz.def.drawAir then hz.def.drawAir(world, hz) end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Banners and the encounter's health bar (called from src/ui/hud.lua).
function Director.drawHud(game, covered)
    local world = game.world
    local self = world and world.director
    if not self or covered then return end
    local Theme = require("src.ui.theme")
    local lg = love.graphics
    local w, h = lg.getDimensions()
    local u = Theme.u
    local enc = self.encounter
    if enc and not enc.e.dead then
        local bw = math.min(u(420), w * 0.42)
        local bx, by = (w - bw) / 2, h - u(world.boss and not world.boss.dead and 118 or 70)
        lg.setFont(Theme.font(16))
        Theme.printShadow((enc.e.title or enc.def.name):upper(), 0, by - u(22), { 1, 0.65, 0.45, 1 }, "center", w)
        lg.setColor(0.1, 0.05, 0.08, 0.9)
        lg.rectangle("fill", bx - 2, by - 2, bw + 4, u(10) + 4)
        lg.setColor(0.95, 0.5, 0.2, 1)
        lg.rectangle("fill", bx, by, bw * math.max(0, enc.e.hp / enc.e.maxHp), u(10))
    end
    -- a hazard has no health bar: its name, and what it is doing right now
    local hz = self.hazard
    if hz and not hz.leaving and not (enc and not enc.e.dead) then
        local by = h - u(world.boss and not world.boss.dead and 118 or 70)
        lg.setFont(Theme.font(16))
        Theme.printShadow((hz.def.title or hz.def.name):upper() .. "  -  STAGE HAZARD", 0, by - u(22), { 1, 0.65, 0.45, 1 }, "center", w)
        if hz.label then
            local pulse = hz.danger and (0.65 + 0.35 * math.sin(world.time * 14)) or 0.85
            lg.setFont(Theme.font(15, "bold"))
            local c = hz.danger and { 1, 0.35, 0.25, pulse } or { 0.95, 0.88, 0.75, pulse }
            Theme.printShadow(hz.label, 0, by, c, "center", w)
        end
    end
    world.props:drawLabels(function() return Theme.font(13, "bold") end)
    local y = h * 0.62
    for i = #self.banners, 1, -1 do
        local b = self.banners[i]
        local k = math.min(1, b.t / 0.25, (b.life - b.t) / 0.6)
        local c = b.color
        lg.setFont(Theme.font(b.big and 34 or 26, "bold"))
        Theme.printShadow(b.title:upper(), 0, y - (1 - k) * u(8), { c[1], c[2], c[3], k }, "center", w)
        if b.sub and b.sub ~= "" then
            lg.setFont(Theme.font(15))
            Theme.printShadow(b.sub, 0, y + u(b.big and 38 or 30), { 0.92, 0.9, 0.85, k }, "center", w)
        end
        y = y - u(72)
    end
    lg.setColor(1, 1, 1, 1)
end

return Director
