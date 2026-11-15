-- Save and quit mid-run, then pick it up again from the title screen.
--
-- A run is saved as a snapshot of what makes it *your* run: the bug, mode and stage, the waves
-- cleared, time, KOs, HP, the bag (every item where you put it and how it's turned), the bag's
-- extra rows, the skill tree, the nectar balance, the species met so far and queens already fought, any item choice
-- still owed, and the run's record counters. The fight itself is not saved: resuming starts with
-- a short breather before the next wave, and a run saved mid-wave plays that wave again.
--
-- Saved by Pause > Save & Quit, automatically at every wave clear (phones and browser tabs can be
-- closed at any moment), and when the game is closed mid-run. The save is gone once the run ends
-- (defeat, End Run) or a new run starts. Practice runs and the sandbox are never saved.
-- File: "run.lua" in the save folder.
local util = require("src.core.util")
local Content = require("src.content")
local Inventory = require("src.game.inventory")

local RunSave = { FILE = "run.lua", VERSION = 1 }

-- Record counters carried over so the run's stats line in Records stays whole.
local RECORD_FIELDS = { "kills", "elites", "queens", "killsBy", "killsByFamily", "wavesCleared", "flawlessWaves",
    "damageTaken", "itemsTaken", "itemsEaten", "started", "won", "blocked", "dashKills" }

-- Can this game be saved? (a real run that's still going)
function RunSave.allowed(game)
    local w = game and game.world
    return w ~= nil and game.mode == "run" and not game.params.practice and not w.player.dead and not w.flags.demo
end

function RunSave.snapshot(game)
    local w = game.world
    local p, sp = w.player, w.spawner
    local snap = {
        version = RunSave.VERSION,
        character = p.def.id, gameMode = w.gameMode, stage = w.stage.id,
        startItems = game.params.startItems,
        -- waves fully behind you: a wave still going is played again
        wave = (sp.phase == "wave") and math.max(0, sp.wave - 1) or sp.wave,
        time = w.time, kos = w.kos, bestCombo = w.bestCombo, xp = w.xp, won = w.won or nil,
        continued = w.continued or nil, bonusPicks = w.bonusPicks,
        hp = p.hp, rows = p.inventory.rows,
        bag = {}, known = {}, usedQueens = {},
        skills = { xp = p.skills and p.skills.xp or 0, ranks = util.deepcopy(p.skills and p.skills.ranks or {}) },
        saved = os.time(),
        -- the run's seed and daily run (src/game/daily.lua), and the item choice's rerolls,
        -- bans and locked cards (src/game/choices.lua)
        -- (the seed as text: the save file keeps numbers to 14 digits, a seed has up to 16)
        seed = w.seed and ("%.0f"):format(w.seed), daily = util.deepcopy(w.daily),
        choice = util.deepcopy(w.choice),
        -- danger level (src/config/danger.lua) and the bug rule's state (src/game/bugrules.lua)
        danger = w.danger and w.danger.level or 0, ruleState = util.deepcopy(w.ruleState),
        -- blessings and curses from map gambles (src/game/gambles.lua)
        blessings = util.deepcopy(w.blessings),
    }
    -- nectar: the balance, plus any beads still on the floor (as if swept up)
    local beads = w.beads and w.beads:pending() or 0
    snap.nectar = (w.nectar or 0) + beads * (w.beads and w.beads.cfg.perXP or 1)
    snap.nectarEarned, snap.nectarSpent = (w.nectarEarned or 0) + beads, w.nectarSpent or 0
    if beads > 0 then
        snap.xp = (snap.xp or 0) + beads
        snap.skills.xp = snap.skills.xp + beads
    end
    for _, e in ipairs(p.inventory.bag) do
        snap.bag[#snap.bag + 1] = { id = e.item.id, x = e.x, y = e.y, rot = e.item.rot or 0 }
    end
    for _, d in ipairs(sp.knownList) do snap.known[#snap.known + 1] = d.id end
    for id in pairs(sp.usedQueens) do snap.usedQueens[#snap.usedQueens + 1] = id end
    local pc = w.pendingChoice
    if pc then snap.pendingChoice = { count = pc.count, boss = pc.boss, wave = pc.wave, endless = pc.endless, minRarity = pc.minRarity } end
    local Records = require("src.game.records")
    local run = Records.run
    if run and run.world == w then
        snap.record = {}
        for _, k in ipairs(RECORD_FIELDS) do snap.record[k] = util.deepcopy(run[k]) end
    end
    return snap
end

function RunSave.save(game)
    if RunSave.noSave or not RunSave.allowed(game) then return false end
    local ok, s = pcall(util.serialize, RunSave.snapshot(game))
    if not ok then return false end
    local wrote = pcall(love.filesystem.write, RunSave.FILE, "return " .. s .. "\n")
    RunSave.cache = nil
    return wrote
end

-- The saved run, or nil (also nil when it names a bug or mode that no longer exists).
function RunSave.peek()
    if RunSave.cache ~= nil then return RunSave.cache or nil end
    local snap
    if love.filesystem.getInfo(RunSave.FILE) then
        local ok, chunk = pcall(love.filesystem.load, RunSave.FILE)
        local ok2, data = false, nil
        if ok and chunk then ok2, data = pcall(chunk) end
        if ok2 and type(data) == "table" and data.version == RunSave.VERSION
            and type(data.character) == "string" and Content.characters:get(data.character)
            and Content.modes:get(data.gameMode or "colony") then
            snap = data
        end
    end
    RunSave.cache = snap or false
    return snap
end

function RunSave.clear()
    RunSave.cache = false
    if RunSave.noSave then return end
    if love.filesystem.getInfo(RunSave.FILE) then pcall(love.filesystem.remove, RunSave.FILE) end
end

-- "Rhino Beetle · Colony · wave 7" for the title screen.
function RunSave.describe(snap)
    local c = Content.characters:get(snap.character)
    local m = Content.modes:get(snap.gameMode or "colony")
    local wave = (m and m.endless) and ("level " .. (snap.wave + 1)) or ("wave " .. (snap.wave + 1))
    return (c and c.name or snap.character) .. "  ·  " .. (m and m.name or "") .. "  ·  " .. wave
end

-- Game params that start the saved run (Game.new calls RunSave.restore with the snapshot).
function RunSave.params(snap)
    return { mode = "run", character = snap.character, gameMode = snap.gameMode, stage = snap.stage,
        startItems = snap.startItems, seed = tonumber(snap.seed), daily = snap.daily, resume = snap,
        danger = tonumber(snap.danger) or 0 }
end

-- Put a fresh world into the saved run's state.
function RunSave.restore(world, snap)
    local p, sp = world.player, world.spawner
    world.time = snap.time or 0
    world.kos, world.bestCombo, world.xp = snap.kos or 0, snap.bestCombo or 0, snap.xp or 0
    world.won, world.continued, world.bonusPicks = snap.won, snap.continued, snap.bonusPicks or 0
    world.resumed = true
    world.nectar = snap.nectar or 0
    world.nectarEarned, world.nectarSpent = snap.nectarEarned or world.nectar, snap.nectarSpent or 0
    if snap.choice then world.choice = util.deepcopy(snap.choice) end
    if type(snap.ruleState) == "table" then world.ruleState = util.deepcopy(snap.ruleState) end
    -- the bag, exactly as it was (anything that no longer fits, or no longer exists, is stowed or skipped)
    local inv = p.inventory
    inv:clear()
    inv.rows = math.max(inv.rows, snap.rows or inv.rows)
    inv:rebuildGrid()
    for _, e in ipairs(snap.bag or {}) do
        if Content.items:get(e.id) then
            local item = Inventory.newItem(e.id)
            item.rot = e.rot or 0
            if inv:fits(item, e.x, e.y) then
                inv:placeInBag(item, e.x, e.y)
                if item.def.onAdd then item.def.onAdd(p, inv:count(item.id)) end
            else
                inv:give(item)
            end
        end
    end
    -- the skill tree: XP back (quietly), then every node bought
    local sk = p.skills
    if sk and snap.skills then
        local Skills = require("src.game.skills")
        sk = Skills.new(p, snap.skills.xp or 0)
        for id, r in pairs(snap.skills.ranks or {}) do
            local node = sk.tree and sk.tree.nodes[id]
            if node then
                r = math.min(r, node.ranks)
                sk.ranks[id] = r
                sk.points = math.max(0, sk.points - node.cost * r)
                sk.spent = sk.spent + node.cost * r
            end
        end
        p.skills = sk
        sk:apply()
    end
    if snap.blessings then require("src.game.gambles").restore(world, snap.blessings) end
    p.hp = math.max(1, math.min(snap.hp or p.stats:get("maxHp"), p.stats:get("maxHp")))
    -- the waves: species met and queens fought, then a breather before the next wave
    for _, id in ipairs(snap.known or {}) do
        local d = Content.enemies:get(id)
        if d then sp:learn(d) end
    end
    for _, id in ipairs(snap.usedQueens or {}) do sp.usedQueens[id] = true end
    sp.wave = snap.wave or 0
    sp.phase = "break"
    local manual = sp.breakLength and sp:breakLength() == math.huge
    sp.timer = manual and math.huge or 4
    if snap.pendingChoice then
        local pc = util.deepcopy(snap.pendingChoice)
        pc.at = world.time + 0.6
        world.pendingChoice = pc
    end
end

-- Carry the saved record counters into the new tracking run (Records.track was just called).
function RunSave.restoreRecord(run, snap)
    if not run or not snap.record then return end
    for _, k in ipairs(RECORD_FIELDS) do
        if snap.record[k] ~= nil then run[k] = util.deepcopy(snap.record[k]) end
    end
end

return RunSave
