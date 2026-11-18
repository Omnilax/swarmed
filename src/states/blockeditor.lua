-- Bug Creator: build a move from blocks, no code (src/game/moveblocks.lua). A list of blocks per
-- step (one step = a plain move, two or three = a combo: tap, tap again, tap again), each with
-- its numbers on sliders, and the move fighting on the right with its hitboxes drawn.
-- opts: title, slot ("attack" | "secondary" | "dash" | "ultimate"), value (the move table so far
-- or nil), previewRaw(value) -> a whole bug's script table for the preview, onDone(value).
local State = require("src.core.state")
local Theme = require("src.ui.theme")
local Menu = require("src.ui.menu")
local Content = require("src.content")
local MB = require("src.game.moveblocks")
local HS = require("src.game.hitshapes")

local Editor = {}
Editor.__index = Editor

local PREVIEW_ID = "custom__blockpreview"

local STARTERS = {
    attack = { { "arc", radius = 50, degrees = 120, damage = 9, knockback = 80, windup = 0 } },
    secondary = { { "root", time = 0.2 }, { "wait", time = 0.2 }, { "circle", radius = 60, ahead = 30, damage = 20, knockback = 240, windup = 0 } },
    dash = { { "lunge", distance = 70 }, { "push", radius = 40, strength = 200 } },
    ultimate = { { "ring_fx", radius = 120 }, { "circle", radius = 120, ahead = 0, damage = 40, knockback = 400, windup = 0 }, { "shake", amount = 0.3 } },
}

local function copyList(l)
    local out = {}
    for i, b in ipairs(l or {}) do
        local c = {}
        for k, v in pairs(b) do c[k] = v end
        out[i] = c
    end
    return out
end

