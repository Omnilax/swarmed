-- Optional mini-goals: from wave `fromWave`, some waves (src/config/rewards.lua goals.chance)
-- come with one side task from content/goals (catch the courier, guard the aphid...). Finishing
-- it pays bonus skill XP and frenzy; failing costs nothing. Goals never hold a wave up.
-- Also the helpers for "guard this critter" goals (Goals.guarded): a spot some ants go for
-- instead of the player (enemy.lure, read by World:updateEnemies), drained by ants touching it.
local Content = require("src.content")
local Settings = require("src.core.settings")
local Audio = require("src.core.audio")
local Theme = require("src.ui.theme")
local Iso = require("src.core.iso")

local Goals = {}
Goals.__index = Goals

function Goals.new(rewards)
    local self = setmetatable({ rewards = rewards, world = rewards.world, current = nil, done = 0 }, Goals)
    -- forward world events to the goal's `on` handlers
    local ev = self.world.events
    for _, name in ipairs({ "enemy_died", "player_hurt", "enemy_killed", "item_taken" }) do
        ev:on(name, function(...)
            local g = self.current
            local fn = g and not g.result and g.def.on and g.def.on[name]
            if fn then self:settle(fn(g, self.world, ...)) end
        end)
    end
    return self
end

-- Start a goal for wave n (or a specific goal id, for tests and the sandbox).
function Goals:waveStarted(n, id)
    -- endless mode has no wave clears: the last level's goal is settled as the next one starts
    if self.current and not self.current.result then self:waveCleared() end
    self.current = nil
    local cfg = self.rewards.cfg.goals
    local def
    if id then
        def = Content.goals:require(id)
    else
        if not Settings.get("miniGoals") or n < cfg.fromWave or love.math.random() >= cfg.chance then return end
        if self.world.spawner.finalThisWave then return end
        if not require("src.game.onramp").allows(self.world, "goals", n) then return end
        def = Content.goals:pickWeighted(function(d) return d.weight end, function(d)
            return d.minWave <= n and (not d.allowed or d.allowed(self.world, n) ~= false)
        end)
    end
    if not def then return end
    local g = { def = def, wave = n, t = 0 }
    self.current = g
    if def.start then def.start(g, self.world) end
    self.world.events:emit("goal_started", g)
    return g
end

-- "done" / "failed" settle the current goal (anything else: still going).
function Goals:settle(result)
    local g = self.current
    if not g or g.result or (result ~= "done" and result ~= "failed") then return end
    g.result, g.shownT = result, 0
    local w, p = self.world, self.world.player
    if result == "done" then
        self.done = self.done + 1
        self.rewards:pay(g.def.reward, p.x, p.y)
        w:floatText(p.x, p.y - 18, "GOAL COMPLETE!", { 0.6, 1, 0.5 }, true)
        Audio.play("ui_confirm", { pitch = 1.1 })
    else
        Audio.play("ui_back", { pitch = 0.8 })
    end
    if g.aphid then Goals.releaseGuarded(w, g.aphid) end
    w.events:emit(result == "done" and "goal_done" or "goal_failed", g)
end

function Goals:update(dt)
    local g = self.current
    if not g then return end
    if g.result then
        g.shownT = g.shownT + dt
        if g.shownT > 3 then self.current = nil end
        return
    end
    g.t = g.t + dt
    if g.def.update then self:settle(g.def.update(g, self.world, dt)) end
end

function Goals:waveCleared()
    local g = self.current
    if not g or g.result then return end
    self:settle(g.def.finish and g.def.finish(g, self.world) or "failed")
end

function Goals:drawWorld()
    local g = self.current
    if g and g.def.drawWorld and not g.result then g.def.drawWorld(g, self.world) end
end

function Goals:drawHud(right, y, alpha)
    local g = self.current
    if not g then return end
    local u = Theme.u
    local lg = love.graphics
    local text = g.result == "done" and "GOAL COMPLETE" or g.result == "failed" and "GOAL FAILED" or g.def.text(g, self.world)
    local col = g.result == "done" and { 0.6, 1, 0.5 } or g.result == "failed" and { 1, 0.5, 0.4 } or { 1, 0.9, 0.65 }
    local a = alpha * (g.result and math.max(0, 1 - (g.shownT - 2)) or 1)
    lg.setFont(Theme.font(13, "bold"))
    local head = "GOAL: " .. g.def.name:upper()
    Theme.printShadow(head, right - lg.getFont():getWidth(head), y, { 0.95, 0.7, 0.3, a })
    lg.setFont(Theme.font(15))
    Theme.printShadow(text, right - lg.getFont():getWidth(text), y + u(16), { col[1], col[2], col[3], a })
    if not g.result and g.def.reward and g.def.reward.xp then
        lg.setFont(Theme.font(13))
        local r = "+" .. g.def.reward.xp .. " XP, frenzy"
        Theme.printShadow(r, right - lg.getFont():getWidth(r), y + u(34), { 0.55, 0.85, 1, a * 0.8 })
    end
