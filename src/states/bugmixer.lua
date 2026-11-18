-- Bug Creator: mix and match. Pick a body, the three moves, stats, colours, a rule and a skill
-- tree from the built-in bugs, watch it fight on the right, save. Saving writes a script
-- (src/game/custombugs.lua), so "Edit as Code" carries on from exactly what was mixed here.
local State = require("src.core.state")
local Theme = require("src.ui.theme")
local Menu = require("src.ui.menu")
local Audio = require("src.core.audio")
local Content = require("src.content")
local MovePreview = require("src.ui.movepreview")
local CustomBugs = require("src.game.custombugs")
local Stats = require("src.game.stats")

local Mixer = {}
Mixer.__index = Mixer

local PREVIEW_ID = "custom__preview"
local OWN = "__own"           -- a move written in the script, not copied from a bug
local NONE = "__none"

-- the stats the mixer has sliders for: { id, min, max, step }
local SLIDERS = {
    { "maxHp", 5, 500, 5 }, { "moveSpeed", 30, 300, 5 }, { "armor", -10, 30, 1 },
    { "damage", -80, 150, 5 }, { "attackSpeed", -60, 150, 5 }, { "critChance", 0, 80, 1 }, { "hpRegen", 0, 10, 0.5 },
}

local function builtins()
    return Content.characters:filter(function(c) return not c.custom end)
end

local function statOf(def, id)
    local v = def and def.stats and def.stats[id]
    if v ~= nil then return v end
    local s = Stats.byId[id]
    return s and s.default or 0
end

-- opts.from: a custom bug entry (CustomBugs.get) to start from; nil = a fresh bug
function Mixer.new(opts)
    opts = opts or {}
    local self = setmetatable({ t = 0, previewT = 0 }, Mixer)
    local m = {}
    local entry = opts.from
    local def = entry and entry.def
    if def then
        m.name, m.description, m.lore, m.tip = def.name, def.description, def.lore, def.tip
        m.look = def.mix.look
        m.size = math.floor(def.scale * 20 + 0.5) * 5
        m.colors = def.colors
        m.hue = def.colors and def.colors.hue or 0
        for _, slot in ipairs({ "attack", "secondary", "dash" }) do
            local f = def.mix[slot]
            if f == false then m[slot] = NONE
            elseif f then m[slot] = f
            else m[slot] = OWN end
            m[slot .. "Own"] = def[slot] and CustomBugs.plain(def[slot])
        end
        m.stats = {}
        for k, v in pairs(def.stats) do m.stats[k] = v end
        m.rules, m.skillTree = def.rules or NONE, def.skillTree or NONE
        m.startingItems, m.tags, m.immune = def.startingItems, def.tags, def.immune
        self.replaces = def.id
        if (def.description or ""):find("^The body of the ") then self.autoDesc = def.description end
        self.fromCode = entry.source and not entry.source:find("^%-%- Made with the Bug Creator") or false
        -- own art, code, sounds...: only name, size, colour and stats can change here (tweak mode)
        if CustomBugs.coded(def) and entry.source then
            -- compared with the script without earlier tweaks, so those are kept
            local inner = CustomBugs.untweaked(entry.source)
            self.tweak = { source = inner, def = (inner ~= entry.source and CustomBugs.compile(inner)) or def }
            self.fromCode = false
        end
    else
        local base = Content.characters:get("rhino_beetle") or builtins()[1]
        m.name = "My Bug"
        m.look, m.attack, m.secondary, m.dash = base.id, base.id, base.id, base.id
        m.size = math.floor((base.scale or 1) * 20 + 0.5) * 5
        self.statsFrom = base.id
        m.hue = 0
        m.stats = {}
        for _, s in ipairs(SLIDERS) do m.stats[s[1]] = statOf(base, s[1]) end
        m.rules, m.skillTree = NONE, base.id
    end
    self.m = m
    self.menu = Menu.new({
        items = {},
        onBack = function() self:back() end,
        rect = function()
            local w, h = love.graphics.getDimensions()
            return Theme.u(50), Theme.u(110), math.min(Theme.u(470), w * 0.46), h - Theme.u(170)
        end,
    })
    self:build()
    self:refresh(true)
    return self