function Editor.new(opts)
    local self = setmetatable({ t = 0, opts = opts, slot = opts.slot or "attack", previewT = 0 }, Editor)
    local v = opts.value or {}
    self.name = v.name or (self.slot == "ultimate" and "Ultimate" or "My Move")
    self.cooldown = v.cooldown or (self.slot == "secondary" and 3 or self.slot == "attack" and 0.6 or 1)
    self.steps = {}
    if type(v.combo) == "table" then
        for i, st in ipairs(v.combo) do if type(st) == "table" then self.steps[#self.steps + 1] = copyList(st) end end
        self.window = v.combo.window or 0.8
    elseif type(v.blocks) == "table" then
        self.steps[1] = copyList(v.blocks)
    end
    if #self.steps == 0 then self.steps[1] = copyList(STARTERS[self.slot] or STARTERS.attack) end
    self.window = self.window or 0.8
    self.step = 1
    self.newKind = "arc"
    self.menu = Menu.new({
        items = {},
        onBack = function() self:cancel() end,
        rowHeight = 32, fontSize = 18,
        rect = function()
            local w, h = love.graphics.getDimensions()
            return Theme.u(50), Theme.u(110), math.min(Theme.u(470), w * 0.46), h - Theme.u(170)
        end,
    })
    HS.show = true
    self:build()
    self:refresh(true)
    return self
end

function Editor:value()
    local v = { name = self.name }
    if self.slot ~= "ultimate" and self.slot ~= "dash" then v.cooldown = self.cooldown end
    if self.slot == "dash" then v.charges = 1 end
    if #self.steps > 1 then
        local c = { window = self.window }
        for i, st in ipairs(self.steps) do c[i] = copyList(st) end
        v.combo = c
    else
        v.blocks = copyList(self.steps[1])
    end
    return v
end

function Editor:build(keep)
    local items = {}
    local list = self.steps[self.step]
    items[#items + 1] = { type = "header", label = "Move" }
    if self.slot ~= "ultimate" and self.slot ~= "dash" then
        items[#items + 1] = { type = "slider", label = "Cooldown", min = 0.1, max = 12, step = 0.1,
            get = function() return self.cooldown end, set = function(x) self.cooldown = math.floor(x * 10 + 0.5) / 10 self:refresh() end,
            format = function(x) return ("%.1f s"):format(x) end, desc = "Seconds before it can be used again." }
        items[#items + 1] = { type = "choice", label = "Combo", options = { { value = 1, label = "No (one move)" },
            { value = 2, label = "2 hits" }, { value = 3, label = "3 hits" } },
            get = function() return #self.steps end,
            set = function(n)
                while #self.steps < n do self.steps[#self.steps + 1] = copyList(self.steps[#self.steps]) end
                while #self.steps > n do table.remove(self.steps) end
                self.step = math.min(self.step, n)
                self:build(true) self:refresh()
            end, desc = "A combo plays the next step when you use the move again quickly: tap, tap, tap." }
        if #self.steps > 1 then
            items[#items + 1] = { type = "slider", label = "Combo window", min = 0.2, max = 3, step = 0.1,
                get = function() return self.window end, set = function(x) self.window = math.floor(x * 10 + 0.5) / 10 self:refresh() end,
                format = function(x) return ("%.1f s"):format(x) end, desc = "How long after a hit the next one still counts as the combo." }
            local so = {}
            for i = 1, #self.steps do so[i] = { value = i, label = "Hit " .. i } end
            items[#items + 1] = { type = "choice", label = "Editing", options = so, get = function() return self.step end,
                set = function(i) self.step = i self:build(true) end, desc = "Which hit of the combo the blocks below belong to." }
        end
    end
    items[#items + 1] = { type = "header", label = #self.steps > 1 and ("Blocks of hit " .. self.step) or "Blocks (top to bottom)" }
    local kindOpts = {}
    for _, k in ipairs(MB.ORDER) do kindOpts[#kindOpts + 1] = { value = k, label = MB.KINDS[k].label } end
    for i, b in ipairs(list) do
        local K = MB.KINDS[b[1]]
        local opts = { { value = b[1], label = K.label } }
        for _, o in ipairs(kindOpts) do if o.value ~= b[1] then opts[#opts + 1] = o end end
        opts[#opts + 1] = { value = "__up", label = "^ Move up" }
        opts[#opts + 1] = { value = "__remove", label = "x Remove" }
        items[#items + 1] = { type = "choice", label = i .. ".", options = opts, get = function() return b[1] end,
            set = function(k)
                if k == "__remove" then table.remove(list, i)
                elseif k == "__up" then if i > 1 then list[i], list[i - 1] = list[i - 1], list[i] end
                else list[i] = MB.new(k) end
                self:build(true) self:refresh()
            end, desc = K.desc .. "  (Left / Right: change it, move it up or remove it)" }
        for _, p in ipairs(K.params) do
            items[#items + 1] = { type = "slider", label = "    " .. p.label, min = p.min, max = p.max, step = p.step,
                get = function() return b[p.key] or p.default end,
                set = function(x) b[p.key] = math.floor(x / p.step + 0.5) * p.step self:refresh() end,
                format = function(x)
                    if p.step < 1 then return ("%.2f"):format(x):gsub("0+$", ""):gsub("%.$", "") end
                    return tostring(math.floor(x + 0.5))
                end, desc = K.desc }
        end
        -- blocks that hit can carry one of the bug's statuses
        local sts = self.opts.statuses
        if sts and #sts > 0 and (b[1] == "arc" or b[1] == "circle" or b[1] == "box" or b[1] == "ring" or b[1] == "sweep"
            or b[1] == "shoot" or b[1] == "status") then
            local so = { { value = false, label = "None" } }
            for _, sid in ipairs(sts) do so[#so + 1] = { value = sid, label = sid:sub(1, 1):upper() .. sid:sub(2) } end
            items[#items + 1] = { type = "choice", label = "    Status", options = so, get = function() return b.status or false end,
                set = function(x) b.status = x or nil self:refresh() end, desc = "Put the bug's own status effect on what this hits." }
        end
    end
    items[#items + 1] = { type = "choice", label = "New block", options = kindOpts, get = function() return self.newKind end,
        set = function(k) self.newKind = k end, desc = function() return MB.KINDS[self.newKind].desc end }
    items[#items + 1] = { type = "button", label = "+ Add block", onActivate = function()
        if #list >= 24 then return end
        list[#list + 1] = MB.new(self.newKind)
        self:build(true) self:refresh()
    end, desc = "Adds the block picked above to the end." }
    items[#items + 1] = { type = "header", label = "" }
    items[#items + 1] = { type = "button", label = "Done", onActivate = function() self:done() end }
    items[#items + 1] = { type = "button", label = "Cancel", onActivate = function() self:cancel() end }
    self.menu:setItems(items, keep)
end

function Editor:refresh(now)
    self.previewT = now and 0 or 0.35
    self.pending = true
end

function Editor:rebuildPreview()
    self.pending = false
    self:dropPreview()
    if not self.opts.previewRaw then return end
    local CustomBugs = require("src.game.custombugs")
    local def, errs = CustomBugs.build(self.opts.previewRaw(self:value()))
    self.errors = errs
    if not def then return end
    def.id = PREVIEW_ID
    CustomBugs.prepareArt(def)
    Content.characters:register(def)
    local ok, pv = pcall(require("src.ui.movepreview").new, PREVIEW_ID)
    if ok then
        self.preview = pv
        -- an ultimate shows by itself: fill the meter now and then
        if self.slot == "ultimate" then pv.ultimate = true end
    end
end

function Editor:dropPreview()
    if self.preview then self.preview:release() self.preview = nil end
    if Content.characters:get(PREVIEW_ID) then Content.characters:unregister(PREVIEW_ID) end
end

function Editor:done()
    self:dropPreview()
    HS.show = false
    State.pop()
    if self.opts.onDone then self.opts.onDone(self:value()) end
end

function Editor:cancel()
    self:dropPreview()
    HS.show = false
    State.pop()
end
function Editor:leave() self:dropPreview() HS.show = false end

function Editor:update(dt)
    self.t = self.t + dt
    self.menu:update(dt)
    if self.pending then
        self.previewT = self.previewT - dt
        if self.previewT <= 0 then self:rebuildPreview() end
    end
    if self.preview then
        -- show off the move being built more often than the usual loop
        local w = self.preview.world
        self.fireT = (self.fireT or 0) - dt
        if self.fireT <= 0 then
            self.fireT = 1.4
            if self.slot == "secondary" or self.slot == "dash" then self.preview.extraPress = self.slot end
            if self.slot == "ultimate" and w.rewards and w.rewards.frenzy then
                w.rewards.frenzy.charge = w.rewards.frenzy.max
                w.rewards.frenzy:unleash()
            end
        end
        self.preview:update(dt)
    end
end

function Editor:mousemoved(x, y) self.menu:mousemoved(x, y) end
function Editor:mousepressed(x, y, b) self.menu:mousepressed(x, y, b) end
function Editor:wheelmoved(x, y) self.menu:wheelmoved(x, y) end

function Editor:draw()
    local lg = love.graphics
    local w, h = lg.getDimensions()
    local u = Theme.u
    local c = Theme.colors
    local mx, my, mw = self.menu:rect()
    local px = mx + mw + u(40)
    local pw = w - px - u(50)
    local bx, by, bw = px + u(16), u(126), pw - u(32)
    local bh = math.floor(math.min(bw * 0.62, h * 0.42))
    lg.clear(c.bg)
    Theme.panel(px, u(110), pw, h - u(170))
    if self.preview then self.preview:draw(bx, by, bw, bh)
    else lg.setColor(c.panelEdge) lg.rectangle("line", bx, by, bw, bh) end
    Theme.title(self.opts.title or "Build a Move")
    self.menu:draw()
    local ty = by + bh + u(14)
    lg.setFont(Theme.font("label"))
    lg.setColor(c.dim)
    local lines = {}
    for i, st in ipairs(self.steps) do
        local bits = {}
        for _, b in ipairs(st) do bits[#bits + 1] = MB.KINDS[b[1]].label end
        lines[#lines + 1] = (#self.steps > 1 and ("Hit " .. i .. ": ") or "") .. table.concat(bits, "  >  ")
    end
    lg.printf(table.concat(lines, "\n"), px + u(16), ty, pw - u(32), "center")
    ty = ty + (#lines + 1) * lg.getFont():getHeight()
    local it = self.menu:focused()
    local desc = it and it.desc
    if type(desc) == "function" then desc = desc() end
    if desc then
        lg.setColor(c.text)
        lg.printf(desc, px + u(16), ty, pw - u(32), "center")
    end
    if self.errors and #self.errors > 0 then
        lg.setColor(c.bad)
        lg.printf(self.errors[1], px + u(16), h - u(96), pw - u(32), "center")
    end
    lg.setColor(c.dim)
    lg.printf("Cyan outlines: where each hit lands.", px + u(16), by + bh - u(20), pw - u(32), "center")
    lg.setColor(1, 1, 1, 1)
    Theme.footer({ { "Left/Right", "Change" }, { "Enter", "Select" }, { "Esc", "Cancel" } })
end

return Editor