end

----------------------------------------------------------------------------------------------
-- Guarded critters

-- A stand-in for the player that ants chase instead (fields not set here read through to the
-- player; methods do nothing, so a lured ant can't hurt or slow the real player from afar).
local function noop() end
local function proxyFor(world)
    local p = world.player
    return setmetatable({ vx = 0, vy = 0, z = 0, kvx = 0, kvy = 0, radius = 5 }, {
        __index = function(_, k)
            local v = p[k]
            if k == "attackRange" then return function() return p:attackRange() end end
            if type(v) == "function" then return noop end
            return v
        end })
end

-- A critter to protect at (x, y) with `hp`. params: lureChance (share of nearby ants that go
-- for it, 0.3), lureRange (170), bite (share of an ant's damage per second it takes, 0.6)
function Goals.guarded(world, x, y, hp, params)
    local g = { x = x, y = y, hx = x, hy = y, hp = hp, max = hp, params = params or {}, scanT = 0, hurtT = 0, lured = {} }
    g.proxy = proxyFor(world)
    rawset(g.proxy, "x", x)
    rawset(g.proxy, "y", y)
    return g
end

-- Returns true once it is dead.
function Goals.updateGuarded(world, g, dt)
    if g.hp <= 0 then return true end
    local pr = g.params
    -- it shuffles about a little around where it was left
    local t = world.time
    g.x = g.hx + math.sin(t * 0.7) * 6
    g.y = g.hy + math.cos(t * 0.5) * 4
    rawset(g.proxy, "x", g.x)
    rawset(g.proxy, "y", g.y)
    -- every half second, some ants nearby pick it as their target
    g.scanT = g.scanT - dt
    if g.scanT <= 0 then
        g.scanT = 0.5
        local list, n = world:queryEnemies(g.x, g.y, pr.lureRange or 170)
        for i = 1, n do
            local e = list[i]
            if not e.dead and not e.lureRolled and not e.def.boss and e.damage > 0 then
                e.lureRolled = true
                if love.math.random() < (pr.lureChance or 0.3) then
                    e.lure, e.lureUid = g.proxy, e.uid
                    g.lured[#g.lured + 1] = e
                end
            end
        end
    end
    -- ants touching it nibble it
    local list, n = world:queryEnemies(g.x, g.y, 14)
    local dmg = 0
    for i = 1, n do
        local e = list[i]
        if not e.dead and not e.hidden and e.damage > 0 and (e.x - g.x) ^ 2 + (e.y - g.y) ^ 2 < (e.radius + 6) ^ 2 then
            dmg = dmg + e.damage * (pr.bite or 0.6)
        end
    end
    if dmg > 0 then
        g.hp = g.hp - dmg * dt
        g.hurtT = 0.15
    end
    g.hurtT = math.max(0, g.hurtT - dt)
    if g.hp <= 0 then
        world.particles:burst(g.x, g.y, 16, { { 0.55, 0.85, 0.35 }, { 0.85, 1, 0.6 } }, 90, 60, { grav = 300 })
        world:floatText(g.x, g.y, "APHID LOST", { 1, 0.5, 0.4 }, true)
        Goals.releaseGuarded(world, g)
        return true
    end
end

-- The ants that were after it go back to the player.
function Goals.releaseGuarded(world, g)
    for _, e in ipairs(g.lured) do
        if e.lure == g.proxy and e.lureUid == e.uid then e.lure = nil end
    end
    g.lured = {}
end

function Goals.drawGuarded(world, g)
    if g.hp <= 0 then return end
    local Sprites = require("src.gfx.sprites")
    local lg = love.graphics
    local x, y = Iso.toScreen(g.x, g.y)
    -- a soft marker ring so it reads in a crowd
    lg.setColor(0.6, 1, 0.5, 0.35 + 0.15 * math.sin(world.time * 4))
    lg.ellipse("line", x, y + 1, 10, 5)
    if g.hurtT > 0 then lg.setColor(1, 0.5, 0.5, 1) else lg.setColor(1, 1, 1, 1) end
    Sprites.draw(Sprites.get("aphid"), math.floor(world.time * 3) % 2 + 1, x, y, -0.6, false, 1)
    -- health
    local k = g.hp / g.max
    lg.setColor(0, 0, 0, 0.6)
    lg.rectangle("fill", math.floor(x - 9), math.floor(y - 12), 18, 3)
    lg.setColor(0.5, 1, 0.4, 0.95)
    lg.rectangle("fill", math.floor(x - 9), math.floor(y - 12), math.floor(18 * k + 0.5), 3)
    lg.setColor(1, 1, 1, 1)
end

return Goals
