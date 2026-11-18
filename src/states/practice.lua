-- Practice: drill one wave or one species without it counting as a run. Pick a bug, a game
-- mode, the wave to start on and which species comes (every species of every family, queens
-- included, or "Mixed" for whatever that wave would really bring), optionally with the items
-- and skill points a real run would have by then, and invincibility.
-- Practice runs never count toward Records or achievements and are never saved; the death
-- screen's Try Again replays the same setup. The last setup is remembered (src/game/prefs.lua).
local State = require("src.core.state")
local Content = require("src.content")
local Theme = require("src.ui.theme")
local Menu = require("src.ui.menu")
local Input = require("src.core.input")
local Families = require("src.config.families")
local Prefs = require("src.game.prefs")

local Practice = {}
Practice.__index = Practice

Practice.MAX_WAVE = 45

-- Every species a practice run can be set to, grouped by family, queens last in each.
function Practice.speciesOptions()
    local opts = { { value = "mixed", label = "Mixed (what the wave brings)" } }
    for _, fam in ipairs(Families) do
        local list = {}
        for _, d in ipairs(Content.enemies:all()) do
            if d.family == fam.id and (d.boss or (d.spawn.weight or 0) > 0) then list[#list + 1] = d end
        end
        table.sort(list, function(a, b)
            if (a.boss == true) ~= (b.boss == true) then return not a.boss end
            if a.spawn.minWave ~= b.spawn.minWave then return a.spawn.minWave < b.spawn.minWave end
            return a.name < b.name
        end)
        for _, d in ipairs(list) do
            opts[#opts + 1] = { value = d.id, label = d.name .. (d.boss and "  (boss)" or "") }
        end
    end
    return opts
end

-- XP a real run has earned by the start of wave n (roughly: every ant of every wave killed).
local function xpBy(n)
    local xp = 0
    for w = 1, n - 1 do xp = xp + math.floor((3 + (w - 1)) * 18 * (1 + 0.15 * (w - 1))) end
    return xp
end

-- Set a fresh world up for practice (called by Game.new with params.practice).
-- pr: { wave = n, species = enemy id | "mixed", items = "none" | "run", god = bool }
function Practice.apply(world, pr)
    local sp = world.spawner
    local n = math.max(1, math.min(Practice.MAX_WAVE, pr.wave or 1))
    world.practice = pr
    local def = pr.species and pr.species ~= "mixed" and Content.enemies:get(pr.species)
    if def and def.boss then
        sp.onlyQueen = def              -- every wave is that boss's wave
        sp.cfg.bossEvery = 1
        sp:catchUp(n)
    elseif def then
        sp.only = def                   -- that species and nothing else, no queens
        sp.cfg.bossEvery = 0
        sp:learn(def)
    else
        sp:catchUp(n)
    end
    sp.wave, sp.phase, sp.timer = n - 1, "break", 2
    if pr.items == "run" and n > 1 then
        for _ = 1, n - 1 do world:giveItem(world:rollItem().id) end
        if world.player.skills then world.player.skills:gainXP(xpBy(n), true) end
    end
    if pr.god then world.flags.god = true end
end

function Practice.new()
    local self = setmetatable({ t = 0 }, Practice)
    local saved = Prefs.get().practice or {}
    local last = Prefs.get().last or {}
    local chars = {}
    for _, d in ipairs(Content.characters:all()) do chars[#chars + 1] = { value = d.id, label = d.name } end
    local modes = {}
    for _, m in ipairs(Content.modes:filter(function(d) return not d.hidden end)) do modes[#modes + 1] = { value = m.id, label = m.name } end
    local function valid(list, v, fallback)
        for _, o in ipairs(list) do if o.value == v then return v end end
        return fallback
    end
    local species = Practice.speciesOptions()
    self.setup = {
        character = valid(chars, saved.character or last.character, chars[1].value),
        gameMode = valid(modes, saved.gameMode, "colony"),
        wave = math.max(1, math.min(Practice.MAX_WAVE, tonumber(saved.wave) or 5)),
        species = valid(species, saved.species, "mixed"),
        items = saved.items == "none" and "none" or "run",
        god = saved.god == true,
    }
    local st = self.setup
    local function bind(key) return function() return st[key] end, function(v) st[key] = v end end
    local items = {}
    local function add(it, key)
        if key then it.get, it.set = bind(key) end
        items[#items + 1] = it
    end
    add({ type = "choice", label = "Bug", options = chars, desc = "Which bug to practise with." }, "character")
    add({ type = "choice", label = "Mode", options = modes, desc = "Enemy families, elites and strength follow the mode." }, "gameMode")
    add({ type = "slider", label = "Start At Wave", min = 1, max = Practice.MAX_WAVE, step = 1,
        desc = "Enemy health and numbers are what that wave would have in a real run. Waves keep coming after it." }, "wave")
    add({ type = "choice", label = "Species", options = species,
        desc = "One species only (a boss comes every wave), or Mixed for what the wave would really bring." }, "species")
    add({ type = "choice", label = "Start With", options = { { value = "run", label = "Items Like A Real Run" }, { value = "none", label = "Nothing" } },
        desc = "Items Like A Real Run: one random item and the skill points for every wave skipped." }, "items")
    add({ type = "toggle", label = "Invincible", desc = "Take no damage, to learn a species' moves in peace." }, "god")
    add({ type = "button", label = "Start Practice", onActivate = function() self:start() end })
    add({ type = "button", label = "Back", onActivate = function() State.pop() end })
    self.menu = Menu.new({
        items = items,
        onBack = function() State.pop() end,
        rect = function()
            local w, h = love.graphics.getDimensions()
            local mw = math.min(w - Theme.u(60), Theme.u(720))
            return math.floor((w - mw) / 2), Theme.u(130), mw, math.min(h - Theme.u(330), Theme.u(42) * #items)
        end,
        rowHeight = 42,
    })
    self.menu.focus = #items - 1
    return self
end

function Practice:start()
    local st = self.setup
    Prefs.set("practice", { character = st.character, gameMode = st.gameMode, wave = st.wave, species = st.species,
        items = st.items, god = st.god })
    State.switch(require("src.states.game").new({ mode = "run", character = st.character, gameMode = st.gameMode,
        practice = { wave = st.wave, species = st.species, items = st.items, god = st.god } }))
end

function Practice:update(dt)
    self.t = self.t + dt
    self.menu:update(dt)
end

function Practice:draw()
    local lg = love.graphics
    local w, h = lg.getDimensions()
    local u = Theme.u
    local c = Theme.colors
    lg.clear(c.bg)
    Theme.title("Practice", w)
    self.menu:draw()

    -- what the picked species is, under the list
    local mx, my, mw, mh = self.menu:rect()
    local y = my + mh + u(18)
    local st = self.setup
    local def = st.species ~= "mixed" and Content.enemies:get(st.species)
    local ch = Content.characters:get(st.character)
    lg.setFont(Theme.font("heading", "bold"))
    local line = (ch and ch.name or "") .. "  vs  " .. (def and def.name or ("wave " .. st.wave))
    Theme.printShadow(line, mx, y, c.focus, "center", mw)
    lg.setFont(Theme.font("body"))
    lg.setColor(c.dim)
    local desc = def and (def.description or "") or "Every species a real run would have met by then, and its queens."
    lg.printf(desc, mx + u(20), y + u(36), mw - u(40), "center")
    local it = self.menu:focused()
    if it and it.desc then
        lg.setFont(Theme.font("label"))
        lg.setColor(c.dim)
        lg.printf(it.desc, u(40), h - u(84), w - u(80), "center")
    end
    lg.setFont(Theme.font("small"))
    lg.setColor(c.accent)
    lg.printf("Practice runs don't count toward records or achievements.", 0, h - u(60), w, "center")
    Theme.footer(Input.lastDevice == "gamepad" and { { "D-pad", "Change" }, { "A", "Choose" }, { "B", "Back" } }
        or { { "Arrows", "Change" }, { "Enter", "Choose" }, { "Esc", "Back" } })
end

function Practice:mousemoved(x, y) self.menu:mousemoved(x, y) end
function Practice:mousepressed(x, y, b) self.menu:mousepressed(x, y, b) end
function Practice:wheelmoved(x, y) self.menu:wheelmoved(x, y) end

return Practice
