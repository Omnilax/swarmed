-- Declares every content registry and loads the content/ folders into them.
-- To add a new *kind* of content: add a Registry here and a folder under content/.
-- To add a new *piece* of content: just add a file to the matching folder.
local Registry = require("src.core.registry")
local Stats = require("src.game.stats")

local Content = {}

local function statsValid(def)
    for _, field in ipairs({ "stats", "statsMult" }) do
        for id in pairs(def[field] or {}) do
            if not Stats.byId[id] then return false, "unknown stat '" .. id .. "' in " .. field end
        end
    end
    return true
end

Content.sprites = Registry.new("sprite", { required = { "palette", "frames" } })

-- AI behaviours: update(enemy, world, dt, params) sets enemy.mx/my (desired velocity).
Content.behaviors = Registry.new("behavior", { required = { "update" } })

-- Player attack patterns: fire(player, world, aimX, aimY, params).
Content.attacks = Registry.new("attack", { required = { "fire" } })

Content.enemies = Registry.new("enemy", {
    required = { "name", "sprite" },
    defaults = {
        hp = 10, speed = 40, damage = 5, radius = 5, mass = 1, xp = 1, scale = 1, family = "ant",
        behavior = "chase", behaviorParams = {},
        spawn = { weight = 10, minWave = 1, groupSize = 1 },
        gibs = { "#6b2f2a", "#a04b38", "#f0d9a0" },
        splat = "#c9b45a",
        tags = {},
    },
    validate = function(def)
        for _, f in ipairs(require("src.config.families")) do if f.id == def.family then return true end end
        return false, "unknown family '" .. tostring(def.family) .. "' (src/config/families.lua)"
    end,
})

-- Player dashes (Shift): start(player, world, dx, dy, params, px, py), or hold = true + update.
Content.dashes = Registry.new("dash", { required = { "name" } })

-- Elite affixes (Risk of Rain style): any ant can roll one. See content/elites/_template.lua.
Content.elites = Registry.new("elite", {
    required = { "name", "color" },
    defaults = { description = "", hp = 1, damage = 1, speed = 1, mass = 1, scale = 1.2, weight = 10, minWave = 1,
        params = {}, glow = 0.35 },
})

Content.characters = Registry.new("character", {
    required = { "name", "sprite", "attack" },
    defaults = { description = "", stats = {}, radius = 6, startingItems = {}, tags = {} },
    validate = statsValid,
})

