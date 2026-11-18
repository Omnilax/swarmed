-- One arena run: player, enemies, effects, camera and the spatial hash that keeps it fast.
local Content = require("src.content")
local Settings = require("src.core.settings")
local Screen = require("src.core.screen")
local Iso = require("src.core.iso")
local Events = require("src.core.events")
local SpatialHash = require("src.core.spatialhash")
local Audio = require("src.core.audio")
local util = require("src.core.util")
local Sprites = require("src.gfx.sprites")
local Anim = require("src.gfx.anim")
local Particles = require("src.gfx.particles")
local Ground = require("src.gfx.ground")
local Camera = require("src.game.camera")
local Player = require("src.game.player")
local Enemy = require("src.game.enemy")
local Spawner = require("src.game.spawner")
local Entries = require("src.game.entries")
local Inventory = require("src.game.inventory")
local Hazards = require("src.game.hazards")
local Elites = require("src.game.elites")
local Combat = require("src.game.combat")
local Grab = require("src.game.grab")
local Daylight = require("src.game.daylight")
local Lighting = require("src.gfx.lighting")
local Shading = require("src.gfx.shading")
local Clarity = require("src.gfx.clarity")
local CamFx = require("src.gfx.camfx")
local Ambience = require("src.gfx.ambience")
local Weather = require("src.game.weather")
local Cosmetics = require("src.game.cosmetics")
local RunStats = require("src.game.runstats")
local Director = require("src.game.director")
local Nectar = require("src.game.nectar")

-- particle colours and options, made once (not a new table every frame)
local PFX_1 = { 1, 0.95, 0.7 }
local PFX_2 = { glow = true, grav = 60 }
local PFX_3 = { 1, 1, 1 }
local PFX_4 = { glow = true, grav = 120 }
local PFX_5 = { 0.55, 0.42, 0.3 }
local PFX_6 = { 0.4, 0.3, 0.22 }
local PFX_7 = { grav = 300 }
local PFX_8 = { 0.75, 0.95, 0.35 }
local PFX_9 = { glow = true, grav = -15 }
local PFX_10 = { 0.6, 1, 0.3 }
local PFX_11 = { glow = true, grav = -10 }
local PFX_LIST_1 = { PFX_1 }
local PFX_LIST_2 = { PFX_5, PFX_6 }

-- death spray: options for droplets that do / don't leave a stain, and a scratch colour
local STAIN, NO_STAIN = { stain = true, grav = 380 }, { stain = false, grav = 380 }
local DROP = { 0, 0, 0 }
local function setRGB(t, r, g, b) t[1], t[2], t[3] = r, g, b return t end

local World = {}
World.__index = World

World.ENEMY_CAP = 2000

