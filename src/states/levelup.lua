-- Level-up cards: pick one of three (src/game/levelups.lua). Skill-tree nodes of your bug and
-- stat cards that rolled a rarity. Same feel as the item choice: input waits a moment after it
-- opens (space / A are also dash), and a card needs two presses, one to pick, one to take.
-- The button under the cards banks a skill point instead (spend it in the bag's SKILLS tab);
-- it is two presses too and is focus slot #cards + 1. The game is paused while this is open.
local State = require("src.core.state")
local Input = require("src.core.input")
local Audio = require("src.core.audio")
local Theme = require("src.ui.theme")
local Choices = require("src.game.choices")
local InvState = require("src.states.inventory")

local LevelUp = { transparent = true }
LevelUp.__index = LevelUp

local lg = love.graphics
local SKILL_COL = { 0.5, 0.85, 1 }
local GOLD = { 1, 0.88, 0.45 }

-- entry: a queued pick (LevelUps queue). Optional cards: deal these instead (tests).
function LevelUp.new(game, entry, cards)
    local world = game.world
    local lu = world.levelups
    local self = setmetatable({ game = game, world = world, lu = lu, entry = entry or {}, t = 0 }, LevelUp)
    self.cards = cards or lu:deal(entry)
    self.armTime = lu.cfg.armTime or 0.5
    self.focus = 1
    self.armed = nil
    self:refresh()
    return self
end

function LevelUp:refresh()
    local stats = self.world.player.stats
    self.previews = {}
    for i, c in ipairs(self.cards) do
        if c.kind == "stat" then self.previews[i] = Choices.preview(stats, c) end
    end
end

function LevelUp:enter()
    love.mouse.setVisible(true)
    Audio.play("ui_confirm", { pitch = 1.5 })
end

function LevelUp:ready() return self.t >= self.armTime end
function LevelUp:bankIndex() return #self.cards + 1 end
function LevelUp:canBank() return self.world.player.skills ~= nil end

-- Close, and open the next queued pick straight away (no frame of play in between).
function LevelUp:close()
    self.lu:pop(self.entry)
    State.pop()
    local w = self.world
    local nxt = not w.player.dead and self.lu:nextToShow(require("src.game.rewardflow").ready(w))
    if nxt and State.top() == self.game then State.push(LevelUp.new(self.game, nxt)) end
end

function LevelUp:take(i)
    local c = self.cards[i]
    if not c then return end
    self.lu:take(c)
    Audio.play("equip", { pitch = 1.2 })
    local col = c.kind == "node" and SKILL_COL or LevelUp.rarityColor(c.rarity)
    -- the card flies out of the reward bloom into your bug, and a card on the left says what it was
    local flow = self.world.rewardFlow
    if flow then
        flow:gain({ title = c.kind == "node" and "SKILL" or "LEVEL CARD", name = c.name, color = col,
            line = c.description, fromBloom = flow:stepOf(self.entry) ~= nil })
    end
    self:close()
end

function LevelUp:bank()
    self.lu:take({ kind = "point", id = "skill_point", name = "Skill point" })
    Audio.play("ui_confirm", { pitch = 1.3 })
    local flow = self.world.rewardFlow
    if flow then
        flow:gain({ title = "BANKED", name = "+1 Skill Point", color = SKILL_COL, line = "Spend it in the inventory's SKILLS tab",
            fromBloom = flow:stepOf(self.entry) ~= nil })
    end
    self:close()
end

-- One press: the first picks a card (or the bank button), a second press on it takes it.
function LevelUp:activate(i)
    if not self:ready() then return end
    if not (self.cards[i] or (i == self:bankIndex() and self:canBank())) then return end
    if self.armed == i then
        if i == self:bankIndex() then self:bank() else self:take(i) end
    else
        self.armed, self.focus = i, i
        Audio.play("ui_confirm", { pitch = 0.9 })
    end
end

function LevelUp.rarityColor(id)
    return InvState.rarityColor({ rarity = id or "common" })
end

function LevelUp:layout()
    local w, h = lg.getDimensions()
    local u = Theme.u
    local n = math.max(1, #self.cards)
    local cw = math.floor(math.min(u(230), (w - u(60)) / n - u(16)))
    local ch = math.floor(u(250))
    local gap = u(16)
    local total = n * cw + (n - 1) * gap
    local x0 = math.floor((w - total) / 2)
    local y0 = math.floor((h - ch) / 2 - u(4))
    self.rects = {}
    for i = 1, n do self.rects[i] = { x = x0 + (i - 1) * (cw + gap), y = y0, w = cw, h = ch } end
    local bw, bh = math.floor(u(230)), math.floor(u(34))
    self.bankRect = { x = math.floor((w - bw) / 2), y = y0 + ch + u(48), w = bw, h = bh }
    return self.rects
end

local function inside(r, x, y) return r and x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h end

function LevelUp:slotAt(mx, my)
    for i, r in ipairs(self.rects or self:layout()) do
        if inside(r, mx, my) and self.cards[i] then return i end
    end
    if self:canBank() and inside(self.bankRect, mx, my) then return self:bankIndex() end
end

function LevelUp:update(dt)
    self.t = self.t + dt
    if not self:ready() then return end
    local f, n, bankI = self.focus, #self.cards, self:bankIndex()
    if self.focus == bankI then
        if Input.pressed("ui_up") then self.focus = self.lastCard or 1; Audio.play("ui_move") end
    else
        if n > 0 and Input.pressed("ui_left") then self.focus = (self.focus - 2) % n + 1; Audio.play("ui_move") end
        if n > 0 and Input.pressed("ui_right") then self.focus = self.focus % n + 1; Audio.play("ui_move") end
        if Input.pressed("ui_down") and self:canBank() then self.lastCard = self.focus; self.focus = bankI; Audio.play("ui_move") end
    end
    if self.focus ~= f then self.armed = nil end
    if n == 0 and not self:canBank() then self:close() return end
    if Input.pressed("ui_confirm") then self:activate(self.focus)
    elseif Input.pressed("ui_back") and self:canBank() then
        if self.focus <= n then self.lastCard = self.focus end
        self:activate(bankI)
    end
end

function LevelUp:mousemoved(x, y)
    local i = self:slotAt(x, y)
    if i and i ~= self.focus and not self.armed then
        if self.focus <= #self.cards then self.lastCard = self.focus end
        self.focus = i; Audio.play("ui_move")
    end
end

function LevelUp:mousepressed(x, y, b)
    if b ~= 1 then return end
    local i = self:slotAt(x, y)
    if i then self:activate(i) else self.armed = nil end
end

----------------------------------------------------------------------------------------------
-- Drawing

local function wrapLines(font, text, width, room)
    local _, lines = font:getWrap(text, width)
    local fit = math.max(1, math.floor(room / font:getHeight()))
    if #lines > fit then
        lines[fit] = lines[fit]:gsub("%s*%S*$", "") .. "…"
        for k = #lines, fit + 1, -1 do lines[k] = nil end
    end
    return lines
end

function LevelUp:draw()
    local w, h = lg.getDimensions()
    local u = Theme.u
    local COL = InvState.COL
    lg.setColor(0.02, 0.015, 0.02, 0.72)
    lg.rectangle("fill", 0, 0, w, h)
    local rects = self:layout()
    local sk = self.world.player.skills
    local e = self.entry
    -- a soft burst of light behind the title
    local glow = math.min(1, self.t * 3)
    lg.setColor(GOLD[1], GOLD[2], GOLD[3], 0.08 * glow)
    lg.circle("fill", w / 2, rects[1].y - u(52), u(160) * (0.8 + 0.2 * glow))
    lg.setFont(Theme.font(34, "bold"))
    local title
    if e.source == "level" or e.source == nil then
        title = "LEVEL UP!" .. ((e.level or (sk and sk.level)) and ("  LV " .. (e.level or sk.level)) or "")
    else
        title = (e.source == "chest" and "BROOD CELL" or e.source:upper()) .. "  ·  PICK A CARD"
    end
    Theme.printShadow(title, 0, rects[1].y - u(76), GOLD, "center", w)
    -- the wave's rewards, step by step (src/game/rewardflow.lua)
    local inFlow = require("src.game.rewardflow").drawSteps(self.world, e, math.max(u(8), rects[1].y - u(116))) > 0
    lg.setFont(Theme.font(16))
    lg.setColor(COL.dim)
    local more = #self.lu.queue - 1
    local sub = "Pick one card" .. ((more > 0 and not inFlow) and ("  ·  " .. more .. " more after this") or "")
    lg.printf(sub, 0, rects[1].y - u(36), w, "center")

    local ready = self:ready()
    local pad = Input.lastDevice == "gamepad"
    local touch = Input.lastDevice == "touch"
    for i, c in ipairs(self.cards) do
        local r = rects[i]
        local focus = i == self.focus
        local appear = math.min(1, math.max(0, (self.t - (i - 1) * 0.06) * 6))
        local lift = focus and math.floor(u(8) * math.min(1, self.t * 6)) or 0
        local x, y = r.x, r.y - lift + math.floor((1 - appear) * u(24))
        local col = c.kind == "node" and SKILL_COL or LevelUp.rarityColor(c.rarity)
        InvState.plate(x, y, r.w, r.h, focus and { 0.2, 0.15, 0.12 } or COL.frame, true)
        lg.setColor(col)
        lg.rectangle("fill", x + 2, y + 2, r.w - 4, 3)
        if c.kind == "stat" and (c.rarity == "rare" or c.rarity == "legendary") then
            -- rare and legendary cards shimmer
            local s = 0.5 + 0.5 * math.sin(self.t * 4 + i)
            lg.setColor(col[1], col[2], col[3], 0.12 + 0.1 * s)
            lg.rectangle("fill", x + 4, y + 6, r.w - 8, r.h - 10)
        end
        if focus then
            lg.setColor(col[1], col[2], col[3], 0.85)
            lg.setLineWidth(2)
            lg.rectangle("line", x - 4, y - 4, r.w + 8, r.h + 8)
            lg.setLineWidth(1)
        end
        local ty = y + u(18)
        lg.setFont(Theme.font(13, "bold"))
        lg.setColor(col)
        local kindLabel = c.kind == "node" and ("SKILL  ·  " .. (c.branch or ""):upper())
            or (require("src.config.rarities")[c.rarity] or { label = "" }).label:upper()
        lg.printf(kindLabel, x + u(6), ty, r.w - u(12), "center")
        ty = ty + u(26)
        lg.setFont(Theme.font(20, "bold"))
        local nameLines = wrapLines(lg.getFont(), c.name, r.w - u(20), u(52))
        for k, l in ipairs(nameLines) do Theme.printShadow(l, x + u(10), ty + (k - 1) * lg.getFont():getHeight(), col, "center", r.w - u(20)) end
        ty = ty + #nameLines * lg.getFont():getHeight() + u(6)
        lg.setFont(Theme.font(14))
        lg.setColor(COL.dim)
        if c.kind == "node" then
            local s = "Tier " .. c.tier .. (c.ranks > 1 and ("  ·  rank " .. c.rank .. "/" .. c.ranks) or "")
            lg.printf(s, x, ty, r.w, "center")
            ty = ty + u(22)
        else
            local m = c.mult or 1
            lg.printf(m > 1 and ("x" .. (math.floor(m * 100 + 0.5) / 100) .. " roll") or "base roll", x, ty, r.w, "center")
            ty = ty + u(22)
        end
        -- stat cards: real numbers ("Speed 120 » 128")
        lg.setFont(Theme.font(14))
        for _, l in ipairs(self.previews[i] or {}) do
            lg.setColor(l.good == nil and Theme.colors.text or l.good and Theme.colors.good or Theme.colors.bad)
            lg.printf(l.text, x + u(8), ty, r.w - u(16), "center")
            ty = ty + u(18)
        end
        local desc = c.description
        if desc and desc ~= "" then
            local room = y + r.h - u(28) - (ty + u(4))
            local f = Theme.font(14)
            local lines = wrapLines(f, desc, r.w - u(24), room)
            lg.setFont(f)
            lg.setColor(Theme.colors.text)
            for k, l in ipairs(lines) do lg.printf(l, x + u(12), ty + u(4) + (k - 1) * f:getHeight(), r.w - u(24), "center") end
        end
        if c.kind == "node" and c.excludes and #c.excludes > 0 and sk and sk.tree then
            local names = {}
            for _, id in ipairs(c.excludes) do names[#names + 1] = sk.tree.nodes[id].name end
            lg.setFont(Theme.font(12))
            lg.setColor(1, 0.7, 0.5, 0.85)
            lg.printf("Fork: closes " .. table.concat(names, ", "), x + u(8), y + r.h - u(24), r.w - u(16), "center")
        end
        if self.armed == i then
            lg.setFont(Theme.font(16, "bold"))
            local pulse = 0.75 + 0.25 * math.sin(self.t * 8)
            local text = pad and "PRESS {pad:a} AGAIN TO TAKE" or touch and "TAP AGAIN TO TAKE" or "CLICK AGAIN TO TAKE"
            Theme.rich(text, x - u(20), y + r.h + u(10), r.w + u(40), "center", col, pulse)
        end
        if not ready then
            lg.setColor(0.02, 0.015, 0.02, 0.55 * (1 - self.t / self.armTime))
            lg.rectangle("fill", x, y, r.w, r.h)
        end
    end

    if self:canBank() then
        local br = self.bankRect
        local lit = self.focus == self:bankIndex()
        lg.setColor(lit and { SKILL_COL[1] * 0.3, SKILL_COL[2] * 0.3, SKILL_COL[3] * 0.3, 0.95 } or { COL.frameLo[1], COL.frameLo[2], COL.frameLo[3], 0.9 })
        lg.rectangle("fill", br.x, br.y, br.w, br.h)
        lg.setColor(SKILL_COL[1], SKILL_COL[2], SKILL_COL[3], lit and 1 or 0.55)
        lg.rectangle("line", br.x + 0.5, br.y + 0.5, br.w - 1, br.h - 1)
        lg.setFont(Theme.font(15, "bold"))
        local key = pad and " (B)" or touch and "" or " (Esc)"
        lg.printf("BANK A SKILL POINT" .. key, br.x, br.y + math.floor((br.h - lg.getFont():getHeight()) / 2), br.w, "center")
        if self.armed == self:bankIndex() then
            lg.setFont(Theme.font(14, "bold"))
            local pulse = 0.75 + 0.25 * math.sin(self.t * 8)
            Theme.printShadow(touch and "TAP AGAIN TO BANK IT" or "PRESS AGAIN TO BANK IT", 0, br.y + br.h + u(8), { SKILL_COL[1], SKILL_COL[2], SKILL_COL[3], pulse }, "center", w)
        end
    end
    lg.setFont(Theme.font(13))
    Theme.rich(pad and "{pad:dpad} to look, {pad:a} to pick, {pad:a} again to take"
        or touch and "Tap a card to pick it, tap it again to take it"
        or "Click a card to pick it, click it again to take it  ·  a banked point is spent in the bag (SKILLS tab)",
        0, self.bankRect.y + self.bankRect.h + u(30), w, "center", COL.dim)
    lg.setColor(1, 1, 1, 1)
end

return LevelUp
