-- Balance check:  love . --balance   (headless is fine:  xvfb-run love . --balance)
-- A simple bot plays real runs (no drawing, fixed 60 Hz steps) with each character and reports
-- how far it gets: per wave the time taken, HP left and KOs. The bot is much worse than a person
-- (it kites crudely, dashes when crowded, fires its special whenever ready, takes a random item
-- card and spends skill points on whatever is available), so "the bot clears wave 15" means a
-- run is comfortably winnable. Environment variables:
--   SWARMED_BAL_CHARS = "rhino_beetle,mantis"   characters to test (default: a spread of them)
--   SWARMED_BAL_RUNS  = 2                       runs per character
--   SWARMED_BAL_WAVES = 15                      stop after clearing this wave
--   SWARMED_BAL_DIFF  = "worker"                difficulty setting
local Content = require("src.content")
local Settings = require("src.core.settings")
local Input = require("src.core.input")
local Rarities = require("src.config.rarities")
local Inventory = require("src.game.inventory")
local World = require("src.game.world")
local util = require("src.core.util")

local Balance = {}

-- damage taken per source and spawns per species, over every run (printed at the end)
local hurtBy, spawned = {}, {}

local DEFAULT_CHARS = { "rhino_beetle", "mantis", "tarantula", "scorpion", "crab", "dragonfly", "pistol_shrimp", "millipede" }

