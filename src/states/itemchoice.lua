-- Item choice: after every wave, pick one of three items (more if you killed gilded elites; a
-- boss wave guarantees something rare). Items no longer drop from enemies, so this is where the
-- build comes from. The pick goes into the bag; if it doesn't fit, the inventory opens holding
-- it so you can make room (or eat it). The game is paused while this is open.
-- No accidental picks: input is ignored for a moment after it opens (space / A are also dash,
-- the mouse is also attack), and taking a card needs two presses: one to pick it, one to confirm.
-- SKIP (the button under the cards, Esc / Backspace, or pad B) passes on every card; it is
-- two presses too. The skip slot is focus index #items + 1.
local State = require("src.core.state")
local Input = require("src.core.input")
local Audio = require("src.core.audio")
local Theme = require("src.ui.theme")
local Content = require("src.content")
local Rarities = require("src.config.rarities")
local Inventory = require("src.game.inventory")
local InvState = require("src.states.inventory")

local Choice = { transparent = true }
Choice.__index = Choice

local lg = love.graphics

Choice.ARM_TIME = 0.8     -- seconds before the cards accept any input

-- n different items, weighted by rarity (and the wave they unlock); minRarity forces at least
-- one of that tier or better.
local function roll(world, n, minRarity)
    local wave = world.spawner and math.max(1, world.spawner.wave) or 1
    local taken, out = {}, {}
    local function pick(pred)
        return Content.items:pickWeighted(function(d) return Rarities[d.rarity].weight end, function(d)
            return not taken[d.id] and Rarities[d.rarity].minWave <= wave and (not pred or pred(d))
        end)
    end
    if minRarity then
        local def = pick(function(d) return Rarities[d.rarity].order >= Rarities[minRarity].order end)
            or Content.items:pickWeighted(function() return 1 end, function(d) return Rarities[d.rarity].order >= Rarities[minRarity].order end)
        if def then taken[def.id] = true; out[#out + 1] = Inventory.newItem(def.id) end
    end
    while #out < n do
        local def = pick()
        if not def then break end
        taken[def.id] = true
        out[#out + 1] = Inventory.newItem(def.id)
    end
    -- shuffle so the guaranteed one isn't always first
    for i = #out, 2, -1 do
        local j = love.math.random(i)
        out[i], out[j] = out[j], out[i]
    end
    return out
end

-- opts: count (cards), boss (true after a boss wave: one is rare or better), wave
function Choice.new(game, opts)
    local self = setmetatable({ game = game, world = game.world, t = 0, opts = opts }, Choice)
    self.items = roll(game.world, opts.count or 3, opts.boss and "rare" or nil)
    self.focus = 1
    self.armed = nil          -- the card picked once, waiting for its confirm
    return self
end

function Choice:enter()
    love.mouse.setVisible(true)
    Audio.play("ui_confirm", { pitch = 1.2 })
end

function Choice:take(i)
    local item = self.items[i]
    if not item then return end
    State.pop()
    local inv = self.world.player.inventory
    self.world.events:emit("item_taken", item)
    if inv:give(item) then
        Audio.play("equip")
        self.world:floatText(self.world.player.x, self.world.player.y, item.def.name, InvState.rarityColor(item.def), true)
    else
        -- no room: open the bag holding it, so you can puzzle it in or eat something
        State.push(InvState.new(self.game, { held = item }))
    end
end

-- Pass on every card: nothing goes in the bag.
function Choice:skip()
    State.pop()
    self.world.events:emit("item_skipped")
    Audio.play("ui_back")
    self.world:floatText(self.world.player.x, self.world.player.y, "Skipped", { 0.75, 0.7, 0.65 }, true)
end

function Choice:ready() return self.t >= Choice.ARM_TIME end

function Choice:skipIndex() return #self.items + 1 end

-- One press on card i: the first picks it, a second press on the same card takes it.
function Choice:activate(i)
    if not self:ready() or not (self.items[i] or i == self:skipIndex()) then return end
    if self.armed == i then
        if i == self:skipIndex() then self:skip() else self:take(i) end
    else
        self.armed, self.focus = i, i
        Audio.play("ui_confirm", { pitch = 0.9 })
    end
end

function Choice:layout()
    local w, h = lg.getDimensions()
    local u = Theme.u
    local n = #self.items
    local cw = math.floor(math.min(u(230), (w - u(60)) / n - u(16)))
    local ch = math.floor(u(330))
    local gap = u(16)
    local total = n * cw + (n - 1) * gap
    local x0 = math.floor((w - total) / 2)
    local y0 = math.floor((h - ch) / 2 + u(10))
    self.cards = {}
    for i = 1, n do self.cards[i] = { x = x0 + (i - 1) * (cw + gap), y = y0, w = cw, h = ch } end
    local bw, bh = math.floor(u(150)), math.floor(u(34))
    self.skipRect = { x = math.floor((w - bw) / 2), y = y0 + ch + u(76), w = bw, h = bh }
    return self.cards
end

function Choice:cardAt(mx, my)
    for i, c in ipairs(self.cards or self:layout()) do
        if mx >= c.x and mx < c.x + c.w and my >= c.y and my < c.y + c.h then return i end
    end
    local r = self.skipRect
    if r and mx >= r.x and mx < r.x + r.w and my >= r.y and my < r.y + r.h then return self:skipIndex() end
end

function Choice:update(dt)
    self.t = self.t + dt
    if not self:ready() then return end
    local f, n, skipI = self.focus, #self.items, self:skipIndex()
    if self.focus == skipI then
        if Input.pressed("ui_up") or Input.pressed("ui_left") or Input.pressed("ui_right") then
            self.focus = self.lastCard or 1; Audio.play("ui_move")
        end
    else
        if Input.pressed("ui_left") then self.focus = (self.focus - 2) % n + 1; Audio.play("ui_move") end
        if Input.pressed("ui_right") then self.focus = self.focus % n + 1; Audio.play("ui_move") end
        if Input.pressed("ui_down") then self.lastCard = self.focus; self.focus = skipI; Audio.play("ui_move") end
    end
    if self.focus ~= f then self.armed = nil end
    if Input.pressed("ui_confirm") then self:activate(self.focus)
    elseif Input.pressed("ui_back") then
        if self.focus ~= skipI then self.lastCard = self.focus end
        self:activate(skipI)
    end
end

function Choice:mousemoved(x, y)
    local i = self:cardAt(x, y)
    if i and i ~= self.focus and not self.armed then
        if self.focus <= #self.items then self.lastCard = self.focus end
        self.focus = i; Audio.play("ui_move")
    end
end

function Choice:mousepressed(x, y, b)
    if b ~= 1 then return end
    local i = self:cardAt(x, y)
    if i then self:activate(i) elseif self.armed then self.armed = nil end   -- click away to un-pick
end

function Choice:draw()
    local w, h = lg.getDimensions()
    local u = Theme.u
    local COL = InvState.COL
    lg.setColor(0.02, 0.015, 0.02, 0.75)
    lg.rectangle("fill", 0, 0, w, h)
    local cards = self:layout()
    lg.setFont(Theme.font(30, "bold"))
    local title = self.opts.boss and "THE QUEEN FELL. CHOOSE A PRIZE"
        or self.opts.endless and ("LEVEL " .. (self.opts.wave or "") .. " SURVIVED")
        or ("WAVE " .. (self.opts.wave or "") .. " CLEARED")

    Theme.printShadow(title, 0, cards[1].y - u(78), COL.label, "center", w)
    lg.setFont(Theme.font(16))
    lg.setColor(COL.dim)
    lg.printf("Pick one item for your bag, or skip them all", 0, cards[1].y - u(40), w, "center")

    local inv = self.world.player.inventory
    local ready = self:ready()
    for i, item in ipairs(self.items) do
        local c = cards[i]
        local def = item.def
        local rc = InvState.rarityColor(def)
        local focus = i == self.focus
        local lift = focus and math.floor(u(8) * math.min(1, self.t * 6)) or 0
        local x, y = c.x, c.y - lift
        InvState.plate(x, y, c.w, c.h, focus and { 0.2, 0.15, 0.12 } or COL.frame, true)
        lg.setColor(rc)
        lg.rectangle("fill", x + 2, y + 2, c.w - 4, 3)
        if focus then
            lg.setColor(rc[1], rc[2], rc[3], 0.8)
            lg.setLineWidth(2)
            lg.rectangle("line", x - 4, y - 4, c.w + 8, c.h + 8)
            lg.setLineWidth(1)
        end
        -- the item drawn on its own little grid, so you can see its shape
        local bw, bh = Inventory.size(item)
        local cell = math.floor(math.min(u(58), (c.w - u(40)) / math.max(bw, 1), u(120) / math.max(bh, 1)))
        local gx = math.floor(x + (c.w - bw * cell) / 2)
        local gy = math.floor(y + u(22) + (u(120) - bh * cell) / 2)
        InvState.shapeCells(item, gx, gy, cell, { rc[1] * 0.3, rc[2] * 0.3, rc[3] * 0.3, 0.9 }, { rc[1], rc[2], rc[3], 0.8 })
        InvState.itemIcon(item, gx + 3, gy + 3, bw * cell - 6, bh * cell - 6)
        local ty = y + u(152)
        lg.setFont(Theme.font(19, "bold"))
        Theme.printShadow(def.name, x, ty, rc, "center", c.w)
        ty = ty + u(26)
        lg.setFont(Theme.font(14))
        lg.setColor(COL.dim)
        lg.printf(Rarities[def.rarity].label .. "  ·  " .. #def.cells .. (#def.cells == 1 and " cell" or " cells"), x, ty, c.w, "center")
        ty = ty + u(26)
        for _, l in ipairs(InvState.statLines(def)) do
            lg.setColor(l[2] and Theme.colors.good or Theme.colors.bad)
            lg.printf(l[1], x + u(10), ty, c.w - u(20), "center")
            ty = ty + u(18)
        end
        local effect = def.effect or (#def.procs > 0 and #InvState.statLines(def) == 0 and def.description)
        if effect then
            lg.setColor(Theme.colors.text)
            lg.printf(effect, x + u(12), ty + u(4), c.w - u(24), "center")
        end
        if self.armed == i then
            lg.setFont(Theme.font(16, "bold"))
            local pulse = 0.75 + 0.25 * math.sin(self.t * 8)
            Theme.printShadow(Input.lastDevice == "gamepad" and "PRESS A AGAIN TO TAKE" or Input.lastDevice == "touch" and "TAP AGAIN TO TAKE" or "CLICK AGAIN TO TAKE",
                x, y + c.h + u(10), { rc[1], rc[2], rc[3], pulse }, "center", c.w)
        end
        if not ready then
            lg.setColor(0.02, 0.015, 0.02, 0.55 * (1 - self.t / Choice.ARM_TIME))
            lg.rectangle("fill", x, y, c.w, c.h)
        end
        local have = inv:count(item.id)
        if have > 0 then
            lg.setFont(Theme.font(13))
            lg.setColor(COL.label)
            lg.printf("You have " .. have .. " (stacks)", x, y + c.h - u(26), c.w, "center")
        end
    end
    -- SKIP button under the cards
    local r = self.skipRect
    local sf, sa = self.focus == self:skipIndex(), self.armed == self:skipIndex()
    InvState.plate(r.x, r.y, r.w, r.h, sf and { 0.2, 0.15, 0.12 } or COL.frame, true)
    if sf then
        lg.setColor(COL.label)
        lg.setLineWidth(2)
        lg.rectangle("line", r.x - 3, r.y - 3, r.w + 6, r.h + 6)
        lg.setLineWidth(1)
    end
    lg.setFont(Theme.font(16, "bold"))
    local skipKey = Input.lastDevice == "gamepad" and "B" or Input.lastDevice == "touch" and nil or "Esc"
    Theme.printShadow(skipKey and ("SKIP (" .. skipKey .. ")") or "SKIP", r.x, r.y + math.floor((r.h - lg.getFont():getHeight()) / 2),
        sf and COL.label or COL.dim, "center", r.w)
    if sa then
        lg.setFont(Theme.font(14, "bold"))
        local pulse = 0.75 + 0.25 * math.sin(self.t * 8)
        local again = Input.lastDevice == "touch" and "TAP AGAIN TO SKIP ALL" or "PRESS AGAIN TO SKIP ALL"
        Theme.printShadow(again, 0, r.y + r.h + u(8), { 1, 0.75, 0.6, pulse }, "center", w)
    end
    if not ready then
        lg.setColor(0.02, 0.015, 0.02, 0.55 * (1 - self.t / Choice.ARM_TIME))
        lg.rectangle("fill", r.x, r.y, r.w, r.h)
    end
    lg.setFont(Theme.font(13))
    lg.setColor(COL.dim)
    lg.printf(Input.lastDevice == "gamepad" and "Left / right to look, A to pick, A again to take" or Input.lastDevice == "touch" and "Tap an item to pick it, tap it again to take it" or "Click an item to pick it, click it again to take it",
        0, cards[1].y + cards[1].h + u(44), w, "center")
    lg.setColor(1, 1, 1, 1)
end

return Choice
