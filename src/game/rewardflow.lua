-- Wave rewards as moments in the arena, so it is always clear what is happening (world.rewardFlow):
--
--   1. A wave is cleared: the beads sweep in, and a reward bloom sprouts on the ground next to
--      your bug (content/props/reward_bloom.lua). Its label says what is inside ("2 level-ups +
--      an item"). Walk into it to open it; Next Wave (E) pulls it to you; left alone it rolls to
--      you after a few seconds. The break before the next wave waits for it.
--   2. It bursts open and the reward screens follow one after another, with a strip at the top
--      that shows every step (LEVEL 7 > LEVEL 8 > ITEM) and which one you are on.
--   3. What you took flies out of the bloom into your bug, and a card on the left of the screen
--      says what you got (NEW ITEM, LEVEL CARD, SHOP...) and what it does. Shop buys, chests and
--      level-ups outside the bloom use the same cards, so every reward looks the same.
--
-- Settings "Wave Rewards" = Open at Once skips the walk (the screens open a beat after the wave,
-- as before). Numbers: src/config/bloom.lua.
--
-- The item choice itself is still world.pendingChoice (src/game/spawner.lua makes it); this
-- module adds pc.bloom (the prop) and pc.opened (the screens may open). Game:update opens them
-- once RewardFlow.ready(world) says so.
local Settings = require("src.core.settings")
local Audio = require("src.core.audio")
local Theme = require("src.ui.theme")
local util = require("src.core.util")
local Config = require("src.config.bloom")

local RewardFlow = {}
RewardFlow.__index = RewardFlow

RewardFlow.cfg = Config

local GOLD = { 1, 0.88, 0.45 }

function RewardFlow.new(world)
    local self = setmetatable({ world = world, flights = {}, toasts = {}, steps = nil, stepI = 0 }, RewardFlow)
    -- savings interest is paid the moment a wave is cleared (src/game/economy.lua)
    world.events:on("wave_cleared", function() self:payInterest() end)
    return self
end

-- "bloom" (walk into it) or "instant" (the screens open on their own).
function RewardFlow:mode()
    local w = self.world
    if w.mode ~= "run" or w.flags.demo or not w.props then return "instant" end
    return Settings.get("waveRewards") == "instant" and "instant" or "bloom"
end

-- Whether the wave's reward screens may open now.
function RewardFlow.ready(world)
    local pc = world.pendingChoice
    if not pc then return false end
    if not pc.opened then return false end
    return world.time >= (pc.at or 0)
end

function RewardFlow:payInterest()
    local w = self.world
    local Economy = require("src.game.economy")
    if not Economy.enabled(w) or w.mode ~= "run" then return end
    local n = Economy.payInterest(w)
    if n > 0 then
        local p = w.player
        w:floatText(p.x, p.y - 20, ("+%d nectar interest"):format(n), { 1, 0.8, 0.3 }, true)
    end
end

----------------------------------------------------------------------------------------------
-- The bloom

-- Where the bloom sprouts: a step from the player towards the middle of the arena.
function RewardFlow:spot()
    local w, p = self.world, self.world.player
    local cx, cy = w.size / 2, w.size / 2
    local dx, dy = cx - p.x, cy - p.y
    local l = math.sqrt(dx * dx + dy * dy)
    local ang
    if l < 30 then ang = love.math.random() * math.pi * 2 else ang = math.atan2(dy, dx) + (love.math.random() - 0.5) * 0.9 end
    local d = Config.distance
    local x = util.clamp(p.x + math.cos(ang) * d, Config.edge, w.size - Config.edge)
    local y = util.clamp(p.y + math.sin(ang) * d, Config.edge, w.size - Config.edge)
    return x, y
end

-- What the bloom holds, in words, for its label.
function RewardFlow:contents()
    local w = self.world
    local lu = w.levelups
    local n = lu and #lu.queue or 0
    local parts = {}
    if n > 0 then parts[#parts + 1] = n == 1 and "a level-up" or (n .. " level-ups") end
    local pc = w.pendingChoice
    if pc then parts[#parts + 1] = pc.boss and "a queen's prize" or "an item" end
    return table.concat(parts, " + ")
end

function RewardFlow:update(dt)
    local w = self.world
    local pc = w.pendingChoice
    if pc and not pc.opened and not w.player.dead then
        if self:mode() == "instant" then
            pc.opened = true
            self:startSteps()
        elseif (not pc.bloom or pc.bloom.dead) and w.time >= (pc.at or 0) - 0.4 then
            local x, y = self:spot()
            pc.bloom = w.props:spawn("reward_bloom", x, y, { choice = pc })
            Audio.play("chime", { pitch = 0.9 })
        end
    end
    -- rewards on their way to the bug
    local p = w.player
    for i = #self.flights, 1, -1 do
        local f = self.flights[i]
        f.t = f.t + dt
        if f.t >= f.dur then
            table.remove(self.flights, i)
            self:arrive(f)
        end
    end
    for i = #self.toasts, 1, -1 do
        local t = self.toasts[i]
        t.t = t.t + dt
        if t.t > Config.toastLife then table.remove(self.toasts, i) end
    end
    if p.dead then self.flights = {} end
end

-- The bloom was touched (or rolled into the bug): burst it and let the screens open.
function RewardFlow:open(pc, x, y)
    if pc.opened then return end
    local w = self.world
    pc.opened = true
    pc.at = w.time + Config.openDelay
    self.from = { x = x, y = y }
    Audio.play("wave_clear", { pitch = 1.25 })
    Audio.play("pickup", { pitch = 1.4 })
    w:addFx({ kind = "ring", x = x, y = y, r = 46, life = 0.5, color = pc.boss and { 1, 0.6, 0.35 } or GOLD })
    w:addFx({ kind = "ring", x = x, y = y, r = 24, life = 0.35, color = { 1, 1, 1 } })
    w.particles:burst(x, y - 10, 26, { GOLD, { 1, 0.7, 0.85 }, { 1, 1, 1 } }, 120, 110, { grav = 120 })
    self:startSteps()
    w.events:emit("reward_opened", pc)
end

-- Next Wave (E) while the bloom waits: it rushes to you. Returns true if there was one.
function RewardFlow:pull()
    local pc = self.world.pendingChoice
    if not pc or pc.opened then return false end
    if pc.bloom and not pc.bloom.dead then
        pc.bloom.pulled = true
        return true
    end
    return false
end

-- The bloom waiting to be opened (or nil).
function RewardFlow:bloom()
    local pc = self.world.pendingChoice
    if pc and not pc.opened and pc.bloom and not pc.bloom.dead then return pc.bloom end
end

----------------------------------------------------------------------------------------------
-- The steps strip on the reward screens

-- Every screen the bloom will show, in order: each queued level-up, then the item.
function RewardFlow:startSteps()
    local w = self.world
    local steps = {}
    local lu = w.levelups
    for _, e in ipairs(lu and lu.queue or {}) do
        if not e.now then
            local label = e.source == "level" and e.level and e.level > 0 and ("LEVEL " .. e.level) or "BONUS CARD"
            steps[#steps + 1] = { kind = "level", entry = e, label = label }
        end
    end
    steps[#steps + 1] = { kind = "item", label = (w.pendingChoice and w.pendingChoice.boss) and "QUEEN'S PRIZE" or "ITEM" }
    self.steps = steps
end

-- The index of the step a screen is showing (a level-up queue entry, or "item"), or nil.
function RewardFlow:stepOf(key)
    for i, s in ipairs(self.steps or {}) do
        if (key == "item" and s.kind == "item") or s.entry == key then return i end
    end
end

-- The item screen closed: the bloom's steps are done.
function RewardFlow:finish()
    self.steps = nil
end

-- Draws the strip of steps centred at y (window coords); key = what the screen shows.
-- Returns the strip's height, or 0 when the screen is not part of a bloom.
function RewardFlow.drawSteps(world, key, y)
    local self = world.rewardFlow
    local i = self and self:stepOf(key)
    if not i or #self.steps < 2 then return 0 end
    local lg = love.graphics
    local u = Theme.u
    local f = Theme.font(14, "bold")
    lg.setFont(f)
    local steps = self.steps
    local pad, gap, h = u(10), u(22), math.floor(u(24))
    local total = 0
    for _, s in ipairs(steps) do total = total + f:getWidth(s.label) + pad * 2 end
    total = total + gap * (#steps - 1)
    local sw = lg.getWidth()
    local scale = 1
    if total > sw - u(40) then scale = (sw - u(40)) / total end
    local x = math.floor((sw - total * scale) / 2)
    for k, s in ipairs(steps) do
        local wdt = (f:getWidth(s.label) + pad * 2) * scale
        local done, now = k < i, k == i
        local col = s.kind == "item" and { 1, 0.8, 0.45 } or { 0.55, 0.85, 1 }
        if now then
            lg.setColor(col[1] * 0.35, col[2] * 0.35, col[3] * 0.35, 0.95)
        else
            lg.setColor(0.06, 0.045, 0.04, 0.85)
        end
        lg.rectangle("fill", x, y, wdt, h)
        lg.setColor(col[1], col[2], col[3], now and 1 or (done and 0.5 or 0.35))
        lg.rectangle("line", x + 0.5, y + 0.5, wdt - 1, h - 1)
        lg.setColor(col[1], col[2], col[3], now and 1 or (done and 0.55 or 0.45))
        lg.printf(s.label, x, y + math.floor((h - f:getHeight()) / 2), wdt, "center")
        if k < #steps then
            lg.setColor(0.86, 0.74, 0.55, 0.5)
            local ax = x + wdt + gap * scale / 2
            local ay = y + h / 2
            lg.polygon("fill", ax - u(4), ay - u(5), ax + u(4), ay, ax - u(4), ay + u(5))
        end
        x = x + wdt + gap * scale
    end
    lg.setColor(1, 1, 1, 1)
    return h
end

----------------------------------------------------------------------------------------------
-- Gains: what you got flies into your bug and gets a card on the left

-- g = { title = "NEW ITEM", name, color, item? (draws its icon), line? (what it does),
--       fromBloom? (fly out of the bloom that was just opened; otherwise it lands at once) }
function RewardFlow:gain(g)
    local w = self.world
    local p = w.player
    g.color = g.color or GOLD
    local from = g.fromBloom and self.from
    if from and Settings.get("reduceMotion") ~= true then
        local delay = #self.flights * Config.flightGap
        self.flights[#self.flights + 1] = { g = g, x0 = from.x, y0 = from.y, t = -delay, dur = Config.flight }
    else
        self:arrive({ g = g })
    end
end

function RewardFlow:arrive(f)
    local w, g = self.world, f.g
    local p = w.player
    if not p.dead then
        w:addFx({ kind = "ring", x = p.x, y = p.y, r = 28, life = 0.4, color = g.color })
        w.particles:burst(p.x, p.y - 6, 10, { g.color, { 1, 1, 1 } }, 70, 60, { grav = 80 })
        w:floatText(p.x, p.y - 8, g.name, g.color, true)
    end
    Audio.play("equip", { pitch = 1.15 + love.math.random() * 0.1 })
    table.insert(self.toasts, 1, { g = g, t = 0 })
    while #self.toasts > Config.toasts do table.remove(self.toasts) end
end

-- A short "what it does" line for an item: its biggest stat changes, or its effect words.
function RewardFlow.itemLine(def)
    local Stats = require("src.game.stats")
    local parts = {}
    for _, sd in ipairs(Stats.defs) do
        local v, m = def.stats and def.stats[sd.id], def.statsMult and def.statsMult[sd.id]
        if v and #parts < 3 then parts[#parts + 1] = (v > 0 and "+" or "") .. Stats.format(sd.id, v) .. " " .. sd.label end
        if m and #parts < 3 then parts[#parts + 1] = (m > 0 and "+" or "") .. math.floor(m * 100 + 0.5) .. "% " .. sd.label end
    end
    if #parts > 0 then return table.concat(parts, ", ") end
    return def.effect or def.description
end

-- Rewards in flight (over the world) and the gain cards on the left of the screen.
function RewardFlow.drawHud(game, covered)
    local self = game.world.rewardFlow
    if not self then return end
    local w = self.world
    local lg = love.graphics
    local u = Theme.u
    local p = w.player
    local InvState = require("src.states.inventory")
    for _, f in ipairs(self.flights) do
        if f.t >= 0 then
            local k = math.min(1, f.t / f.dur)
            local e = k * k * (3 - 2 * k)
            local x = f.x0 + (p.x - f.x0) * e
            local y = f.y0 + (p.y - f.y0) * e
            local z = 18 + math.sin(k * math.pi) * 46
            local sx, sy = w:toWindow(x, y, z)
            local c = f.g.color
            local r = u(13)
            lg.setColor(c[1], c[2], c[3], 0.35)
            lg.circle("fill", sx, sy, r * 1.6, 18)
            lg.setColor(0.08, 0.06, 0.05, 0.85)
            lg.circle("fill", sx, sy, r, 18)
            lg.setColor(c[1], c[2], c[3], 1)
            lg.circle("line", sx, sy, r, 18)
            if f.g.item then
                InvState.itemIcon(f.g.item, sx - r * 0.8, sy - r * 0.8, r * 1.6, r * 1.6)
            else
                lg.circle("fill", sx, sy, r * 0.45, 12)
            end
        end
    end
    if covered or #self.toasts == 0 then lg.setColor(1, 1, 1, 1) return end
    -- the cards, below the HUD's row of item icons
    local inv = p.inventory
    local rows = math.max(0, math.ceil(#inv.order / 8))
    local y = u(92) + rows * (u(22) + u(4)) + u(10)
    local cw, ch = math.floor(u(280)), math.floor(u(66))
    local fTitle, fName, fLine = Theme.font(13, "bold"), Theme.font(16, "bold"), Theme.font(13)
    for _, t in ipairs(self.toasts) do
        local g = t.g
        local inK = math.min(1, t.t / 0.22)
        local a = math.min(1, (Config.toastLife - t.t) / 0.6) * inK
        local x = math.floor(u(20) - (1 - inK) * u(40))
        lg.setColor(0.06, 0.045, 0.04, 0.82 * a)
        lg.rectangle("fill", x, y, cw, ch)
        local c = g.color
        lg.setColor(c[1], c[2], c[3], a)
        lg.rectangle("fill", x, y, math.max(2, u(3)), ch)
        local ix = x + u(10)
        local isz = math.floor(ch - u(14))
        lg.setColor(0.03, 0.025, 0.02, 0.8 * a)
        lg.rectangle("fill", ix, y + u(7), isz, isz)
        if g.item then
            InvState.itemIcon(g.item, ix + 2, y + u(7) + 2, isz - 4, isz - 4, a)
        else
            lg.setColor(c[1], c[2], c[3], a)
            lg.circle("fill", ix + isz / 2, y + u(7) + isz / 2, isz * 0.28, 12)
        end
        local tx = ix + isz + u(8)
        local tw = cw - (tx - x) - u(6)
        lg.setFont(fTitle)
        lg.setColor(c[1], c[2], c[3], 0.85 * a)
        lg.print(g.title or "GOT", tx, y + u(4))
        lg.setFont(fName)
        local name = g.name
        if fName:getWidth(name) > tw then
            while #name > 3 and fName:getWidth(name .. "…") > tw do name = name:sub(1, -2) end
            name = name .. "…"
        end
        Theme.printShadow(name, tx, y + u(4) + fTitle:getHeight() - u(2), { 1, 0.96, 0.88, a })
        if g.line then
            lg.setFont(fLine)
            local line = g.line
            if fLine:getWidth(line) > tw then
                while #line > 3 and fLine:getWidth(line .. "…") > tw do line = line:sub(1, -2) end
                line = line .. "…"
            end
            lg.setColor(0.75, 0.7, 0.62, a)
            lg.print(line, tx, y + ch - fLine:getHeight() - u(3))
        end
        y = y + ch + u(6)
    end
    lg.setColor(1, 1, 1, 1)
end

return RewardFlow