local function split(s)
    local out = {}
    for w in (s or ""):gmatch("[^,%s]+") do out[#out + 1] = w end
    return out
end

-- world direction -> the screen-space stick vector the player code expects
local function toStick(wx, wy)
    local dx, dy = wx - wy, (wx + wy) * 0.5
    local l = math.sqrt(dx * dx + dy * dy)
    if l < 1e-6 then return 0, 0 end
    return dx / l, dy / l
end

local function pickItem(world)
    local wave = math.max(1, world.spawner.wave)
    local def = Content.items:pickWeighted(function(d) return Rarities[d.rarity].weight end,
        function(d) return Rarities[d.rarity].minWave <= wave end)
    if def then
        local item = Inventory.newItem(def.id)
        if not world.player.inventory:give(item) then world.player.inventory:eat(item) end
    end
end

local function spendSkills(p)
    local sk = p.skills
    if not (sk and sk.tree and sk.tree.nodes) then return end
    for _ = 1, 20 do
        local bought = false
        for id, node in pairs(sk.tree.nodes) do
            if sk.points > 0 and sk:status(node) == "available" and sk:buy(id) then bought = true end
        end
        if not bought then break end
    end
end

-- One frame of bot input.
local function steer(world, bot)
    local p = world.player
    local list, n = world:queryEnemies(p.x, p.y, 140)
    local fx, fy, close, near = 0, 0, 0, nil
    local nearD = math.huge
    for i = 1, n do
        local e = list[i]
        if not e.dead and not e.hidden then
            local dx, dy = p.x - e.x, p.y - e.y
            local d2 = dx * dx + dy * dy + 1
            if d2 < nearD then nearD, near = d2, e end
            if d2 < 45 * 45 then close = close + 1 end
            fx, fy = fx + dx / d2, fy + dy / d2
        end
    end
    if not near then near = world:nearestEnemy(p.x, p.y, 2000) end
    if not near then
        -- something is left but out of reach of the hash query (burrowed, far off): walk to it
        for i = 1, world.enemyCount do
            local e = world.enemies[i]
            if not e.dead then near = e break end
        end
    end
    local range = p:attackRange()
    local wx, wy = 0, 0
    -- a person goes for the queen: so does the bot, unless it is being swarmed
    local goal, fleeing = near, false
    if world.boss and not world.boss.dead and close < 4 then goal = world.boss end
    if near then
        local tx, ty = goal.x - p.x, goal.y - p.y
        local d = math.sqrt(tx * tx + ty * ty)
        if close >= 4 or d < range * 0.45 then
            fleeing = true
            -- crowded: get out, sliding sideways so we circle the horde instead of hitting walls
            local ux, uy = util.normalize(fx, fy)
            wx, wy = ux - uy * 0.6 * bot.side, uy + ux * 0.6 * bot.side
        elseif d > range * 0.85 then
            wx, wy = tx / d, ty / d
        else
            wx, wy = -ty / d * bot.side, tx / d * bot.side     -- in range: strafe
        end
        bot.aimX, bot.aimY = near.x, near.y
    end
    -- running away: keep off the walls (but do walk into corners to finish things off)
    local S, m = world.size, fleeing and 90 or 0
    if p.x < m then wx = wx + 1.5 elseif p.x > S - m then wx = wx - 1.5 end
    if p.y < m then wy = wy + 1.5 elseif p.y > S - m then wy = wy - 1.5 end
    if love.math.random() < 0.004 then bot.side = -bot.side end
    local sx, sy = toStick(util.normalize(wx, wy))
    Input.virtualMove = { x = sx, y = sy }
    Input.virtualDown.dash = nil
    if close >= 6 and p.dashCharges > 0 and not p.dashDef.hold then Input.press("dash") end
    -- hold dashes (blocks, stamina modes): a person holds them in bursts, not for the whole wave,
    -- since most stop the attack while held. Hold up to 1 s, then leave it 1.5 s.
    if p.dashDef.hold then
        bot.holdT = (bot.holdT or 0) + 1 / 60
        if bot.holdT > 2.5 then bot.holdT = 0 end
        Input.virtualDown.dash = (close >= 6 and bot.holdT < 1) or nil
    end
    if p.secondary and p.secondary.timer <= 0 and near then Input.press("secondary") end
    Input.virtualDown.secondary = near ~= nil or nil
end

function Balance.runOne(charId, maxWave)
    local world = World.new({ mode = "run", character = charId })
    local p = world.player
    local bot = { side = 1, aimX = p.x, aimY = p.y }
    world.mouseWorld = function() return bot.aimX, bot.aimY end
    world.events:on("player_hurt", function(ctx)
        local s = ctx.source
        local id = type(s) == "table" and s.def and s.def.id or tostring(s)
        hurtBy[id] = (hurtBy[id] or 0) + (ctx.damage or 0)
    end)
    -- enemy shots: credit the hit to the species that fired it (the nearest enemy when it was shot)
    local shoot = world.hazards.shoot
    world.hazards.shoot = function(hz, shot)
        local src = world:nearestEnemy(shot.x, shot.y, 30)
        local id = "shot:" .. (src and src.def.id or "?")
        local onHit = shot.onHitPlayer
        shot.onHitPlayer = function(w, sh, pl)
            hurtBy[id] = (hurtBy[id] or 0) + sh.damage
            if onHit then onHit(w, sh, pl) end
        end
        return shoot(hz, shot)
    end
    local spawnEnemy = world.spawnEnemy
    world.spawnEnemy = function(w, def, ...)
        local id = type(def) == "string" and def or def.id
        spawned[id] = (spawned[id] or 0) + 1
        return spawnEnemy(w, def, ...)
    end
    local log, lastWave, waveStart, kosAt = {}, 0, 0, 0
    local dt, limit = 1 / 60, 60 * 60 * 45
    local result = "timeout"
    local function leftovers()
        local by = {}
        for i = 1, world.enemyCount do
            local e = world.enemies[i]
            by[e.def.id] = (by[e.def.id] or 0) + 1
        end
        local out = {}
        for id, k in pairs(by) do out[#out + 1] = id .. " x" .. k end
        return table.concat(out, ", ")
    end
    for _ = 1, limit do
        steer(world, bot)
        world:update(dt)
        Input.endFrame()
        if world.pendingVictory then
            world.pendingVictory = nil
        end
        if world.pendingChoice and world.time >= (world.pendingChoice.at or 0) then
            local c = world.pendingChoice
            world.pendingChoice = nil
            log[#log + 1] = ("  w%-2d %4.0fs  hp %3.0f/%-3.0f  kos %5d  items %2d%s"):format(c.wave, world.time - waveStart,
                p.hp, p.stats:get("maxHp"), world.kos - kosAt, #p.inventory.bag, c.boss and "  (boss)" or "")
            waveStart, kosAt = world.time, world.kos
            pickItem(world)
            spendSkills(p)
            if c.wave >= maxWave then result = "WON" break end
        end
        if os.getenv("SWARMED_BAL_DEBUG") and world.boss and math.floor(world.time * 60) % 300 == 0 then
            local b = world.boss
            print(("  t%.0f boss %s hp %d/%d dist %.0f  player %.0f,%.0f boss %.0f,%.0f range %.0f n %d"):format(world.time, b.def.id, b.hp, b.maxHp,
                math.sqrt((b.x - p.x) ^ 2 + (b.y - p.y) ^ 2), p.x, p.y, b.x, b.y, p:attackRange(), world.enemyCount))
        end
        if p.dead then result = "died on wave " .. world.spawner.wave break end
        if world.spawner.wave ~= lastWave then lastWave = world.spawner.wave end
    end
    if result == "timeout" then
        result = ("timeout on wave %d (%d left: %s; queue %d, streams %d)"):format(world.spawner.wave, world.enemyCount,
            leftovers(), #world.spawner.queue, #world.spawner.streams)
    end
    return result, log, world
end

function Balance.start()
    Settings.set("difficulty", os.getenv("SWARMED_BAL_DIFF") or "worker")
    Settings.set("autoAttack", true)
    Settings.set("aimMode", "nearest")
    Input.lastDevice = "keyboard"
    local chars = split(os.getenv("SWARMED_BAL_CHARS"))
    if #chars == 0 then chars = DEFAULT_CHARS end
    local runs = tonumber(os.getenv("SWARMED_BAL_RUNS") or "") or 1
    local maxWave = tonumber(os.getenv("SWARMED_BAL_WAVES") or "") or 15
    for _, id in ipairs(chars) do
        for r = 1, runs do
            local t0 = love.timer.getTime()
            local ok, result, log = pcall(Balance.runOne, id, maxWave)
            if not ok then
                print(("[balance] %s run %d CRASHED: %s"):format(id, r, tostring(result)))
            else
                print(("[balance] %s run %d: %s  (%.0fs real)"):format(id, r, result, love.timer.getTime() - t0))
                for _, line in ipairs(log) do print(line) end
            end
            io.stdout:flush()
        end
    end
    local rows = {}
    for id, d in pairs(hurtBy) do rows[#rows + 1] = { id = id, d = d } end
    table.sort(rows, function(a, b) return a.d > b.d end)
    print("[balance] damage taken by source (total, per spawned enemy):")
    for i = 1, math.min(25, #rows) do
        local r = rows[i]
        print(("  %-22s %7.0f  %6.2f  (%d spawned)"):format(r.id, r.d, r.d / math.max(1, spawned[r.id] or 0), spawned[r.id] or 0))
    end
    love.event.quit()
end

return Balance
