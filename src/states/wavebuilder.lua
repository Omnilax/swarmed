-- The wave builder (Play > Custom Waves): make wave sets and play them.
--   Sets page:  every saved set, New Set, Paste Set (from the clipboard).
--   Set page:   play it, rename it, enemy strength and elites, its waves (open one to edit),
--               Add Wave, copy it to the clipboard as text, duplicate, delete.
--   Wave page:  up to six groups (species + how many), a queen, wave modifiers, events and a boss
--               encounter / stage hazard, and moving / duplicating / deleting the wave.
-- Everything is saved as it changes (src/game/customwaves.lua, "customwaves.lua" in the save
-- folder). Play picks the set and goes on to the bug select for the Custom Waves mode.
local State = require("src.core.state")
local Content = require("src.content")
local Theme = require("src.ui.theme")
local Menu = require("src.ui.menu")
local Input = require("src.core.input")
local Audio = require("src.core.audio")
local Families = require("src.config.families")
local util = require("src.core.util")
local CustomWaves = require("src.game.customwaves")

local WaveBuilder = {}
WaveBuilder.__index = WaveBuilder

local function pct(v) return math.floor(v * 100 + 0.5) .. "%" end

local function enemyName(id)
    local d = Content.enemies:get(id)
    return d and d.name or id
end

