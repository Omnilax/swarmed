-- Records: the player's save of lifetime stats, past runs and achievements.
--
-- A real run (not the sandbox or the title screen demo) is tracked with Records.track(world, info):
-- it listens on the run's event bus and counts into `Records.run` (this run) and
-- `Records.profile` (all time) as things happen, checks achievements (content/achievements)
-- and saves at every wave clear and when the run ends. Saved to "records.lua" in the save folder.
local util = require("src.core.util")

local Records = { profile = nil, run = nil, toasts = {} }
local FILE = "records.lua"
local HISTORY = 50          -- past runs kept
local CHECK_EVERY = 0.5     -- seconds between achievement checks during a run

local function blankProfile()
    return {
        version = 1,
        runs = 0, wins = 0, deaths = 0,
        kills = 0, elites = 0, queens = 0,
        killsBy = {},        -- enemy id -> kills
        killsByFamily = {},  -- family id -> kills
        elitesBy = {},       -- elite affix id -> kills
        wavesCleared = 0, flawlessWaves = 0,
        bestWave = 0, bestKOs = 0, bestCombo = 0, bestLevel = 0, longestRun = 0,
        playTime = 0, damageTaken = 0, itemsTaken = 0, itemsEaten = 0,
        characters = {},     -- character id -> { runs, wins, kills, bestWave }
        modes = {},          -- game mode id -> { runs, wins, bestWave }
        daily = {},          -- daily run date "YYYY-MM-DD" -> best { wave, kos, won, character }
        history = {},        -- newest first, see Records.endRun
        achievements = {},   -- achievement id -> os.time() it unlocked
        molts = {},          -- molt recipe id -> times molted (the recipe book, Records > Recipes)
        moltCount = 0, chestsOpened = 0, duplicated = 0,
        seen = {},           -- enemy id -> true once met (first-sighting popups, src/ui/runhud.lua)
        swarmsSurvived = 0,  -- Final Swarms lived through (src/game/finalswarm.lua)
        -- characters[id] also gets `danger` (highest danger level won, src/config/danger.lua)
        -- and `swarmKills` (most kills in a Final Swarm) once they happen
    }
end

local function sub(t, k, fields)
    local s = t[k]
    if not s then
        s = {}
        for _, f in ipairs(fields) do s[f] = 0 end
        t[k] = s
    end
    return s
end
local CHAR_FIELDS = { "runs", "wins", "kills", "bestWave" }
local MODE_FIELDS = { "runs", "wins", "bestWave" }

function Records.load()
    local p = blankProfile()
    if love.filesystem.getInfo(FILE) then
        local ok, chunk = pcall(love.filesystem.load, FILE)
        local ok2, data = false, nil
        if ok and chunk then ok2, data = pcall(chunk) end
        if ok2 and type(data) == "table" then
            -- keep only fields of the right type, so an old or damaged save can't break anything
            for k, v in pairs(data) do
                if type(v) == type(p[k]) then p[k] = v end
            end
        end
    end
    Records.profile = p
    return p
end

function Records.get() return Records.profile or Records.load() end

-- Has this molt recipe ever been molted? (the recipe book shows its result once it has)
function Records.moltKnown(id)
    local p = Records.get()
    return (p.molts[id] or 0) > 0
end

function Records.save()
    if not Records.profile or Records.noSave then return end
    local ok, s = pcall(util.serialize, Records.profile)
    if ok then love.filesystem.write(FILE, "return " .. s .. "\n") end
end

-- Closing the game mid-run counts as leaving it.
function Records.quit()
    if Records.run and not Records.run.ended then Records.endRun("quit") end
    Records.save()
end

-- Wipe everything (Records screen > Reset).
function Records.reset()
    Records.profile = blankProfile()
    Records.save()
end

local function modeId(world, info)
    return info.gameMode or world.gameMode or "colony"
end

-- Display name of a game mode id (from a game mode registry, when there is one).
function Records.modeName(id)
    local Content = require("src.content")
    for _, k in ipairs({ "modes", "gamemodes" }) do
        local reg = Content[k]
        local def = reg and reg.get and reg:get(id)
        if def and def.name then return def.name end
    end
    return (tostring(id):gsub("_", " "):gsub("^%l", string.upper))
