-- Bug Creator (main menu): make your own playable bugs.
--   Mix Parts        pick a body, moves, stats... from the built-in bugs (src/states/bugmixer.lua)
--   Write a Script   start from the blueprint in the script editor (src/states/codeeditor.lua)
--   Paste a Script   a script someone shared, from the clipboard
-- Dropping a .lua file on the window imports it too (desktop). Every custom bug is a script in
-- the save folder's custom_bugs/ (src/game/custombugs.lua); the guide is docs/CUSTOM_BUGS.md.
local State = require("src.core.state")
local Theme = require("src.ui.theme")
local Menu = require("src.ui.menu")
local Audio = require("src.core.audio")
local Content = require("src.content")
local Sprites = require("src.gfx.sprites")
local CustomBugs = require("src.game.custombugs")

local Creator = {}
Creator.__index = Creator

local function Editor() return require("src.states.codeeditor") end
local function Mixer() return require("src.states.bugmixer") end

function Creator.new()
    local self = setmetatable({ t = 0 }, Creator)
    self.menu = Menu.new({
        items = {},
        onBack = function() State.pop() end,
        rect = function()
            local w, h = love.graphics.getDimensions()
            return Theme.u(60), Theme.u(120), math.min(Theme.u(400), w * 0.4), h - Theme.u(180)
        end,
    })
    self:build()
    return self
end

function Creator:resume()
    local it = self.menu:focused()
    self:build(it and (it.bugId or it.label))
end

local function playBug(id)
    local mode = (require("src.game.prefs").get().last or {}).gameMode or "colony"
    require("src.states.menu").quickStart(id, mode)
end

