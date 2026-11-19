-- Run summary: damage by source (items, attacks, dashes), kills by species, a damage graph per
-- wave, the achievements closest to unlocking, and the run's seed. Opened from the results
-- screens (game over, victory) and the pause menu. Reads world.runStats (src/game/runstats.lua).
local State = require("src.core.state")
local Input = require("src.core.input")
local Theme = require("src.ui.theme")
local Content = require("src.content")
local RunStats = require("src.game.runstats")
local RunHud = require("src.ui.runhud")

local Summary = { transparent = true }
Summary.__index = Summary

Summary.ROWS = 8            -- rows in the damage and kill lists

function Summary.new(game)
    return setmetatable({ game = game, t = 0 }, Summary)
end

function Summary:enter() love.mouse.setVisible(true) end

function Summary:update(dt)
    self.t = self.t + dt
    if self.t < 0.2 then return end       -- the press that opened it
    if Input.pressed("ui_back") or Input.pressed("pause") or Input.pressed("ui_confirm") then
        require("src.core.audio").play("ui_back")
        State.pop()
    end
end

function Summary:mousepressed() if self.t >= 0.2 then State.pop() end end

local function fmt(n)
    n = math.floor(n + 0.5)
    if n >= 100000 then return ("%.0fk"):format(n / 1000) end
    if n >= 10000 then return ("%.1fk"):format(n / 1000) end
    return tostring(n)
end

local function clock(t)
    t = math.floor(t or 0)
    return ("%d:%02d"):format(math.floor(t / 60), t % 60)
end