end

----------------------------------------------------------------------------------------------
-- Tracking a run

-- info: { character = id, gameMode = id } (Game params). Call once, right after the world is made.
-- A resumed run (info.resume, src/game/runsave.lua) carries on the run it was saved from, so it
-- isn't counted as another run.
function Records.track(world, info)
    local p = Records.get()
    if Records.run and not Records.run.ended then Records.endRun("quit") end
    local charId = world.player.def.id
    local run = {
        world = world, character = charId, mode = modeId(world, info or {}),
        kills = 0, elites = 0, queens = 0, killsBy = {}, killsByFamily = {},
        wave = 0, wavesCleared = 0, flawlessWaves = 0, waveDamage = 0,
        damageTaken = 0, itemsTaken = 0, itemsEaten = 0, time = 0,
        won = false, started = os.time(), checkT = 0, daily = world.daily, time0 = world.time,
        blocked = 0, dashKills = 0, danger = world.danger and world.danger.level or 0,
    }
    Records.run = run
    sub(p.characters, charId, CHAR_FIELDS)
    sub(p.modes, run.mode, MODE_FIELDS)
    if not (info and info.resume) then
        p.runs = p.runs + 1
        p.characters[charId].runs = p.characters[charId].runs + 1
        p.modes[run.mode].runs = p.modes[run.mode].runs + 1
    end

    local ev = world.events
    ev:on("enemy_died", function(e) Records.onKill(e) end)
    ev:on("player_hurt", function(ctx)
        local d = ctx.damage or 0
        run.damageTaken, run.waveDamage = run.damageTaken + d, run.waveDamage + d
        p.damageTaken = p.damageTaken + d
    end)
    ev:on("wave_started", function(wave)
        run.wave, run.waveDamage = wave, 0
        p.bestWave = math.max(p.bestWave, wave)
        local c = p.characters[charId]
        c.bestWave = math.max(c.bestWave, wave)
        local m = p.modes[run.mode]
        m.bestWave = math.max(m.bestWave, wave)
    end)
    ev:on("wave_cleared", function(wave)
        run.wavesCleared = run.wavesCleared + 1
        p.wavesCleared = p.wavesCleared + 1
        if run.waveDamage <= 0 then
            run.flawlessWaves = run.flawlessWaves + 1
            p.flawlessWaves = p.flawlessWaves + 1
        end
        Records.check()
        Records.save()
    end)
    ev:on("player_blocked", function(amount) run.blocked = run.blocked + (amount or 0) end)
    ev:on("dash_kill", function() run.dashKills = run.dashKills + 1 end)
    ev:on("final_swarm_over", function(info)
        if not info.survived then return end
        p.swarmsSurvived = (p.swarmsSurvived or 0) + 1
        local c = p.characters[charId]
        c.swarmKills = math.max(c.swarmKills or 0, info.kills or 0)
        Records.check()
        Records.save()
    end)
    ev:on("run_won", function()
        if run.won then return end
        run.won = true
        -- Custom Waves can be as easy as you make them: a win there counts for the mode only
        -- (no bug wins, no danger mastery, no win achievements)
        if world.modeDef and world.modeDef.custom then
            p.modes[run.mode].wins = p.modes[run.mode].wins + 1
            Records.save()
            return
        end
        p.wins = p.wins + 1
        p.characters[charId].wins = p.characters[charId].wins + 1
        -- mastery: the highest danger level won with this bug
        local c = p.characters[charId]
        c.danger = math.max(c.danger or -1, run.danger or 0)
        p.modes[run.mode].wins = p.modes[run.mode].wins + 1
        Records.check()
        Records.save()
    end)
    ev:on("item_taken", function()
        run.itemsTaken, p.itemsTaken = run.itemsTaken + 1, p.itemsTaken + 1
    end)
    ev:on("item_eaten", function()
        run.itemsEaten, p.itemsEaten = run.itemsEaten + 1, p.itemsEaten + 1
    end)
    ev:on("item_molted", function(recipe)
        p.molts[recipe.id] = (p.molts[recipe.id] or 0) + 1
        p.moltCount = p.moltCount + 1
        run.molts = (run.molts or 0) + 1
        Records.check()
    end)
    ev:on("chest_opened", function(kind, n)
        p.chestsOpened = p.chestsOpened + 1
        run.chests = (run.chests or 0) + 1
    end)
    ev:on("item_duplicated", function() p.duplicated = p.duplicated + 1 end)
    ev:on("player_died", function() Records.endRun("died") end)
    return run
