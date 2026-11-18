-- Run rules: switches that change how the game itself plays (spawns, difficulty, pacing, events,
-- gambles...). They are deliberately NOT in Settings: the main game always plays with the
-- defaults below, so everyone's game is the same game. Only a run's mode changes them:
--   * a Custom Waves set's `rules` table (picked in the wave builder, src/states/wavebuilder.lua)
--   * a mode file's `rules = { key = value }` (content/modes)
-- Settings keeps comfort options only (auto attack, aim, health bars, hit stop...).
--
--   Rules.get(key)        the value for the current run
--   Rules.begin(tbl)      World.new starts a run with its mode's rules (nil = the defaults)
--   Rules.set(key, v)     a developer / selftest override that wins over everything (nil clears)
local Rules = { current = nil, test = {} }

-- Every rule. `custom = true` ones are offered in the wave builder (the others mean nothing in a
-- scripted set: its waves already name their species, modifiers, events and encounters).
Rules.LIST = {
    { key = "mapGambles", label = "Map Gambles", type = "choice", default = "normal", custom = true,
        options = { { value = "often", label = "Often" }, { value = "normal", label = "Normal" }, { value = "off", label = "Off" } },
        desc = "Risky spots that pop up in a wave: a dewdrop shrine, a challenge bell, a gamble flower." },
    { key = "parasites", label = "Parasites", type = "toggle", default = true, custom = true,
        desc = "Parasite items can turn up in the item choices." },
    { key = "levelUps", label = "Level-Ups", type = "choice", default = "cards", custom = true,
        options = { { value = "cards", label = "Pick a Card" }, { value = "points", label = "Skill Points" } },
        desc = "Pick a Card: every level offers stat cards (or skip them for a skill point). Skill Points: every level is simply a skill point." },
    { key = "waveOverlap", label = "Overlapping Waves", type = "toggle", default = true, custom = true,
        desc = "When a wave is down to its last few ants, the next one marches in while they are still about." },
    { key = "adaptiveWaves", label = "Wave Heat", type = "toggle", default = true, custom = true,
        desc = "Waves have a par time. Past it the ants speed up and hit harder." },
    { key = "miniGoals", label = "Mini-Goals", type = "toggle", default = true, custom = true,
        desc = "Some waves come with an optional side task for bonus XP and frenzy." },
    { key = "routeGates", label = "Route Gates", type = "toggle", default = true, custom = true,
        desc = "After a wave, walk into a safer tunnel or a harder one with a better prize." },
    { key = "weatherEffects", label = "Weather Effects", type = "toggle", default = true, custom = true,
        desc = "Wind pushes everyone, rain slows the fight down, a heatwave speeds it up." },
    { key = "dashTech", label = "Dash Tech", type = "toggle", default = true, custom = true,
        desc = "A kill during a dash refunds half its stamina, and quick follow-up dashes chain faster." },
    -- main game only (scripted sets set these through their waves and strength sliders)
    { key = "midWaveEvents", default = "normal" },     -- "often" | "normal" | "off"
    { key = "bossEncounters", default = true },
    { key = "waveModifiers", default = true },
    { key = "speciesOrder", default = "random" },      -- "random" | "classic"
    { key = "eliteFrequency", default = 1 },           -- elite chance multiplier
    { key = "difficulty", default = "worker" },        -- Enemy.DIFFICULTY key
    { key = "travelActs", default = true },
}

Rules.defaults, Rules.byKey = {}, {}
for _, r in ipairs(Rules.LIST) do Rules.defaults[r.key], Rules.byKey[r.key] = r.default, r end

function Rules.get(key)
    local v = Rules.test[key]
    if v ~= nil then return v end
    local c = Rules.current
    if c and c[key] ~= nil then return c[key] end
    return Rules.defaults[key]
end

function Rules.set(key, value) Rules.test[key] = value end

function Rules.begin(tbl) Rules.current = tbl end

-- A rules table with only known keys and valid values (pasted / saved sets).
function Rules.clean(tbl)
    if type(tbl) ~= "table" then return nil end
    local out, any = {}, false
    for k, v in pairs(tbl) do
        local r = Rules.byKey[k]
        local ok = r and type(v) == type(r.default)
        if ok and r.options then
            ok = false
            for _, o in ipairs(r.options) do if o.value == v then ok = true end end
        end
        if ok and v ~= r.default then out[k], any = v, true end
    end
    return any and out or nil
end

return Rules
