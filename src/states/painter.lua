-- Bug Creator: the Bug Painter. Draw a bug's own pixel art in the game (no script needed):
--   Body     paint pixels (left click), erase (right click), fill, mirror top/bottom, resize
--   Parts    build a body from a kit: a head, a middle and a back from different bugs
--   Legs     drag each leg's hip, knee and foot; add or remove legs
--   Limbs    add claws, blades, fangs, horns, feelers, tails and wings; drag where they sit,
--            set their length, angle, tip, colour, and whether they flap or sway
--   Colours  every palette colour (each body part's colour), the legs' and the limbs'
-- The bug walks on the right as you paint. Saving writes art = { ... } into the bug's script
-- (a new bug, or a few lines after an existing bug's script).
-- opts: entry (a custom bug to repaint) or nil for a new bug.
local State = require("src.core.state")
local Theme = require("src.ui.theme")
local Audio = require("src.core.audio")
local Content = require("src.content")
local Sprites = require("src.gfx.sprites")
local CustomBugs = require("src.game.custombugs")
local Parts = require("src.config.bugparts")
local util = require("src.core.util")

local Painter = {}
Painter.__index = Painter

local PREVIEW_ID = "custom__paintpreview"
local TABS = { "Body", "Parts", "Legs", "Limbs", "Colours" }
local SLOTS = { "o", "a", "b", "c", "d", "e", "w", "y" }
local MAX_W, MAX_H = 48, 32

-- colours ------------------------------------------------------------------------------------
local function toHex(r, g, b, a)
    local s = ("#%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
    if a and a < 0.999 then s = s .. ("%02x"):format(math.floor(a * 255 + 0.5)) end
    return s
end
local function hsv(h, s, v)
    local i = math.floor(h * 6) % 6
    local f = h * 6 - math.floor(h * 6)
    local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    local r, g, b = ({ { v, t, p }, { q, v, p }, { p, v, t }, { p, q, v }, { t, p, v }, { v, p, q } })[i + 1][1], 0, 0
    local row = ({ { v, t, p }, { q, v, p }, { p, v, t }, { p, q, v }, { t, p, v }, { v, p, q } })[i + 1]
    r, g, b = row[1], row[2], row[3]
    return r, g, b
end
local function toHsv(r, g, b)
    local mx, mn = math.max(r, g, b), math.min(r, g, b)
    local d = mx - mn
    local h = 0
    if d > 0 then
        if mx == r then h = ((g - b) / d) % 6 elseif mx == g then h = (b - r) / d + 2 else h = (r - g) / d + 4 end
        h = h / 6
    end
    return h, mx > 0 and d / mx or 0, mx
end

-- the starting drawing for a new bug: the parts kit's beetle
local function fresh()
    local rows, legs = Parts.compose(1, 1, 1)
    local pal = {}
    for k, v in pairs(Parts.palette) do pal[k] = v end
    pal.d = "#c8a060"
    return { palette = pal, rows = rows, legs = legs, legColor = "#3a2a1a", limbs = {}, height = 3, lift = 2 }
end

function Painter.new(opts)
    opts = opts or {}
    local self = setmetatable({ t = 0, tab = 1, slot = "b", tool = "pen", mirror = true, buttons = {}, previewT = 0,
        kit = { 1, 1, 1 }, newLimb = 1, sel = 1, entry = opts.entry }, Painter)
    local art = opts.entry and opts.entry.def and opts.entry.def.art and self:fromDef(opts.entry.def)
    self.art = art or fresh()
    self:fitGrid()
    self:refresh(true)
    return self
end

-- Read a bug's art back (from the sprite defs its script built).
function Painter:fromDef(def)
    local spr = def.art and def.art[2]
    if not (spr and spr.frames and spr.frames[1]) then return nil end
    local pal = {}
    for k, v in pairs(spr.palette) do pal[k] = v end
    local rows = {}
    for i, r in ipairs(spr.frames[1]) do rows[i] = r:gsub(" ", ".") end
    local legs = {}
    for i, l in ipairs(def.art[3] and def.art[3].rig or {}) do legs[i] = { unpack(l) } end
    local lc = def.art[3] and def.art[3].palette and def.art[3].palette.l or "#302820"
    local limbs = {}
    for _, l in ipairs(def.model and def.model.restLimbs or {}) do
        local c = {}
        for k, v in pairs(l) do if type(v) ~= "table" or k == "segs" then c[k] = v end end
        c.segs = {}
        for i, sg in ipairs(l.segs) do c.segs[i] = { sg[1], sg[2], sg[3] } end
        if l.wave then c.wave = { speed = l.wave.speed, yaw = l.wave.yaw, pitch = l.wave.pitch, follow = l.wave.follow, lag = l.wave.lag } end
        limbs[#limbs + 1] = c
    end
    return { palette = pal, rows = rows, legs = legs, legColor = lc, limbs = limbs,
        height = def.model and def.model.height or 3, lift = def.model and def.model.lift or 2 }
end

function Painter:fitGrid()
    local a = self.art
    local w = 0
    for _, r in ipairs(a.rows) do w = math.max(w, #r) end
    self.W, self.H = math.max(4, math.min(MAX_W, w)), math.max(3, math.min(MAX_H, #a.rows))
    for y = 1, self.H do
        local r = a.rows[y] or ""
        a.rows[y] = (r .. string.rep(".", self.W)):sub(1, self.W)
    end
    for y = #a.rows, self.H + 1, -1 do a.rows[y] = nil end
end

-- The art table for the script.
function Painter:artTable()
    local a = self.art
    local pal = {}
    local used = {}
    for _, r in ipairs(a.rows) do for x = 1, #r do used[r:sub(x, x)] = true end end
    for k, v in pairs(a.palette) do if used[k] or k == "o" then pal[k] = v end end
    for _, l in ipairs(a.limbs) do if type(l.color) == "string" and #l.color == 1 and a.palette[l.color] then pal[l.color] = a.palette[l.color] end end
    local rows = {}
    for i, r in ipairs(a.rows) do rows[i] = r end
    local limbs = {}
    for i, l in ipairs(a.limbs) do
        local c = {}
        for k, v in pairs(l) do c[k] = v end
        limbs[i] = c
    end
    return { palette = pal, body = rows, legs = #a.legs > 0 and a.legs or nil, legColor = a.legColor,
        limbs = #limbs > 0 and limbs or nil, height = a.height, lift = a.lift }
end

function Painter:refresh(now)
    self.previewT = now and 0 or 0.25
    self.pending = true
end

function Painter:rebuild()
    self.pending = false
    local def, errs = CustomBugs.build({ name = "Painting", art = self:artTable() })
    self.errors = errs
    if not def then return end
    def.id = PREVIEW_ID
    CustomBugs.prepareArt(def)
    self.def = def
end

----------------------------------------------------------------------------------------------
-- painting

function Painter:cellAt(mx, my)
    local g = self.grid
    if not g then return end
    local x = math.floor((mx - g.x) / g.cell) + 1
    local y = math.floor((my - g.y) / g.cell) + 1
    if x >= 1 and x <= self.W and y >= 1 and y <= self.H then return x, y end
end

local function setPx(rows, x, y, ch)
    local r = rows[y]
    rows[y] = r:sub(1, x - 1) .. ch .. r:sub(x + 1)
end

function Painter:paint(x, y, ch)
    local rows = self.art.rows
    if self.tool == "fill" then
        local from = rows[y]:sub(x, x)
        if from == ch then return end
        local stack, n = { { x, y } }, 0
        while #stack > 0 and n < 4000 do
            local p = table.remove(stack)
            local px, py = p[1], p[2]
            if px >= 1 and px <= self.W and py >= 1 and py <= self.H and rows[py]:sub(px, px) == from then
                setPx(rows, px, py, ch)
                if self.mirror then setPx(rows, px, self.H + 1 - py, ch) end
                n = n + 1
                stack[#stack + 1] = { px + 1, py } stack[#stack + 1] = { px - 1, py }
                stack[#stack + 1] = { px, py + 1 } stack[#stack + 1] = { px, py - 1 }
            end
        end
    elseif self.tool == "pick" then
        local c = rows[y]:sub(x, x)
        if c ~= "." then self.slot = c end
        self.tool = "pen"
        return
    else
        if rows[y]:sub(x, x) == ch and not self.mirror then return end
        setPx(rows, x, y, ch)
        if self.mirror then setPx(rows, x, self.H + 1 - y, ch) end
    end
    self:refresh()
end

-- art units (u forward, v to the side) <-> screen
function Painter:toScreen(u, v)
    local g = self.grid
    return g.x + (u + (self.W + 1) / 2 - 0.5) * g.cell, g.y + (v + (self.H + 1) / 2 - 0.5) * g.cell
end
function Painter:toArt(mx, my)
    local g = self.grid
    return (mx - g.x) / g.cell + 0.5 - (self.W + 1) / 2, (my - g.y) / g.cell + 0.5 - (self.H + 1) / 2
end

function Painter:resize(dw, dh)
    local a = self.art
    local W, H = math.max(4, math.min(MAX_W, self.W + dw)), math.max(3, math.min(MAX_H, self.H + dh))
    -- grow / shrink round the middle so the drawing stays centred
    local rows = {}
    local offY = math.floor((H - self.H) / 2)
    local offX = math.floor((W - self.W) / 2)
    for y = 1, H do
        local src = a.rows[y - offY]
        local r = ""
        for x = 1, W do
            local sx = x - offX
            r = r .. (src and sx >= 1 and sx <= #src and src:sub(sx, sx) or ".")
        end
        rows[y] = r
    end
    a.rows = rows
    self.W, self.H = W, H
    self:refresh()
end

----------------------------------------------------------------------------------------------
-- input

function Painter:button(x, y, w, h, label, fn, on)
    self.buttons[#self.buttons + 1] = { x = x, y = y, w = w, h = h, label = label, fn = fn, on = on }
end

function Painter:mousepressed(mx, my, b)
    for _, bt in ipairs(self.buttons) do
        if mx >= bt.x and mx <= bt.x + bt.w and my >= bt.y and my <= bt.y + bt.h then
            Audio.play("ui_move")
            bt.fn(b)
            return
        end
    end
    local tab = TABS[self.tab]
    if tab == "Body" or tab == "Colours" or tab == "Parts" then
        local x, y = self:cellAt(mx, my)
        if x then
            self.painting = b
            self:paint(x, y, b == 2 and "." or self.slot)
        end
    elseif tab == "Legs" then
        self.drag = self:nearestJoint(mx, my)
    elseif tab == "Limbs" then
        local l = self.art.limbs[self.sel]
        if l and self:cellAt(mx, my) then
            self.dragLimb = true
            self:moveLimb(mx, my)
        end
    end
end

function Painter:mousemoved(mx, my)
    if self.painting and love.mouse.isDown(self.painting) then
        local x, y = self:cellAt(mx, my)
        if x and self.tool == "pen" then self:paint(x, y, self.painting == 2 and "." or self.slot) end
    elseif self.painting then
        self.painting = nil
    end
    if self.drag and love.mouse.isDown(1) then
        local u, v = self:toArt(mx, my)
        local leg = self.art.legs[self.drag[1]]
        local j = self.drag[2]
        leg[j * 2 - 1] = util.clamp(math.floor(u + 0.5), -60, 60)
        leg[j * 2] = util.clamp(math.floor(v + 0.5), -60, 60)
        self:refresh()
    elseif self.drag then self.drag = nil end
    if self.dragLimb and love.mouse.isDown(1) then self:moveLimb(mx, my)
    elseif self.dragLimb then self.dragLimb = nil end
end

function Painter:mousereleased() self.painting, self.drag, self.dragLimb = nil, nil, nil end

function Painter:moveLimb(mx, my)
    local l = self.art.limbs[self.sel]
    if not l then return end
    local u, v = self:toArt(mx, my)
    l.u = util.clamp(math.floor(u * 2 + 0.5) / 2, -60, 60)
    l.v = util.clamp(math.floor(math.abs(v) * 2 + 0.5) / 2, 0, 40)
    self:refresh()
end

function Painter:nearestJoint(mx, my)
    local best, bd
    for i, leg in ipairs(self.art.legs) do
        for j = 1, #leg / 2 do
            local sx, sy = self:toScreen(leg[j * 2 - 1], leg[j * 2])
            local d = (sx - mx) ^ 2 + (sy - my) ^ 2
            if not bd or d < bd then best, bd = { i, j }, d end
        end
    end
    if best and bd < (self.grid.cell * 2.5) ^ 2 then return best end
end

function Painter:keypressed(key)
    if key == "escape" then self:back() return end
    if key == "q" or key == "pageup" then self.tab = (self.tab - 2) % #TABS + 1 end
    if key == "e" or key == "pagedown" or key == "tab" then self.tab = self.tab % #TABS + 1 end
    local n = tonumber(key)
    if n and SLOTS[n] then self.slot = SLOTS[n] end
    if key == "f" then self.tool = self.tool == "fill" and "pen" or "fill" end
    if key == "m" then self.mirror = not self.mirror end
    if key == "i" then self.tool = "pick" end
    if key == "s" and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then self:save() end
end

function Painter:back()
    if Content.characters:get(PREVIEW_ID) then Content.characters:unregister(PREVIEW_ID) end
    State.pop()
end

----------------------------------------------------------------------------------------------
-- saving

function Painter:source()
    local art = self:artTable()
    local e = self.entry
    if e and e.source then
        return CustomBugs.tweakSource(e.source, { extras = { art = art } })
    end
    return CustomBugs.toSource({ name = "Painted Bug", description = "A bug painted in the Bug Painter.", playstyle = "brawler",
        art = art, attack = "rhino_beetle", secondary = "rhino_beetle", dash = "rhino_beetle" },
        "-- Made with the Bug Creator's painter. Edit anything below, or open it in the mixer.")
end

function Painter:save()
    local def, info = CustomBugs.save(self:source(), self.entry and self.entry.id)
    if not def then
        self.flash = { "Can't save: " .. tostring(info.errors[1]), Theme.colors.bad }
        Audio.play("ui_back")
        return
    end
    self.entry = CustomBugs.get(def.id)
    self.flash = { "Saved " .. def.name .. ". Tweak it in the mixer to rename it and pick its moves.", Theme.colors.good }
    Audio.play("ui_confirm")
end

----------------------------------------------------------------------------------------------
-- update / draw

function Painter:update(dt)
    self.t = self.t + dt
    if self.pending then
        self.previewT = self.previewT - dt
        if self.previewT <= 0 then self:rebuild() end
    end
end

local function swatch(x, y, s, hex, on)
    local lg = love.graphics
    local c = util.hex(hex)
    lg.setColor(0.15, 0.12, 0.1, 1)
    lg.rectangle("fill", x - 2, y - 2, s + 4, s + 4, 3, 3)
    lg.setColor(c[1], c[2], c[3], 1)
    lg.rectangle("fill", x, y, s, s, 2, 2)
    if on then
        lg.setColor(Theme.colors.focus)
        lg.setLineWidth(2)
        lg.rectangle("line", x - 3, y - 3, s + 6, s + 6, 3, 3)
        lg.setLineWidth(1)
    end
end

function Painter:drawButtons()
    local lg = love.graphics
    local c = Theme.colors
    local mx, my = love.mouse.getPosition()
    lg.setFont(Theme.font("label"))
    for _, b in ipairs(self.buttons) do
        if b.label then
            local hot = mx >= b.x and mx <= b.x + b.w and my >= b.y and my <= b.y + b.h
            lg.setColor(b.on and c.focusBg or (hot and c.panelHi or c.panel))
            lg.rectangle("fill", b.x, b.y, b.w, b.h, 4, 4)
            lg.setColor(b.on and c.focus or c.panelEdge)
            lg.rectangle("line", b.x, b.y, b.w, b.h, 4, 4)
            lg.setColor(b.on and c.focus or c.text)
            lg.printf(b.label, b.x, b.y + (b.h - lg.getFont():getHeight()) / 2, b.w, "center")
        end
    end
end

function Painter:draw()
    local lg = love.graphics
    local w, h = lg.getDimensions()
    local u = Theme.u
    local c = Theme.colors
    lg.clear(c.bg)
    Theme.title("Bug Painter")
    self.buttons = {}
    -- tabs
    local tx = u(60)
    for i, name in ipairs(TABS) do
        local bw = u(110)
        self:button(tx, u(96), bw, u(30), name, function() self.tab = i end, self.tab == i)
        tx = tx + bw + u(8)
    end
    -- canvas
    local cx, cy = u(60), u(140)
    local cw, ch = math.min(w * 0.55, w - u(480)), h - u(250)
    Theme.panel(cx - u(10), cy - u(10), cw + u(20), ch + u(20))
    local cell = math.max(4, math.floor(math.min(cw / self.W, ch / self.H)))
    local gx, gy = cx + math.floor((cw - cell * self.W) / 2), cy + math.floor((ch - cell * self.H) / 2)
    self.grid = { x = gx, y = gy, cell = cell }
    -- checker background
    for y = 1, self.H do
        for x = 1, self.W do
            local k = ((x + y) % 2 == 0) and 0.16 or 0.13
            lg.setColor(k, k * 0.92, k * 0.85, 1)
            lg.rectangle("fill", gx + (x - 1) * cell, gy + (y - 1) * cell, cell, cell)
        end
    end
    local pal = self.art.palette
    for y, r in ipairs(self.art.rows) do
        for x = 1, #r do
            local ch2 = r:sub(x, x)
            if pal[ch2] then
                local col = util.hex(pal[ch2])
                lg.setColor(col[1], col[2], col[3], math.max(0.35, col[4] or 1))
                lg.rectangle("fill", gx + (x - 1) * cell, gy + (y - 1) * cell, cell, cell)
            end
        end
    end
    -- the middle line (mirror) and the facing arrow
    lg.setColor(c.focus[1], c.focus[2], c.focus[3], self.mirror and 0.5 or 0.15)
    lg.line(gx, gy + self.H * cell / 2, gx + self.W * cell, gy + self.H * cell / 2)
    lg.setColor(c.dim)
    lg.setFont(Theme.font("small"))
    lg.print("front >", gx + self.W * cell - u(50), gy - u(18))
    local tab = TABS[self.tab]
    if tab == "Legs" or tab == "Limbs" then
        lg.setScissor(cx - u(10), cy - u(10), cw + u(20), ch + u(20))
        self:drawRig(tab)
        lg.setScissor()
    end

    -- right side: the bug walking, then the tab's controls
    local px = cx + cw + u(30)
    local pw = w - px - u(40)
    Theme.panel(px, cy - u(10), pw, u(170))
    if self.def and self.def.model then
        local spr = Sprites.get(self.def.sprite)
        local s = math.max(2, math.floor(math.min(u(7), u(110) / math.max(1, spr.w))))
        local ang = math.pi * 0.25 + math.sin(self.t * 0.6) * 1.3
        local bx, by = px + pw / 2, cy + u(80)
        lg.setColor(0, 0, 0, 0.35)
        lg.ellipse("fill", bx, by + s * 2, spr.w * s * 0.5, spr.w * s * 0.22)
        lg.setColor(1, 1, 1, 1)
        Sprites.drawModel(self.def.model, math.floor(self.t * 12) + 1, bx, by, ang, false, s, s)
    end
    if self.errors and #self.errors > 0 then
        lg.setColor(c.bad)
        lg.setFont(Theme.font("small"))
        lg.printf(self.errors[1], px + u(8), cy + u(130), pw - u(16), "center")
    end
    local y = cy + u(180)
    self:drawControls(tab, px, y, pw)
    -- bottom bar
    local by2 = h - u(86)
    self:button(u(60), by2, u(140), u(36), "Save", function() self:save() end)
    self:button(u(210), by2, u(140), u(36), "Back", function() self:back() end)
    self:drawButtons()
    if self.flash then
        lg.setFont(Theme.font("label"))
        lg.setColor(self.flash[2])
        lg.print(self.flash[1], u(370), by2 + u(8))
    end
    lg.setColor(1, 1, 1, 1)
    Theme.footer({ { "Left click", tab == "Legs" and "Drag joints" or tab == "Limbs" and "Place limb" or "Paint" },
        { "Right click", "Erase" }, { "1-8", "Colour" }, { "F", "Fill" }, { "M", "Mirror" }, { "Q/E", "Tabs" }, { "Esc", "Back" } })
end

function Painter:drawRig(tab)
    local lg = love.graphics
    local c = Theme.colors
    local cell = self.grid.cell
    -- legs: one side drawn (the other mirrors it)
    for i, leg in ipairs(self.art.legs) do
        local pts = {}
        for j = 1, #leg / 2 do
            local sx, sy = self:toScreen(leg[j * 2 - 1], leg[j * 2])
            pts[#pts + 1] = sx
            pts[#pts + 1] = sy
        end
        lg.setColor(1, 0.85, 0.5, tab == "Legs" and 0.9 or 0.3)
        lg.setLineWidth(2)
        if #pts >= 4 then lg.line(pts) end
        lg.setLineWidth(1)
        if tab == "Legs" then
            for j = 1, #pts, 2 do
                lg.setColor(j == 1 and { 1, 0.5, 0.4 } or j == #pts - 1 and { 0.5, 1, 0.6 } or { 1, 0.9, 0.5 })
                lg.circle("fill", pts[j], pts[j + 1], math.max(3, cell * 0.45))
            end
            lg.setColor(c.text)
            lg.setFont(Theme.font("small"))
            lg.print(tostring(i), pts[#pts - 1] + 6, pts[#pts] - 6)
        end
    end
    if tab == "Limbs" then
        for i, l in ipairs(self.art.limbs) do
            for sd = 1, -1, -2 do
                if not l.side or l.side == sd then
                    local sx, sy = self:toScreen(l.u or 0, (l.v or 0) * sd)
                    lg.setColor(i == self.sel and c.focus or { 0.6, 0.8, 1 })
                    lg.circle(i == self.sel and "fill" or "line", sx, sy, math.max(3, cell * 0.5))
                    -- roughly where it reaches (top-down)
                    local yaw, uu, vv = 0, l.u or 0, (l.v or 0) * sd
                    local pts = { sx, sy }
                    for _, sg in ipairs(l.segs or {}) do
                        yaw = yaw + (sg[2] or 0) * sd
                        uu, vv = uu + math.cos(yaw) * sg[1] * math.cos(sg[3] or 0), vv + math.sin(yaw) * sg[1] * math.cos(sg[3] or 0)
                        local px, py = self:toScreen(uu, vv)
                        pts[#pts + 1] = px
                        pts[#pts + 1] = py
                    end
                    lg.setLineWidth(2)
                    if #pts >= 4 then lg.line(pts) end
                    lg.setLineWidth(1)
                end
            end
        end
    end
end

function Painter:drawControls(tab, px, y, pw)
    local lg = love.graphics
    local u = Theme.u
    local c = Theme.colors
    local a = self.art
    local bw, bh = math.floor((pw - u(16)) / 3), u(30)
    local function row(labels)
        for i, l in ipairs(labels) do
            if l then self:button(px + (i - 1) * (bw + u(8)), y, bw, bh, l[1], l[2], l[3]) end
        end
        y = y + bh + u(8)
    end
    local function text(s, col)
        lg.setFont(Theme.font("label"))
        lg.setColor(col or c.text)
        lg.printf(s, px, y, pw, "left")
        local _, lines = lg.getFont():getWrap(s, pw)
        y = y + #lines * lg.getFont():getHeight() + u(6)
    end
    local function palette()
        local s = u(26)
        for i, k in ipairs(SLOTS) do
            local x = px + (i - 1) * (s + u(10))
            if a.palette[k] then
                swatch(x, y, s, a.palette[k], self.slot == k)
                self:button(x, y, s, s, nil, function() self.slot = k end)
            else
                lg.setColor(c.dim)
                lg.rectangle("line", x, y, s, s, 2, 2)
                self:button(x, y, s, s, nil, function() a.palette[k] = "#808080" self.slot = k end)
            end
            lg.setColor(c.dim)
            lg.setFont(Theme.font("small"))
            lg.print(tostring(i), x + s / 2 - 3, y + s + 2)
        end
        y = y + s + u(24)
    end
    if tab == "Body" then
        palette()
        row({ { "Pen", function() self.tool = "pen" end, self.tool == "pen" }, { "Fill", function() self.tool = "fill" end, self.tool == "fill" },
            { "Pick colour", function() self.tool = "pick" end, self.tool == "pick" } })
        row({ { self.mirror and "Mirror: on" or "Mirror: off", function() self.mirror = not self.mirror end, self.mirror },
            { "Clear", function() for i = 1, self.H do a.rows[i] = string.rep(".", self.W) end self:refresh() end },
            { "Thicker", function() a.height = math.min(10, (a.height or 3) + 1) self:refresh() end } })
        row({ { "Wider", function() self:resize(2, 0) end }, { "Narrower", function() self:resize(-2, 0) end },
            { "Thinner", function() a.height = math.max(1, (a.height or 3) - 1) self:refresh() end } })
        row({ { "Taller", function() self:resize(0, 2) end }, { "Shorter", function() self:resize(0, -2) end },
            { ("Size %dx%d"):format(self.W, self.H), function() end } })
        text("Paint the bug from above, facing right. Mirror copies each pixel to the other side. Thicker / Thinner sets how tall the body stands.", c.dim)
    elseif tab == "Parts" then
        local lists = { { "Head", Parts.heads }, { "Middle", Parts.middles }, { "Back", Parts.backs } }
        for i, l in ipairs(lists) do
            local cur = l[2][self.kit[i]]
            row({ { "<", function() self.kit[i] = (self.kit[i] - 2) % #l[2] + 1 end },
                { l[1] .. ": " .. cur.name, function() self.kit[i] = self.kit[i] % #l[2] + 1 end },
                { ">", function() self.kit[i] = self.kit[i] % #l[2] + 1 end } })
        end
        row({ { "Build the body", function()
            local rows, legs = Parts.compose(self.kit[1], self.kit[2], self.kit[3])
            a.rows, a.legs = rows, legs
            for k, v in pairs(Parts.palette) do if not a.palette[k] then a.palette[k] = v end end
            self:fitGrid()
            self:refresh()
            self.flash = { "Built from parts: now paint over it, recolour it, move its legs.", c.good }
        end }, false, false })
        text("Mix a beetle head, a wasp middle and a spider back... The parts share one set of colours (change them in Colours). Building replaces the drawing and the legs.", c.dim)
    elseif tab == "Legs" then
        row({ { "Add a leg", function()
            if #a.legs < 10 then
                local last = a.legs[#a.legs] or { 0, -1, 0, -4, 0, -7 }
                a.legs[#a.legs + 1] = { last[1] - 2, last[2], last[3] - 3, last[4], last[5] - 4, last[6] }
                self:refresh()
            end
        end }, { "Remove last", function() table.remove(a.legs) self:refresh() end },
            { ("%d a side"):format(#a.legs), function() end } })
        row({ { "Higher knees", function() a.kneeUp = math.min(6, (a.kneeUp or 1) + 1) self:refresh() end },
            { "Lower knees", function() a.kneeUp = math.max(0, (a.kneeUp or 1) - 1) self:refresh() end },
            { "Lift body", function() a.lift = ((a.lift or 2) + 1) % 8 self:refresh() end } })
        text("Drag the dots: red is the hip, yellow the knee, green the foot. The other side copies these.", c.dim)
        text("Leg colour:")
        local s = u(26)
        for i, k in ipairs(SLOTS) do
            if a.palette[k] then
                local x = px + (i - 1) * (s + u(10))
                swatch(x, y, s, a.palette[k], a.legColor == a.palette[k])
                self:button(x, y, s, s, nil, function() a.legColor = a.palette[k]:sub(1, 7) self:refresh() end)
            end
        end
        y = y + s + u(10)
    elseif tab == "Limbs" then
        local P = Parts.limbs[self.newLimb]
        row({ { "<", function() self.newLimb = (self.newLimb - 2) % #Parts.limbs + 1 end },
            { "Add: " .. P.name, function()
                if #a.limbs >= 10 then return end
                local l = {}
                for k, v in pairs(P.limb) do l[k] = v end
                l.segs = {}
                for i, sg in ipairs(P.limb.segs) do l.segs[i] = { sg[1], sg[2], sg[3] } end
                local front = self.W / 2 - 1
                l.u = l.u or (P.id == "tail" or P.id == "club") and -front or (P.id == "wing") and 0 or front
                l.v = l.v or ((P.id == "horn" or P.id == "tail" or P.id == "club") and 0 or 1.5)
                l.color = l.color or "a"
                a.limbs[#a.limbs + 1] = l
                self.sel = #a.limbs
                self:refresh()
            end }, { ">", function() self.newLimb = self.newLimb % #Parts.limbs + 1 end } })
        local l = a.limbs[self.sel]
        if l then
            local nm = ("Limb %d of %d"):format(self.sel, #a.limbs)
            row({ { "< prev", function() self.sel = (self.sel - 2) % #a.limbs + 1 end }, { nm, function() end },
                { "next >", function() self.sel = self.sel % #a.limbs + 1 end } })
            local function each(fn) for _, sg in ipairs(l.segs) do fn(sg) end self:refresh() end
            row({ { "Longer", function() each(function(sg) sg[1] = math.min(30, sg[1] + 1) end) end },
                { "Shorter", function() each(function(sg) sg[1] = math.max(1, sg[1] - 1) end) end },
                { "Remove", function() table.remove(a.limbs, self.sel) self.sel = math.max(1, self.sel - 1) self:refresh() end } })
            row({ { "Turn out", function() l.segs[1][2] = math.min(7, l.segs[1][2] + 0.2) self:refresh() end },
                { "Turn in", function() l.segs[1][2] = math.max(-7, l.segs[1][2] - 0.2) self:refresh() end },
                { "Raise", function() l.segs[1][3] = math.min(1.5, (l.segs[1][3] or 0) + 0.15) self:refresh() end } })
            local tipI = 1
            for i, tp in ipairs(Parts.TIPS) do if tp == (l.tip or "none") then tipI = i end end
            row({ { "Tip: " .. (l.tip or "none"), function()
                    local n = Parts.TIPS[tipI % #Parts.TIPS + 1]
                    l.tip = n ~= "none" and n or nil
                    l.tipLen = l.tipLen or 3
                    self:refresh()
                end },
                { (l.flap and "Flaps") or (l.sway and "Sways") or "Still", function()
                    if l.flap then l.flap, l.sway = nil, 0.25 elseif l.sway then l.sway = nil else l.flap = 24 end
                    l.wave = nil
                    self:refresh()
                end },
                { "Lower", function() l.segs[1][3] = math.max(-1.5, (l.segs[1][3] or 0) - 0.15) self:refresh() end } })
            row({ { l.side and "One (middle)" or "A pair", function() l.side = (not l.side) and 1 or nil self:refresh() end },
                { "Bigger tip", function() l.tipLen = math.min(12, (l.tipLen or 3) + 1) self:refresh() end },
                { "Smaller tip", function() l.tipLen = math.max(1, (l.tipLen or 3) - 1) self:refresh() end } })
            text("Colour:")
            local s = u(26)
            for i, k in ipairs(SLOTS) do
                if a.palette[k] then
                    local x = px + (i - 1) * (s + u(10))
                    swatch(x, y, s, a.palette[k], l.color == k)
                    self:button(x, y, s, s, nil, function() l.color = k self:refresh() end)
                end
            end
            y = y + s + u(10)
            text("Click the drawing to move the selected limb.", c.dim)
        else
            text("Pick a limb and press Add. Claws and blades sit at the front, tails at the back, wings in the middle.", c.dim)
        end
    elseif tab == "Colours" then
        palette()
        local k = self.slot
        local hex = a.palette[k]
        if hex then
            local col = util.hex(hex)
            local hh, ss, vv = toHsv(col[1], col[2], col[3])
            local alpha = col[4] or 1
            local bars = { { "Hue", hh }, { "Strength", ss }, { "Brightness", vv } }
            for bi, bar in ipairs(bars) do
                local bx, bwid, bht = px, pw, u(22)
                lg.setFont(Theme.font("label"))
                lg.setColor(c.text)
                lg.print(bar[1], bx, y)
                y = y + lg.getFont():getHeight() + u(2)
                for i = 0, 59 do
                    local f = i / 59
                    local r, g, b
                    if bi == 1 then r, g, b = hsv(f, 0.8, 0.9)
                    elseif bi == 2 then r, g, b = hsv(hh, f, math.max(0.3, vv))
                    else r, g, b = hsv(hh, ss, f) end
                    lg.setColor(r, g, b, 1)
                    lg.rectangle("fill", bx + f * (bwid - bwid / 60), y, bwid / 60 + 1, bht)
                end
                lg.setColor(1, 1, 1, 1)
                lg.rectangle("line", bx + bar[2] * (bwid - 4), y - 2, 4, bht + 4)
                self:button(bx, y, bwid, bht, nil, function()
                    local mx = love.mouse.getX()
                    local f = util.clamp((mx - bx) / bwid, 0, 1)
                    local nh, ns, nv = hh, ss, vv
                    if bi == 1 then nh = f elseif bi == 2 then ns = f else nv = f end
                    local r, g, b = hsv(nh, ns, nv)
                    local old = a.palette[k]
                    a.palette[k] = toHex(r, g, b, alpha)
                    if a.legColor == old:sub(1, 7) then a.legColor = a.palette[k]:sub(1, 7) end
                    self:refresh()
                end)
                y = y + bht + u(10)
            end
            text(("Colour %d (%s): %s. Every pixel in this colour changes with it, so each part of the bug can have its own colour."):format(
                (function() for i, s2 in ipairs(SLOTS) do if s2 == k then return i end end end)(), k, hex), c.dim)
        end
    end
end

return Painter
