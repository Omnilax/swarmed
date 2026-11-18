-- The in-game wiki's pages (src/states/wiki.lua, opened from the Field Guide). Everything here is
-- written at runtime from the content registries and configs, so new bugs, enemies, items, maps
-- and so on show up by themselves. "How it works" notes are the comment block at the top of the
-- content file (a behaviour, attack or dash file), minus its "params:" lines, so the wiki says what
-- the code says. The Design notes section comes from src/config/wiki_notes.lua (made from
-- docs/wiki/*.md by tools/make_wiki_notes.py).
--
-- A section: { id, label, entries }. An entry: { title, group (a list heading), icon (sprite id),
-- tint, hidden (not met yet), blocks = { { h = heading } | { p = text, color = "dim"|"good"|...,
-- italic } | { pic = sprite id } } }.
local Content = require("src.content")
local Settings = require("src.core.settings")

local Wiki = {}

----------------------------------------------------------------------------------------------
-- Helpers

local commentCache = {}

-- The prose at the top of a content file: its leading "--" lines without the params part.
function Wiki.howItWorks(path)
    if commentCache[path] ~= nil then return commentCache[path] or nil end
    local ok, src = pcall(love.filesystem.read, path)
    local paras, cur, inParams = {}, {}, false
    if ok and src then
        for line in (src .. "\n"):gmatch("(.-)\r?\n") do
            local body = line:match("^%-%-+%s?(.*)$")
            if not body then break end
            if body:match("^%s*[Pp]arams?%s*:") or body:match("^%s*[Pp]arameters%s*:") then
                inParams = true
            elseif inParams and body:match("^%s%s+") then
                -- a params continuation line
            elseif body:match("^%s*$") then
                inParams = false
                if #cur > 0 then paras[#paras + 1] = table.concat(cur, " "); cur = {} end
            else
                inParams = false
                cur[#cur + 1] = (body:gsub("^%s+", ""))
            end
        end
    end
    if #cur > 0 then paras[#paras + 1] = table.concat(cur, " ") end
    local text = #paras > 0 and table.concat(paras, "\n") or false
    if text then text = text:gsub("[{}]", "") end
    commentCache[path] = text
    return text or nil
end

local function fmtNum(v)
    if type(v) ~= "number" then return tostring(v) end
    local s = math.floor(v * 100 + 0.5) / 100
    if s == math.floor(s) then return tostring(math.floor(s)) end
    return tostring(s)
end

local function statLabel(id)
    local Stats = require("src.game.stats")
    local d = Stats.byId[id]
    return d and d.label or id, d
end

-- "+5 Damage, +10% Move Speed, x1.2 Max HP"
function Wiki.statLine(stats, mult)
    local parts = {}
    local ids = {}
    for id in pairs(stats or {}) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local v = stats[id]
        local label, d = statLabel(id)
        if type(v) == "number" and v ~= 0 then
            parts[#parts + 1] = (v > 0 and "+" or "") .. fmtNum(v) .. (d and d.percent and "%" or (d and d.suffix) or "") .. " " .. label
        end
    end
    ids = {}
    for id in pairs(mult or {}) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local v = mult[id]
        if type(v) == "number" and v ~= 0 then
            parts[#parts + 1] = (v > 0 and "+" or "") .. fmtNum(v * 100) .. "% " .. (statLabel(id))
        end
    end
    return table.concat(parts, ", ")
end

local function add(blocks, b) blocks[#blocks + 1] = b end
local function para(blocks, text, color, italic)
    if type(text) == "function" then
        local ok, v = pcall(text)
        text = ok and v or nil
    end
    if type(text) == "string" and text ~= "" then add(blocks, { p = text, color = color, italic = italic }) end
end
local function heading(blocks, text) add(blocks, { h = text }) end

local function joinNames(reg, weights)
    local list = {}
    for id, w in pairs(weights or {}) do
        local def = reg and reg:get(id)
        if (type(w) ~= "number" or w > 0) then list[#list + 1] = def and def.name or id end
    end
    table.sort(list)
    return table.concat(list, ", ")
end

local function unlockAll() return Settings.get("unlockAll") == true end

----------------------------------------------------------------------------------------------
-- Bugs

local function moveBlocks(blocks, label, move, reg, folder)
    if type(move) ~= "table" or not move.type then return end
    local def = reg:get(move.type)
    heading(blocks, label .. ": " .. (def and def.name or move.type))
    para(blocks, def and def.description)
    local how = Wiki.howItWorks("content/" .. folder .. "/" .. move.type .. ".lua")
    if how then para(blocks, how, "dim") end
    local nums = {}
    for _, k in ipairs({ "damage", "cooldown", "charges", "distance", "radius", "range" }) do
        if type(move[k]) == "number" then nums[#nums + 1] = k:sub(1, 1):upper() .. k:sub(2) .. " " .. fmtNum(move[k]) end
    end
    if #nums > 0 then para(blocks, table.concat(nums, ", "), "accent") end
end

local function bugEntry(def)
    local b = {}
    if def.sprite then add(b, { pic = def.sprite }) end
    para(b, def.description)
    local s = def.stats or {}
    local line = {}
    for _, k in ipairs({ "maxHp", "moveSpeed", "damage", "armor", "attackSpeed", "critChance" }) do
        if s[k] then line[#line + 1] = statLabel(k) .. " " .. fmtNum(s[k]) end
    end
    if #line > 0 then para(b, table.concat(line, ", "), "accent") end
    para(b, def.tip and ("Tip: " .. def.tip), "good")
    moveBlocks(b, "Attack", def.attack, Content.attacks, "attacks")
    moveBlocks(b, "Special", def.secondary, Content.attacks, "attacks")
    moveBlocks(b, "Dash", def.dash, Content.dashes, "dashes")
    for _, tree in ipairs(Content.skilltrees:all()) do
        if tree.character == def.id then
            heading(b, "Skill tree")
            for _, br in ipairs(tree.branches or {}) do
                local names = {}
                for _, n in ipairs(br.nodes or {}) do names[#names + 1] = n.name end
                para(b, br.name .. (br.blurb and (" (" .. br.blurb .. ")") or "") .. ": " .. table.concat(names, ", "))
            end
            if tree.signature then para(b, "Signature, " .. tree.signature.name .. ": " .. (tree.signature.desc or ""), "accent") end
        end
    end
    if def.lore then heading(b, "Field notes"); para(b, def.lore, "dim", true) end
    return b
end

local function bugsSection()
    local styles = require("src.config.playstyles").styles
    local entries = {}
    for _, st in ipairs(styles) do
        for _, def in ipairs(Content.characters:all()) do
            if def.playstyle == st.id and not def.custom then
                entries[#entries + 1] = { title = def.name, group = st.label, icon = def.sprite, def = def, build = bugEntry }
            end
        end
    end
    for _, def in ipairs(Content.characters:all()) do
        local known = false
        for _, st in ipairs(styles) do if def.playstyle == st.id then known = true end end
        if not known or def.custom then
            entries[#entries + 1] = { title = def.name, group = def.custom and "Your bugs" or "Other", icon = def.sprite, def = def, build = bugEntry }
        end
    end
    return entries
end

----------------------------------------------------------------------------------------------
-- Enemies

local function seen(def)
    if unlockAll() then return true end
    local ok, Records = pcall(require, "src.game.records")
    local prof = ok and Records.get and Records.get()
    return prof and prof.seen and prof.seen[def.id] or false
end

local function groupLabel(g)
    if g >= 1.2 then return "huge columns" elseif g >= 0.8 then return "columns" elseif g >= 0.3 then return "small packs" end
    return "alone or in pairs"
end

local function enemyEntry(def)
    local b = {}
    add(b, { pic = def.sprite })
    para(b, def.description)
    local sp = def.spawn or {}
    para(b, ("Health %s, speed %s, bite %s"):format(fmtNum(def.hp), fmtNum(def.speed), fmtNum(def.damage)), "accent")
    if not def.boss and (sp.weight or 0) > 0 then
        para(b, ("Turns up from wave %s, %s."):format(fmtNum(sp.minWave or 1), groupLabel(sp.groupSize or 1)), "dim")
    end
    para(b, def.tip and ("Tip: " .. def.tip), "good")
    if def.behavior then
        local beh = Content.behaviors:get(def.behavior)
        heading(b, "How it behaves" .. (beh and beh.name and (": " .. beh.name) or ""))
        para(b, Wiki.howItWorks("content/behaviors/" .. def.behavior .. ".lua") or "It walks straight at you.", "dim")
    end
    if def.brood then
        local brood = Content.enemies:get(def.brood)
        para(b, "Queen of the " .. (brood and brood.name or def.brood) .. ". She brings her brood with her.", "dim")
    end
    if def.lore then heading(b, "Field notes"); para(b, def.lore, "dim", true) end
    return b
end

local function eliteEntry(el)
    local b = {}
    para(b, el.description)
    local parts = {}
    for _, k in ipairs({ "hp", "damage", "speed" }) do
        if type(el[k]) == "number" and el[k] ~= 1 then parts[#parts + 1] = k:sub(1, 1):upper() .. k:sub(2) .. " x" .. fmtNum(el[k]) end
    end
    if #parts > 0 then para(b, table.concat(parts, ", "), "accent") end
    para(b, "Any ant can roll an elite affix from wave " .. fmtNum(el.minWave or 1) .. ". Elites glow in the affix colour and drop more.", "dim")
    para(b, Wiki.howItWorks("content/elites/" .. el.id .. ".lua"), "dim")
    return b
end

local function enemiesSection()
    local list = {}
    for _, def in ipairs(Content.enemies:all()) do list[#list + 1] = def end
    table.sort(list, function(a, c)
        local wa, wc = (a.spawn or {}).minWave or 1, (c.spawn or {}).minWave or 1
        if wa ~= wc then return wa < wc end
        return a.name < c.name
    end)
    local entries = {}
    for _, fam in ipairs(require("src.config.families")) do
        for _, def in ipairs(list) do
            if not def.boss and def.family == fam.id then
                entries[#entries + 1] = { title = def.name, group = fam.label, icon = def.sprite, def = def, build = enemyEntry, hidden = not seen(def) }
            end
        end
    end
    for _, def in ipairs(list) do
        if def.boss then
            entries[#entries + 1] = { title = def.name, group = "Queens", icon = def.sprite, def = def, build = enemyEntry, hidden = not seen(def) }
        end
    end
    for _, el in ipairs(Content.elites:all()) do
        entries[#entries + 1] = { title = el.name, group = "Elite affixes", tint = el.color, def = el, build = eliteEntry }
    end
    return entries
end

----------------------------------------------------------------------------------------------
-- Items

local function itemEntry(def)
    local b = {}
    add(b, { pic = def.icon or ("icon_" .. def.id) })
    para(b, def.description)
    para(b, def.curse and ("Cost: " .. def.curse), "bad")
    local st = Wiki.statLine(def.stats, def.statsMult)
    if st ~= "" and st ~= def.description then para(b, st, "accent") end
    local rar = require("src.config.rarities")[def.rarity]
    local cdef = def.category and require("src.config.categories")[def.category]
    local cat = type(cdef) == "table" and cdef.label or nil
    local info = { (rar and rar.label or def.rarity) }
    if cat or def.category then info[#info + 1] = cat or def.category end
    if def.shape then info[#info + 1] = #def.shape .. " cells"
    elseif type(def.size) == "table" then info[#info + 1] = (def.size[1] or 1) .. "x" .. (def.size[2] or 1) .. " cells" end
    if not def.parasite and (def.price or 0) > 0 then info[#info + 1] = def.price .. " nectar" end
    para(b, table.concat(info, ", "), "dim")
    if #(def.tags or {}) > 0 then
        local tags = require("src.config.tags")
        local t = {}
        for _, id in ipairs(def.tags) do t[#t + 1] = tags[id] and tags[id].label or id end
        para(b, "Tags: " .. table.concat(t, ", "), "dim")
    end
    if def.parasite then
        para(b, "A parasite lives in your bug, not the bag. Only a Green Mushroom purges it.", "dim")
    end
    if def.lore then para(b, def.lore, "dim", true) end
    return b
end

local function itemsSection()
    local rar = require("src.config.rarities")
    local order = {}
    for id, r in pairs(rar) do order[#order + 1] = { id = id, r = r } end
    table.sort(order, function(a, c)
        local oa = a.r.order == 0 and (a.r.parasite and 7 or 6) or a.r.order
        local oc = c.r.order == 0 and (c.r.parasite and 7 or 6) or c.r.order
        return oa < oc
    end)
    local entries = {}
    for _, o in ipairs(order) do
        local list = Content.items:filter(function(d) return d.rarity == o.id and not d.hidden end)
        table.sort(list, function(a, c) return a.name < c.name end)
        for _, def in ipairs(list) do
            entries[#entries + 1] = { title = def.name, group = o.r.label, icon = def.icon or ("icon_" .. def.id), def = def, build = itemEntry }
        end
    end
    return entries
end

----------------------------------------------------------------------------------------------
-- Level-up cards, maps, the world, modes, progression

local function simple(def, extra)
    local b = {}
    para(b, def.description)
    if extra then extra(b, def) end
    if #b == 0 then para(b, "Nothing more to it.", "dim") end
    return b
end

local function cardsSection()
    local entries = {}
    for _, def in ipairs(Content.levelcards:all()) do
        entries[#entries + 1] = { title = def.name, group = "Level-up cards", def = def, build = function(d)
            return simple(d, function(b)
                local st = Wiki.statLine(d.stats, d.statsMult)
                if st ~= "" then para(b, st, "accent") end
                para(b, "Dealt from level " .. fmtNum(d.minLevel or 1) .. ". Rarer cards multiply the numbers.", "dim")
            end)
        end }
    end
    return entries
end

local function stageEntry(def)
    return simple(def, function(b)
        if def.weather then heading(b, "Weather"); para(b, joinNames(Content.weather, def.weather)) end
        if def.fauna then heading(b, "Locals"); para(b, joinNames(Content.enemies, def.fauna)) end
        if def.props then heading(b, "Lying about"); para(b, joinNames(Content.props, def.props)) end
        if type(def.mechanic) == "table" and def.mechanic.type then
            local m = Content.mechanics:get(def.mechanic.type)
            heading(b, "Map rule: " .. (m and m.name or def.mechanic.type))
            para(b, m and m.description)
        end
    end)
end

local function mapsSection()
    local entries = {}
    for _, def in ipairs(Content.stages:all()) do
        entries[#entries + 1] = { title = def.name, group = "Maps", def = def, build = stageEntry }
    end
    return entries
end

local function withHow(folder)
    return function(def)
        return simple(def, function(b)
            local how = Wiki.howItWorks("content/" .. folder .. "/" .. def.id .. ".lua")
            if how then heading(b, "How it works"); para(b, how, "dim") end
        end)
    end
end

local function worldSection()
    local entries = {}
    local function list(reg, group, folder, pred)
        for _, def in ipairs(reg:all()) do
            if not pred or pred(def) then
                entries[#entries + 1] = { title = def.title or def.name, group = group, def = def, build = withHow(folder) }
            end
        end
    end
    list(Content.events, "Events & hazards", "events")
    list(Content.bosses, "Stage hazards", "bosses", function(d) return d.hazard end)
    list(Content.bosses, "Encounters", "bosses", function(d) return not d.hazard end)
    list(Content.mechanics, "Map rules", "mechanics")
    list(Content.wavemods, "Wave modifiers", "wavemods")
    list(Content.weather, "Weather", "weather")
    list(Content.props, "Things on the ground", "props", function(d) return not d.hidden end)
    list(Content.pickups, "Pickups", "pickups")
    return entries
end

local function modesSection()
    local entries = {}
    for _, def in ipairs(Content.modes:all()) do
        if not def.hidden then
            entries[#entries + 1] = { title = def.name, group = "Modes", def = def, build = function(d)
                return simple(d, function(b)
                    para(b, d.tagline, "accent")
                    if d.finalWave then para(b, "Won after wave " .. fmtNum(d.finalWave) .. " (you may keep going).", "dim")
                    elseif d.finalWave == false then para(b, "No end: see how far you get.", "dim") end
                end)
            end }
        end
    end
    for _, r in ipairs(require("src.game.rules").LIST) do
        if r.custom then
            entries[#entries + 1] = { title = r.label, group = "Run rules (Custom Waves)", def = r, build = function(d)
                local b = {}
                para(b, d.desc)
                para(b, "Run rules are set by a mode or a Custom Waves set, never in Settings: the main game always plays the same way.", "dim")
                return b
            end }
        end
    end
    return entries
end

local function progressionSection()
    local entries = {}
    for _, def in ipairs(Content.artifacts:all()) do
        entries[#entries + 1] = { title = def.name, group = "Artifacts (the Burrow)", tint = def.color, def = def, build = function(d)
            return simple(d, function(b) para(b, fmtNum(d.cost) .. " amber. An artifact changes a rule of the run, not your power.", "dim") end)
        end }
    end
    for _, def in ipairs(require("src.config.keepsakes")) do
        entries[#entries + 1] = { title = def.name, group = "Keepsakes", tint = def.color, def = def, build = function(d)
            return simple(d, function(b) para(b, fmtNum(d.cost) .. " amber. Carry one into a run: always a trade, never a straight gain.", "dim") end)
        end }
    end
    for i, def in ipairs(require("src.config.danger")) do
        entries[#entries + 1] = { title = "Danger " .. i .. ": " .. def.name, group = "Danger levels", tint = def.color, def = def, build = function(d)
            return simple(d, function(b) para(b, "Each level adds its rule on top of the ones below. Win a run to open the next level for that bug.", "dim") end)
        end }
    end
    return entries
end

local function notesSection()
    local ok, notes = pcall(require, "src.config.wiki_notes")
    local entries = {}
    if not ok then return entries end
    for _, ch in ipairs(notes) do
        for _, pg in ipairs(ch.pages) do
            entries[#entries + 1] = { title = pg.title, group = ch.title, def = pg, build = function(d)
                local b = {}
                for _, blk in ipairs(d.blocks) do
                    if blk.h then heading(b, blk.h) else para(b, blk.p, blk.color) end
                end
                return b
            end }
        end
    end
    return entries
end

----------------------------------------------------------------------------------------------

Wiki.SECTIONS = {
    { id = "bugs", label = "Bugs", blurb = "Every bug you can play: stats, moves, how each move works, and its skill tree.", make = bugsSection },
    { id = "enemies", label = "Enemies", blurb = "Every ant, bee, wasp, termite and queen, and how each one behaves. Ones you haven't met stay hidden.", make = enemiesSection },
    { id = "items", label = "Items", blurb = "Every item by rarity: what it does, its stats, tags, size and price.", make = itemsSection },
    { id = "cards", label = "Level-ups", blurb = "The level-up cards and what they give.", make = cardsSection },
    { id = "maps", label = "Maps", blurb = "Every map: its weather, the locals that wander in, what lies about, and its map rule.", make = mapsSection },
    { id = "world", label = "World", blurb = "Events, stage hazards, encounters, map rules, wave modifiers, weather, props and pickups.", make = worldSection },
    { id = "modes", label = "Modes", blurb = "The modes and the run rules a Custom Waves set can change.", make = modesSection },
    { id = "meta", label = "Progress", blurb = "Artifacts, keepsakes and danger levels.", make = progressionSection },
    { id = "notes", label = "Design", blurb = "How the game is built and why: engine, systems, style.", make = notesSection },
}

-- The entries of section i (built once per open of the wiki, so they follow unlocks).
function Wiki.entries(i)
    local s = Wiki.SECTIONS[i]
    local ok, list = pcall(s.make)
    if not ok then
        print("wiki: section " .. s.id .. " failed: " .. tostring(list))
        return {}
    end
    return list
end

-- The blocks of one entry (made on first view and kept).
function Wiki.blocks(entry)
    if not entry.blocks then
        local ok, b = pcall(entry.build, entry.def)
        entry.blocks = ok and b or { { p = "This page could not be written: " .. tostring(b), color = "bad" } }
    end
    return entry.blocks
end

return Wiki