-- The achievements nearest to done (not yet unlocked, not hidden, goal above 1), as
-- { def, value, goal } sorted by how close.
function Summary.closest(n, run)
    local reg = Content.achievements
    if not reg then return {} end
    local Records = require("src.game.records")
    local p = Records.get()
    local list = {}
    for _, a in ipairs(reg:all()) do
        if not p.achievements[a.id] and not a.hidden then
            local v, goal = Records.progress(a, p, run)
            if goal > 1 and v > 0 then list[#list + 1] = { def = a, value = v, goal = goal } end
        end
    end
    table.sort(list, function(x, y) return x.value / x.goal > y.value / y.goal end)
    while #list > n do table.remove(list) end
    return list
end

-- A labelled horizontal bar row; returns the next y.
local function barRow(x, y, w, label, value, frac, color, icon)
    local lg = love.graphics
    local u = Theme.u
    local c = Theme.colors
    local rh = u(26)
    local tx = x
    if icon then
        RunHud.icon(icon, x + u(10), y + u(10), u(20))
        tx = x + u(26)
    end
    lg.setColor(1, 1, 1, 0.06)
    lg.rectangle("fill", tx, y + u(17), w - (tx - x), u(5))
    lg.setColor(color)
    lg.rectangle("fill", tx, y + u(17), (w - (tx - x)) * math.max(0, math.min(1, frac)), u(5))
    lg.setFont(Theme.font("small"))
    lg.setColor(c.text)
    local vw = lg.getFont():getWidth(value)
    lg.printf(label, tx, y - u(2), w - (tx - x) - vw - u(8), "left")
    lg.setColor(c.dim)
    lg.print(value, x + w - vw, y - u(2))
    return y + rh
end

-- Per-wave chart: amber bars = damage dealt, red ticks = damage taken (own scale).
function Summary.drawGraph(rs, x, y, w, h)
    local lg = love.graphics
    local u = Theme.u
    local c = Theme.colors
    local n = 0
    for k in pairs(rs.waves) do if k > n then n = k end end
    lg.setColor(0, 0, 0, 0.25)
    lg.rectangle("fill", x, y, w, h)
    if n == 0 then
        lg.setFont(Theme.font("small"))
        lg.setColor(c.dim)
        lg.printf("No waves fought yet", x, y + h / 2 - u(8), w, "center")
        return
    end
    local maxD, maxT = 1, 1
    for i = 1, n do
        local wv = rs.waves[i]
        if wv then maxD, maxT = math.max(maxD, wv.dealt), math.max(maxT, wv.taken) end
    end
    local slot = w / n
    local bw = math.max(2, math.min(u(26), slot * 0.62))
    local base = y + h - u(18)
    local top = y + u(18)
    lg.setFont(Theme.font("small"))
    for i = 1, n do
        local wv = rs.waves[i] or { dealt = 0, taken = 0 }
        local cx = x + (i - 0.5) * slot
        local bh = (base - top) * wv.dealt / maxD
        lg.setColor(c.focus[1], c.focus[2], c.focus[3], 0.85)
        lg.rectangle("fill", math.floor(cx - bw / 2), math.floor(base - bh), math.floor(bw), math.ceil(bh))
        if wv.taken > 0 then
            local th = (base - top) * wv.taken / maxT
            lg.setColor(c.hp[1], c.hp[2], c.hp[3], 1)
            lg.rectangle("fill", math.floor(cx - bw / 2 - 1), math.floor(base - th) - 1, math.floor(bw) + 2, math.max(2, u(3)))
        end
        -- wave numbers, thinned out when there are many
        local every = math.max(1, math.ceil(n / math.max(1, math.floor(w / u(30)))))
        if i % every == 0 or i == 1 then
            lg.setColor(c.dim)
            lg.printf(tostring(i), math.floor(cx - u(20)), base + u(2), u(40), "center")
        end
    end
    lg.setColor(c.dim)
    lg.print("peak " .. fmt(maxD), x + u(6), y + u(1))
end

function Summary:draw()
    local lg = love.graphics
    local w, h = lg.getDimensions()
    local u = Theme.u
    local c = Theme.colors
    local world = self.game.world
    local rs = RunStats.of(world)
    lg.setColor(0.04, 0.03, 0.03, math.min(0.92, 0.5 + self.t * 3))
    lg.rectangle("fill", 0, 0, w, h)
    Theme.title("Run Summary", w)

    -- who, where, how long, and the seed
    local sp = world.spawner
    local bits = { world.player.def.name }
    if world.modeDef and world.modeDef.name then bits[#bits + 1] = world.modeDef.name end
    bits[#bits + 1] = ((sp and sp.endless) and "Level " or "Wave ") .. (sp and sp.wave or 0)
    bits[#bits + 1] = clock(world.time)
    bits[#bits + 1] = world.kos .. " KOs"
    bits[#bits + 1] = "Seed " .. tostring(world.seed or "?")
    lg.setFont(Theme.font("label"))
    lg.setColor(c.dim)
    lg.printf(table.concat(bits, "   ·   "), 0, u(94), w, "center")

    local pad = u(24)
    local top = u(128)
    local cols = w > u(900) and 3 or 2
    local colW = math.floor((w - pad * (cols + 1)) / cols)
    local graphH = math.max(u(110), math.min(u(170), h * 0.22))
    local panelH = h - top - graphH - u(110)

    -- Damage by source
    local x = pad
    Theme.panel(x, top, colW, panelH)
    lg.setFont(Theme.font("small", "bold"))
    lg.setColor(c.focus)
    lg.print("DAMAGE BY SOURCE", x + u(14), top + u(10))
    lg.setColor(c.dim)
    local total = math.max(1, rs.totalDealt)
    local s = fmt(rs.totalDealt) .. " total"
    lg.print(s, x + colW - u(14) - lg.getFont():getWidth(s), top + u(10))
    local yy = top + u(36)
    local list = RunStats.sorted(rs.dealt, Summary.ROWS)
    local maxRows = math.max(1, math.floor((panelH - u(44)) / u(26)))
    for i, row in ipairs(list) do
        if i > maxRows then break end
        local pct = math.floor(row[2] * 100 / total + 0.5)
        yy = barRow(x + u(14), yy, colW - u(28), row[1], fmt(row[2]) .. "  " .. pct .. "%", row[2] / list[1][2], c.focus)
    end
    if #list == 0 then
        lg.setFont(Theme.font("small"))
        lg.setColor(c.dim)
        lg.print("Nothing hit yet", x + u(14), yy)
    end

    -- Kills by species
    x = pad * 2 + colW
    Theme.panel(x, top, colW, panelH)
    lg.setFont(Theme.font("small", "bold"))
    lg.setColor(c.focus)
    lg.print("KILLS BY SPECIES", x + u(14), top + u(10))
    yy = top + u(36)
    list = RunStats.sorted(rs.kills, Summary.ROWS)
    for i, row in ipairs(list) do
        if i > maxRows then break end
        local def = Content.enemies:get(row[1])
        yy = barRow(x + u(14), yy, colW - u(28), def and def.name or row[1], fmt(row[2]), row[2] / list[1][2], c.accent, def and def.sprite)
    end
    if #list == 0 then
        lg.setFont(Theme.font("small"))
        lg.setColor(c.dim)
        lg.print("No kills yet", x + u(14), yy)
    end

    -- Closest achievements (third column on wide screens)
    if cols == 3 then
        x = pad * 3 + colW * 2
        Theme.panel(x, top, colW, panelH)
        lg.setFont(Theme.font("small", "bold"))
        lg.setColor(c.focus)
        lg.print("CLOSE TO UNLOCKING", x + u(14), top + u(10))
        yy = top + u(36)
        local Records = require("src.game.records")
        local run = Records.run and not Records.run.ended and Records.run or nil
        for i, a in ipairs(Summary.closest(math.max(1, math.floor(maxRows / 1.5)), run)) do
            yy = barRow(x + u(14), yy, colW - u(28), a.def.name, fmt(a.value) .. " / " .. fmt(a.goal), a.value / a.goal, c.good)
            lg.setFont(Theme.font("small"))
            lg.setColor(c.dim)
            lg.printf(a.def.description or "", x + u(14), yy - u(2), colW - u(28))
            yy = yy + u(16)
        end
    end

    -- Damage per wave
    local gy = top + panelH + u(16)
    local gw = w - pad * 2
    Theme.panel(pad, gy, gw, graphH + u(30))
    lg.setFont(Theme.font("small", "bold"))
    lg.setColor(c.focus)
    lg.print("DAMAGE PER WAVE", pad + u(14), gy + u(8))
    local key = "dealt"
    local kx = pad + gw - u(14)
    lg.setFont(Theme.font("small"))
    local tw = lg.getFont():getWidth("taken")
    lg.setColor(c.dim)
    lg.print("taken", kx - tw, gy + u(8))
    lg.setColor(c.hp)
    lg.rectangle("fill", kx - tw - u(18), gy + u(15), u(12), u(3))
    local dw = lg.getFont():getWidth(key)
    kx = kx - tw - u(30)
    lg.setColor(c.dim)
    lg.print(key, kx - dw, gy + u(8))
    lg.setColor(c.focus)
    lg.rectangle("fill", kx - dw - u(18), gy + u(11), u(12), u(8))
    Summary.drawGraph(rs, pad + u(14), gy + u(28), gw - u(28), graphH - u(4))

    Theme.footer({ { "Esc", "Back" } })
end

return Summary
