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
        for i, p in ipairs(def.procs) do
            if not p.trigger or not p.effect then return false, "proc #" .. i .. " needs trigger and effect" end
        end
        return true
    end,
})

-- Skill trees: one per character (`character` = its id; see content/skilltrees/_template.lua).
Content.skilltrees = Registry.new("skilltree", {
    required = { "character", "branches" },
    validate = function(def) return require("src.game.skills").validateTree(def) end,
})

Content.stages = Registry.new("stage", {
    required = { "name", "palette" },
    defaults = { size = 640, tileSize = 16, spawn = { interval = 2.2, minInterval = 0.5, group = { 3, 6 }, waveLength = 30 } },
})

-- Planned registries, ready for content: bosses and run events (swarm surges, hazards, ...).
Content.bosses = Registry.new("boss", { required = { "name", "enemy" } })
Content.events = Registry.new("event", { required = { "name" } })
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

Content.order = { "sprites", "behaviors", "attacks", "dashes", "elites", "enemies", "characters", "skilltrees", "items", "stages", "bosses", "events", "wavemods", "modes", "achievements" }

-- Weather spells (visual only): see content/weather/_template.lua and src/game/weather.lua.
Content.weather = Registry.new("weather", { required = { "name" }, defaults = { weight = 10 } })
-- Cosmetics (src/game/cosmetics.lua): skins recolour a character, decor dresses a location.
Content.skins = Registry.new("skin", { required = { "name" }, defaults = { description = "" } })
Content.decor = Registry.new("decor", { required = { "name", "paint" }, defaults = { description = "" } })
-- (they load before achievements, which stay last)
do
    local at = #Content.order + 1
    for i, kind in ipairs(Content.order) do if kind == "achievements" then at = i end end
    for i, kind in ipairs({ "weather", "skins", "decor" }) do table.insert(Content.order, at + i - 1, kind) end
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
    for _, b in ipairs(Content.bosses:all()) do need(Content.enemies, b.enemy, "boss '" .. b.id .. "'") end
    for _, sk in ipairs(Content.skins:all()) do
        if sk.character then need(Content.characters, sk.character, "skin '" .. sk.id .. "'") end
    end
    for _, m in ipairs(Content.modes:all()) do
        for _, id in ipairs(m.enemies or {}) do need(Content.enemies, id, "mode '" .. m.id .. "'") end
        for _, id in ipairs(m.bossPool or {}) do need(Content.enemies, id, "mode '" .. m.id .. "' bossPool") end
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