-- opts: stage (id), character (id), mode ("run" | "sandbox"), gameMode (content/modes id,
-- default "colony"), customWaves (a wave set, src/game/customwaves.lua; Custom Waves mode), startItems (item ids given at the start: the endless mode's loadout)
function World.new(opts)
    local self = setmetatable({}, World)
    self.mode = opts.mode or "run"
    -- the run's seed: the daily run passes a fixed one, so its waves are the same for everyone
    self.seed = opts.seed or (os.time() * 1000 + love.math.random(0, 999))
    self.daily = opts.daily
    love.math.setRandomSeed(self.seed)
    self.modeDef = Content.modes:get(opts.gameMode or "colony") or Content.modes:all()[1]
    -- Custom Waves: the set picked in the wave builder (or the one a saved run carried)
    if self.modeDef.custom then
        self.modeDef = require("src.game.customwaves").modeDef(self.modeDef, opts.customWaves)
        self.customWaves = self.modeDef.set
    end
    self.gameMode = self.modeDef.id
    -- danger level of this run (src/config/danger.lua): every level adds one rule
    self.danger = require("src.game.unlocks").dangerRules(opts.danger or 0)
    -- no stage given: the location picked in Cosmetics
    self.stage = Content.stages:require(opts.stage or Cosmetics.location())
    self.size = self.stage.size
    self.events = Events.new()
    self.time, self.timeScale = 0, 1
    self.enemies, self.enemyCount = {}, 0
    self.hash = SpatialHash.new(16)
    self.particles = Particles.new(2500)
    self.ground = Ground.new(self.stage)
    Cosmetics.paintDecor(self.ground, self.stage)
    self.fx, self.texts, self.pendingSplats = {}, {}, {}
    self.corpses = {}
    self.thrown = {}        -- ants flying through the air (src/game/grab.lua)
    self.hazards = Hazards.new(self)
    self.deferred = {}      -- death effects run next frame (so chain reactions can't recurse)
    self.attackers = 0      -- ants biting the player this frame
    self.frameSlow = 1      -- see World:slowPlayer
    self.latchCount = 0
    self.shieldCount = 0    -- live shield ants (turtle ants), lets combat skip the shield check
    self.boss = nil
    -- kills of the last frame ({x, y, id}), so behaviours can react (scatter, rally...)
    self.recentDeaths, self.deathsNow = { n = 0 }, { n = 0 }
    self.hitstop, self.killsThisFrame, self.hitstopCd, self.decalFadeT = 0, 0, 0, 0
    self.floorBudget = 40   -- bodies that may still leave pools and remains (refills over time)
    self.bonusPicks = 0     -- extra cards in the next item choice (queens slain)
    self.xp = 0             -- XP earned this run (see World:grantXP)
    -- nectar: the run's currency (src/game/nectar.lua has the API); beads and ground pickups
    self.nectar, self.nectarEarned, self.nectarSpent = 0, 0, 0
    self.freezeT = 0        -- frost pickup: every enemy frozen while > 0
    self.beads = Nectar.new(self)
    -- a cleared wave sweeps every bead left on the floor to the player
    self.events:on("wave_cleared", function() self.beads:magnet() end)
    self.milestone = nil
    self.drawList = {}
    self.flags = { god = false, freezeAI = false }
    self.kos, self.combo, self.bestCombo, self.comboTimer = 0, 0, 0, 0
    -- damage by source, kills by species, hits taken (src/game/runstats.lua)
    self.runStats = RunStats.new(self)

    -- level-up card picks (src/game/levelups.lua); made before the player, whose skills ask it
    self.levelups = require("src.game.levelups").new(self)
    local charId = opts.character or Content.characters:all()[1].id
    self.player = Player.new(self, Content.characters:require(charId), self.size / 2, self.size / 2)
    self.spawner = Spawner.new(self, self.stage)
    self.spawner.enabled = self.mode == "run"
    for _, id in ipairs(opts.startItems or {}) do self:giveItem(id) end

    local sx, sy = Iso.toScreen(self.player.x, self.player.y)
    self.camera = Camera.new(sx, sy)
    self.weather = Weather.new(self)
    self.events:on("wave_cleared", function() CamFx.onWaveCleared(self) end)
    -- frenzy meter, streak buffs, mini-goals, treasure ant, route gates (src/game/rewards.lua)
    self.rewards = require("src.game.rewards").new(self)
    -- molting after a queen wave, brood cell chests opening by themselves when the wave ends
    self.molts = 0
    self.events:on("wave_cleared", function() self:onWaveClearedMolting() end)
    self.route = nil        -- the route gate taken into this wave (content/routes), if any
    -- mid-wave events, boss encounters, stage mechanics, weather effects, props (world.env, world.props)
    self.director = Director.new(self)
    -- Gentle Start: systems held back over a new player's first runs, with a "NEW" card each
    require("src.game.onramp").attach(self)
    -- artifacts (content/artifacts): run rules switched on before the run
    require("src.game.artifacts").apply(self, opts.artifacts)
    -- a keepsake (src/config/keepsakes.lua): one small trade carried into the run
    require("src.game.keepsakes").apply(self, opts.keepsake)
    -- queens with phases, the Empress, named champions (src/game/bosses.lua)
    require("src.game.bosses").attach(self)
    -- Playtest Log (Settings > Developer): a CSV line per wave in the save folder
    require("src.game.playlog").attach(self)
    -- the guided tutorial (content/modes/tutorial.lua): lessons instead of waves
    require("src.game.lessons").attach(self)
    -- wave rewards as moments in the arena: the reward bloom, rewards flying in, gain cards
    self.rewardFlow = require("src.game.rewardflow").new(self)
    -- kill-dash refunds and chained dashes (src/game/dashtech.lua), the bug's own rule (src/game/bugrules.lua)
    require("src.game.dashtech").attach(self)
    require("src.game.bugrules").attach(self)
    -- skin: recoloured in drawing (Cosmetics.shader), or a whole other model
    local skin = Cosmetics.skinFor(charId)
    self.player.skin = skin
    if skin and skin.model then self.player.model = skin.model end
    return self
end

-- 0 at night .. 1 in full daylight (worked out once per frame).
function World:daylight()
    if self._dayT ~= self.time then self._dayT, self._day = self.time, Daylight.level(self.stage, self.time) end
    return self._day
end

-- Behaviours that slow the player while something holds (silk strands, latched jaws) call this
-- every frame; the slowest wins and it resets after the hazards pass reads it.
function World:slowPlayer(mul)
    if mul < self.frameSlow then self.frameSlow = mul end
end

function World:hpScale()
    local m = self.modeDef
    local sp = self.spawner
    return m.enemyHp * (1 + (sp and math.max(0, sp.wave - 1) * (m.hpPerWave or 0.12) or 0))
        * (sp and require("src.game.pacing").hpMul(sp) or 1)
        * (self.route and self.route.hpMul or 1)
        * (self.danger and self.danger.hpMul or 1)

end

----------------------------------------------------------------------------------------------
-- Enemies

-- elite (optional): an elite affix (id or def) from content/elites.
function World:spawnEnemy(def, x, y, elite)
    if self.enemyCount >= World.ENEMY_CAP then return nil end
    if type(def) == "string" then def = Content.enemies:require(def) end
    if type(elite) == "string" then elite = Content.elites:require(elite) end
    local S = self.size
    local e = Enemy.spawn(self, def, util.clamp(x, def.radius, S - def.radius), util.clamp(y, def.radius, S - def.radius), elite)
    self.enemyCount = self.enemyCount + 1
    self.enemies[self.enemyCount] = e
    if self.spawner then require("src.game.pacing").onSpawn(self.spawner, e) end
    -- the first of a species this run (the HUD's first-sighting popup listens)
    local rs = self.runStats
    if rs and not rs.seen[def.id] then
        rs.seen[def.id] = true
        self.events:emit("species_seen", def, e)
    end
    if elite then self.events:emit("elite_spawned", e) end
    CamFx.onSpawn(self, e)
    return e
end

-- Spawn `n` enemies in a ring around a point (sandbox / console helper).
function World:spawnRing(def, n, cx, cy, radius, elite)
    for i = 1, n do
        local a = (i / n) * math.pi * 2 + love.math.random() * 0.3
        local r = radius + love.math.random() * 40
        self:spawnEnemy(def, cx + math.cos(a) * r, cy + math.sin(a) * r, elite)
    end
end

function World:killEnemy(e)
    if e.dead then return end
    e.dead = true
    self.events:emit("enemy_died", e)      -- every death, whatever killed it (run records)
    local def = e.def
    self.kos = self.kos + 1
    self.killsThisFrame = self.killsThisFrame + 1
    if e.elite or def.boss or def.encounter then Lighting.pop(self, e.x, e.y, def.boss or def.encounter) end
    -- nectar beads worth the enemy's `xp` (plus a gilded elite's bonusXP): skill XP and
    -- nectar once collected; maybe a ground pickup (src/game/nectar.lua)
    if not e.noBeads then self.beads:onKill(e) end
    if self.kos % 100 == 0 then
        self.milestone = { text = self.kos .. " KO!", t = 0 }
        Audio.play("ui_confirm", { pitch = 0.8 })
        self.camera:shake(0.2)
    end
    local dn = self.deathsNow
    if dn.n < 64 then
        dn.n = dn.n + 1
        local k = dn[dn.n] or {}
        k.x, k.y, k.id = e.x, e.y, def.id
        dn[dn.n] = k
    end
    self.combo = self.combo + 1
    self.bestCombo = math.max(self.bestCombo, self.combo)
    self.comboTimer = 2.5
    local gibs = def._gibColors
    if not gibs then
        gibs = {}
        for i, c in ipairs(def.gibs) do gibs[i] = util.hex(c) end
        def._gibColors = gibs
        def._splatColor = util.hex(def.splat)
    end
    -- Direction of the killing blow (knockback), or away from the player.
    local dx, dy = e.kvx, e.kvy
    local l = math.sqrt(dx * dx + dy * dy)
    if l < 1 then
        dx, dy = e.x - self.player.x, e.y - self.player.y
        l = math.sqrt(dx * dx + dy * dy) + 0.001
    end
    local nx, ny = dx / l, dy / l
    local decals = Settings.get("decals")
    local blood = def._splatColor
    -- The floor has a budget: in a big massacre only some bodies leave a pool and remains, so
    -- the ground shows the carnage without turning into one solid mat.
    local mark = decals and self.floorBudget >= 1
    if mark then self.floorBudget = self.floorBudget - 1 end

    -- Hemolymph: a splat on the floor, plus droplets sprayed along the blow that stain where they land.
    if mark then
        self.pendingSplats[#self.pendingSplats + 1] = { kind = "splat", e.x, e.y, blood, e.radius * 1.6, nx, ny }
    end
    local base = math.atan2(ny, nx)
    for _ = 1, Particles.count(8 + e.radius * 2) do
        local a = base + (love.math.random() - 0.5) * 1.3
        local s = 50 + love.math.random() * 140
        local j = (love.math.random() - 0.5) * 0.1
        self.particles:spawn(e.x, e.y, 3, math.cos(a) * s, math.sin(a) * s, 30 + love.math.random() * 70,
            -- (spawn copies the colour, so one scratch table does for every droplet)
            1.2, setRGB(DROP, blood[1] + j, blood[2] + j, blood[3] + j), 1, (mark and love.math.random() < 0.5) and STAIN or NO_STAIN)
    end
    -- Body bits: legs and fragments that tumble and stay on the ground.
    for _ = 1, Particles.count(2 + e.radius * 0.6) do
        local a = love.math.random() * math.pi * 2
        local s = 30 + love.math.random() * 90
        local c = gibs[love.math.random(#gibs)]
        self.particles:spawn(e.x, e.y, 4, math.cos(a) * s, math.sin(a) * s, 60 + love.math.random() * 80,
            1.2, c, love.math.random() < 0.4 and 2 or 1, mark and STAIN or NO_STAIN)
    end
    self.particles:burst(e.x, e.y, 2, PFX_LIST_1, 40, 30, PFX_2)

    -- The body gets knocked away spinning, Warriors style, then stays on the floor as remains.
    if #self.corpses >= 150 then
        -- too many bodies in the air: this one drops straight to the floor as remains
        if mark then self.pendingSplats[#self.pendingSplats + 1] = { kind = "remains", e.sprite, e.x, e.y, e.angle, e.scale } end
    else
        local speed = (70 + math.min(l, 250) * 0.6 + love.math.random() * 40) / e.mass ^ 0.5
        self.corpses[#self.corpses + 1] = {
            sprite = e.sprite, x = e.x, y = e.y, z = 2, angle = e.angle, scale = e.scale,
            vx = nx * speed, vy = ny * speed, vz = 60 + love.math.random() * 50,
            spin = (love.math.random() - 0.5) * 30, t = 0, life = 0.6, shadow = e.shadow, mark = mark,
            style = Ambience.styleOf(e.def),
        }
    end
    local ksx, ksy = Iso.toScreen(e.x, e.y)
    Audio.play("kill", { pitch = 1 + math.min(self.combo, 80) * 0.008, sx = ksx, sy = ksy })
    local elite = e.elite
    if elite then
        local c = Elites.color(elite)
        self.particles:burst(e.x, e.y, 10, { c, PFX_3 }, 90, 70, PFX_4)
        -- gilded elites: a big bead of bonus XP (added in Nectar:onKill)
        if elite.onDeath then
            local x, y = e.x, e.y
            self.deferred[#self.deferred + 1] = function() elite.onDeath(self, x, y, e) end
        end
    end
    if def.onDeath then
        local x, y, info = e.x, e.y, { selfDestruct = e.st.exploded }
        self.deferred[#self.deferred + 1] = function() def.onDeath(self, x, y, def, info) end
    end
    if def.boss then
        -- a queen: whatever touches in the bag molts once this wave is cleared, and she leaves a
        -- brood cell chest behind (src/game/molting.lua, content/props/brood_cell.lua)
        self.queenThisWave = true
        local x, y = e.x, e.y
        self.deferred[#self.deferred + 1] = function() self:dropChest(x, y, "queen") end
    end
    if self.boss == e then
        self.boss = nil
        -- a slain queen adds one more card to the item choice after the wave
        self.bonusPicks = math.min(2, self.bonusPicks + 1)
        require("src.game.choices").onQueen(self)   -- and some item choice rerolls back
        self:floatText(e.x, e.y - 20, "+1 ITEM CHOICE", { 1, 0.9, 0.4 }, true)
        self.milestone = { text = def.name:upper() .. " SLAIN", t = 0 }
        self.hitstop = math.max(self.hitstop, self.rewards.cfg.feel.queenStop)
        self.camera:shake(0.6)
        Audio.play("boom", { pitch = 0.6 })
        if decals then
            for _ = 1, 6 do
                self.pendingSplats[#self.pendingSplats + 1] = { kind = "splat", e.x + (love.math.random() - 0.5) * 20, e.y + (love.math.random() - 0.5) * 20, blood, 8, nx, ny }
            end
        end
        self.events:emit("boss_killed", e)
    end
end

-- A brood cell chest at (x, y): kind "queen" or "treasure" (odds in src/config/molting.lua).
-- Walk into it to open it; one still shut when the wave ends opens by itself.
function World:dropChest(x, y, kind)
    if not self.props then return nil end
    local o = self.props:spawn("brood_cell", x, y, { kind = kind or "queen" })
    self.events:emit("chest_dropped", o)
    return o
end

-- Queue a chest's fanfare (src/states/broodcell.lua, opened by Game:update before the item choice).
function World:openChest(kind, x, y)
    self.pendingChests = self.pendingChests or {}
    local list = self.pendingChests
    list[#list + 1] = { kind = kind or "queen", x = x, y = y }
end

function World:onWaveClearedMolting()
    if self.queenThisWave then
        self.queenThisWave = nil
        require("src.game.molting").afterQueenWave(self)
    end
    -- chests nobody opened pop open now
    if self.props then
        for _, o in ipairs(self.props:find("brood_cell")) do o.def.open(self, o) end
    end
end

-- An enemy leaves the arena without being killed (a courier gets home, a treasure ant burrows
-- away): no KO, no XP, no death effects.
function World:escapeEnemy(e, text)
    if e.dead then return end
    e.dead, e.escaped = true, true
    if self.boss == e then self.boss = nil end
    self.particles:burst(e.x, e.y, 10, PFX_LIST_2, 60, 50, PFX_7)
    if text then self:floatText(e.x, e.y, text, { 1, 0.6, 0.4 }, true) end
    self.events:emit("enemy_escaped", e)
end

function World:clearEnemies()
    self.boss = nil
    self.hash:clear()
    self.shieldCount = 0
    self.hazards:clear()
    if self.spawner then require("src.game.entries").clear(self.spawner) end
    self.thrown = {}
    for i = 1, self.enemyCount do
        Enemy.release(self.enemies[i])
        self.enemies[i] = nil
    end
    self.enemyCount = 0
end

-- Each call gets its own result list (pooled, recycled every frame). Content code damages
-- enemies while looping over the list, and a kill can set off another query (death bursts,
-- procs); with one shared list that inner query wiped the outer loop's list mid-iteration.
function World:queryEnemies(x, y, r)
    local pool = self.queryPool
    if not pool then pool = { n = 0 } self.queryPool = pool end
    local i = pool.n + 1
    pool.n = i
    local out = pool[i]
    if not out then out = {} pool[i] = out end
    return self.hash:query(x, y, r, out)
end

function World:nearestEnemy(x, y, maxR)
    local list, n = self.hash:query(x, y, maxR)
    local best, bestD = nil, maxR * maxR
    for i = 1, n do
        local e = list[i]
        if not e.dead and not e.hidden then
            local dx, dy = e.x - x, e.y - y
            local d = dx * dx + dy * dy
            if d < bestD then best, bestD = e, d end
        end
    end
    return best
end

----------------------------------------------------------------------------------------------
-- Items

-- A random item instance, weighted by rarity (src/config/rarities.lua) and the current wave.
function World:rollItem()
    local Rarities = require("src.config.rarities")
    local wave = self.spawner and math.max(1, self.spawner.wave) or 1
    local def = Content.items:pickWeighted(function(d) return Rarities[d.rarity].weight end,
        function(d) return Rarities[d.rarity].minWave <= wave and not Rarities[d.rarity].cursed end) or Content.items:all()[1]
    return Inventory.newItem(def.id)
end

-- Items never lie on the ground. Whatever does not fit in the bag is eaten on the spot
-- (it heals, like eating it from the inventory).
function World:overflowItem(item)
    local p = self.player
    local hp = p.inventory:eat(item)
    self:floatText(p.x, p.y, "Bag full: ate " .. item.def.name .. (hp > 0 and (" +" .. hp .. " HP") or ""), { 1, 0.6, 0.4 }, false)
end

-- Give items to the player (into the bag). Returns how many did not fit (and were eaten).
function World:giveItem(id, n)
    local left = self.player.inventory:add(id, n)
    for _, item in ipairs(left) do self:overflowItem(item) end
    return #left
end

----------------------------------------------------------------------------------------------
-- Effects and feedback

-- fx kinds: "arc" (slash: x, y, r, a, arc, dir = 1 | -1 sweep direction), "ring" (shockwave:
-- x, y, r), "stab" (thrust: x, y, x2, y2, w width, z height), "streak" (dash trail: x, y, x2, y2,
-- w), "bolt" (lightning: x, y, x2, y2). All need life; color is optional.
function World:addFx(fx)
    fx.t = 0
    self.fx[#self.fx + 1] = fx
end

-- e (optional): the enemy hit. With "Combine Damage Numbers" on, quick hits on the same enemy
-- add up into one number that keeps counting instead of a spray of small ones.
function World:damageNumber(x, y, value, crit, e)
    local mode = Settings.get("damageNumbers")
    if mode == "off" or (mode == "crits" and not crit) then return end
    if e and Settings.get("combineDamageNumbers") then
        local t = e._dmgText
        if t and not t.gone and t.t < 0.45 and t.owner == e then
            t.value = t.value + value
            t.text = tostring(t.value)
            t.t, t.z, t.vz = 0, math.max(t.z, 10), 30
            t.x, t.y = e.x, e.y
            if crit and not t.big then t.big, t.color, t.life = true, { 1, 0.85, 0.2 }, 0.9 end
            return
        end
        t = self:floatText(x, y, tostring(value), crit and { 1, 0.85, 0.2 } or { 1, 1, 1 }, crit)
        t.value, t.owner, t.life = value, e, t.life + 0.2
        e._dmgText = t
        return
    end
    self:floatText(x, y, tostring(value), crit and { 1, 0.85, 0.2 } or { 1, 1, 1 }, crit)
end

-- XP for the skill tree: collected nectar beads (kills) and bonus sources (goals, treasure)
-- go through here. Only bonus amounts (more than 1) float a number, and `quiet` (bead pickups)
-- floats none, so sweeping up a trail doesn't spam the screen.
function World:grantXP(amount, x, y, quiet)
    if not amount or amount <= 0 then return end
    if self.xpMul then amount = amount * self.xpMul end
    self.xp = (self.xp or 0) + amount
    if self.player and self.player.skills then self.player.skills:gainXP(amount) end
    self.events:emit("xp_gained", amount, x, y)
    if amount > 1 and x and not quiet then self:floatText(x, y, "+" .. amount .. " XP", { 0.55, 0.9, 1 }, true) end
end

----------------------------------------------------------------------------------------------
-- Nectar (the run's currency; see src/game/nectar.lua for the whole API)

function World:addNectar(amount, x, y)
    if not amount or amount <= 0 then return end
    -- a keepsake can change what you earn (src/game/keepsakes.lua)
    if self.nectarMul then amount = math.max(1, math.floor(amount * self.nectarMul + 0.5)) end
    self.nectar = self.nectar + amount
    self.nectarEarned = self.nectarEarned + amount
    self.events:emit("nectar_changed", self.nectar, amount)
    if x and amount > 1 then self:floatText(x, y, "+" .. amount .. " nectar", { 1, 0.8, 0.3 }, true) end
end

function World:canAffordNectar(amount) return self.nectar >= (amount or 0) end

-- Pay `amount`. Returns false (and changes nothing) when the balance is short.
function World:spendNectar(amount)
    amount = amount or 0
    if amount < 0 or self.nectar < amount then return false end
    if amount == 0 then return true end
    self.nectar = self.nectar - amount
    self.nectarSpent = self.nectarSpent + amount
    self.events:emit("nectar_changed", self.nectar, -amount)
    return true
end

function World:dropNectar(x, y, value) return self.beads:drop(x, y, value) end
function World:magnetNectar() self.beads:magnet() end
function World:dropPickup(id, x, y) return self.beads:dropPickup(id, x, y) end

-- Every enemy freezes stiff for `t` seconds (no moving, no biting).
function World:freezeEnemies(t)
    local was = self.freezeT > 0
    self.freezeT = math.max(self.freezeT, t or 2)
    self.frostAt = self.time        -- Frost Dew won't drop again for a while (content/pickups/freeze.lua)
    if not was then
        local p = self.player
        self:addFx({ kind = "ring", x = p.x, y = p.y, r = 160, life = 0.5, color = { 0.6, 0.9, 1 } })
        Audio.play("zap", { pitch = 0.6 })
        self.events:emit("enemies_frozen", self.freezeT)
    end
end

function World:floatText(x, y, text, color, big)
    if #self.texts > 50 then table.remove(self.texts, 1).gone = true end
    local t = {
        x = x + (love.math.random() - 0.5) * 8, y = y, z = 14, vz = 40,
        text = text, color = color, big = big, t = 0, life = big and 0.9 or 0.6,
    }
    self.texts[#self.texts + 1] = t
    return t
end

-- Context table handed to proc effects. See content/items/_template.lua.
function World:procContext(target, damage, crit, depth)
    return { world = self, player = self.player, target = target, damage = damage, crit = crit,
        x = target.x, y = target.y, procDepth = depth }
end

----------------------------------------------------------------------------------------------
-- A short freeze for a heavy hit (big punches, molts, encounters). Respects the Hit Stop
-- setting and is scaled down by rewards feel.stopScale so freezes stay rare and brief.
function World:hitStop(t)
    if not Settings.get("hitstop") then return end
    self.hitstop = math.max(self.hitstop or 0, t * (self.rewards.cfg.feel.stopScale or 1))
end

-- Update

function World:update(dt)
    dt = dt * self.timeScale * (Settings.get("gameSpeed") / 100)
    dt = dt * self.rewards:timeScale(dt)       -- slow motion on big moments
    if self.queryPool then self.queryPool.n = 0 end

    -- Hitstop: freeze the action for a few frames after a big multi-kill.
    if self.hitstop > 0 then
        self.hitstop = self.hitstop - dt
        self.camera:update(dt)
        return
    end
    self.time = self.time + dt
    Lighting.update(self, dt)
    Shading.update(self, dt)
    Ambience.update(self, dt)
    self.killsThisFrame = 0
    -- last frame's kills become visible to behaviours; start a fresh list
    self.recentDeaths, self.deathsNow = self.deathsNow, self.recentDeaths
    self.deathsNow.n = 0
    self.latchCount = 0     -- driver ants hanging on to the player (latcher behaviour)

    local hash = self.hash
    hash:clear()
    local enemies = self.enemies
    for i = 1, self.enemyCount do hash:insert(enemies[i]) end

    local deferred = self.deferred
    if #deferred > 0 then
        self.deferred = {}
        for k = 1, #deferred do deferred[k]() end
    end

    self.player:update(dt)
    self.spawner:update(dt)
    self:updateEnemies(dt)
    if self.freezeT > 0 then self.freezeT = math.max(0, self.freezeT - dt) end
    self.beads:update(dt)
    Grab.update(self, dt)
    self.hazards:update(dt)
    self.director:update(dt)
    require("src.game.bosses").update(self, dt)
    self.rewardFlow:update(dt)
    require("src.game.economy").update(self, dt)     -- the shop restocks every minute or so
    if self.finalSwarm then self.finalSwarm:update(dt) end     -- the optional last stand (src/game/finalswarm.lua)
    self:pushPlayerOutOfSolids()

    -- Remove the dead, keeping the array packed.
    local n = self.enemyCount
    local i = 1
    while i <= n do
        local e = enemies[i]
        if e.dead then
            Enemy.release(e)
            enemies[i] = enemies[n]
            enemies[n] = nil
            n = n - 1
        else
            i = i + 1
        end
    end
    self.enemyCount = n

    self.particles:update(dt)
    self.weather:update(dt)
    local landed = self.particles.landed
    if #landed > 0 then
        for k = 1, #landed do self.pendingSplats[#self.pendingSplats + 1] = landed[k] end
        self.particles.landed = {}
    end
    self:updateCorpses(dt)
    if self.milestone then
        self.milestone.t = self.milestone.t + dt
        if self.milestone.t > 1.6 then self.milestone = nil end
    end
    -- Cooldown so constant mass kills give a punchy beat now and then instead of a stutter.
    if self.hitstopCd > 0 then self.hitstopCd = self.hitstopCd - dt end
    local feel = self.rewards.cfg.feel
    if self.killsThisFrame >= feel.stopKills and Settings.get("hitstop") and self.hitstopCd <= 0 then
        self.hitstop = math.min(feel.stopMax, feel.stopMin + self.killsThisFrame * feel.stopPerKill)
        self.hitstopCd = feel.stopCooldown
        self.camera:shake(math.min(0.4, self.killsThisFrame * 0.02))
    end
    for j = #self.fx, 1, -1 do
        local fx = self.fx[j]
        fx.t = fx.t + dt
        if fx.t >= fx.life then table.remove(self.fx, j) end
    end
    for j = #self.texts, 1, -1 do
        local t = self.texts[j]
        t.t = t.t + dt
        t.z = t.z + t.vz * dt
        t.vz = t.vz * (1 - util.damp(6, dt))
        if t.t >= t.life then table.remove(self.texts, j).gone = true end
    end

    self.decalFadeT = self.decalFadeT + dt
    self.floorBudget = math.min(40, self.floorBudget + dt * 25)
    if self.comboTimer > 0 then
        self.comboTimer = self.comboTimer - dt
        if self.comboTimer <= 0 then self.combo = 0 end
    end

    self.rewards:update(dt)

    local p = self.player
    local px, py = Iso.toScreen(p.x, p.y)
    local ax, ay = Iso.toScreen(p.aimX, p.aimY)
    CamFx.update(self, dt)                      -- auto-zoom, framing, size zoom (src/gfx/camfx.lua)
    self.camera:follow(px, py - 4, ax, ay)
    self.camera:update(dt)
end

-- Solid enemies (leafcutter walls) block the player, except while dashing through them.
function World:pushPlayerOutOfSolids()
    local p = self.player
    if p.dead or p.dashT > 0 then return end
    local list, n = self.hash:query(p.x, p.y, p.radius + 12)
    for i = 1, n do
        local e = list[i]
        if e.def.solid and not e.dead then
            local dx, dy = p.x - e.x, p.y - e.y
            local r = p.radius + e.radius
            local d2 = dx * dx + dy * dy
            if d2 < r * r and d2 > 0.0001 then
                local d = math.sqrt(d2)
                p.x, p.y = e.x + dx / d * r, e.y + dy / d * r
            end
        end
    end
end

function World:updateCorpses(dt)
    local list = self.corpses
    for i = #list, 1, -1 do
        local c = list[i]
        c.t = c.t + dt
        if c.t >= c.life then
            if c.mark and Settings.get("decals") then
                self.pendingSplats[#self.pendingSplats + 1] = { kind = "remains", c.sprite, c.x, c.y, c.angle, c.scale }
            end
            list[i] = list[#list]
            list[#list] = nil
        else
            c.x = util.clamp(c.x + c.vx * dt, 0, self.size)
            c.y = util.clamp(c.y + c.vy * dt, 0, self.size)
            c.vz = c.vz - 400 * dt
            c.z = c.z + c.vz * dt
            if c.z <= 0 then
                c.z = 0
                c.vz = -c.vz * 0.3
                c.vx, c.vy = c.vx * 0.5, c.vy * 0.5
                c.spin = c.spin * 0.5
            end
            c.angle = c.angle + c.spin * dt
        end
    end
end

-- While the player is camouflaged (player.cloakT set: pistol shrimp cloak, wolf spider) the
-- ants lose track of it: each behaviour sees a decoy at a spot near where the player was last
-- seen, wandering a little, so they mill about there. Anything a behaviour tries to do to the
-- decoy (sting it, slow it) does nothing.
local decoyMeta = { __newindex = function() end }
local function noop() end
local function decoyFor(world, e, p, decoy)
    if e.lostId ~= p.cloakT then
        e.lostId = p.cloakT
        local a = love.math.random() * math.pi * 2
        local r = 20 + love.math.random() * 50
        e.lostX, e.lostY = p.x + math.cos(a) * r, p.y + math.sin(a) * r
    end
    -- the guess drifts as they search
    e.lostX = e.lostX + math.sin(world.time * 0.7 + e.uid) * 0.4
    e.lostY = e.lostY + math.cos(world.time * 0.6 + e.uid * 1.3) * 0.4
    rawset(decoy, "x", e.lostX)
    rawset(decoy, "y", e.lostY)
    return decoy
end

function World:updateEnemies(dt)
    local enemies, hash, p = self.enemies, self.hash, self.player
    local unseen = p.cloakT ~= nil and not p.dead
    local decoy
    if unseen then
        decoy = setmetatable({ vx = 0, vy = 0, z = 0, kvx = 0, kvy = 0 }, {
            __newindex = decoyMeta.__newindex,
            __index = function(_, k)
                local v = p[k]
                if k == "attackRange" then return function() return p:attackRange() end end     -- a read, safe to pass through
                if type(v) == "function" then return noop end
                return v
            end })
    end
    local S = self.size
    local iced = self.freezeT > 0       -- the frost pickup: frozen solid, no bites
    local freeze = self.flags.freezeAI or iced
    local kDamp = 1 - util.damp(8, dt)
    local attackers, shields = 0, 0
    local env = self.env
    local envK, envField = env.enemySpeed, env.field
    -- a curse in the bag (Queen's Pheromone) speeds every ant up
    local curseK = self.player and self.player.inventory and self.player.inventory:sum("enemySpeed") or 0
    if curseK ~= 0 then envK = envK * math.max(0.2, 1 + curseK) end
    local driftX, driftY = env.driftX, env.driftY
    if freeze then envK, driftX, driftY, envField = 1, 0, 0, nil end
    local sqrt = math.sqrt
    local atan2 = math.atan2
    local floor = math.floor
    local cells, cellS = hash.cells, hash.size     -- (SpatialHash keys cells as cx * 65536 + cy)
    -- the visible area (projected), with a margin, for the off-screen shortcut below
    local vw, vh = Screen.viewW or 960, Screen.viewH or 540
    local ox, oy = self.camera:origin(vw, vh)
    local vx0, vy0, vx1, vy1 = ox - 80, oy - 80, ox + vw + 80, oy + vh + 80
    self.frameNo = (self.frameNo or 0) + 1
    local frameNo = self.frameNo
    for i = 1, self.enemyCount do
        local e = enemies[i]
        if not e.dead then
            if e.spawnT > 0 then e.spawnT = e.spawnT - dt end
            -- held in jaws or flying through the air: whoever holds it moves it
            if e.held then
                -- carried off by another bug (cicada killer) that has since died: dropped
                local by = e.heldBy
                if by and (by.dead or by.uid ~= e.heldByUid) then e.held, e.heldBy, e.z = nil, nil, 0 end
                if e.flash > 0 then e.flash = e.flash - dt end
                if e.hurtTimer > 0 then e.hurtTimer = e.hurtTimer - dt end
            else -- (no goto: the web build runs plain Lua 5.1)
            if freeze then
                e.mx, e.my = 0, 0
            elseif e.dropH then
                -- coming down from the sky (Entries "drop"): falls into the fight, then flies on
                e.dropH = e.dropH - dt * (40 + e.dropH * 3)
                if e.dropH <= 0 then e.dropH = nil end
                e.mx, e.my = 0, 0
            elseif e.stunT > 0 then
                -- stunned (hissing roach): stands reeling, can't move or bite
                e.stunT = e.stunT - dt
                e.mx, e.my = 0, 0
            elseif e.lure and not unseen then
                -- going for something else (a critter a mini-goal has you guard)
                self.player = e.lure
                e.behavior.update(e, self, dt, e.params)
                self.player = p
            elseif unseen then
                self.player = decoyFor(self, e, p, decoy)
                self.actingEnemy = e
                e.behavior.update(e, self, dt, e.params)
                self.player = p
            else
                self.actingEnemy = e     -- hazards it makes remember who (death recap)
                e.behavior.update(e, self, dt, e.params)
            end
            self.actingEnemy = nil
            if e.corrodeT > 0 then
                e.corrodeT = e.corrodeT - dt
                if love.math.random() < dt * 5 then
                    self.particles:spawn(e.x, e.y, 4, 0, 0, 16, 0.4, PFX_8, 1, PFX_9)
                end
            end
            if e.poisonT > 0 then
                -- venom ticks twice a second
                e.poisonT = e.poisonT - dt
                e.poisonTick = e.poisonTick + dt
                if e.poisonTick >= 0.5 then
                    e.poisonTick = e.poisonTick - 0.5
                    Combat.damage(self, e, e.poisonDps * 0.5, { noCrit = true, dot = true, procDepth = Combat.MAX_PROC_DEPTH, source = e.poisonSrc or "Poison" })
                    self.particles:spawn(e.x, e.y, 6, 0, 0, 20, 0.4, PFX_10, 1, PFX_11)
                end
                if e.poisonT <= 0 then e.poisonDps = 0 end
            end
            if e.slowT > 0 then
                e.slowT = e.slowT - dt
                e.mx, e.my = e.mx * e.slowMul, e.my * e.slowMul
            end

            -- Separation (push apart) and flocking (match neighbours' heading) in one pass.
            -- personalSpace < 1 lets swarming ants pack tightly into one dark mass.
            local def = e.def
            local sx, sy, checks = 0, 0, 0
            local ax, ay, an = 0, 0, 0
            local r0 = e.radius
            local space = def.personalSpace or 1
            local flock = def.flock or 0
            -- The grid cells are walked directly (no copied result list), and the walk stops
            -- as soon as both caps (6 pushes, 8 flock mates) are reached: in a dense crowd a
            -- query covers dozens of ants and most of them would be skipped anyway.
            -- Off screen, the crowd only sorts itself out every other frame (alternating halves
            -- of the horde): nobody sees it, and it halves the cost of the far side of a big wave.
            local ex, ey = e.x, e.y
            local psx, psy = ex - ey, (ex + ey) * 0.5
            local lazy = (psx < vx0 or psx > vx1 or psy < vy0 or psy > vy1) and (e.uid + frameNo) % 2 == 0
            if not e.hidden and not lazy then    -- burrowed: passes under the crowd
                local em = e.mass
                local qr = flock > 0 and r0 * 4 or r0 * 2
                local x0, x1 = floor((ex - qr) / cellS), floor((ex + qr) / cellS)
                local y0, y1 = floor((ey - qr) / cellS), floor((ey + qr) / cellS)
                local needFlock = flock > 0
                local cx = x0
                while cx <= x1 do
                    local cy = y0
                    while cy <= y1 do
                        local cell = cells[cx * 65536 + cy]
                        if cell then
                            for j = 1, cell.n do
                                local o = cell[j]
                                if o ~= e and not o.hidden then
                                    if checks < 6 then
                                        local dx, dy = ex - o.x, ey - o.y
                                        local r = (r0 + o.radius) * space
                                        local d2 = dx * dx + dy * dy
                                        if d2 < r * r and d2 > 0.0001 then
                                            local d = sqrt(d2)
                                            local push = (r - d) / d * (o.mass / (em + o.mass))
                                            sx, sy = sx + dx * push, sy + dy * push
                                            checks = checks + 1
                                        end
                                    end
                                    if needFlock and o.def == def and an < 8 then
                                        ax, ay, an = ax + o.mx, ay + o.my, an + 1
                                    end
                                    if checks >= 6 and (not needFlock or an >= 8) then break end
                                end
                            end
                            if checks >= 6 and (not needFlock or an >= 8) then cy = y1 cx = x1 end
                        end
                        cy = cy + 1
                    end
                    cx = cx + 1
                end
            end
            if an > 0 and not freeze then
                local l = sqrt(ax * ax + ay * ay)
                if l > 0.001 then
                    local mx = e.mx * (1 - flock) + ax / l * e.speed * flock
                    local my = e.my * (1 - flock) + ay / l * e.speed * flock
                    local ml = sqrt(mx * mx + my * my) + 0.0001
                    e.mx, e.my = mx / ml * e.speed, my / ml * e.speed
                end
            end

            -- the arena's pull on it (src/game/director.lua): weather, water, sun and shade
            local k = envK
            if envField then k = k * envField(ex, ey, e) end
            local wk = def._windK
            if not wk then wk = 1 / math.sqrt(math.max(0.2, def.mass)) def._windK = wk end
            e.x = util.clamp(e.x + (e.mx * k + e.kvx + driftX * wk) * dt + sx * 0.6, r0, S - r0)
            e.y = util.clamp(e.y + (e.my * k + e.kvy + driftY * wk) * dt + sy * 0.6, r0, S - r0)
            e.kvx, e.kvy = e.kvx * kDamp, e.kvy * kDamp

            -- Turn to face the direction of travel on screen.
            local svx, svy = e.mx - e.my, (e.mx + e.my) * 0.5
            if svx * svx + svy * svy > 1 then
                local target = atan2(svy, svx)
                e.angle = e.angle + util.angleDiff(e.angle, target) * math.min(1, dt * 10)
                -- leg animation speed follows actual walking speed
                e.anim = e.anim + dt * e.sprite.fps * math.min(1.6, sqrt(e.mx * e.mx + e.my * e.my) / e.def.speed)
            end
            if e.flash > 0 then e.flash = e.flash - dt end
            if e.squash > 0 then e.squash = e.squash - dt end
            if e.hurtTimer > 0 then e.hurtTimer = e.hurtTimer - dt end
            if e.biteCd > 0 then e.biteCd = e.biteCd - dt end
            if def.shield then shields = shields + 1 end
            local el = e.elite
            if el and el.sparkle and love.math.random() < dt * 6 then
                self.particles:spawn(e.x + (love.math.random() - 0.5) * 8, e.y + (love.math.random() - 0.5) * 8, 4 + love.math.random() * 6,
                    0, 0, 14, 0.5, { 1, 0.92, 0.5 }, 1, { glow = true, grav = 0 })
            end

            -- Bites: every ant touching you bites on its own timer, so damage grows with the
            -- size of the crowd on you (and armour reduces every single bite).
            local dx, dy = p.x - e.x, p.y - e.y
            local rr = p.radius + r0 + 1
            if dx * dx + dy * dy < rr * rr and e.damage > 0 and e.z < 3 and not e.dropH and (p.z < 4 or p.airborne) and not e.hidden and e.stunT <= 0 and not unseen and not iced then
                attackers = attackers + 1
                if e.biteCd <= 0 then
                    e.biteCd = (def.biteRate or 0.9) * (0.85 + love.math.random() * 0.3)
                    p:hurt(e.damage, e)
                    local venom = def.venom or (e.elite and e.elite.venom)
                    if venom then p:poison(venom.dps * e.damage / math.max(0.1, def.damage), venom.time) end
                    e.squash = 0.1
                end
            end
        end
        end
    end
    self.attackers = attackers
    self.shieldCount = shields
end

----------------------------------------------------------------------------------------------
-- Drawing

function World:mouseWorld()
    local vx, vy = Screen.toView(love.mouse.getPosition())
    local ox, oy = self.camera:origin(Screen.viewW, Screen.viewH)
    return Iso.toWorld(vx + ox, vy + oy)
end

-- World position -> window pixel position (for text drawn at full resolution).
function World:toWindow(x, y, z)
    local sx, sy = Iso.toScreen(x, y, z)
    local ox, oy = self.camera:origin(Screen.viewW, Screen.viewH)
    return Screen.fromView(sx - ox, sy - oy)
end

-- Must run before the world canvas is bound: paints queued splats onto the ground.
function World:flushDecals()
    -- Fade old stains: every half second, scale the whole decal layer down a little (and take
    -- off one step so faint leftovers reach zero), so stains and remains melt away evenly
    -- instead of darkening into black blots.
    local fade = Settings.get("decalFade")
    if fade > 0 and self.decalFadeT >= 0.5 then
        local m = 0.03 ^ (self.decalFadeT / fade)
        self.decalFadeT = 0
        love.graphics.push("all")
        love.graphics.setCanvas(self.ground.decals)
        love.graphics.origin()
        love.graphics.setBlendMode("multiply", "premultiplied")
        love.graphics.setColor(m, m, m, m)
        love.graphics.rectangle("fill", 0, 0, self.ground.decals:getDimensions())
        love.graphics.setBlendMode("subtract", "premultiplied")
        local d = 1.5 / 255
        love.graphics.setColor(d, d, d, d)
        love.graphics.rectangle("fill", 0, 0, self.ground.decals:getDimensions())
        love.graphics.pop()
    end
    if #self.pendingSplats == 0 then return end
    love.graphics.push("all")
    love.graphics.setCanvas(self.ground.decals)
    local g = self.ground
    local pools = 0
    for _, s in ipairs(self.pendingSplats) do
        -- full pools are pricier to paint; past 80 in one frame the rest become simple drops
        if s.kind == "splat" and pools < 80 then pools = pools + 1; g:splat(s[1], s[2], s[3], s[4], s[5], s[6])
        elseif s.kind == "splat" then g:drop(s[1], s[2], s[3], 2)
        elseif s.kind == "remains" then g:stamp(s[1], s[2], s[3], s[4], s[5])
        else g:drop(s[1], s[2], s[3], s[4]) end
    end
    love.graphics.pop()
    self.pendingSplats = {}
end

-- Insertion sort by depth: the draw list keeps last frame's order, which is almost sorted
-- already, so this is close to linear (table.sort would redo all the work every frame).
local function sortByDepth(list, n)
    for i = 2, n do
        local o = list[i]
        local d = o.x + o.y
        local j = i - 1
        while j >= 1 and list[j].x + list[j].y > d do
            list[j + 1] = list[j]
            j = j - 1
        end
        list[j + 1] = o
    end
end

function World:draw()
    Lighting.nq = 0
    local vw, vh = Screen.viewW, Screen.viewH
    local ox, oy = self.camera:origin(vw, vh)
    local atlas = Sprites.atlas
    local lg = love.graphics
    lg.push()
    lg.translate(-ox, -oy)

    local gsh = Clarity.groundShader()           -- Background Dim / Actors Pop
    if gsh then lg.setShader(gsh) end
    self.ground:draw()
    if gsh then lg.setShader() end
    Shading.drawWet(self, ox, oy, vw, vh)           -- Wet Ground after rain
    Ambience.drawGround(self)                       -- Horde Tracks
    Ambience.drawDecor(self)                        -- Night Glow Decor
    self.hazards:drawGround()
    Entries.drawGround(self.spawner, self.time)     -- burrow mounds, landing shadows, nest holes
    self.rewards:drawGround()                       -- route tunnels, guarded critters
    require("src.game.pacing").drawGuard(self, self.time)   -- a guarded queen's gold ring
    self.director:drawGround()                      -- puddles, pits, lane warnings, shadows overhead

    -- View culling bounds in projected space.
    local cx0, cy0, cx1, cy1 = ox - 40, oy - 40, ox + vw + 40, oy + vh + 60

    -- Keep the enemy array itself depth-sorted; frame to frame it barely changes.
    sortByDepth(self.enemies, self.enemyCount)
    local list, n = self.drawList, 0
    local p = self.player
    for i = 1, self.enemyCount do
        local e = self.enemies[i]
        local sx, sy = Iso.toScreen(e.x, e.y)
        if sx > cx0 and sx < cx1 and sy > cy0 and sy < cy1 then
            n = n + 1
            list[n] = e
            e._sx, e._sy = sx, sy
        end
    end
    if not p.dead then
        n = n + 1
        list[n] = p
        p._sx, p._sy = Iso.toScreen(p.x, p.y)
    end
    for i = n + 1, #list do list[i] = nil end
    sortByDepth(list, n)

    -- nectar beads and ground pickups (one sprite batch)
    self.beads:draw(cx0, cy0, cx1, cy1)

    -- Swarm underlay: soft dark blobs that merge dense crowds into one flowing mass.
    local glowQ = Sprites.glow
    local iced = self.freezeT > 0
    for i = 1, n do
        local o = list[i]
        local sw = o.def and not o.hidden and o.def.swarmShade
        if sw then
            lg.setColor(0.08, 0.04, 0.03, sw)
            lg.draw(atlas, glowQ, o._sx, o._sy + 1, 0, o.radius * 0.6, o.radius * 0.4, 8, 8)
        end
        if o.rival == "red" and not o.hidden then
            -- a rival colony's ant (colony war): a red mark under it
            lg.setColor(1, 0.25, 0.15, 0.45)
            lg.draw(atlas, glowQ, o._sx, o._sy + 1, 0, o.radius * 0.45 + 1, o.radius * 0.25 + 0.5, 8, 8)
        end
        if iced and o ~= p and not o.hidden then
            -- frozen by the frost pickup: an icy patch under every enemy
            lg.setColor(0.55, 0.85, 1, 0.55)
            lg.draw(atlas, glowQ, o._sx, o._sy + 1, 0, o.radius * 0.5 + 1, o.radius * 0.3 + 0.5, 8, 8)
        end
        if o.elite and not o.hidden then
            -- a coloured aura on the ground marks elites even in a dense swarm
            local c = Elites.color(o.elite)
            lg.setColor(c[1], c[2], c[3], 0.35 + 0.15 * math.sin(self.time * 5 + o.uid))
            lg.draw(atlas, glowQ, o._sx, o._sy + 1, 0, o.radius * 0.45 + 1, o.radius * 0.25 + 0.5, 8, 8)
        end
    end

    -- Sun Shadows and Contact Shadows (src/gfx/shading.lua)
    Shading.drawGround(self, list, n)
    -- Shadows first (all one texture -> batched).
    lg.setColor(1, 1, 1, 1)
    for i = 1, n do
        local o = list[i]
        local sh = o.shadow
        if not o.hidden then lg.draw(atlas, sh.quad, math.floor(o._sx - sh.w / 2 + 1), math.floor(o._sy - sh.h / 2 + 3)) end
    end
    if Settings.get("playerOutline") and not p.dead then
        lg.setColor(1, 0.9, 0.3, 0.9)
        lg.draw(atlas, Sprites.ring, math.floor(p._sx - 10), math.floor(p._sy - 4))
        lg.setColor(1, 1, 1, 1)
    end

    Clarity.drawCompass(self)                       -- Danger Compass
    -- Pebbles, twigs, cocoons, allies, the merchant (src/game/props.lua)
    self.director:drawProps()

    -- Things behaviours put in the world (silk strands, feeding threads): always drawn.
    for i = 1, n do
        local o = list[i]
        if o.behavior and o.behavior.drawUnder then o.behavior.drawUnder(o, self) end
    end
    lg.setColor(1, 1, 1, 1)

    if p.dashDef and p.dashDef.draw then p.dashDef.draw(p, self, p.dashParams) end
    if p.secondary and p.secondary.type.draw then p.secondary.type.draw(p, self, p.secondary.params) end
    if p.attack and p.attack.type.draw then p.attack.type.draw(p, self, p.attack.params) end
    if p.def.custom then require("src.game.scriptmoves").draw(p, self) end
    -- stunned ants (hissing roach) see stars
    for i = 1, n do
        local o = list[i]
        if o ~= p and o.stunT > 0 and not o.hidden then Combat.drawDazed(o) end
    end
    if not p.dead and p.stunT > 0 then Combat.drawDazed(p) end
    if p.blocking then
        -- braced: a shimmering guard in front of the claws
        lg.setColor(0.7, 0.85, 1, 0.5 + 0.2 * math.sin(self.time * 20))
        local bx, by = Iso.toScreen(p.x + p.aimX * 8, p.y + p.aimY * 8, 3)
        lg.ellipse("line", bx, by, 9, 5)
    end

    -- Enemy telegraphs (charges, lunges...)
    if Settings.get("telegraphs") then
        -- High-Contrast Warnings: thicker lines with a dark outline drawn first (src/ui/palette.lua)
        local hc = Settings.get("telegraphContrast")
        if hc then
            World.edgeShader = World.edgeShader or lg.newShader([[
                vec4 effect(vec4 c, Image t, vec2 tc, vec2 sc) { return vec4(0.0, 0.0, 0.0, Texel(t, tc).a * c.a); }
            ]])
            lg.setLineWidth(3)
            lg.setShader(World.edgeShader)
            for i = 1, n do
                local o = list[i]
                if o.behavior and o.behavior.draw then o.behavior.draw(o, self) end
            end
            lg.setShader()
            lg.setLineWidth(1.5)
        end
        for i = 1, n do
            local o = list[i]
            if o.behavior and o.behavior.draw then o.behavior.draw(o, self) end
        end
        if hc then lg.setLineWidth(1) end
        lg.setColor(1, 1, 1, 1)
    end

    -- Knocked-away bodies (darkened, spinning, fading).
    for _, c in ipairs(self.corpses) do
        local sx, sy = Iso.toScreen(c.x, c.y, c.z)
        if sx > cx0 and sx < cx1 and sy > cy0 and sy < cy1 then
            local k = math.min(1, c.t / (c.life * 0.6))
            local v = 0.8 - k * 0.38
            lg.setColor(v, v * 0.92, v * 0.88, 1)
            local ca, csx, csy = Ambience.corpseStyle(c)         -- Death Styles
            Sprites.draw(c.sprite, 1, sx, sy, ca, false, csx, csy)
        end
    end
    lg.setColor(1, 1, 1, 1)

    local flashOk = Settings.get("hitFlash") and not Settings.get("reduceFlashing")
    Clarity.drawOutlines(self, list, n)             -- Threat Outlines
    Shading.drawRims(self, list, n)                 -- Rim Light (enemies, one batch)
    local hordeDepth = Settings.get("hordeDepth")
    local squash = Settings.get("squashStretch")
    local sheens, nSheen = self.sheens, 0
    if not sheens then sheens = {} self.sheens = sheens end
    for i = 1, n do
        local o = list[i]
        local flash = flashOk and o.flash > 0
        local sxs, sys = o.scale or 1, o.scale or 1
        if o == p then
            if p.alpha then
                lg.setColor(1, 1, 1, p.alpha)      -- cloaked (pistol shrimp)
            elseif p.iframes > 0 and p.dashT <= 0 and math.floor(p.iframes * 20) % 2 == 0 then
                lg.setColor(1, 1, 1, 0.4)
            end
            if p.dashT > 0 then
                sxs, sys = 1.15, 0.85
            elseif p.moving then
                local w = math.sin(p.anim * 1.6) * 0.05
                sxs, sys = 1 + w, 1 - w
            end
            local ps = p.def.scale      -- bigger bugs (lobster) draw their model larger
            if ps then sxs, sys = sxs * ps, sys * ps end
        else
            if o.spawnT > 0 then
                local k = 1 - o.spawnT / 0.2 * 0.7
                sxs, sys = sxs * k, sys * k
            end
            if o.squash > 0 then
                local k = o.squash / 0.12
                sxs, sys = sxs * (1 + 0.3 * k), sys * (1 - 0.25 * k)
            end
        end
        local skinShader = o == p and Cosmetics.shader(p.skin)
        if skinShader then lg.setShader(skinShader) end
        if o.model and o.hidden then
            -- burrowed underground (camel spider): nothing to draw
        elseif o.model then
            local _, _, _, a = lg.getColor()
            -- dash afterimages
            for _, g in ipairs(o.model.kind ~= "chain" and o.ghosts or {}) do
                local gx, gy = Iso.toScreen(g.x, g.y)
                Sprites.drawModel(o.model, math.floor(g.anim) + 1, gx, gy, g.wangle, false, 1, 1, 0.45 * (1 - g.t / 0.22), { tint = { 0.55, 0.8, 1 } })
            end
            -- body pose: steps bob the body, attacks lunge it forward over planted legs,
            -- hits knock it back, and standing still it slowly breathes
            local pose = o._pose or {}
            o._pose = pose
            local moving = o.moving or o.dashT > 0
            pose.bob = moving and ((math.floor(o.anim) % 4 < 2) and 1 or 0) or ((o.idleT % 1.6 < 0.8) and 1 or 0)
            -- rearing up for a slam
            if o.rear then pose.bob = pose.bob + math.min(1, o.rear.t / o.rear.time) * 5 end
            local lx, ly = 0, 0
            if o.lungeT > 0 then
                local k = math.sin((1 - o.lungeT / 0.18) * math.pi) * 3
                lx, ly = (o.aimX - o.aimY) * k, (o.aimX + o.aimY) * 0.5 * k
            end
            if o.recoilT > 0 then
                local k = o.recoilT / 0.2 * 2
                lx, ly = lx - (o.aimX - o.aimY) * k + (love.math.random() - 0.5), ly - (o.aimX + o.aimY) * 0.5 * k
            end
            pose.bx, pose.by = lx, ly
            -- legs: a smooth step cycle, with the feet swinging the way the bug is walking
            pose.phase = (o.anim % 8) / 8
            local spd = math.sqrt((o.vx or 0) ^ 2 + (o.vy or 0) ^ 2)
            if spd > 5 then
                local d = math.atan2(o.vy, o.vx) - o.wangle
                pose.gu, pose.gv = math.cos(d), math.sin(d)
            else
                pose.gu, pose.gv = 1, 0
            end
            if o.chain then
                -- segment screen offsets from the head, with a travelling side-to-side ripple
                pose.chain = pose.chain or {}
                local ripple = math.min(1, spd / 100) * 0.9
                local prev = o
                for i, seg in ipairs(o.chain) do
                    local a = math.atan2(prev.y - seg.y, prev.x - seg.x)
                    local w = math.sin(o.anim * 0.9 - i * 0.75) * ripple * math.min(1, i / 3)
                    local wx, wy = seg.x - o.x - math.sin(a) * w, seg.y - o.y + math.cos(a) * w
                    -- tail stab: the last segments lunge out backwards
                    local ts = o.tailStab
                    if ts then
                        local reachK = math.max(0, i - (#o.chain - 4)) / 4
                        local k = math.sin(ts.t / 0.22 * math.pi) * reachK * 14
                        wx, wy = wx + ts.dx * k, wy + ts.dy * k
                    end
                    local c = pose.chain[i] or {}
                    pose.chain[i] = c
                    c[1], c[2], c[3] = (wx - wy) * sxs, (wx + wy) / 2 * sys, a
                    prev = seg
                end
                pose.gu, pose.gv = 1, 0
            end
            pose.tint = o.venomT > 0 and { 0.85 + 0.15 * math.sin(self.time * 10), 0.7, 1 } or nil
            -- o.reversed: facing backwards (centipede aiming its rear end)
            local facing = o.reversed and o.wangle + math.pi or o.wangle
            Anim.applyTo(pose, Anim.sample(o), facing, sxs, sys)    -- attack clips (src/gfx/anim.lua)
            if o.lungeT > 0.09 then sxs, sys = sxs * 1.06, sys * 0.94 end
            if o == p and not p.alpha then Shading.drawPlayerRim(self, o.model, math.floor(o.anim) + 1, o._sx, o._sy - o.z - (o.dropH or 0), facing, sxs, sys, pose) end
            Sprites.drawModel(o.model, math.floor(o.anim) + 1, o._sx, o._sy - o.z - (o.dropH or 0), facing, flash, sxs, sys, a, pose)
        elseif o ~= p and o.def.drawBody then
            -- big creatures drawn by their own code (encounter bosses: content/enemies/predators.lua)
            if not o.hidden then o.def.drawBody(o, self, o._sx, o._sy, sxs, sys, flash) end
        elseif not o.hidden then
            local el = o.elite
            local alpha = o.alpha or 1
            if el then
                -- elites: tinted towards their colour, plus a pulsing additive sheen
                local c = Elites.color(el)
                lg.setColor(0.5 + c[1] * 0.5, 0.5 + c[2] * 0.5, 0.5 + c[3] * 0.5, alpha)
            elseif o.tint then
                lg.setColor(o.tint[1], o.tint[2], o.tint[3], alpha)     -- a rival colony (colony war)
            elseif alpha < 1 then
                lg.setColor(1, 1, 1, alpha)
            end
            -- Horde Depth: the back of a big pack a little darker than the front
            local dk = hordeDepth and not el and Clarity.depthShade(math.sqrt((o.x - p.x) ^ 2 + (o.y - p.y) ^ 2))
            if dk then
                local r, g, b, a2 = lg.getColor()
                lg.setColor(r * dk, g * dk, b * dk, a2)
                o._dk = true
            end
            local fy = o._sy - (o.z or 0) - (o.dropH or 0)
            if squash and (o.flash or 0) > 0 then sxs, sys = sxs * 1.14, sys * 0.86 end     -- Squash & Stretch
            Sprites.draw(o.sprite, math.floor(o.anim) + 1, o._sx, fy, o.angle, flash, sxs, sys)
            if el then
                -- the sheen is drawn after the crowd in one additive batch (switching blend modes
                -- per elite split the sprite batch twice for every elite on screen)
                nSheen = nSheen + 1
                local sh = sheens[nSheen]
                if not sh then sh = {} sheens[nSheen] = sh end
                sh.o, sh.y, sh.sx, sh.sy, sh.a = o, fy, sxs, sys, alpha
            end
        end
        if skinShader then lg.setShader() end
        -- plain ants leave the colour white; skip the reset for them (it adds up in a horde)
        if o == p or o.model or o.elite or o.tint or (o.alpha or 1) < 1 or o.def.drawBody or o._dk then lg.setColor(1, 1, 1, 1) o._dk = nil end
    end

    if nSheen > 0 then
        lg.setBlendMode("add")
        for i = 1, nSheen do
            local sh = sheens[i]
            local o = sh.o
            local el = o.elite
            local c = Elites.color(el)
            lg.setColor(c[1], c[2], c[3], el.glow * (0.75 + 0.25 * math.sin(self.time * 6 + o.uid)) * sh.a)
            Sprites.draw(o.sprite, math.floor(o.anim) + 1, o._sx, sh.y, o.angle, false, sh.sx, sh.sy)
            sh.o = nil
        end
        lg.setBlendMode("alpha")
        lg.setColor(1, 1, 1, 1)
    end

    -- Enemy health bars (pixel quads keep them in the batch).
    local hb = Settings.get("enemyHealthBars")
    if hb ~= "off" then
        local q = Sprites.pixel
        for i = 1, n do
            local e = list[i]
            local show = false
            if e ~= p and not e.hidden then
                if hb == "always" then show = true
                elseif hb == "elites" then show = (e.elite ~= nil or e.def.boss) and e.hp < e.maxHp
                else show = e.hp < e.maxHp and e.hurtTimer > 0 end
            end
            if show then
                local w = math.max(8, e.sprite.w - 4)
                local x = math.floor(e._sx - w / 2)
                local y = math.floor(e._sy - e.sprite.h * 0.5 * e.scale - 5)
                lg.setColor(0.1, 0.05, 0.08, 0.9)
                lg.draw(atlas, q, x - 1, y - 1, 0, w + 2, 3)
                lg.setColor(0.95, 0.3, 0.3, 1)
                lg.draw(atlas, q, x, y, 0, math.max(1, math.floor(w * e.hp / e.maxHp)), 1)
            end
        end
        lg.setColor(1, 1, 1, 1)
    end

    self.particles:draw(cx0, cy0, cx1, cy1)
    self.hazards:drawAir()
    self.director:drawAir()
    self.weather:draw(ox, oy, vw, vh)
    self:drawLighting(ox, oy, list, n)
    Shading.drawRays(self, ox, oy, vw, vh)          -- Sun Rays at golden hour and dawn
    Ambience.drawLeaves(self, ox, oy, vw, vh)       -- Falling Leaves
    CamFx.drawForeground(self, ox, oy, vw, vh)      -- Foreground Grass
    self.weather:drawGlow(ox, oy, vw, vh)
    if self.freezeT > 0 then
        -- frost pickup: a cold blue wash over the arena while the swarm is frozen
        lg.setColor(0.55, 0.85, 1, 0.12 * math.min(1, self.freezeT * 2))
        lg.rectangle("fill", ox, oy, vw, vh)
        lg.setColor(1, 1, 1, 1)
    end
    if (p.blindT or 0) > 0 and not Settings.get("lighting") then
        lg.setColor(0, 0, 0, 0.75 * math.min(1, p.blindT / 0.6))
        lg.rectangle("fill", ox, oy, vw, vh)
        lg.setColor(1, 1, 1, 1)
    end

    -- Additive glow pass: attack swooshes, sparks, explosions.
    -- (Glare Guard / Own Effects Opacity: drawn on their own layer and soft-capped, src/gfx/lighting.lua)
    local fxLayer = Lighting.fxLayer()
    if fxLayer then Lighting.beginFx() end
    lg.setBlendMode("add")
    self:drawFx()
    self.particles:drawGlow(cx0, cy0, cx1, cy1)
    lg.setBlendMode("alpha")
    if fxLayer then Lighting.endFx() end
    if Settings.get("shotsOnTop") then self.hazards:drawAir(true) end     -- Enemy Shots On Top
    Clarity.drawSilhouette(self)                    -- See-Through Silhouettes
    if Settings.get("showHitboxes") then self:drawHitboxes(list, n) end
    if Settings.get("showSpatialGrid") then self:drawGrid() end
    lg.pop()
end

-- Lighting: the scene is multiplied by a light map that starts at the ambient colour for the
-- time of day (src/game/daylight.lua) and is brightened by additive lights: the player, effects, glowing sparks and any
-- enemy whose definition has `light = { radius, color }`.
function World:drawLighting(ox, oy, list, n)
    if not Settings.get("lighting") then return end
    local lg = love.graphics
    local r0, g0, b0 = Daylight.ambient(self.stage, self.time)
    local d = Settings.get("darkness") / 100
    local ar, ag, ab = 1 + (r0 - 1) * d, 1 + (g0 - 1) * d, 1 + (b0 - 1) * d
    -- clouds (rain, storms) dim the daylight; lightning briefly floods it
    local wm = self.weather:ambientMul()
    local fl = self.weather.flash * self.weather:strength() * 0.5
    ar, ag, ab = ar * wm + fl, ag * wm + fl, ab * wm + fl
    -- blinded (venom sprayed in the eyes): everything past arm's reach goes nearly black
    local blind = math.min(1, (self.player.blindT or 0) / 0.6)
    if blind > 0 then
        local k = 1 - 0.85 * blind
        ar, ag, ab = ar * k, ag * k, ab * k
    end
    local L = Sprites.light
    -- Bold lights: the map holds half the light so it can reach 2x (src/gfx/lighting.lua)
    local lm, am = Lighting.lightMul((ar + ag + ab) / 3), Lighting.ambientMul()
    -- light(x, y, radius, r, g, b, a): an ellipse squashed 2:1 to sit on the iso ground.
    local function light(x, y, r, cr, cg, cb, ca)
        lg.setColor(cr, cg, cb, math.min(1, ca * lm))
        lg.draw(L, x, y, 0, r / 64, r / 128, 64, 64)
    end

    lg.push("all")
    lg.setCanvas(Screen.light)
    lg.clear(ar * am, ag * am, ab * am, 1)
    lg.setBlendMode("add")
    -- the light map is smaller than the scene (Screen.LIGHT_DIV): same projected coordinates, scaled down
    local div = Screen.LIGHT_DIV
    lg.origin()
    lg.scale(1 / div)
    lg.translate(-ox, -oy)
    -- Cloud Shadows: soft dark shapes taken out of the light (src/gfx/shading.lua)
    lg.setBlendMode("subtract")
    Shading.clouds(self, function(x, y, r, k)
        lg.setColor(1, 1, 1, k * am)
        lg.draw(L, x, y, 0, r / 64, r / 128, 64, 64)
    end, ox, oy, Screen.viewW, Screen.viewH)
    lg.setBlendMode("add")
    local p = self.player
    if not p.dead then
        local px, py = Iso.toScreen(p.x, p.y)
        light(px, py, 230 - 150 * blind, 1, 0.82, 0.55, 0.5)
        light(px, py, 90 - 20 * blind, 1, 0.9, 0.75, 0.45 + 0.3 * blind)
        local sl = p.skin and p.skin.light
        if sl then
            if not sl._c then sl._c = util.hex(sl.color) end
            light(px, py, sl.radius or 60, sl._c[1], sl._c[2], sl._c[3], sl.intensity or 0.5)
        end
    end
    for i = 1, n do
        local e = list[i]
        local l = e.def and e.def.light
        if e.elite then
            local c = Elites.color(e.elite)
            light(e._sx, e._sy, 34, c[1], c[2], c[3], 0.5)
        end
        if l then
            if not l._c then l._c = util.hex(l.color) end
            light(e._sx, e._sy, l.radius * 2, l._c[1], l._c[2], l._c[3], l.intensity or 0.6)
        end
    end
    self.hazards:lights(light)
    Lighting.extras(self, light, list, n)
    Ambience.lights(self, light)
    for _, l in ipairs(self.ground.decorLights or {}) do
        local tw = l.twinkle and (0.75 + 0.25 * math.sin(self.time * l.twinkle + l.x)) or 1
        light(l.x, l.y, l.radius, l.color[1], l.color[2], l.color[3], (l.intensity or 0.5) * tw)
    end
    for _, fx in ipairs(self.fx) do
        local c = fx.color or { 1, 1, 1 }
        local fade = 1 - fx.t / fx.life
        local r = (fx.r or 40) * 2.4
        local x, y = Iso.toScreen(fx.x, fx.y)
        if fx.x2 then
            x, y = Iso.toScreen((fx.x + fx.x2) / 2, (fx.y + fx.y2) / 2)
            r = fx.kind == "bolt" and 90 or 60
        end
        light(x, y, r, c[1], c[2], c[3], 0.6 * fade)
    end
    local plist = self.particles.list
    local lit = 0
    -- (only on-screen sparks spend the 120-light budget)
    local vx0, vy0, vx1, vy1 = ox - 20, oy - 20, ox + Screen.viewW + 20, oy + Screen.viewH + 20
    for i = 1, self.particles.n do
        local pt = plist[i]
        if pt.glow then
            local x, y = Iso.toScreen(pt.x, pt.y, pt.z)
            if x > vx0 and x < vx1 and y > vy0 and y < vy1 then
                lit = lit + 1
                light(x, y, 18, pt.r, pt.g, pt.b, 0.3 * pt.life / pt.maxLife)
                if lit >= 120 then break end
            end
        end
    end
    if Lighting.bold() then
        Lighting.composite(div)
    else
        lg.setCanvas(Screen.canvas)
        lg.setBlendMode("multiply", "premultiplied")
        lg.origin()
        lg.setColor(1, 1, 1, 1)
        lg.draw(Screen.light, Screen.lightQuad, 0, 0, 0, div, div)
    end
    lg.pop()
end

local function isoCircle(x, y, r, segments)
    local pts = {}
    for i = 0, segments do
        local a = i / segments * math.pi * 2
        local sx, sy = Iso.toScreen(x + math.cos(a) * r, y + math.sin(a) * r)
        pts[#pts + 1] = sx
        pts[#pts + 1] = sy
    end
    return pts
end

-- Drawn in additive blend mode, so overlapping effects bloom brighter.
function World:drawFx()
    local lg = love.graphics
    lg.setLineStyle("rough")
    for _, fx in ipairs(self.fx) do
        local k = fx.t / fx.life
        local c = fx.color or { 1, 1, 1 }
        local fade = 1 - k
        if fx.draw then
            fx.draw(fx, k, fade)      -- a move's own effect (content/attacks, content/dashes)
        elseif fx.kind == "arc" then
            -- A slash: a crescent that sweeps from one end of the arc to the other (fx.dir picks
            -- the way), thick in the middle and tapered at both tips, then thins out and fades.
            local half = fx.arc / 2
            local sweep = math.min(1, k / 0.35)
            local thin = k < 0.35 and 1 or (1 - (k - 0.35) / 0.65)
            local dir = fx.dir or 1
            local a0 = dir > 0 and (fx.a - half) or (fx.a + half)
            local segs = 14
            local outerPts, innerPts = {}, {}
            local depth = fx.r * 0.32 * thin
            for s = 0, segs do
                local f = s / segs * sweep
                local ang = a0 + dir * fx.arc * f
                -- thickest a little behind the leading edge, tapered to points at both ends
                local prof = math.sin(math.min(1, f / math.max(0.01, sweep)) * math.pi) ^ 0.7
                local ro, ri = fx.r, fx.r - depth * prof
                local ox, oy = Iso.toScreen(fx.x + math.cos(ang) * ro, fx.y + math.sin(ang) * ro, 3)
                local ix, iy = Iso.toScreen(fx.x + math.cos(ang) * ri, fx.y + math.sin(ang) * ri, 3)
                outerPts[#outerPts + 1], outerPts[#outerPts + 2] = ox, oy
                innerPts[#innerPts + 1], innerPts[#innerPts + 2] = ix, iy
            end
            lg.setColor(c[1], c[2], c[3], 0.45 * fade)
            for s = 1, segs do
                local o1, i1 = s * 2 - 1, s * 2 - 1
                lg.polygon("fill", outerPts[o1], outerPts[o1 + 1], outerPts[o1 + 2], outerPts[o1 + 3],
                    innerPts[i1 + 2], innerPts[i1 + 3], innerPts[i1], innerPts[i1 + 1])
            end
            -- a crisp bright cutting edge
            lg.setColor(math.min(1, c[1] + 0.3), math.min(1, c[2] + 0.3), math.min(1, c[3] + 0.3), fade)
            lg.setLineWidth(1)
            if #outerPts >= 4 then lg.line(outerPts) end
        elseif fx.kind == "ring" then
            -- a shockwave: a quick bright flash, then a thin ring racing outward
            local r = fx.r * (0.3 + 0.7 * math.sqrt(k))
            if k < 0.3 then
                lg.setColor(c[1], c[2], c[3], 0.18 * (1 - k / 0.3))
                lg.polygon("fill", isoCircle(fx.x, fx.y, r, 24))
            end
            lg.setColor(c[1], c[2], c[3], 0.25 * fade)
            lg.setLineWidth(3)
            lg.line(isoCircle(fx.x, fx.y, r * 0.96, 24))
            lg.setColor(c[1], c[2], c[3], 0.8 * fade)
            lg.setLineWidth(1)
            lg.line(isoCircle(fx.x, fx.y, r, 24))
        elseif fx.kind == "stab" then
            -- a thrust: a tapered spike that shoots out to its tip, then withdraws and fades
            local out = math.min(1, k / 0.25)
            local back = k > 0.5 and (k - 0.5) / 0.5 or 0
            local x1, y1 = Iso.toScreen(fx.x, fx.y, fx.z or 5)
            local x2, y2 = Iso.toScreen(fx.x2, fx.y2, fx.z or 5)
            local bx, by = util.lerp(x1, x2, back), util.lerp(y1, y2, back)
            local tx, ty = util.lerp(x1, x2, out), util.lerp(y1, y2, out)
            local dx, dy = tx - bx, ty - by
            local l = math.sqrt(dx * dx + dy * dy) + 0.001
            local w = (fx.w or 3) * (1 - back)
            local nx, ny = -dy / l * w, dx / l * w
            lg.setColor(c[1], c[2], c[3], 0.5 * fade)
            lg.polygon("fill", bx + nx, by + ny, tx, ty, bx - nx, by - ny)
            lg.setColor(1, 1, 1, 0.9 * fade)
            lg.setLineWidth(1)
            lg.line(bx, by, tx, ty)
        elseif fx.kind == "streak" then
            -- a dash streak: a band that is brightest at the head and fades out behind
            local x1, y1 = Iso.toScreen(fx.x, fx.y, 3)
            local x2, y2 = Iso.toScreen(fx.x2, fx.y2, 3)
            local dx, dy = x2 - x1, y2 - y1
            local l = math.sqrt(dx * dx + dy * dy) + 0.001
            local w = (fx.w or 4) * fade
            local nx, ny = -dy / l * w, dx / l * w
            local tail = math.min(1, k * 1.6)
            local sx, sy = util.lerp(x1, x2, tail), util.lerp(y1, y2, tail)
            lg.setColor(c[1], c[2], c[3], 0.3 * fade)
            lg.polygon("fill", sx, sy, x2 + nx, y2 + ny, x2 - nx, y2 - ny)
            lg.setColor(c[1], c[2], c[3], 0.8 * fade)
            lg.line(sx, sy, x2, y2)
        elseif fx.kind == "bolt" then
            -- lightning: the zigzag is picked once so it flickers in brightness, not shape
            local x1, y1 = Iso.toScreen(fx.x, fx.y, 6)
            local x2, y2 = Iso.toScreen(fx.x2, fx.y2, 6)
            if not fx.jit then
                fx.jit = {}
                for s = 1, 8 do fx.jit[s] = (love.math.random() - 0.5) * 7 end
            end
            local pts = { x1, y1 }
            for s = 1, 4 do
                local t = s / 5
                pts[#pts + 1] = util.lerp(x1, x2, t) + fx.jit[s * 2 - 1]
                pts[#pts + 1] = util.lerp(y1, y2, t) + fx.jit[s * 2]
            end
            pts[#pts + 1], pts[#pts + 2] = x2, y2
            local flick = 0.7 + 0.3 * math.sin(fx.t * 90)
            lg.setColor(c[1], c[2], c[3], 0.35 * fade * flick)
            lg.setLineWidth(3)
            lg.line(pts)
            lg.setColor(1, 1, 1, fade * flick)
            lg.setLineWidth(1)
            lg.line(pts)
        end
    end
    lg.setLineWidth(1)
    lg.setColor(1, 1, 1, 1)
end

function World:drawHitboxes(list, n)
    local lg = love.graphics
    for i = 1, n do
        local o = list[i]
        lg.setColor(o == self.player and { 0.3, 1, 0.4, 0.9 } or { 1, 0.3, 0.3, 0.7 })
        lg.line(isoCircle(o.x, o.y, o.radius, 12))
    end
    local p = self.player
    lg.setColor(0.4, 0.7, 1, 0.5)
    lg.line(isoCircle(p.x, p.y, p:attackRange(), 32))
    lg.setColor(1, 1, 1, 1)
end

function World:drawGrid()
    local lg = love.graphics
    self.hash:eachCell(function(x, y, s, count)
        local a = math.min(0.6, 0.1 + count * 0.05)
        lg.setColor(0.3, 0.8, 1, a)
        local p1x, p1y = Iso.toScreen(x, y)
        local p2x, p2y = Iso.toScreen(x + s, y)
        local p3x, p3y = Iso.toScreen(x + s, y + s)
        local p4x, p4y = Iso.toScreen(x, y + s)
        lg.polygon("line", p1x, p1y, p2x, p2y, p3x, p3y, p4x, p4y)
    end)
    lg.setColor(1, 1, 1, 1)
end

-- Text that lives in the world but is drawn at window resolution (crisp).
function World:drawText(fonts)
    local lg = love.graphics
    for _, t in ipairs(self.texts) do
        local wx, wy = self:toWindow(t.x, t.y, t.z)
        local f = t.big and fonts.big or fonts.small
        local a = (1 - math.max(0, (t.t / t.life - 0.6) / 0.4)) * Clarity.textFade(self, wx, wy)
        lg.setFont(f)
        local w = f:getWidth(t.text)
        lg.setColor(0, 0, 0, 0.8 * a)
        lg.print(t.text, math.floor(wx - w / 2) + 1, math.floor(wy) + 1)
        lg.setColor(t.color[1], t.color[2], t.color[3], a)
        lg.print(t.text, math.floor(wx - w / 2), math.floor(wy))
    end
    lg.setColor(1, 1, 1, 1)
end

return World