end

----------------------------------------------------------------------------------------------
-- The script the current mix makes

function Mixer:raw()
    local m = self.m
    local function nameOf(id) local d = Content.characters:get(id) return d and d.name or id end
    local raw = {
        name = m.name,
        description = m.description,
        lore = m.lore,
        tip = m.tip,
        look = m.look,
        scale = m.size / 100,
        playstyle = (Content.characters:get(m.look) or {}).playstyle,
        stats = {},
        immune = m.immune,
        tags = m.tags,
        startingItems = m.startingItems and #m.startingItems > 0 and m.startingItems or nil,
    }
    -- a made-up description until the player writes one (Edit as Code)
    if not raw.description or raw.description == "" or self.autoDesc == raw.description then
        local parts = { "The body of the " .. nameOf(m.look) }
        if m.attack ~= OWN then parts[#parts + 1] = "the attack of the " .. nameOf(m.attack) end
        if m.secondary ~= OWN and m.secondary ~= NONE then parts[#parts + 1] = "the special of the " .. nameOf(m.secondary) end
        if m.dash ~= OWN and m.dash ~= NONE then parts[#parts + 1] = "the dash of the " .. nameOf(m.dash) end
        local d = table.concat(parts, ", ", 1, #parts - 1) .. (#parts > 1 and " and " or "") .. parts[#parts] .. "."
        raw.description = d:sub(1, 1):upper() .. d:sub(2)
        self.autoDesc = raw.description
    end
    -- stats at their default are left out of the script
    for k, v in pairs(m.stats) do
        local st = Stats.byId[k]
        if not st or st.default ~= v then raw.stats[k] = v end
    end
    if m.hue ~= 0 or m.colors then
        local c = {}
        for k, v in pairs(m.colors or {}) do c[k] = v end
        c.hue = m.hue ~= 0 and m.hue or nil
        raw.colors = next(c) and c or nil
    end
    for _, slot in ipairs({ "attack", "secondary", "dash" }) do
        local v = m[slot]
        if v == OWN then raw[slot] = m[slot .. "Own"]
        elseif v == NONE then raw[slot] = false
        else raw[slot] = v end
    end
    if m.rules ~= NONE then raw.rules = m.rules end
    if m.skillTree ~= NONE then raw.skillTree = m.skillTree end
    return raw
end

function Mixer:source()
    if not self.tweak then return CustomBugs.toSource(self:raw()) end
    -- tweak mode: the script stays, a few lines after it change what was changed here
    local m, d = self.m, self.tweak.def
    local t = { stats = {} }
    if m.name ~= d.name then t.name = m.name end
    if m.size ~= math.floor(d.scale * 20 + 0.5) * 5 then t.scale = m.size / 100 end
    if m.hue ~= (d.colors and d.colors.hue or 0) then
        local c = {}
        for k, v in pairs(d.colors or {}) do c[k] = v end
        c.hue = m.hue ~= 0 and m.hue or nil
        t.colors = next(c) and c or false
    end
    for k, v in pairs(m.stats) do
        if v ~= statOf(d, k) then t.stats[k] = v end
    end
    if not (t.name or t.scale or t.colors ~= nil or next(t.stats)) then return self.tweak.source end
    -- the name is always written once it differs, so the file keeps its name after a rename
    return CustomBugs.tweakSource(self.tweak.source, t)
end

----------------------------------------------------------------------------------------------
-- Menu

function Mixer:build(keep)
    local m = self.m
    local items = {}
    local bugOpts, secOpts, dashOpts = {}, {}, {}
    for _, d in ipairs(builtins()) do
        bugOpts[#bugOpts + 1] = { value = d.id, label = d.name }
        if d.secondary then secOpts[#secOpts + 1] = { value = d.id, label = d.name } end
        dashOpts[#dashOpts + 1] = { value = d.id, label = d.name }
    end
    local function withOwn(opts, slot, none)
        local o = {}
        if m[slot] == OWN then o[1] = { value = OWN, label = "Own move (script)" } end
        if none then o[#o + 1] = { value = NONE, label = none } end
        for _, x in ipairs(opts) do o[#o + 1] = x end
        return o
    end
    local function set(k) return function(v) m[k] = v self:refresh() end end
    local function get(k) return function() return m[k] end end

    items[#items + 1] = { type = "header", label = "Bug" }
    items[#items + 1] = { type = "button", label = "Name", value = function()
            return self.naming and (m.name .. ((self.t % 1 < 0.6) and "_" or " ")) or m.name
        end, desc = "Type a name (Enter when done).",
        onActivate = function() self:startNaming() end }
    if not self.tweak then
        items[#items + 1] = { type = "choice", label = "Body", options = bugOpts, get = get("look"), set = set("look"),
            desc = "Whose body, model and animations it has." }
    end
    items[#items + 1] = { type = "slider", label = "Size", min = 50, max = 200, step = 5, get = get("size"), set = set("size"),
        format = function(v) return v .. "%" end, desc = "Drawn size. Bigger bugs have a bigger hitbox and get shoved less." }
    items[#items + 1] = { type = "slider", label = "Colour", min = 0, max = 350, step = 10, get = get("hue"), set = set("hue"),
        format = function(v) return v == 0 and "Natural" or (v .. "°") end, desc = "Turns every colour round the colour wheel." }
    if not self.tweak then
    items[#items + 1] = { type = "header", label = "Moves" }
    items[#items + 1] = { type = "choice", label = "Attack", options = withOwn(bugOpts, "attack"), get = get("attack"),
        set = set("attack"), desc = "The main attack (left click) of this bug." }
    items[#items + 1] = { type = "choice", label = "Special", options = withOwn(secOpts, "secondary", "None"),
        get = get("secondary"), set = set("secondary"), desc = "The special (right click) of this bug." }
    items[#items + 1] = { type = "choice", label = "Dash", options = withOwn(dashOpts, "dash", "Plain dash"), get = get("dash"),
        set = set("dash"), desc = "The Shift move of this bug." }
    end
    items[#items + 1] = { type = "header", label = "Stats" }
    items[#items + 1] = not self.tweak and { type = "choice", label = "Copy stats of", options = bugOpts,
        get = function() return self.statsFrom or m.look end,
        set = function(v)
            self.statsFrom = v
            local d = Content.characters:get(v)
            for _, s in ipairs(SLIDERS) do m.stats[s[1]] = statOf(d, s[1]) end
            self:refresh()
        end, desc = "Sets every slider below to that bug's stats." } or nil
    for _, s in ipairs(SLIDERS) do
        local st = Stats.byId[s[1]]
        items[#items + 1] = { type = "slider", label = st and st.label or s[1], min = s[2], max = s[3], step = s[4],
            get = function() return m.stats[s[1]] or statOf(nil, s[1]) end,
            set = function(v) m.stats[s[1]] = v self:refresh() end,
            format = function(v) return (st and st.percent) and (v .. "%") or tostring(v) end,
            desc = st and st.info and st.info(m.stats[s[1]] or st.default) or nil }
    end
    if not self.tweak then
    items[#items + 1] = { type = "header", label = "Extras" }
    local ruleOpts, treeOpts = { { value = NONE, label = "None" } }, { { value = NONE, label = "Fits its playstyle" } }
    local Presets = require("src.config.presettrees")
    for _, pid in ipairs(Presets.order) do
        treeOpts[#treeOpts + 1] = { value = "preset:" .. pid, label = "Preset: " .. Presets.list[pid].name }
    end
    local Rules = require("src.config.bugrules")
    local Skills = require("src.game.skills")
    for _, d in ipairs(builtins()) do
        if Rules[d.id] then ruleOpts[#ruleOpts + 1] = { value = d.id, label = Rules[d.id].name .. " (" .. d.name .. ")" } end
        if Skills.treeFor(d.id) then treeOpts[#treeOpts + 1] = { value = d.id, label = d.name } end
    end
    items[#items + 1] = { type = "choice", label = "Item rule", options = ruleOpts, get = get("rules"), set = set("rules"),
        desc = "Borrow a bug's special item rule." }
    items[#items + 1] = { type = "choice", label = "Skill tree", options = treeOpts, get = get("skillTree"), set = set("skillTree"),
        desc = "A ready-made preset tree (works with any moves), or borrow a bug's tree (its upgrades work best with that bug's own moves). Every bug also gets its kin branch." }
    end
    items[#items + 1] = { type = "header", label = "" }
    items[#items + 1] = { type = "button", label = "Save", onActivate = function() self:save(false) end,
        desc = "Save it. It joins the bug select screen (Show: Custom Bugs)." }
    items[#items + 1] = { type = "button", label = "Save & Play", onActivate = function() self:save(true) end }
    items[#items + 1] = { type = "button", label = "Edit as Code", onActivate = function() self:toCode() end,
        desc = "Open this mix as a Lua script to change any number, write a description and more." }
    items[#items + 1] = { type = "button", label = "Back", onActivate = function() self:back() end }
    self.menu:setItems(items, keep)
end

----------------------------------------------------------------------------------------------
-- Naming (typed straight into the Name row)

function Mixer:startNaming()
    self.naming = true
    self.wantsText = true        -- main.lua: keys come here while typing
    if love.keyboard.setTextInput then love.keyboard.setTextInput(true) end
end

function Mixer:stopNaming()
    self.naming, self.wantsText = false, nil
    if love.keyboard.setTextInput then love.keyboard.setTextInput(false) end
    if not self.m.name:find("%w") then self.m.name = "My Bug" end
    self:refresh()
end

function Mixer:textinput(t)
    if not self.naming then return end
    if #self.m.name + #t <= 28 then self.m.name = self.m.name .. t end
end

function Mixer:keypressed(key)
    if not self.naming then return end
    if key == "backspace" then
        local s = self.m.name
        local c = #s
        while c > 1 and s:byte(c) >= 0x80 and s:byte(c) < 0xC0 do c = c - 1 end
        self.m.name = s:sub(1, c - 1)
    elseif key == "return" or key == "kpenter" or key == "escape" or key == "tab" then
        self:stopNaming()
    end
end

----------------------------------------------------------------------------------------------
-- Preview, save, leave

function Mixer:refresh(now)
    self.previewT = now and 0 or 0.35
    self.pending = true
end

function Mixer:rebuildPreview()
    self.pending = false
    local def, errs, warns
    if self.tweak then
        local info
        def, info = CustomBugs.compile(self:source(), "tweak")
        errs, warns = info.errors, info.warnings
        if def then CustomBugs.prepareArt(def) end
    else
        def, errs, warns = CustomBugs.build(self:raw())
    end
    self.errors, self.warnings = errs, warns
    if self.preview then self.preview:release() self.preview = nil end
    if Content.characters:get(PREVIEW_ID) then Content.characters:unregister(PREVIEW_ID) end
    self.def = def
    if not def then return end
    def.id = PREVIEW_ID
    Content.characters:register(def)
    local ok, pv = pcall(MovePreview.new, PREVIEW_ID)
    if ok then self.preview = pv else print("[mixer] preview failed: " .. tostring(pv)) end
end

function Mixer:dropPreview()
    if self.preview then self.preview:release() self.preview = nil end
    if Content.characters:get(PREVIEW_ID) then Content.characters:unregister(PREVIEW_ID) end
end

function Mixer:save(play)
    if self.naming then self:stopNaming() end
    local def, info = CustomBugs.save(self:source(), self.replaces)
    if not def then
        self.flash = { "Can't save: " .. tostring(info.errors[1]), Theme.colors.bad }
        Audio.play("ui_back")
        return
    end
    self.replaces = def.id
    self.flash = { "Saved " .. def.name .. ".", Theme.colors.good }
    self.saved = true
    if play then
        self:dropPreview()
        local mode = (require("src.game.prefs").get().last or {}).gameMode or "colony"
        require("src.states.menu").quickStart(def.id, mode)
    end
end

function Mixer:toCode()
    if self.naming then self:stopNaming() end
    local Editor = require("src.states.codeeditor")
    local replaces = self.replaces
    self:dropPreview()
    State.pop()
    State.push(Editor.new({ text = self:source(), replaces = replaces, title = "Bug Script" }))
end

function Mixer:back()
    if self.naming then self:stopNaming() return end
    self:dropPreview()
    State.pop()
end

function Mixer:leave() self:dropPreview() end

function Mixer:update(dt)
    self.t = self.t + dt
    if not self.naming then self.menu:update(dt) end
    if self.pending then
        self.previewT = self.previewT - dt
        if self.previewT <= 0 then self:rebuildPreview() end
    end
    if self.preview then self.preview:update(dt) end
end

function Mixer:mousemoved(x, y) if not self.naming then self.menu:mousemoved(x, y) end end
function Mixer:mousepressed(x, y, b)
    if self.naming then self:stopNaming() end
    self.menu:mousepressed(x, y, b)
end
function Mixer:wheelmoved(x, y) self.menu:wheelmoved(x, y) end

function Mixer:draw()
    local lg = love.graphics
    local w, h = lg.getDimensions()
    local u = Theme.u
    local c = Theme.colors
    -- the preview draws through the world canvas first
    local mx, my, mw = self.menu:rect()
    local px = mx + mw + u(40)
    local pw = w - px - u(50)
    local bx, by, bw = px + u(16), u(126), pw - u(32)
    local bh = math.floor(math.min(bw * 0.62, h * 0.42))
    lg.clear(c.bg)
    Theme.panel(px, u(110), pw, h - u(170))
    if self.preview then
        self.preview:draw(bx, by, bw, bh)
    else
        lg.setColor(c.panelEdge)
        lg.rectangle("line", bx, by, bw, bh)
    end
    Theme.title(self.tweak and "Tweak" or self.replaces and "Mix Parts" or "New Bug")
    self.menu:draw()

    local d = self.def
    local ty = by + bh + u(14)
    lg.setFont(Theme.font("heading"))
    Theme.printShadow(self.m.name, px, ty, c.text, "center", pw)
    ty = ty + lg.getFont():getHeight() + u(6)
    lg.setFont(Theme.font("label"))
    if d then
        local function mv(slot, reg)
            local p = d[slot]
            local mdef = p and reg:get(p.type)
            return p and p.name or (mdef and (mdef.name or p.type)) or "none"
        end
        lg.setColor(c.dim)
        lg.printf(("Attack: %s    Special: %s    Dash: %s"):format(mv("attack", Content.attacks),
            mv("secondary", Content.attacks), mv("dash", Content.dashes)), px + u(16), ty, pw - u(32), "center")
        ty = ty + lg.getFont():getHeight() * 2 + u(6)
    end
    -- help for the focused row, then any problem
    local it = self.menu:focused()
    local desc = it and it.desc
    if self.tweak then
        desc = (desc and desc .. "\n\n" or "") .. "This bug has its own art or code, so its script is kept as it is: what you change here is added as a few lines after it."
    elseif self.fromCode then
        desc = (desc and desc .. "\n\n" or "") .. "This bug was written as code: saving here rewrites its script from these settings."
    end
    if desc then
        lg.setColor(c.text)
        lg.printf(desc, px + u(16), ty, pw - u(32), "center")
    end
    local fy = h - u(170) + u(110) - u(36)
    if self.errors and #self.errors > 0 then
        lg.setColor(c.bad)
        lg.printf(self.errors[1], px + u(16), fy, pw - u(32), "center")
    elseif self.flash then
        lg.setColor(self.flash[2])
        lg.printf(self.flash[1], px + u(16), fy, pw - u(32), "center")
    end
    lg.setColor(1, 1, 1, 1)
    if self.naming then
        Theme.footer({ { "Type", "Name" }, { "Enter", "Done" } })
    else
        Theme.footer({ { "Left/Right", "Change" }, { "Enter", "Select" }, { "Esc", "Back" } })
    end
end

return Mixer
