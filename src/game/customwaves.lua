-- Custom waves: wave sets the player builds in the wave builder (src/states/wavebuilder.lua) and
-- plays in the "Custom Waves" mode (content/modes/custom.lua). A set is plain data:
--
--   { name = "My Waves",
--     enemyHp = 1, enemyDamage = 1,     -- multipliers on every enemy
--     hpPerWave = 0.12,                 -- extra enemy health per wave
--     elites = "normal",                -- "none" | "normal" | "double" | "all"
--     rules = { mapGambles = "off", parasites = false },   -- run rules (src/game/rules.lua), optional
--     itemsOff = { honeydew = true },   -- items switched out of this set's item choices, optional
--     waves = {
--       { groups = { { "worker_ant", 30 }, { "fire_ant", 12 } },   -- species id, how many
--         queen = "queen_fire",         -- a boss enemy that comes this wave (optional)
--         mods = { "armored" },         -- wave modifiers, content/wavemods ids
--         events = { "lawnmower" },     -- mid-wave events, content/events ids
--         encounter = "sparrow" },      -- a boss encounter / stage hazard, content/bosses id
--       ... } }
--
-- Scripted modes in content/modes use the same `waves` list (see content/modes/gauntlet.lua), so
-- a set made in the game can be pasted straight into a mode file. Sets are saved in
-- "customwaves.lua" in the save folder; Copy / Paste in the builder moves them around as text.
local Content = require("src.content")
local util = require("src.core.util")
local Rules = require("src.game.rules")

local CustomWaves = { FILE = "customwaves.lua", data = nil, MAX_WAVES = 40, MAX_GROUPS = 6, MAX_COUNT = 200 }

CustomWaves.ELITES = {
    { value = "none", label = "None", cfg = { chance = 0 } },
    { value = "normal", label = "Now And Then", cfg = nil },
    { value = "double", label = "Twice As Often", cfg = { mul = 2 } },
    { value = "all", label = "Every Enemy", cfg = { chance = 1, anyWave = true } },
}

-- The sets a new save starts with: one to show how it works, one to edit.
function CustomWaves.starter()
    return {
        name = "First Steps",
        enemyHp = 1, enemyDamage = 1, hpPerWave = 0.12, elites = "normal",
        waves = {
            { groups = { { "worker_ant", 40 } } },
            { groups = { { "worker_ant", 30 }, { "fire_ant", 14 } } },
            { groups = { { "worker_ant", 30 }, { "soldier_ant", 10 } }, mods = { "swarm" } },
            { groups = { { "fire_ant", 24 }, { "soldier_ant", 14 } }, events = { "acorns" } },
            { groups = { { "worker_ant", 30 } }, queen = "queen_worker" },
        },
    }
end

function CustomWaves.blankWave() return { groups = { { "worker_ant", 30 } } } end

----------------------------------------------------------------------------------------------
-- Checking a set: anything unknown (a species removed since, a typo in pasted text) is dropped
-- rather than crashing a run.

local function num(v, lo, hi, def)
    v = tonumber(v)
    if not v or v ~= v then return def end
    return math.max(lo, math.min(hi, v))
end