end

function Records.onKill(e)
    local run, p = Records.run, Records.profile
    if not run or run.ended then return end
    local def = e.def
    run.kills, p.kills = run.kills + 1, p.kills + 1
    run.killsBy[def.id] = (run.killsBy[def.id] or 0) + 1
    p.killsBy[def.id] = (p.killsBy[def.id] or 0) + 1
    local fam = def.family or "ant"
    run.killsByFamily[fam] = (run.killsByFamily[fam] or 0) + 1
    p.killsByFamily[fam] = (p.killsByFamily[fam] or 0) + 1
    p.characters[run.character].kills = p.characters[run.character].kills + 1
    if e.elite then
        run.elites, p.elites = run.elites + 1, p.elites + 1
        local id = e.elite.id or "?"
        p.elitesBy[id] = (p.elitesBy[id] or 0) + 1
    end
    if def.boss then run.queens, p.queens = run.queens + 1, p.queens + 1 end
end

-- Every frame (from love.update): run time, periodic achievement checks, toast timers.
function Records.update(dt)
    local run = Records.run
    if run and not run.ended then
        local w = run.world
        run.time = w.time
        run.checkT = run.checkT - dt
        if run.checkT <= 0 then
            run.checkT = CHECK_EVERY
            Records.check()
        end
    end
    for i = #Records.toasts, 1, -1 do
        local t = Records.toasts[i]
        if i <= 3 then t.t = t.t + dt end      -- up to three at once, the rest wait their turn
        if t.t > 4 then table.remove(Records.toasts, i) end
    end
end