-- Option lists for the choice rows (built once per builder).
local function speciesOptions()
    local out = {}
    for _, fam in ipairs(Families) do
        local list = {}
        for _, d in ipairs(Content.enemies:all()) do
            if d.family == fam.id and CustomWaves.isSpecies(d) then list[#list + 1] = d end
        end
        table.sort(list, function(a, b)
            if a.spawn.minWave ~= b.spawn.minWave then return a.spawn.minWave < b.spawn.minWave end
            return a.name < b.name
        end)
        for _, d in ipairs(list) do out[#out + 1] = { value = d.id, label = d.name .. "  (" .. fam.label .. ")" } end
    end
    return out
end

local function queenOptions()
    local out = { { value = false, label = "None" } }
    for _, d in ipairs(Content.enemies:all()) do
        if d.boss and not d.encounter then out[#out + 1] = { value = d.id, label = d.name } end
    end
    return out
end

local function encounterOptions()
    local out = { { value = false, label = "None" } }
    for _, b in ipairs(Content.bosses:all()) do
        out[#out + 1] = { value = b.id, label = b.name .. (b.hazard and "  (hazard)" or "") }
    end
    return out
end

-- "Fire Ant x30, Worker Ant x20 + Fire Queen" for a wave's row.
function WaveBuilder.summary(w)
    local bits, total = {}, 0
    for _, g in ipairs(w.groups or {}) do
        bits[#bits + 1] = enemyName(g[1]) .. " x" .. g[2]
        total = total + g[2]
    end
    local s = table.concat(bits, ", ")
    if w.queen then s = s .. (s ~= "" and " + " or "") .. enemyName(w.queen) end
    local extra = #(w.mods or {}) + #(w.events or {}) + (w.encounter and 1 or 0)
    if extra > 0 then s = s .. "  (+" .. extra .. ")" end
    return s, total
end

-- "48 enemies + queen (+3)" for a wave's row on the set page.
function WaveBuilder.short(w)
    local _, total = WaveBuilder.summary(w)
    local s = total .. " enemies"
    if #(w.groups or {}) == 1 then s = total .. " " .. enemyName(w.groups[1][1]) end
    if w.queen then s = s .. " + queen" end
    local extra = #(w.mods or {}) + #(w.events or {}) + (w.encounter and 1 or 0)
    if extra > 0 then s = s .. "  (+" .. extra .. ")" end
    return s
end

function WaveBuilder.new()
    local self = setmetatable({ t = 0, page = "sets", si = 1, wi = 1, msg = nil, msgT = 0 }, WaveBuilder)
    self.data = CustomWaves.get()
    self.species = speciesOptions()
    self.queens = queenOptions()
    self.encounters = encounterOptions()
    self.menu = Menu.new({
        items = {},
        onBack = function() self:back() end,
        rect = function() return self:menuRect() end,
        rowHeight = 40,
    })
    self:build()
    return self
end

function WaveBuilder:menuRect()
    local w, h = love.graphics.getDimensions()
    local u = Theme.u
    local mw = self:panelRoom() and math.min(u(520), w * 0.5) or math.min(w - u(40), u(640))
    local x = self:panelRoom() and u(50) or math.floor((w - mw) / 2)
    return x, u(110), mw, h - u(200)
end

-- Is the screen wide enough for the summary panel beside the menu?
function WaveBuilder:panelRoom()
    local w = love.graphics.getWidth()
    return w - math.min(Theme.u(520), w * 0.5) > Theme.u(380)
end

-- The set page's row for the wave being edited.
function WaveBuilder:waveRow() return (self.firstWaveRow or 8) + self.wi - 1 end

function WaveBuilder:set() return self.data.sets[self.si] end
function WaveBuilder:wave() local s = self:set() return s and s.waves[self.wi] end

function WaveBuilder:say(text)
    self.msg, self.msgT = text, 3
end

function WaveBuilder:changed() CustomWaves.save() end

function WaveBuilder:back()
    if self.typing then return self:stopTyping() end
    if self.page == "wave" then
        self.page = "set"
        self:build(self:waveRow())
    elseif self.page == "set" then
        self.page = "sets"
        self:build(self.si + 1)
    else
        State.pop()
    end
end

function WaveBuilder:open(page, focus)
    self.page = page
    self:build(focus)
end

-- (Re)build the menu for the current page; focus = the row to land on.
function WaveBuilder:build(focus)
    local items = {}
    local function add(it) items[#items + 1] = it return it end
    local function bind(tbl, key, after)
        return function() return tbl[key] end, function(v) tbl[key] = v if after then after(v) end self:changed() end
    end
    self.confirmDelete = nil

    if self.page == "sets" then
        add({ type = "header", label = "Your Wave Sets" })
        for i, s in ipairs(self.data.sets) do
            add({ type = "button", label = s.name, star = i == self.data.active,
                value = function() return #s.waves .. (#s.waves == 1 and " wave" or " waves") end,
                desc = "Open this set to play or edit it.",
                onActivate = function() self.si = i self:open("set", 2) end })
        end
        add({ type = "button", label = "New Set", desc = "A fresh set with one wave of worker ants.",
            onActivate = function()
                local n = #self.data.sets + 1
                self.data.sets[n] = { name = "My Waves " .. n, enemyHp = 1, enemyDamage = 1, hpPerWave = 0.12,
                    elites = "normal", waves = { CustomWaves.blankWave() } }
                self.si = n
                self:changed()
                self:open("set", 2)
            end })
        add({ type = "button", label = "Paste Set", desc = "Add a set copied as text (from Copy Set, a friend, or a mode file).",
            onActivate = function() self:paste() end })
        add({ type = "button", label = "Back", onActivate = function() State.pop() end })
    elseif self.page == "set" then
        local s = self:set()
        local function bound(it, key) it.get, it.set = bind(s, key) return it end
        add({ type = "header", label = s.name })
        add({ type = "button", label = "Play This Set", desc = "Pick a bug and fight these waves. Clear the last one to win.",
            onActivate = function() self:play() end })
        add({ type = "button", label = "Rename", value = function() return self.typing and (s.name .. "_") or s.name end,
            desc = Input.lastDevice == "touch" and "Tap to type a new name." or "Type a new name, then Enter.",
            onActivate = function() self:startTyping() end })
        add(bound({ type = "slider", label = "Enemy Health", min = 0.25, max = 4, step = 0.05, format = pct,
            desc = "Multiplies every enemy's health." }, "enemyHp"))
        add(bound({ type = "slider", label = "Enemy Damage", min = 0.25, max = 4, step = 0.05, format = pct,
            desc = "Multiplies every enemy's damage." }, "enemyDamage"))
        add(bound({ type = "slider", label = "Tougher Each Wave", min = 0, max = 0.5, step = 0.02, format = function(v) return "+" .. pct(v) end,
            desc = "Extra enemy health every wave (the normal game is +12%)." }, "hpPerWave"))
        local elites = {}
        for _, e in ipairs(CustomWaves.ELITES) do elites[#elites + 1] = { value = e.value, label = e.label } end
        add(bound({ type = "choice", label = "Elites", options = elites, desc = "How often enemies come as elites." }, "elites"))
        add({ type = "header", label = "Waves" })
        self.firstWaveRow = #items + 1
        for i, w in ipairs(s.waves) do
            add({ type = "button", label = "Wave " .. i, value = function() return WaveBuilder.short(w) end,
                desc = "Edit what comes in this wave.",
                onActivate = function() self.wi = i self:open("wave", 2) end })
        end
        add({ type = "button", label = "Add Wave", disabled = #s.waves >= CustomWaves.MAX_WAVES,
            desc = "A copy of the last wave, to change from there.",
            onActivate = function()
                s.waves[#s.waves + 1] = util.deepcopy(s.waves[#s.waves] or CustomWaves.blankWave())
                self:changed()
                self.wi = #s.waves
                self:open("wave", 2)
            end })
        add({ type = "header", label = "Set" })
        add({ type = "button", label = "Copy Set", desc = "Copy the set as text to share it, or to paste into a mode file.",
            onActivate = function() self:copy() end })
        add({ type = "button", label = "Duplicate Set", onActivate = function()
            local c = util.deepcopy(s)
            c.name = (s.name .. " Copy"):sub(1, 28)
            table.insert(self.data.sets, self.si + 1, c)
            self.si = self.si + 1
            self:changed()
            self:say("Duplicated.")
            self:build(2)
        end })
        add({ type = "button", label = "Delete Set", disabled = #self.data.sets <= 1,
            value = function() return self.confirmDelete == "set" and "Press again" or "" end,
            onActivate = function()
                if self.confirmDelete ~= "set" then self.confirmDelete = "set" return end
                table.remove(self.data.sets, self.si)
                self.data.active = math.max(1, math.min(#self.data.sets, self.data.active > self.si and self.data.active - 1 or self.data.active))
                self.si = math.max(1, self.si - 1)
                self:changed()
                self.page = "sets"
                self:build(2)
            end })
        add({ type = "button", label = "Back", onActivate = function() self:back() end })
    else
        local s, w = self:set(), self:wave()
        add({ type = "header", label = "Wave " .. self.wi .. " of " .. #s.waves })
        for gi, g in ipairs(w.groups) do
            add({ type = "choice", label = "Group " .. gi, options = self.species, desc = "Which species this group is.",
                get = function() return g[1] end, set = function(v) g[1] = v self:changed() end })
            add({ type = "slider", label = "   How Many", min = 5, max = CustomWaves.MAX_COUNT, step = 5,
                desc = "How many of them come (in columns of about twenty).",
                get = function() return g[2] end, set = function(v) g[2] = v self:changed() end })
            add({ type = "button", label = "   Remove Group " .. gi, disabled = #w.groups <= 1 and not w.queen,
                onActivate = function()
                    table.remove(w.groups, gi)
                    self:changed()
                    self:build(self.menu.focus)
                end })
        end
        add({ type = "button", label = "Add Group", disabled = #w.groups >= CustomWaves.MAX_GROUPS,
            onActivate = function()
                local last = w.groups[#w.groups]
                w.groups[#w.groups + 1] = { last and last[1] or "worker_ant", 20 }
                self:changed()
                self:build(self.menu.focus + 3)
            end })
        add({ type = "choice", label = "Queen", options = self.queens, desc = "A boss that comes two seconds in. The wave lasts until she falls.",
            get = function() return w.queen or false end,
            set = function(v) w.queen = v or nil self:changed() end })
        add({ type = "choice", label = "Encounter", options = self.encounters,
            desc = "A boss encounter, or a stage hazard (too big to fight) that hunts until the wave is cleared.",
            get = function() return w.encounter or false end,
            set = function(v) w.encounter = v or nil self:changed() end })
        add({ type = "header", label = "Wave Modifiers (up to 3)" })
        for _, d in ipairs(Content.wavemods:all()) do
            add({ type = "toggle", label = d.name, desc = d.description,
                get = function() return util.contains(w.mods or {}, d.id) end,
                set = function(on) self:toggleIn(w, "mods", d.id, on, 3) end })
        end
        add({ type = "header", label = "Events (up to 4)" })
        for _, d in ipairs(Content.events:all()) do
            add({ type = "toggle", label = d.name, desc = d.description,
                get = function() return util.contains(w.events or {}, d.id) end,
                set = function(on) self:toggleIn(w, "events", d.id, on, 4) end })
        end
        add({ type = "header", label = "This Wave" })
        add({ type = "button", label = "Duplicate Wave", disabled = #s.waves >= CustomWaves.MAX_WAVES, onActivate = function()
            table.insert(s.waves, self.wi + 1, util.deepcopy(w))
            self.wi = self.wi + 1
            self:changed()
            self:say("Duplicated: now editing wave " .. self.wi .. ".")
            self:build(2)
        end })
        add({ type = "button", label = "Move Earlier", disabled = self.wi <= 1, onActivate = function()
            s.waves[self.wi], s.waves[self.wi - 1] = s.waves[self.wi - 1], s.waves[self.wi]
            self.wi = self.wi - 1
            self:changed()
            self:build(self.menu.focus)
        end })
        add({ type = "button", label = "Move Later", disabled = self.wi >= #s.waves, onActivate = function()
            s.waves[self.wi], s.waves[self.wi + 1] = s.waves[self.wi + 1], s.waves[self.wi]
            self.wi = self.wi + 1
            self:changed()
            self:build(self.menu.focus)
        end })
        add({ type = "button", label = "Delete Wave", disabled = #s.waves <= 1,
            value = function() return self.confirmDelete == "wave" and "Press again" or "" end,
            onActivate = function()
                if self.confirmDelete ~= "wave" then self.confirmDelete = "wave" return end
                table.remove(s.waves, self.wi)
                self.wi = math.max(1, self.wi - 1)
                self:changed()
                self.page = "set"
                self:build(self:waveRow())
            end })
        add({ type = "button", label = "Done", onActivate = function() self:back() end })
    end
    self.menu:setItems(items)
    if focus then
        self.menu.focus = math.max(1, math.min(#items, focus))
        self.menu:fixFocus(1)
    end
end

-- Switch an id in or out of a wave's list (mods / events), at most `max` of them.
function WaveBuilder:toggleIn(w, key, id, on, max)
    local list = w[key] or {}
    for i = #list, 1, -1 do if list[i] == id then table.remove(list, i) end end
    if on then
        if #list >= max then
            self:say("Up to " .. max .. " per wave.")
            Audio.play("ui_back")
        else
            list[#list + 1] = id
        end
    end
    w[key] = #list > 0 and list or nil
    self:changed()
end

function WaveBuilder:play()
    local s = CustomWaves.clean(self:set())
    if not s then self:say("This set has no enemies in it.") return end
    CustomWaves.setActive(self.si)
    State.push(require("src.states.charselect").new({ gameMode = "custom" }))
end

function WaveBuilder:copy()
    local text = CustomWaves.toText(self:set())
    local ok = text and pcall(love.system.setClipboardText, text)
    self:say(ok and "Copied the set to the clipboard as text." or "Couldn't copy here.")
end

function WaveBuilder:paste()
    local ok, text = pcall(love.system.getClipboardText)
    local set, err = CustomWaves.fromText(ok and text or nil)
    if not set then self:say("Couldn't paste: " .. tostring(err) .. ".") Audio.play("ui_back") return end
    self.data.sets[#self.data.sets + 1] = set
    self.si = #self.data.sets
    self:changed()
    self:say("Added \"" .. set.name .. "\".")
    self:open("set", 2)
end

----------------------------------------------------------------------------------------------
-- Typing a set's name

function WaveBuilder:startTyping()
    self.typing = true
    pcall(love.keyboard.setTextInput, true)
end

function WaveBuilder:stopTyping()
    self.typing = false
    self.skipFrame = true       -- the Enter that ended typing must not press the row again
    pcall(love.keyboard.setTextInput, false)
    local s = self:set()
    s.name = s.name:gsub("^%s+", ""):gsub("%s+$", "")
    if s.name == "" then s.name = "My Waves" end
    self:changed()
    self:build(self.menu.focus)
end

function WaveBuilder:textinput(t)
    if not self.typing then return end
    local s = self:set()
    if #s.name < 28 then s.name = s.name .. t:gsub("[%c\"\\]", "") end
end

function WaveBuilder:keypressed(key)
    if not self.typing then return end
    if key == "backspace" then
        local s = self:set()
        -- drop the last character (UTF-8 aware)
        local byte = #s.name
        while byte > 0 and s.name:byte(byte) >= 0x80 and s.name:byte(byte) < 0xC0 do byte = byte - 1 end
        s.name = s.name:sub(1, math.max(0, byte - 1))
    elseif key == "return" or key == "kpenter" or key == "escape" then
        self:stopTyping()
    end
end

----------------------------------------------------------------------------------------------

function WaveBuilder:update(dt)
    self.t = self.t + dt
    if self.msgT > 0 then self.msgT = self.msgT - dt end
    if self.typing then
        -- a tap anywhere / the pad's confirm finishes typing
        if Input.pressed("ui_confirm") and Input.lastDevice == "gamepad" then self:stopTyping() end
        return
    end
    if self.skipFrame then self.skipFrame = false return end
    local before = self.menu.focus
    self.menu:update(dt)
    if self.menu.focus ~= before then self.confirmDelete = nil end
end

-- Right-hand panel: the whole set (set page) or the wave being edited (wave page).
function WaveBuilder:drawPanel()
    local lg = love.graphics
    local u, c = Theme.u, Theme.colors
    local w, h = lg.getDimensions()
    local mx, my, mw, mh = self:menuRect()
    local px = mx + mw + u(40)
    local pw, ph = w - px - u(40), mh
    Theme.panel(px, my, pw, ph)
    local x, y, iw = px + u(26), my + u(22), pw - u(52)
    local bottom = my + ph - u(26)
    local function line(text, color, font)
        if y > bottom then return end
        lg.setFont(Theme.font(font or "label"))
        lg.setColor(color or c.text)
        local _, wrapped = lg.getFont():getWrap(text, iw)
        lg.printf(text, x, y, iw)
        y = y + math.max(1, #wrapped) * lg.getFont():getHeight() + u(6)
    end
    if self.page == "sets" then
        lg.setFont(Theme.font("heading", "bold"))
        Theme.printShadow("CUSTOM WAVES", x, y, c.focus)
        y = y + u(40)
        line("Build your own run: choose every wave's species and how many come, add queens, wave modifiers, events and stage hazards, and set how tough the enemies are.", c.text, "body")
        y = y + u(8)
        line("Clear your last wave to win, then keep going: the set starts again, tougher.", c.dim)
        line("Copy Set puts a set on the clipboard as text. Paste it back here, send it to a friend, or drop its waves into a mode file in content/modes (see gauntlet.lua).", c.dim)
        local it = self.menu:focused()
        if it and it.label and it.type == "button" then
            for _, s in ipairs(self.data.sets) do
                if s.name == it.label then
                    y = y + u(10)
                    line(s.name, c.accent, "body")
                    for i, wv in ipairs(s.waves) do line(i .. ".  " .. (WaveBuilder.summary(wv))) end
                    break
                end
            end
        end
        return
    end
    local s = self:set()
    if self.page == "set" then
        lg.setFont(Theme.font("heading", "bold"))
        Theme.printShadow(s.name:upper(), x, y, c.focus)
        y = y + u(40)
        local total = 0
        for _, wv in ipairs(s.waves) do local _, n = WaveBuilder.summary(wv) total = total + n end
        line(#s.waves .. " waves, " .. total .. " enemies in all.  Health " .. pct(s.enemyHp) .. ", damage " .. pct(s.enemyDamage) .. ".", c.accent)
        y = y + u(6)
        for i, wv in ipairs(s.waves) do
            local text, n = WaveBuilder.summary(wv)
            line(("%d.  %s"):format(i, text ~= "" and text or "(empty)"), n > 0 and c.text or c.dim)
        end
        return
    end
    local wv = self:wave()
    lg.setFont(Theme.font("heading", "bold"))
    Theme.printShadow("WAVE " .. self.wi, x, y, c.focus)
    y = y + u(40)
    local _, total = WaveBuilder.summary(wv)
    line(total .. " enemies" .. (wv.queen and (" and " .. enemyName(wv.queen)) or ""), c.accent, "body")
    for _, g in ipairs(wv.groups) do
        local d = Content.enemies:get(g[1])
        line(g[2] .. "  " .. (d and d.name or g[1]), c.text)
        if d and d.description and d.description ~= "" then line("     " .. d.description, c.dim, "small") end
    end
    local function names(list, reg)
        local out = {}
        for _, id in ipairs(list or {}) do local d = reg:get(id) out[#out + 1] = d and d.name or id end
        return table.concat(out, ", ")
    end
    if wv.mods then line("Modifiers: " .. names(wv.mods, Content.wavemods), c.text) end
    if wv.events then line("Events: " .. names(wv.events, Content.events), c.text) end
    if wv.encounter then line("Encounter: " .. names({ wv.encounter }, Content.bosses), c.text) end
end

function WaveBuilder:draw()
    local lg = love.graphics
    local w, h = lg.getDimensions()
    local u, c = Theme.u, Theme.colors
    lg.clear(c.bg)
    Theme.title("Custom Waves", w)
    self.menu:draw()
    if self:panelRoom() then self:drawPanel() end
    local it = self.menu:focused()
    local text = (self.msgT > 0 and self.msg) or (self.typing and "Type a name, then Enter.") or (it and it.desc)
    if text then
        lg.setFont(Theme.font("label"))
        lg.setColor(self.msgT > 0 and c.accent or c.dim)
        lg.printf(text, u(40), h - u(80), w - u(80), "center")
    end
    Theme.footer(Input.lastDevice == "gamepad" and { { "D-pad", "Change" }, { "A", "Choose" }, { "B", "Back" } }
        or { { "Arrows", "Change" }, { "Enter", "Choose" }, { "Esc", "Back" } })
end

function WaveBuilder:mousemoved(x, y) if not self.typing then self.menu:mousemoved(x, y) end end
function WaveBuilder:mousepressed(x, y, b)
    if self.typing then self:stopTyping() return end
    self.menu:mousepressed(x, y, b)
end
function WaveBuilder:wheelmoved(x, y) self.menu:wheelmoved(x, y) end

return WaveBuilder