local function ids(list, reg, max)
    local out = {}
    if type(list) ~= "table" then return out end
    for _, id in ipairs(list) do
        if type(id) == "string" and reg:get(id) and not util.contains(out, id) then out[#out + 1] = id end
        if #out >= (max or 8) then break end
    end
    return out
end

-- A spawnable species (not a boss, not a stage critter)?
function CustomWaves.isSpecies(d)
    return d and not d.boss and not d.encounter and (d.spawn and (d.spawn.weight or 0) > 0)
end

function CustomWaves.cleanWave(w)
    local out = { groups = {} }
    if type(w) ~= "table" then return out end
    for _, g in ipairs(type(w.groups) == "table" and w.groups or {}) do
        local id = type(g) == "table" and (g.enemy or g[1])
        local n = type(g) == "table" and (g.count or g[2])
        if type(id) == "string" and CustomWaves.isSpecies(Content.enemies:get(id)) then
            out.groups[#out.groups + 1] = { id, math.floor(num(n, 1, CustomWaves.MAX_COUNT, 20)) }
        end
        if #out.groups >= CustomWaves.MAX_GROUPS then break end
    end
    local q = type(w.queen) == "string" and Content.enemies:get(w.queen)
    if q and q.boss then out.queen = q.id end
    local mods = ids(w.mods, Content.wavemods, 3)
    if #mods > 0 then out.mods = mods end
    local evs = ids(w.events, Content.events, 4)
    if #evs > 0 then out.events = evs end
    if type(w.encounter) == "string" and Content.bosses:get(w.encounter) then out.encounter = w.encounter end
    return out
end

function CustomWaves.clean(set)
    if type(set) ~= "table" then return nil end
    local out = {
        name = type(set.name) == "string" and set.name:sub(1, 28) or "Custom Waves",
        enemyHp = num(set.enemyHp, 0.25, 4, 1),
        enemyDamage = num(set.enemyDamage, 0.25, 4, 1),
        hpPerWave = num(set.hpPerWave, 0, 0.5, 0.12),
        elites = "normal",
        waves = {},
    }
    for _, e in ipairs(CustomWaves.ELITES) do if e.value == set.elites then out.elites = e.value end end
    out.rules = Rules.clean(set.rules)
    if type(set.itemsOff) == "table" then
        for id, on in pairs(set.itemsOff) do
            if on == true and type(id) == "string" and Content.items:get(id) then
                out.itemsOff = out.itemsOff or {}
                out.itemsOff[id] = true
            end
        end
    end
    for _, w in ipairs(type(set.waves) == "table" and set.waves or {}) do
        local cw = CustomWaves.cleanWave(w)
        -- a wave needs someone in it
        if #cw.groups > 0 or cw.queen then out.waves[#out.waves + 1] = cw end
        if #out.waves >= CustomWaves.MAX_WAVES then break end
    end
    if #out.waves == 0 then return nil end
    return out
end

----------------------------------------------------------------------------------------------
-- Saving

function CustomWaves.load()
    local d = { sets = {}, active = 1 }
    if love.filesystem.getInfo(CustomWaves.FILE) then
        local ok, chunk = pcall(love.filesystem.load, CustomWaves.FILE)
        local ok2, data = false, nil
        if ok and chunk then ok2, data = pcall(chunk) end
        if ok2 and type(data) == "table" and type(data.sets) == "table" then
            for _, s in ipairs(data.sets) do
                local c = CustomWaves.clean(s)
                if c then d.sets[#d.sets + 1] = c end
            end
            d.active = tonumber(data.active) or 1
        end
    end
    if #d.sets == 0 then d.sets[1] = CustomWaves.starter() end
    d.active = math.max(1, math.min(#d.sets, d.active))
    CustomWaves.data = d
    return d
end

function CustomWaves.get() return CustomWaves.data or CustomWaves.load() end

function CustomWaves.save()
    if CustomWaves.noSave or not CustomWaves.data then return end
    local ok, s = pcall(util.serialize, CustomWaves.data)
    if ok then pcall(love.filesystem.write, CustomWaves.FILE, "return " .. s .. "\n") end
end

-- The set the Custom Waves mode plays (the one last picked in the builder).
function CustomWaves.active()
    local d = CustomWaves.get()
    return d.sets[d.active] or d.sets[1]
end

function CustomWaves.setActive(i)
    local d = CustomWaves.get()
    d.active = math.max(1, math.min(#d.sets, i))
    CustomWaves.save()
end

----------------------------------------------------------------------------------------------
-- As a game mode

-- The mode a set plays as: the Custom Waves mode def with the set's waves and strength.
function CustomWaves.modeDef(base, set)
    set = CustomWaves.clean(set) or CustomWaves.clean(CustomWaves.active()) or CustomWaves.starter()
    local m = {}
    for k, v in pairs(base) do m[k] = v end
    m.waves = set.waves
    m.set = set
    m.finalWave = #set.waves
    m.enemyHp, m.enemyDamage, m.hpPerWave = set.enemyHp, set.enemyDamage, set.hpPerWave
    for _, e in ipairs(CustomWaves.ELITES) do if e.value == set.elites then m.elites = e.cfg end end
    -- the set's run rules on top of the mode's own (src/game/rules.lua)
    m.rules = {}
    for k, v in pairs(base.rules or {}) do m.rules[k] = v end
    for k, v in pairs(set.rules or {}) do m.rules[k] = v end
    if set.itemsOff then m.rules.itemsOff = set.itemsOff end
    if m.rules.parasites == false then m.parasites = false end
    return m
end

----------------------------------------------------------------------------------------------
-- As text (Copy / Paste in the builder): a Lua table, the same as a mode file's `waves`.

function CustomWaves.toText(set)
    local ok, s = pcall(util.serialize, CustomWaves.clean(set) or set)
    return ok and ("return " .. s) or nil
end

-- Read a set back from text. The text runs with nothing to call and a step limit, so a pasted
-- set can only ever be data. Returns set or nil, error.
function CustomWaves.fromText(text)
    if type(text) ~= "string" or #text == 0 then return nil, "the clipboard is empty" end
    if #text > 64000 then return nil, "that is far too long for a wave set" end
    text = text:gsub("^%s+", "")
    if not text:find("^return") then text = "return " .. text end
    local env = {}
    local chunk, err
    if setfenv and loadstring then
        chunk, err = loadstring(text, "waves")
        if chunk then setfenv(chunk, env) end
    else
        chunk, err = load(text, "waves", "t", env)
    end
    if not chunk then return nil, "that isn't a wave set (" .. tostring(err):gsub("^.-:%d+: ", "") .. ")" end
    local hooked = debug and debug.sethook
    if hooked then debug.sethook(function() error("too slow", 0) end, "", 1e6) end
    local ok, data = pcall(chunk)
    if hooked then debug.sethook() end
    if not ok then return nil, "that isn't a wave set" end
    local set = CustomWaves.clean(data)
    if not set then return nil, "no waves with any enemies in them" end
    return set
end

return CustomWaves