-- outcome: "died" | "quit". Adds the run to the history and saves. Safe to call twice.
function Records.endRun(outcome)
    local run, p = Records.run, Records.profile
    if not run or run.ended then return end
    run.ended = true
    local w = run.world
    run.time = w.time
    run.outcome = outcome
    if outcome == "died" then p.deaths = p.deaths + 1 end
    p.playTime = p.playTime + run.time - (run.time0 or 0)
    p.longestRun = math.max(p.longestRun, run.time)
    p.bestKOs = math.max(p.bestKOs, w.kos or run.kills)
    p.bestCombo = math.max(p.bestCombo, w.bestCombo or 0)
    local level = w.player.skills and w.player.skills.level or 0
    p.bestLevel = math.max(p.bestLevel, level)
    -- the daily run keeps its best result per day (furthest wave, then most KOs)
    if run.daily then
        local b = p.daily[run.daily]
        local kos = w.kos or run.kills
        if not b or run.wave > b.wave or (run.wave == b.wave and kos > b.kos) then
            p.daily[run.daily] = { wave = run.wave, kos = kos, won = run.won, character = run.character }
        end
        -- only the last few weeks are kept
        local keys = {}
        for k in pairs(p.daily) do keys[#keys + 1] = k end
        table.sort(keys)
        for i = 1, #keys - 30 do p.daily[keys[i]] = nil end
    end
    -- a run that never got going (quit in the first seconds) isn't worth a history line
    if run.time >= 5 or run.kills > 0 then
        -- the most-killed species of the run, for the history line
        local top, topN = nil, 0
        for id, n in pairs(run.killsBy) do if n > topN then top, topN = id, n end end
        local items = {}
        for _, e in ipairs(w.player.inventory.bag or {}) do items[#items + 1] = e.item.id end
        table.insert(p.history, 1, {
            date = run.started, character = run.character, mode = run.mode,
            wave = run.wave, cleared = run.wavesCleared, won = run.won, outcome = outcome,
            time = math.floor(run.time), kills = run.kills, elites = run.elites, queens = run.queens,
            combo = w.bestCombo or 0, level = level, damage = math.floor(run.damageTaken),
            top = top, topN = topN, items = items, danger = run.danger,
        })
        while #p.history > HISTORY do table.remove(p.history) end
    end
    Records.check()
    Records.save()
end

-- Save & Quit: the run stops being tracked but isn't over, so it gets no history line yet (it
-- is written when the resumed run ends). Play time so far still counts.
function Records.suspend()
    local run, p = Records.run, Records.profile
    if not run or run.ended then return end
    run.ended = true
    run.time = run.world.time
    p.playTime = p.playTime + run.time - (run.time0 or 0)
    Records.check()
    Records.save()
end

----------------------------------------------------------------------------------------------
-- Achievements

-- Progress of an achievement: value, goal (numbers).
function Records.progress(a, p, run)
    p = p or Records.get()
    local goal = type(a.goal) == "function" and a.goal() or a.goal or 1
    local ok, v = pcall(a.value, p, run)
    if not ok then v = 0 end
    if v == true then v = goal elseif type(v) ~= "number" then v = 0 end
    return math.min(v, goal), goal
end

function Records.unlocked(id) return Records.get().achievements[id] ~= nil end

-- Unlock whatever is now done. `run` is passed to the checks only while a run is going.
function Records.check()
    local Content = require("src.content")
    local reg = Content.achievements
    if not reg then return end
    local p = Records.get()
    local run = Records.run
    local any = false
    for _, a in ipairs(reg:all()) do
        if not p.achievements[a.id] then
            local v, goal = Records.progress(a, p, run)
            if v >= goal then
                p.achievements[a.id] = os.time()
                Records.grant(a)
                Records.toasts[#Records.toasts + 1] = { def = a, t = 0 }
                any = true
            end
        end
    end
    if any then
        require("src.core.audio").play("ui_confirm", { pitch = 1.3 })
        Records.save()
    end
end

-- An achievement's `unlocks`: locked cosmetics (skin / decor / location ids) it reveals.
function Records.grant(a)
    if not a.unlocks then return end
    local ok, Cosmetics = pcall(require, "src.game.cosmetics")
    if not ok or not Cosmetics.data then return end
    local ids = type(a.unlocks) == "table" and a.unlocks or { a.unlocks }
    for _, id in ipairs(ids) do
        if Records.noSave then Cosmetics.data.unlocked[id] = true else Cosmetics.unlock(id) end
    end
end

-- Re-grant the rewards of everything already unlocked (after the cosmetics save is loaded).
function Records.regrant()
    local reg = require("src.content").achievements
    local p = Records.get()
    for _, a in ipairs(reg and reg:all() or {}) do
        if p.achievements[a.id] then Records.grant(a) end
    end
end

-- "Achievement unlocked" card that slides in at the top right (drawn over every screen).
function Records.drawToasts()
    for i = 1, math.min(3, #Records.toasts) do Records.drawToast(Records.toasts[i], i) end
end

function Records.drawToast(t, i)
    local Theme = require("src.ui.theme")
    local lg = love.graphics
    local u = Theme.u
    local w = lg.getWidth()
    local slide = math.max(0, math.min(1, t.t * 5, (4 - t.t) * 5))
    slide = 1 - (1 - slide) ^ 3
    local bw, bh = u(320), u(64)
    local x, y = w - (bw + u(16)) * slide, u(140) + (i - 1) * (bh + u(8))      -- below the combo counter and enemies left
    Theme.panel(x, y, bw, bh)
    local c = Theme.colors.focus
    lg.setColor(c)
    lg.rectangle("fill", x, y + u(8), u(4), bh - u(16))
    lg.setFont(Theme.font(14))
    lg.setColor(Theme.colors.dim)
    lg.print(t.def.unlockKind and "Unlocked" or "Achievement", x + u(16), y + u(9))
    lg.setFont(Theme.font(20, "bold"))
    Theme.printShadow(t.def.name, x + u(16), y + u(28), c)
    lg.setColor(1, 1, 1, 1)
end

return Records
