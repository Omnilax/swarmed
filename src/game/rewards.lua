-- Combat feel and in-run rewards, in one place per world (world.rewards):
--   frenzy meter + super move  (src/game/frenzy.lua,  content/frenzies)
--   kill-streak buffs          (src/game/streaks.lua, content/streaks)
--   optional mini-goals        (src/game/goals.lua,   content/goals)
--   route gates between waves  (src/game/routes.lua,  content/routes)
--   the treasure ant, hitstop / slow-mo / camera punch on big moments, and proc snowballing.
-- Numbers live in src/config/rewards.lua (a game mode can override them with `rewards = {...}`).
-- World calls Rewards:update at the end of its update, and the HUD calls Rewards.drawHud.
local Settings = require("src.core.settings")
local Audio = require("src.core.audio")
local Theme = require("src.ui.theme")
local util = require("src.core.util")

local Rewards = {}
Rewards.__index = Rewards

-- The config for a world: src/config/rewards.lua with the mode's `rewards` overrides on top.
function Rewards.config(modeDef)
    local base = require("src.config.rewards")
    local over = modeDef and modeDef.rewards
    if not over then return base end
    local out = {}
    for k, v in pairs(base) do
        if type(v) == "table" and type(over[k]) == "table" then
            local t = {}
            for k2, v2 in pairs(v) do t[k2] = v2 end
            for k2, v2 in pairs(over[k]) do t[k2] = v2 end
            out[k] = t
        elseif over[k] ~= nil then
            out[k] = over[k]
        else
            out[k] = v
        end
    end
    return out
end

function Rewards.new(world)
    local self = setmetatable({ world = world, cfg = Rewards.config(world.modeDef), slowT = 0, slowScale = 1, bigCd = 0 }, Rewards)
    self.frenzy = require("src.game.frenzy").new(self)
    self.streaks = require("src.game.streaks").new(self)
    self.goals = require("src.game.goals").new(self)
    self.routes = require("src.game.routes").new(self)
    local ev = world.events
    ev:on("enemy_died", function(e) self:onDeath(e) end)
    ev:on("boss_killed", function(e) self:queenDown(e) end)
    ev:on("wave_started", function(n) self:waveStarted(n) end)
    ev:on("wave_cleared", function(n) self:waveCleared(n) end)
    return self
end

-- Only real runs get goals, treasure and routes (not the sandbox, the title demo or tests
-- that switch the spawner off).
function Rewards:live()
    local w = self.world
    return w.mode == "run" and not w.flags.demo and w.spawner and w.spawner.enabled
end

----------------------------------------------------------------------------------------------
-- Big moments: slow motion and a camera punch

-- Slow the whole game to `scale` for `time` real seconds (the slowest / longest wins).
function Rewards:slowmo(scale, time)
    if not Settings.get("slowMotion") then return end
    if self.slowT <= 0 or scale < self.slowScale then self.slowScale = scale end
    self.slowT = math.max(self.slowT, time)
end

-- The time scale for this frame. World:update multiplies its dt by it (dt here is unscaled).
function Rewards:timeScale(dt)
    if self.slowT <= 0 then return 1 end
    self.slowT = self.slowT - dt
    -- ease back to full speed over the last third
    local k = self.slowScale
    if self.slowT < 0.15 then k = util.lerp(1, k, math.max(0, self.slowT) / 0.15) end
    return k
end

function Rewards:punch(amount)
    self.world.camera:punch(amount)
end

function Rewards:queenDown(e)
    local f = self.cfg.feel
    self:slowmo(f.queenSlow, f.queenSlowTime)
    self:punch(f.queenPunch)
end

----------------------------------------------------------------------------------------------
-- Kills, waves

function Rewards:onDeath(e)
    if e.escaped then return end
    local fc = self.cfg.frenzy
    local amount = fc.perKill * (e.def.xp or 1)
    if e.elite then amount = amount + fc.elite end
    if e.def.boss then amount = amount + fc.boss end
    self.frenzy:add(amount)
end

function Rewards:waveStarted(n)
    if not self:live() then return end
    self.routes:waveStarted(n)
    self.goals:waveStarted(n)
    -- now and then a treasure ant shows up partway through the wave
    local tc = self.cfg.treasure
    self.treasureAt = nil
    if tc and n >= tc.fromWave and love.math.random() < tc.chance and not self.world.spawner.finalThisWave then
        self.treasureAt = tc.delay[1] + love.math.random() * (tc.delay[2] - tc.delay[1])
    end
end

function Rewards:waveCleared(n)
    if not self:live() then return end
    self.goals:waveCleared(n)
    self.routes:waveCleared(n)
end

