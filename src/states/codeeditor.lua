-- Bug Creator script editor: a small code editor for custom bug scripts (src/game/custombugs.lua).
-- Typing, arrows, Home/End, Page Up/Down, Tab, Enter keeps the indent, Ctrl+Z undo, Ctrl+V paste,
-- Ctrl+C copies the whole script, Ctrl+S saves, Ctrl+Enter / F5 checks. Mouse or touch places the
-- cursor, the wheel scrolls. The script is checked as you type; errors point at their line.
-- On a phone the on-screen keyboard opens with the editor.
local State = require("src.core.state")
local Theme = require("src.ui.theme")
local Audio = require("src.core.audio")
local Input = require("src.core.input")
local CustomBugs = require("src.game.custombugs")

local Editor = {}
Editor.__index = Editor
Editor.wantsText = true         -- main.lua: every key comes here, not to game actions

local KEYWORDS = {}
for w in ("and break do else elseif end false for function if in local nil not or repeat return then true until while")
    :gmatch("%S+") do KEYWORDS[w] = true end

local function splitLines(text)
    text = (text or ""):gsub("\r\n?", "\n"):gsub("\t", "    ")
    local lines = {}
    for l in (text .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
    if #lines == 0 then lines[1] = "" end
    return lines
end

-- opts: text, replaces (custom bug id the script was opened as), title, onSaved(def)
function Editor.new(opts)
    opts = opts or {}
    local self = setmetatable({ t = 0, opts = opts }, Editor)
    self.lines = splitLines(opts.text or CustomBugs.blueprint())
    self.cl, self.cc = 1, 0           -- cursor line (1-based) and column (bytes before the cursor)
    self.scrollY, self.scrollX = 0, 0
    self.undo = {}
    self.dirty = false
    self.replaces = opts.replaces
    self.checkT = 0
    self.blinkT = 0
    self:check()
    return self
end

function Editor:enter()
    if love.keyboard.setTextInput then love.keyboard.setTextInput(true) end
end
function Editor:leave()
    if love.keyboard.setTextInput then love.keyboard.setTextInput(false) end
end
function Editor:resume() self:enter() end

function Editor:text() return table.concat(self.lines, "\n") end

----------------------------------------------------------------------------------------------
-- Editing

function Editor:snapshot(kind)
    local now = love.timer.getTime()
    if kind == self.lastKind and now - (self.lastSnapT or 0) < 1 then return end
    self.lastKind, self.lastSnapT = kind, now
    local copy = {}
    for i, l in ipairs(self.lines) do copy[i] = l end
    self.undo[#self.undo + 1] = { lines = copy, cl = self.cl, cc = self.cc }
    if #self.undo > 200 then table.remove(self.undo, 1) end
end

function Editor:changed()
    self.dirty = true
    self.checkT = 0.5
    self.blinkT = 0
    self.wantCursor = true
end

function Editor:doUndo()
    local s = table.remove(self.undo)
    if not s then Audio.play("ui_back") return end
    self.lines, self.cl, self.cc = s.lines, s.cl, s.cc
    self.lastKind = nil
    self:changed()
end

-- the byte position of the character start before / after column c (UTF-8 aware)
local function prevChar(line, c)
    c = c - 1
    while c > 0 and line:byte(c + 1) and line:byte(c + 1) >= 0x80 and line:byte(c + 1) < 0xC0 do c = c - 1 end
    return math.max(0, c)
end
local function nextChar(line, c)
    c = c + 1
    while c < #line and line:byte(c + 1) >= 0x80 and line:byte(c + 1) < 0xC0 do c = c + 1 end
    return math.min(#line, c)
end

function Editor:insert(s)
    self:snapshot("type")
    s = s:gsub("\r\n?", "\n"):gsub("\t", "    ")
    local line = self.lines[self.cl]
    local before, after = line:sub(1, self.cc), line:sub(self.cc + 1)
    local parts = splitLines(s)
    if #parts == 1 then
        self.lines[self.cl] = before .. parts[1] .. after
        self.cc = self.cc + #parts[1]
    else
        self.lines[self.cl] = before .. parts[1]
        for i = 2, #parts do table.insert(self.lines, self.cl + i - 1, parts[i]) end
        self.cl = self.cl + #parts - 1
        self.cc = #self.lines[self.cl]
        self.lines[self.cl] = self.lines[self.cl] .. after
    end
    self:changed()
end

function Editor:newline()
    self:snapshot("newline")
    local line = self.lines[self.cl]
    local indent = line:match("^(%s*)")
    local before, after = line:sub(1, self.cc), line:sub(self.cc + 1)
    -- one level deeper after an opening brace / do / then / function
    local trimmed = before:gsub("%-%-.*$", ""):gsub("%s+$", "")
    if trimmed:match("[{%(]$") or trimmed:match("%f[%w]do$") or trimmed:match("%f[%w]then$")
        or trimmed:match("%f[%w]else$") or trimmed:match("function%s*[%w_.:]*%b()$") then
        indent = indent .. "    "
    end
    self.lines[self.cl] = before
    table.insert(self.lines, self.cl + 1, indent .. after:gsub("^%s+", ""))
    self.cl, self.cc = self.cl + 1, #indent
    self:changed()
end

function Editor:backspace()
    self:snapshot("delete")
    if self.cc > 0 then
        local line = self.lines[self.cl]
        -- inside the indent: back to the previous tab stop
        local p
        if line:sub(1, self.cc):match("^ +$") then p = math.max(0, (math.ceil(self.cc / 4) - 1) * 4)
        else p = prevChar(line, self.cc) end
        self.lines[self.cl] = line:sub(1, p) .. line:sub(self.cc + 1)
        self.cc = p
    elseif self.cl > 1 then
        local prev = self.lines[self.cl - 1]
        self.cc = #prev
        self.lines[self.cl - 1] = prev .. self.lines[self.cl]
        table.remove(self.lines, self.cl)
        self.cl = self.cl - 1
    else
        return
    end
    self:changed()
end

function Editor:delete()
    self:snapshot("delete")
    local line = self.lines[self.cl]
    if self.cc < #line then
        self.lines[self.cl] = line:sub(1, self.cc) .. line:sub(nextChar(line, self.cc) + 1)
    elseif self.cl < #self.lines then
        self.lines[self.cl] = line .. table.remove(self.lines, self.cl + 1)
    else
        return
    end
    self:changed()
end

function Editor:moveTo(l, c)
    self.cl = math.max(1, math.min(#self.lines, l))
    self.cc = math.max(0, math.min(#self.lines[self.cl], c))
    self.blinkT = 0
    self.wantCursor = true
    self.lastKind = nil
end

-- Up / Down keep the cursor's on-screen x where they can.
function Editor:vertical(d)
    local f = self:font()
    local x = self.goalX or f:getWidth(self.lines[self.cl]:sub(1, self.cc))
    self:moveTo(self.cl + d, 0)
    self.cc = self:colAt(self.cl, x)
    self.goalX = x
end

function Editor:colAt(l, x)
    local f = self:font()
    local line = self.lines[l]
    local c = 0
    while c < #line do
        local n = nextChar(line, c)
        local w0, w1 = f:getWidth(line:sub(1, c)), f:getWidth(line:sub(1, n))
        if x < (w0 + w1) / 2 then break end
        c = n
    end
    return c
end

----------------------------------------------------------------------------------------------
-- Checking and saving

function Editor:check()
    local def, info = CustomBugs.compile(self:text(), "script")
    self.def, self.info = def, info
    self.errLine = info.line
    -- build errors name a field, not a line: point at the line where that field is written
    if not self.errLine and not def and info.errors[1] then
        local field = info.errors[1]:match("^([%w_]+)")
        for i, l in ipairs(self.lines) do
            if field and l:match("^%s*" .. field .. "%s*=") then self.errLine = i break end
        end
    end
    return def, info
end

function Editor:save(play)
    local def, info = CustomBugs.save(self:text(), self.replaces)
    self.info = info
    if not def then
        self.def = nil
        self.flash = { "Can't save: " .. (info.errors[1] or "?"), Theme.colors.bad }
        Audio.play("ui_back")
        return
    end
    self.def, self.replaces, self.dirty = def, def.id, false
    self.flash = { "Saved " .. def.name .. ".  It's on the bug select screen (Show: Custom Bugs).", Theme.colors.good }
    Audio.play("ui_confirm")
    if self.opts.onSaved then self.opts.onSaved(def) end
    if play then
        local mode = (require("src.game.prefs").get().last or {}).gameMode or "colony"
        require("src.states.menu").quickStart(def.id, mode)
    end
end

function Editor:paste()
    local ok, t = pcall(love.system.getClipboardText)
    if ok and type(t) == "string" and t ~= "" then
        self:insert(t)
    else
        self.flash = { "The clipboard is empty (on the web, type the script or use the desktop game).", Theme.colors.dim }
        Audio.play("ui_back")
    end
end

function Editor:copyAll()
    local ok = pcall(love.system.setClipboardText, self:text())
    self.flash = ok and { "Copied the whole script.", Theme.colors.good } or { "Copying isn't available here.", Theme.colors.dim }
    Audio.play(ok and "ui_confirm" or "ui_back")
end

function Editor:back()
    if self.dirty and not self.confirmBack then
        self.confirmBack = 2.5
        self.flash = { "Unsaved changes. Press Esc / Back again to leave without saving.", Theme.colors.focus }
        Audio.play("ui_back")
        return
    end
    Audio.play("ui_back")
    State.pop()
end

function Editor:loadBlueprint()
    self:snapshot("replace")
    self.lastKind = nil
    self.lines = splitLines(CustomBugs.blueprint())
    self:moveTo(1, 0)
    self:changed()
    self.flash = { "Blueprint loaded (Ctrl+Z to undo).", Theme.colors.dim }
end

function Editor:filedropped(file)
    local ok = pcall(file.open, file, "r")
    local data = ok and file:read() or nil
    pcall(file.close, file)
    if type(data) ~= "string" then return end
    self:snapshot("replace")
    self.lastKind = nil
    self.lines = splitLines(data)
    self:moveTo(1, 0)
    self:changed()
    self.flash = { "Loaded " .. tostring(file:getFilename():match("[^/\\]+$")) .. ".  Save to keep it.", Theme.colors.good }
end

----------------------------------------------------------------------------------------------
-- Input

function Editor:textinput(t)
    self.goalX = nil
    self:insert(t)
end

function Editor:keypressed(key)
    local ctrl = love.keyboard.isDown("lctrl", "rctrl", "lgui", "rgui")
    if key ~= "up" and key ~= "down" then self.goalX = nil end
    if ctrl then
        if key == "s" then self:save(false)
        elseif key == "v" then self:paste()
        elseif key == "c" then self:copyAll()
        elseif key == "z" then self:doUndo()
        elseif key == "return" or key == "kpenter" then self:check() self.checkT = 0 self.flash = nil
        elseif key == "home" then self:moveTo(1, 0)
        elseif key == "end" then self:moveTo(#self.lines, math.huge)
        end
        return
    end
    local line = self.lines[self.cl]
    if key == "escape" then self:back()
    elseif key == "f5" then self:check() self.checkT = 0 self.flash = nil
    elseif key == "left" then
        if self.cc > 0 then self:moveTo(self.cl, prevChar(line, self.cc))
        elseif self.cl > 1 then self:moveTo(self.cl - 1, math.huge) end
    elseif key == "right" then
        if self.cc < #line then self:moveTo(self.cl, nextChar(line, self.cc))
        elseif self.cl < #self.lines then self:moveTo(self.cl + 1, 0) end
    elseif key == "up" then self:vertical(-1)
    elseif key == "down" then self:vertical(1)
    elseif key == "pageup" then self:vertical(-self:visibleLines())
    elseif key == "pagedown" then self:vertical(self:visibleLines())
    elseif key == "home" then
        local ind = #(line:match("^%s*"))
        self:moveTo(self.cl, self.cc == ind and 0 or ind)
    elseif key == "end" then self:moveTo(self.cl, math.huge)
    elseif key == "backspace" then self:backspace()
    elseif key == "delete" then self:delete()
    elseif key == "return" or key == "kpenter" then self:newline()
    elseif key == "tab" then
        local shift = love.keyboard.isDown("lshift", "rshift")
        if shift then
            local n = math.min(4, #line:match("^ *"))
            if n > 0 then
                self:snapshot("indent")
                self.lines[self.cl] = line:sub(n + 1)
                self.cc = math.max(0, self.cc - n)
                self:changed()
            end
        else
            self:insert(string.rep(" ", 4 - self.cc % 4))
        end
    end
end

----------------------------------------------------------------------------------------------
-- Layout

function Editor:font() return Theme.font(15) end
function Editor:lineH() return math.floor(self:font():getHeight() * 1.15) end

-- text box, toolbar and status area
function Editor:layout()
    local w, h = love.graphics.getDimensions()
    local u = Theme.u
    local L = {}
    L.toolbarY = u(96)
    L.toolbarH = u(34)
    L.x, L.y = u(40), L.toolbarY + L.toolbarH + u(14)
    L.w = w - u(80)
    L.statusH = u(78)
    L.h = h - L.y - L.statusH - u(56)
    L.gutter = self:font():getWidth("000") + u(14)
    return L
end

function Editor:visibleLines()
    local L = self:layout()
    return math.max(1, math.floor((L.h - Theme.u(8)) / self:lineH()))
end

-- toolbar buttons: { label, key hint, action }
function Editor:buttons()
    return {
        { "Save", "Ctrl+S", function() self:save(false) end },
        { "Save & Play", nil, function() self:save(true) end },
        { "Check", "F5", function() self:check() self.checkT = 0 self.flash = nil end },
        { "Paste", "Ctrl+V", function() self:paste() end },
        { "Copy All", "Ctrl+C", function() self:copyAll() end },
        { "Undo", "Ctrl+Z", function() self:doUndo() end },
        { "Blueprint", nil, function() self:loadBlueprint() end },
        { "Back", "Esc", function() self:back() end },
    }
end

function Editor:buttonRects()
    local L = self:layout()
    local f = Theme.font("label", "bold")
    local rects, x = {}, L.x
    for i, b in ipairs(self:buttons()) do
        local bw = f:getWidth(b[1]) + Theme.u(26)
        if x + bw > L.x + L.w then break end
        rects[i] = { x = x, y = L.toolbarY, w = bw, h = L.toolbarH, b = b }
        x = x + bw + Theme.u(8)
    end
    return rects
end

function Editor:keepCursorVisible()
    local L = self:layout()
    local lh = self:lineH()
    local top = (self.cl - 1) * lh
    local viewH = L.h - Theme.u(8)
    if top < self.scrollY then self.scrollY = top end
    if top + lh > self.scrollY + viewH then self.scrollY = top + lh - viewH end
    local f = self:font()
    local cx = f:getWidth(self.lines[self.cl]:sub(1, self.cc))
    local viewW = L.w - L.gutter - Theme.u(16)
    if cx < self.scrollX then self.scrollX = math.max(0, cx - Theme.u(40)) end
    if cx > self.scrollX + viewW then self.scrollX = cx - viewW + Theme.u(40) end
end

function Editor:maxScroll()
    local L = self:layout()
    return math.max(0, #self.lines * self:lineH() - (L.h - Theme.u(8)))
end

function Editor:mousepressed(mx, my, b)
    if b ~= 1 then return end
    for _, r in pairs(self:buttonRects()) do
        if mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h then
            Audio.play("ui_confirm")
            r.b[3]()
            return
        end
    end
    local L = self:layout()
    if mx >= L.x and mx <= L.x + L.w and my >= L.y and my <= L.y + L.h then
        local lh = self:lineH()
        local l = math.floor((my - L.y - Theme.u(4) + self.scrollY) / lh) + 1
        l = math.max(1, math.min(#self.lines, l))
        self:moveTo(l, self:colAt(l, mx - L.x - L.gutter - Theme.u(8) + self.scrollX))
        self.wantCursor = false
        self.goalX = nil
        -- a tap also brings the phone keyboard back if it was closed
        if love.keyboard.setTextInput then love.keyboard.setTextInput(true) end
    end
end

function Editor:wheelmoved(dx, dy)
    self.scrollY = math.max(0, math.min(self:maxScroll(), self.scrollY - dy * self:lineH() * 3))
    if dx ~= 0 then self.scrollX = math.max(0, self.scrollX - dx * Theme.u(40)) end
end

function Editor:update(dt)
    self.t = self.t + dt
    self.blinkT = self.blinkT + dt
    if self.checkT > 0 then
        self.checkT = self.checkT - dt
        if self.checkT <= 0 then self:check() end
    end
    if self.confirmBack then
        self.confirmBack = self.confirmBack - dt
        if self.confirmBack <= 0 then self.confirmBack = nil end
    end
    -- a controller can still leave (B)
    if Input.joystick and Input.joystick:isGamepadDown("b") then
        if not self.padB then self.padB = true self:back() end
    else
        self.padB = nil
    end
    if self.wantCursor then self:keepCursorVisible() self.wantCursor = false end
end

----------------------------------------------------------------------------------------------
-- Drawing

local COL = {
    text = { 0.93, 0.89, 0.8, 1 }, keyword = { 0.98, 0.7, 0.32, 1 }, string = { 0.6, 0.86, 0.48, 1 },
    number = { 0.55, 0.78, 0.98, 1 }, comment = { 0.5, 0.46, 0.4, 1 }, field = { 0.9, 0.8, 0.62, 1 },
}

-- A line split into coloured pieces for love.graphics.print({color, text, ...}).
local function colourise(line, inComment)
    local out, i, n = {}, 1, #line
    local function push(c, s) out[#out + 1] = c out[#out + 1] = s end
    if inComment then
        local e = line:find("]]", 1, true)
        if not e then push(COL.comment, line) return out, true end
        push(COL.comment, line:sub(1, e + 1))
        i = e + 2
    end
    while i <= n do
        local ch = line:sub(i, i)
        if line:sub(i, i + 3) == "--[[" then
            local e = line:find("]]", i + 4, true)
            if not e then push(COL.comment, line:sub(i)) return out, true end
            push(COL.comment, line:sub(i, e + 1))
            i = e + 2
        elseif line:sub(i, i + 1) == "--" then
            push(COL.comment, line:sub(i))
            break
        elseif ch == '"' or ch == "'" then
            local j = i + 1
            while j <= n and line:sub(j, j) ~= ch do
                if line:sub(j, j) == "\\" then j = j + 1 end
                j = j + 1
            end
            push(COL.string, line:sub(i, j))
            i = j + 1
        elseif ch:match("%d") then
            local s, e = line:find("^[%d%.xXa-fA-F]+", i)
            push(COL.number, line:sub(s, e))
            i = e + 1
        elseif ch:match("[%a_]") then
            local s, e = line:find("^[%w_]+", i)
            local word = line:sub(s, e)
            local after = line:sub(e + 1):match("^%s*(.)")
            push(KEYWORDS[word] and COL.keyword or (after == "=" and line:sub(e + 1):match("^%s*==") == nil) and COL.field or COL.text, word)
            i = e + 1
        else
            local s, e = line:find("^[^%w_\"'%-]+", i)
            if not s then s, e = i, i end
            push(COL.text, line:sub(s, e))
            i = e + 1
        end
    end
    if #out == 0 then push(COL.text, "") end
    return out, false
end

function Editor:draw()
    local lg = love.graphics
    local w, h = lg.getDimensions()
    local u = Theme.u
    local c = Theme.colors
    lg.clear(c.bg)
    Theme.title(self.opts.title or "Bug Script")
    local L = self:layout()

    -- toolbar
    local f = Theme.font("label", "bold")
    lg.setFont(f)
    local mx, my = love.mouse.getPosition()
    for _, r in pairs(self:buttonRects()) do
        local hot = mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h
        Theme.panel(r.x, r.y, r.w, r.h, false)
        if hot then lg.setColor(c.focusBg) lg.rectangle("fill", r.x, r.y, r.w, r.h) end
        lg.setColor(hot and c.focus or c.text)
        lg.printf(r.b[1], r.x, r.y + math.floor((r.h - f:getHeight()) / 2), r.w, "center")
    end
    -- the bug's name and whether it is saved, top right
    lg.setFont(Theme.font("label"))
    local state = (self.def and self.def.name or "?") .. (self.dirty and "  ·  not saved" or (self.replaces and "  ·  saved" or ""))
    lg.setColor(self.dirty and c.focus or c.dim)
    lg.printf(state, 0, u(52), w - u(40), "right")

    -- text area
    Theme.panel(L.x, L.y, L.w, L.h)
    local cf = self:font()
    lg.setFont(cf)
    local lh = self:lineH()
    lg.setScissor(L.x, L.y, L.w, L.h)
    local first = math.floor(self.scrollY / lh) + 1
    local last = math.min(#self.lines, first + math.ceil(L.h / lh) + 1)
    -- block comments carry over from earlier lines
    local inComment = false
    for i = 1, first - 1 do
        local l = self.lines[i]
        if inComment then inComment = not l:find("]]", 1, true) end
        if not inComment and l:find("--[[", 1, true) and not l:find("]]", (l:find("--[[", 1, true)) + 4, true) then inComment = true end
    end
    local tx = L.x + L.gutter + u(8)
    for i = first, last do
        local y = L.y + u(4) + (i - 1) * lh - self.scrollY
        if i == self.cl then
            lg.setColor(1, 0.9, 0.7, 0.05)
            lg.rectangle("fill", L.x + 2, y, L.w - 4, lh)
        end
        if i == self.errLine then
            lg.setColor(c.bad[1], c.bad[2], c.bad[3], 0.16)
            lg.rectangle("fill", L.x + 2, y, L.w - 4, lh)
        end
        lg.setColor(i == self.errLine and c.bad or (i == self.cl and c.dim or { 0.38, 0.33, 0.29, 1 }))
        lg.printf(tostring(i), L.x, y, L.gutter - u(4), "right")
        local parts
        parts, inComment = colourise(self.lines[i], inComment)
        lg.setScissor(tx - 1, L.y, L.x + L.w - tx, L.h)
        lg.setColor(1, 1, 1, 1)
        lg.print(parts, tx - self.scrollX, y)
        lg.setScissor(L.x, L.y, L.w, L.h)
    end
    -- cursor
    if self.blinkT % 1 < 0.6 then
        local y = L.y + u(4) + (self.cl - 1) * lh - self.scrollY
        local cx = tx - self.scrollX + cf:getWidth(self.lines[self.cl]:sub(1, self.cc))
        if cx >= tx - 1 then
            lg.setColor(c.focus)
            lg.rectangle("fill", math.floor(cx), y + 1, 2, lh - 2)
        end
    end
    lg.setScissor()
    -- gutter line
    lg.setColor(c.panelEdge)
    lg.rectangle("fill", L.x + L.gutter, L.y, 1, L.h)
    -- scroll bar
    local total = #self.lines * lh
    if total > L.h then
        local bh = math.max(u(20), L.h * L.h / total)
        local by = L.y + (L.h - bh) * (self.scrollY / math.max(1, self:maxScroll()))
        lg.setColor(c.rivet)
        lg.rectangle("fill", L.x + L.w - u(6), by, u(3), bh)
    end

    -- status: the flash message, else the check result
    local sy = L.y + L.h + u(10)
    lg.setFont(Theme.font("label"))
    local info = self.info or { errors = {}, warnings = {} }
    local lines = {}
    if self.flash then lines[#lines + 1] = { self.flash[2], self.flash[1] } end
    if #info.errors > 0 then
        lines[#lines + 1] = { c.bad, "Error: " .. info.errors[1] .. (#info.errors > 1 and ("   (+" .. (#info.errors - 1) .. " more)") or "") }
    elseif self.def then
        local d = self.def
        local function mv(slot, reg)
            local p = d[slot]
            local m = p and reg:get(p.type)
            return p and p.name or (m and (m.name or p.type)) or "none"
        end
        local Content = require("src.content")
        local looks = d.mix.art and "its own art" or ("looks like the " .. ((Content.characters:get(d.mix.look or "") or {}).name or tostring(d.mix.look)))
        lines[#lines + 1] = { c.good, ("OK: %s  ·  %s  ·  attack %s  ·  special %s  ·  dash %s"):format(d.name,
            looks, mv("attack", Content.attacks),
            mv("secondary", Content.attacks), mv("dash", Content.dashes)) }
    end
    for i = 1, math.min(2, #info.warnings) do lines[#lines + 1] = { c.focus, "Note: " .. info.warnings[i] } end
    for i = 1, math.min(2, #(info.log or {})) do lines[#lines + 1] = { c.dim, "print: " .. info.log[i] } end
    local lfh = lg.getFont():getHeight()
    lg.setScissor(L.x, sy, L.w, L.statusH)
    for i = 1, math.min(4, #lines) do
        lg.setColor(lines[i][1])
        lg.print(lines[i][2], L.x, sy + (i - 1) * (lfh + 2))
    end
    lg.setScissor()
    lg.setColor(1, 1, 1, 1)
    Theme.footer({ { "Ctrl+S", "Save" }, { "F5", "Check" }, { "Ctrl+V", "Paste" }, { "Ctrl+Z", "Undo" }, { "Esc", "Back" } })
end

return Editor