Content.items = Registry.new("item", {
    required = { "name" },
    defaults = { description = "", rarity = "common", stats = {}, statsMult = {}, procs = {}, tags = {}, price = 25,
        size = { 1, 1 } },
    validate = function(def)
        def.icon = def.icon or ("icon_" .. def.id)
        local Categories = require("src.config.categories")
        if def.category and not Categories.index[def.category] then
            return false, "unknown category '" .. tostring(def.category) .. "' (see src/config/categories.lua)"
        end
        def.category = def.category or Categories.guess(def)
        -- cells it covers: from `shape` rows ("X" = filled), else the full `size` rectangle
        def.cells = {}
        if def.shape then
            local w = 0
            for y, row in ipairs(def.shape) do
                w = math.max(w, #row)
                for x = 1, #row do
                    if row:sub(x, x) ~= "." and row:sub(x, x) ~= " " then def.cells[#def.cells + 1] = { x - 1, y - 1 } end
                end
            end
            def.size = { w, #def.shape }
        else
            for y = 0, def.size[2] - 1 do for x = 0, def.size[1] - 1 do def.cells[#def.cells + 1] = { x, y } end end
        end
        if #def.cells == 0 then return false, "shape has no cells" end
        local ok, err = statsValid(def)
        if not ok then return ok, err end
        -- molted items (content/molts) are never dealt in item choices, only made by molting
        def.molted = def.rarity == "molted" or nil
        for i, p in ipairs(def.procs) do
            if not p.trigger or not p.effect then return false, "proc #" .. i .. " needs trigger and effect" end
        end
        return true
    end,
})

-- Kin branches (content/skillbranches/_template.lua): a 4th skill tree branch shared by a whole
-- lineage of bugs (beetles, spiders, crustaceans...). Each tree gets the best match for its bug's
-- tags, topped with the tree's own `signature` node. Loaded before the skill trees.
Content.skillbranches = Registry.new("skillbranch", {
    required = { "name", "nodes" },
    defaults = { tags = {}, priority = 0, blurb = "" },
})

-- Skill trees: one per character (`character` = its id; see content/skilltrees/_template.lua).
Content.skilltrees = Registry.new("skilltree", {
    required = { "character", "branches" },
    validate = function(def)
        local Skills = require("src.game.skills")
        Skills.attachKin(def, Content.characters:get(def.character))
        return Skills.validateTree(def)
    end,
})

Content.stages = Registry.new("stage", {
    required = { "name", "palette" },
    defaults = { size = 640, tileSize = 16, spawn = { interval = 2.2, minInterval = 0.5, group = { 3, 6 }, waveLength = 30 } },
})

-- Planned registries, ready for content: bosses and run events (swarm surges, hazards, ...).
-- Boss encounters (content/bosses): something big that joins boss waves (src/game/director.lua):
-- a fightable bug (`enemy`) or a stage hazard too big to fight (`hazard = true`).
Content.bosses = Registry.new("boss", { required = { "name" }, defaults = { description = "", weight = 10, minWave = 1 },
    validate = function(d)
        if d.hazard then return d.update ~= nil, "a hazard needs an update hook" end
        return d.enemy ~= nil, "needs an enemy (or hazard = true)"
    end })
-- Mid-wave events and moving hazards (content/events/_template.lua).
Content.events = Registry.new("event", { required = { "name" }, defaults = { description = "", weight = 10, minWave = 2 } })
-- Props: pebbles, twigs, cocoons, allies, the merchant (content/props/_template.lua, src/game/props.lua).
Content.props = Registry.new("prop", { required = { "name" }, defaults = { radius = 5 } })
-- Stage mechanics: a stage's `mechanic = { type = id, ... }` (content/mechanics/_template.lua).
Content.mechanics = Registry.new("mechanic", { required = { "name" } })
-- Wave modifiers (Swarm, Ambush, Shield Wall...): content/wavemods/_template.lua, src/game/pacing.lua.
Content.wavemods = Registry.new("wavemod", { required = { "name" },
    defaults = { description = "", color = { 1, 0.8, 0.4 }, weight = 10, minWave = 3 } })

-- Game modes: wave structures (who comes, how hard, when the run ends). content/modes/_template.lua.
Content.modes = Registry.new("mode", {
    required = { "name" },
    defaults = { description = "", tagline = "", order = 50, finalWave = 15, spawn = {},
        enemyHp = 1, enemyDamage = 1 },
})

-- Achievements (content/achievements/_template.lua); loaded last so they can be generated
-- from the other registries (one per character, family, elite, game mode...).
Content.achievements = Registry.new("achievement", {
    required = { "name", "value" },
    defaults = { description = "", category = "Misc", goal = 1 },
})

Content.order = { "sprites", "behaviors", "attacks", "dashes", "elites", "enemies", "characters", "skillbranches", "skilltrees", "items", "stages", "bosses", "events", "props", "mechanics", "wavemods", "modes", "achievements" }

-- Weather spells (visual only): see content/weather/_template.lua and src/game/weather.lua.
Content.weather = Registry.new("weather", { required = { "name" }, defaults = { weight = 10 } })
-- Cosmetics (src/game/cosmetics.lua): skins recolour a character, decor dresses a location.
Content.skins = Registry.new("skin", { required = { "name" }, defaults = { description = "" } })
Content.decor = Registry.new("decor", { required = { "name", "paint" }, defaults = { description = "" } })
-- Combat rewards (src/game/rewards.lua, numbers in src/config/rewards.lua): frenzy super moves,
-- kill-streak buffs, optional mini-goals in a wave, and the route gates between waves.
Content.frenzies = Registry.new("frenzy", { required = { "name", "start" }, defaults = { description = "", params = {}, tags = {} } })
Content.streaks = Registry.new("streak", { required = { "name" }, defaults = { description = "", stats = {}, statsMult = {}, time = 5, weight = 10, color = "#ffb050" } })
Content.goals = Registry.new("goal", { required = { "name", "text" }, defaults = { description = "", weight = 10, minWave = 2, reward = { xp = 20, frenzy = 0.25 } } })
Content.routes = Registry.new("route", { required = { "name", "kind" }, defaults = { description = "", weight = 10, minWave = 2, color = "#c0a070", groupMul = 1, eliteMul = 1, hpMul = 1, reward = {} } })
-- Level-up cards anyone can take (src/game/levelups.lua, content/levelcards/_template.lua).
Content.levelcards = Registry.new("levelcard", { required = { "name" },
    defaults = { stats = {}, statsMult = {}, weight = 10, minLevel = 1 }, validate = statsValid })
-- Ground pickups (src/game/nectar.lua, content/pickups/_template.lua): magnet, freeze, frenzy fill.
Content.pickups = Registry.new("pickup", { required = { "name", "collect" }, defaults = { description = "", color = "#ffffff", icon = "star", weight = 10, minWave = 1 } })
-- Artifacts: run rules toggled before a run, bought with amber (src/game/artifacts.lua).
Content.artifacts = Registry.new("artifact", { required = { "name", "description" }, defaults = { cost = 60, order = 50, color = "#c0a070" } })
-- (they load before achievements, which stay last)
do
    local at = #Content.order + 1
    for i, kind in ipairs(Content.order) do if kind == "achievements" then at = i end end
    for i, kind in ipairs({ "weather", "skins", "decor", "frenzies", "streaks", "goals", "routes", "levelcards", "pickups", "artifacts" }) do table.insert(Content.order, at + i - 1, kind) end
end

-- Molting recipes (content/molts/_template.lua, src/game/molting.lua): items touching in the bag
-- after a queen wave molt into a stronger item. Loaded after items, before achievements.
Content.molts = Registry.new("molt", { required = { "from", "into" }, defaults = { hint = nil } })
do
    local at = #Content.order + 1
    for i, kind in ipairs(Content.order) do if kind == "achievements" then at = i end end
    table.insert(Content.order, at, "molts")
end

-- Cross-references are checked after everything is loaded so content can live in any order.
local function crossCheck()
    local errors = {}
    local function need(reg, id, what)
        if not reg:get(id) then errors[#errors + 1] = what .. " references missing " .. reg.kind .. " '" .. tostring(id) .. "'" end
    end
    for _, e in ipairs(Content.enemies:all()) do
        need(Content.sprites, e.sprite, "enemy '" .. e.id .. "'")
        need(Content.behaviors, e.behavior, "enemy '" .. e.id .. "'")
        for id in pairs(e.elites or {}) do need(Content.elites, id, "enemy '" .. e.id .. "' elite variant") end
    end
    for _, c in ipairs(Content.characters:all()) do
        need(Content.sprites, c.sprite, "character '" .. c.id .. "'")
        if c.model then
            need(Content.sprites, c.model.legs, "character '" .. c.id .. "' model")
            for _, k in ipairs(c.model.kind == "chain" and { "head", "segment" } or { "body" }) do
                need(Content.sprites, c.model[k], "character '" .. c.id .. "' model")
            end
        end
        need(Content.attacks, c.attack.type, "character '" .. c.id .. "'")
        if c.secondary then need(Content.attacks, c.secondary.type, "character '" .. c.id .. "' secondary") end
        if c.dash then need(Content.dashes, c.dash.type, "character '" .. c.id .. "' dash") end
        for _, item in ipairs(c.startingItems) do need(Content.items, item, "character '" .. c.id .. "'") end
    end
    for _, t in ipairs(Content.skilltrees:all()) do need(Content.characters, t.character, "skill tree '" .. t.id .. "'") end
    for _, it in ipairs(Content.items:all()) do need(Content.sprites, it.icon, "item '" .. it.id .. "' icon") end
    for _, b in ipairs(Content.bosses:all()) do if b.enemy then need(Content.enemies, b.enemy, "boss '" .. b.id .. "'") end end
    for _, st in ipairs(Content.stages:all()) do
        if st.mechanic then need(Content.mechanics, st.mechanic.type, "stage '" .. st.id .. "' mechanic") end
        for id in pairs(st.props or {}) do need(Content.props, id, "stage '" .. st.id .. "' props") end
        -- fauna keys: enemy ids, family ids, "first" (an enemy id) or "other"
        local fams = {}
        for _, f in ipairs(require("src.config.families")) do fams[f.id] = true end
        for k, v in pairs(st.fauna or {}) do
            if k == "first" then need(Content.enemies, v, "stage '" .. st.id .. "' fauna.first")
            elseif k ~= "other" and not fams[k] then need(Content.enemies, k, "stage '" .. st.id .. "' fauna") end
        end
    end
    for _, sk in ipairs(Content.skins:all()) do
        if sk.character then need(Content.characters, sk.character, "skin '" .. sk.id .. "'") end
    end
    for _, m in ipairs(Content.modes:all()) do
        for _, id in ipairs(m.enemies or {}) do need(Content.enemies, id, "mode '" .. m.id .. "'") end
        for _, id in ipairs(m.bossPool or {}) do need(Content.enemies, id, "mode '" .. m.id .. "' bossPool") end
        -- scripted waves: every species, queen, modifier, event and encounter they name
        for i, wv in ipairs(m.waves or {}) do
            local where = "mode '" .. m.id .. "' wave " .. i
            for _, g in ipairs(wv.groups or {}) do need(Content.enemies, g[1] or g.enemy, where) end
            if wv.queen then need(Content.enemies, wv.queen, where .. " queen") end
            for _, id in ipairs(wv.mods or {}) do need(Content.wavemods, id, where .. " mods") end
            for _, id in ipairs(wv.events or {}) do need(Content.events, id, where .. " events") end
            if wv.encounter then need(Content.bosses, wv.encounter, where .. " encounter") end
        end
    end

    for _, c in ipairs(Content.characters:all()) do
        if c.frenzy then need(Content.frenzies, c.frenzy, "character '" .. c.id .. "' frenzy") end
    end
    for _, st in ipairs(Content.streaks:all()) do
        for _, field in ipairs({ "stats", "statsMult" }) do
            for id in pairs(st[field]) do if not Stats.byId[id] then errors[#errors + 1] = "streak '" .. st.id .. "' has unknown stat '" .. id .. "'" end end
        end
    end
    for _, m in ipairs(Content.molts:all()) do
        for _, id in ipairs(m.from) do need(Content.items, id, "molt '" .. m.id .. "'") end
        need(Content.items, m.into, "molt '" .. m.id .. "'")
    end

    if #errors > 0 then error("Content errors:\n  " .. table.concat(errors, "\n  ")) end
end

function Content.load()
    for _, kind in ipairs(Content.order) do
        Content[kind]:loadDirectory("content/" .. kind)
    end
    crossCheck()
end

return Content