function Creator:build(focusKey)
    local items = {}
    items[#items + 1] = { type = "header", label = "Make a bug" }
    items[#items + 1] = { type = "button", label = "Mix Parts", onActivate = function() State.push(Mixer().new()) end,
        desc = "Build a bug from the parts of the others: one bug's body, another's attack, a third's dash. Then set its stats and colour and watch it fight." }
    items[#items + 1] = { type = "button", label = "Write a Script", onActivate = function()
            State.push(Editor().new({ title = "New Bug Script" }))
        end,
        desc = "Write a bug in Lua, starting from the blueprint: every field explained, change what you like. The guide (docs/CUSTOM_BUGS.md) lists every move, stat and item." }
    items[#items + 1] = { type = "button", label = "Paste a Script", onActivate = function() self:pasteScript() end,
        desc = "Import a bug someone shared: copy their script, then press this. On a computer you can also drop a .lua file onto the game window." }

    items[#items + 1] = { type = "button", label = "Example: Stick Insect", onActivate = function()
            State.push(Editor().new({ text = love.filesystem.read("content/characters/_example_stick_insect.lua"),
                title = "Example Bug" }))
        end,
        desc = "A brand-new bug made only from a script: its own pixel art and legs, and three moves written in code. Open it, read it, press Save to play it, or use it as a starting point." }
    items[#items + 1] = { type = "button", label = "Example: Velvet Worm", onActivate = function()
            State.push(Editor().new({ text = love.filesystem.read("content/characters/_example_velvet_worm.lua"),
                title = "Example Bug" }))
        end,
        desc = "Everything a script can do: a segmented body with feelers, a hold-to-charge glue squirt, a sticky wall, a stamina mode, code that runs when it kills or gets hurt, its own sounds, animations and skill tree." }

    local bugs = CustomBugs.all()
    items[#items + 1] = { type = "header", label = ("Your bugs  (%d)"):format(#bugs) }
    if #bugs == 0 and #CustomBugs.broken == 0 then
        items[#items + 1] = { type = "button", label = "None yet", disabled = true }
    end
    for _, e in ipairs(bugs) do
        local open = self.open == e.id
        items[#items + 1] = { type = "button", label = e.def.name, bugId = e.id, entry = e,
            value = function() return open and "Close" or nil end,
            onActivate = function() self.open = (self.open ~= e.id) and e.id or nil self:build(e.id) end }
        if open then
            local function act(label, fn, desc)
                items[#items + 1] = { type = "button", label = "     " .. label, entry = e, onActivate = fn, desc = desc }
            end
            act("Play", function() playBug(e.id) end)
            -- a bug with its own art or code opens the mixer in tweak mode: name, size, colour
            -- and stats change, the rest of its script stays as it is
            act(CustomBugs.coded(e.def) and "Tweak" or "Mix Parts",
                function() State.push(Mixer().new({ from = e })) end)
            act("Edit Code", function() State.push(Editor().new({ text = e.source, replaces = e.id, title = "Bug Script" })) end)
            act("Copy Code", function()
                local ok = pcall(love.system.setClipboardText, e.source or "")
                self.flash = ok and { "Copied " .. e.def.name .. "'s script: paste it anywhere to share it.", Theme.colors.good }
                    or { "Copying isn't available here.", Theme.colors.dim }
            end)
            act(self.confirmDelete == e.id and "Press again to delete" or "Delete", function()
                if self.confirmDelete ~= e.id then
                    self.confirmDelete = e.id
                    self:build("     Press again to delete")
                    return
                end
                CustomBugs.delete(e.id)
                self.confirmDelete, self.open = nil, nil
                self.flash = { "Deleted " .. e.def.name .. ".", Theme.colors.dim }
                self:build()
            end)
        end
    end
    for _, b in ipairs(CustomBugs.broken) do
        items[#items + 1] = { type = "button", label = b.id, broken = b, value = function() return "Broken" end,
            onActivate = function()
                State.push(Editor().new({ text = b.source or "", replaces = b.id, title = "Fix Bug Script" }))
            end, desc = "This file didn't load: " .. tostring(b.error) .. "\n\nOpen it to fix it." }
    end

    items[#items + 1] = { type = "header", label = "Share" }
    items[#items + 1] = { type = "button", label = "Copy the Blueprint", onActivate = function()
            local ok = pcall(love.system.setClipboardText, CustomBugs.blueprint())
            self.flash = ok and { "Blueprint copied: paste it into any text editor.", Theme.colors.good }
                or { "Copying isn't available here.", Theme.colors.dim }
        end, desc = "The documented template for a bug script, to write bugs outside the game." }
    local os = love.system.getOS()
    if os ~= "Web" and os ~= "iOS" and os ~= "Android" then
        items[#items + 1] = { type = "button", label = "Open the Bug Folder", onActivate = function()
                love.filesystem.createDirectory(CustomBugs.dir)
                love.system.openURL("file://" .. love.filesystem.getSaveDirectory() .. "/" .. CustomBugs.dir)
            end, desc = "Every custom bug is a .lua file in this folder. Add, change or remove files there, then press Reload." }
        items[#items + 1] = { type = "button", label = "Reload Bug Files", onActivate = function()
                local n = CustomBugs.loadAll()
                self.flash = { ("Loaded %d bug%s%s."):format(n, n == 1 and "" or "s",
                    #CustomBugs.broken > 0 and (", " .. #CustomBugs.broken .. " broken") or ""), Theme.colors.good }
                self:build()
            end, desc = "Load the bug folder again after changing files in it." }
    end
    items[#items + 1] = { type = "button", label = "Back", onActivate = function() State.pop() end }

    self.menu:setItems(items)
    if focusKey then
        for i, it in ipairs(items) do
            if (it.bugId and it.bugId == focusKey) or it.label == focusKey then self.menu.focus = i break end
        end
    end
    if self.menu.items[self.menu.focus] and self.menu.items[self.menu.focus].disabled then self.menu:fixFocus(1) end
end

-- Import a script: compile it, save it if it works, else open it in the editor to fix.
function Creator:import(text, from)
    if type(text) ~= "string" or text == "" then
        self.flash = { "Nothing to import: the clipboard is empty.", Theme.colors.dim }
        Audio.play("ui_back")
        return
    end
    local def, info = CustomBugs.save(text)
    if def then
        self.flash = { "Imported " .. def.name .. (from and (" from " .. from) or "") .. ".", Theme.colors.good }
        Audio.play("ui_confirm")
        self.open = def.id
        self:build(def.id)
    else
        Audio.play("ui_back")
        local ed = Editor().new({ text = text, title = "Fix Bug Script" })
        ed.flash = { "That script has a problem: fix it and save.", Theme.colors.bad }
        State.push(ed)
    end
end

function Creator:pasteScript()
    local ok, t = pcall(love.system.getClipboardText)
    self:import(ok and t or nil, "the clipboard")
end

function Creator:filedropped(file)
    local name = tostring(file:getFilename()):match("[^/\\]+$") or "file"
    if not name:lower():match("%.lua$") and not name:lower():match("%.txt$") then
        self.flash = { "Only .lua bug scripts can be imported.", Theme.colors.bad }
        return
    end
    local ok = pcall(file.open, file, "r")
    local data = ok and file:read() or nil
    pcall(file.close, file)
    self:import(data, name)
end

function Creator:update(dt)
    self.t = self.t + dt
    self.menu:update(dt)
    local it = self.menu:focused()
    if self.confirmDelete and not (it and it.label == "     Press again to delete") then
        self.confirmDelete = nil
        self:build(it and it.label)
    end
end

function Creator:mousemoved(x, y) self.menu:mousemoved(x, y) end
function Creator:mousepressed(x, y, b) self.menu:mousepressed(x, y, b) end
function Creator:wheelmoved(x, y) self.menu:wheelmoved(x, y) end

function Creator:draw()
    local lg = love.graphics
    local w, h = lg.getDimensions()
    local u = Theme.u
    local c = Theme.colors
    lg.clear(c.bg)
    Theme.title("Bug Creator")
    self.menu:draw()

    local mx, _, mw = self.menu:rect()
    local px = mx + mw + u(50)
    local pw, ph = w - px - u(60), h - u(180)
    Theme.panel(px, u(120), pw, ph)
    local it = self.menu:focused()
    local e = it and it.entry
    local ty = u(140)
    local small = h < 600       -- phones: smaller model, shorter text, all inside the panel
    lg.setScissor(px, u(120), pw, ph)
    if e then
        local def = e.def
        -- the bug, slowly turning
        local spr = Sprites.get(def.sprite)
        local s = small and 2 or math.floor(u(4))
        local ds = s * (def.scale or 1)
        local cx, cy = px + pw / 2, ty + u(small and 30 or 70)
        lg.setColor(0, 0, 0, 0.35)
        lg.ellipse("fill", cx, cy + s * 2, spr.w * ds * 0.55, spr.w * ds * 0.25)
        lg.setColor(1, 1, 1, 1)
        local Cos = require("src.game.cosmetics")
        local sh = Cos.shader(def.colors)
        if sh then lg.setShader(sh) end
        if def.model then
            Sprites.drawModel(def.model, math.floor(self.t * spr.fps) + 1, cx, cy, math.pi * 0.25 + math.sin(self.t * 0.7) * 1.4, false, ds, ds)
        else
            Sprites.draw(spr, math.floor(self.t * spr.fps) + 1, cx, cy, -math.pi / 2, false, ds)
        end
        lg.setShader()
        ty = cy + u(small and 30 or 70)
        lg.setFont(Theme.font("heading"))
        Theme.printShadow(def.name, px, ty, c.text, "center", pw)
        ty = ty + lg.getFont():getHeight() + u(8)
        lg.setFont(Theme.font(small and "label" or "body"))
        lg.setColor(c.text)
        local descText = small and "" or def.description
        local _, wrapped = lg.getFont():getWrap(descText, pw - u(48))
        lg.printf(descText, px + u(24), ty, pw - u(48), "center")
        ty = ty + #wrapped * lg.getFont():getHeight() + u(12)
        lg.setFont(Theme.font("label"))
        local function mv(slot, reg)
            local p = def[slot]
            local m = p and reg:get(p.type)
            return p and p.name or (m and (m.name or p.type)) or "none"
        end
        local look = def.mix.look and Content.characters:get(def.mix.look)
        local rows = {
            { "Body", def.mix.art and "Its own art" or (look and look.name) or tostring(def.mix.look) },
            { "Attack", mv("attack", Content.attacks) },
            { "Special", mv("secondary", Content.attacks) },
            { "Dash", mv("dash", Content.dashes) },
        }
        local Stats = require("src.game.stats")
        for _, k in ipairs({ "maxHp", "moveSpeed", "armor" }) do
            local st = Stats.byId[k]
            rows[#rows + 1] = { st.label, tostring(def.stats[k] or st.default) }
        end
        -- what's in the script besides the basics
        local extras = {}
        if def.hooks then extras[#extras + 1] = "event code" end
        if def.ownTree then extras[#extras + 1] = "own skill tree" end
        if def.sounds then extras[#extras + 1] = "own sounds" end
        if def.mix.anims then extras[#extras + 1] = "own animations" end
        if #extras > 0 and not small then rows[#rows + 1] = { "Extras", table.concat(extras, ", ") } end
        -- how it has done (Records keeps every bug's runs, custom ones too)
        local rec = require("src.game.records").get().characters[def.id]
        rows[#rows + 1] = { "Runs", rec and ("%d played, %d won, best wave %d"):format(rec.runs or 0, rec.wins or 0, rec.bestWave or 0) or "not played yet" }
        local lh = lg.getFont():getHeight() + u(4)
        for i, r in ipairs(rows) do
            lg.setColor(c.accent)
            lg.printf(r[1], px + u(24), ty + (i - 1) * lh, pw / 2 - u(32), "right")
            lg.setColor(c.text)
            lg.print(r[2], px + pw / 2 + u(8), ty + (i - 1) * lh)
        end
        ty = ty + #rows * lh + u(8)
        local moveErr = require("src.game.scriptmoves").errors[def.id]
        if moveErr then
            lg.setColor(c.bad)
            lg.printf("Move error last run: " .. moveErr, px + u(24), ty, pw - u(48), "center")
            ty = ty + lh * 2
        end
        lg.setColor(c.dim)
        lg.printf("File: " .. tostring(e.file), px + u(24), ty, pw - u(48), "center")
    else
        lg.setFont(Theme.font("heading"))
        Theme.printShadow(it and it.label or "", px, ty, c.text, "center", pw)
        ty = ty + lg.getFont():getHeight() + u(12)
        lg.setFont(Theme.font("body"))
        lg.setColor(c.text)
        if it and it.desc then lg.printf(it.desc, px + u(24), ty, pw - u(48), "center") end
        lg.setColor(c.dim)
        lg.setFont(Theme.font("label"))
        lg.printf(small and "" or "Custom bugs show on the bug select screen with the others (Show: Custom Bugs). They're just for fun: they don't count towards the play-every-bug achievements.",
            px + u(24), u(120) + ph - u(80), pw - u(48), "center")
    end
    lg.setScissor()
    if self.flash then
        lg.setFont(Theme.font("label"))
        lg.setColor(self.flash[2])
        lg.printf(self.flash[1], u(60), h - u(56) - lg.getFont():getHeight() - u(8), w - u(120), "left")
    end
    lg.setColor(1, 1, 1, 1)
    Theme.footer({ { "Enter", "Select" }, { "Esc", "Back" } })
end

return Creator