-- Pay out a reward table { xp, frenzy (share of a full meter), minRarity } at (x, y).
function Rewards:pay(r, x, y)
    if not r then return end
    local w = self.world
    if r.xp and r.xp > 0 then w:grantXP(r.xp, x, y) end
    if r.frenzy and r.frenzy > 0 then self.frenzy:add(r.frenzy * self.frenzy.max, true) end
    if r.minRarity then
        -- the next item choice: its best card is at least this rare
        local R = require("src.config.rarities")
        local cur = self.minRarity and R[self.minRarity].order or 0
        if R[r.minRarity] and R[r.minRarity].order > cur then self.minRarity = r.minRarity end
    end
end

-- Spawner asks this when it sets up the item choice after a wave.
function Rewards:takeMinRarity()
    local r = self.minRarity
    self.minRarity = nil
    return r
end

-- Treasure ant
function Rewards:spawnTreasure()
    local w = self.world
    local tc = self.cfg.treasure
    local S, p = w.size, w.player
    -- pops out of the ground a fair way from the player, on screen
    local a = love.math.random() * math.pi * 2
    local x = util.clamp(p.x + math.cos(a) * 130, 40, S - 40)
    local y = util.clamp(p.y + math.sin(a) * 130, 40, S - 40)
    local e = w:spawnEnemy(tc.enemy, x, y, "gilded")
    if not e then return end
    w.particles:burst(x, y, 14, { { 1, 0.9, 0.4 }, { 0.6, 0.45, 0.3 } }, 80, 60, { grav = 200 })
    w:floatText(x, y, "TREASURE ANT!", { 1, 0.85, 0.3 }, true)
    w.milestone = { text = "TREASURE ANT!", t = 0.4 }
    Audio.play("pickup", { pitch = 1.3 })
    w.events:emit("treasure_spawned", e)
end

function Rewards:treasureCaught(x, y)
    local tc, fc = self.cfg.treasure, self.cfg.frenzy
    self:pay({ xp = tc.xp, frenzy = fc.treasure }, x, y)
    self.world:floatText(x, y - 10, "TREASURE!", { 1, 0.85, 0.3 }, true)
    -- and a brood cell chest of level-up cards (content/props/brood_cell.lua)
    if self.world.dropChest then self.world:dropChest(x, y, "treasure") end
    self.world.particles:burst(x, y, 30, { { 1, 0.9, 0.4 }, { 1, 1, 0.8 } }, 160, 100, { glow = true, grav = 120 })
    Audio.play("pickup", { pitch = 0.9 })
    self:punch(0.08)
    self.world.events:emit("treasure_caught")
end

----------------------------------------------------------------------------------------------
-- Proc snowball: chances grow each wave, and late waves allow one more link in a proc chain.

function Rewards:procMul()
    local pc, sp = self.cfg.procs, self.world.spawner
    local wave = sp and math.max(1, sp.wave) or 1
    return math.min(pc.maxMul, 1 + (wave - 1) * pc.perWave)
end

function Rewards:procDepth()
    local pc, sp = self.cfg.procs, self.world.spawner
    local wave = sp and sp.wave or 0
    return wave >= pc.deepFrom and pc.deepDepth or pc.depth
end

----------------------------------------------------------------------------------------------
-- Update (from World:update, with the game-speed-scaled dt)

function Rewards:update(dt)
    local w = self.world
    local f = self.cfg.feel
    -- a big multi-kill: slow motion and a punch on top of the hitstop
    self.bigCd = math.max(0, self.bigCd - dt)
    if w.killsThisFrame >= f.bigKill and self.bigCd <= 0 then
        self.bigCd = f.cooldown
        self:slowmo(f.bigSlow, f.bigSlowTime)
        self:punch(math.min(0.12, f.bigPunch + w.killsThisFrame * 0.002))
    end
    self.frenzy:update(dt)
    self.streaks:update(dt)
    if self:live() then
        self.goals:update(dt)
        self.routes:update(dt)
        local sp = w.spawner
        if self.treasureAt and sp.phase == "wave" and sp.waveTime >= self.treasureAt then
            self.treasureAt = nil
            self:spawnTreasure()
        end
    end
end

-- On the ground, under the bugs (projected pixels): route tunnels, guarded critters.
function Rewards:drawGround()
    self.goals:drawWorld()
    self.routes:drawWorld()
end

----------------------------------------------------------------------------------------------
-- HUD: the frenzy meter, streak buff and mini-goal on the right, under the KO counter.

function Rewards.drawHud(game, covered)
    local world = game.world
    local self = world.rewards
    if not self or world.flags.demo then return end
    local lg = love.graphics
    local u = Theme.u
    local w = lg.getDimensions()
    local alpha = Settings.get("hudOpacity") / 100
    local right = w - u(20)
    -- under the KO counter and the enemies-left chip (src/ui/hud.lua sets rightY each frame)
    local y = math.max(u(114), (require("src.ui.hud").rightY or 0) + u(8))
    self.frenzy:drawHud(right, y, alpha)
    y = y + u(30)
    y = self.streaks:drawHud(right, y, alpha)
    self.goals:drawHud(right, y, alpha)
    if not covered then self.routes:drawHud(alpha) end
    lg.setColor(1, 1, 1, 1)
end

return Rewards
