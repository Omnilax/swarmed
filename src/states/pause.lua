-- Pause overlay on top of the running game: the menu in the middle, every stat on the left
-- (hover one for what its number means), and every item in the bag with its full effect on
-- the right (wheel / drag to scroll it).
local State = require("src.core.state")
local Input = require("src.core.input")
local Theme = require("src.ui.theme")
local Menu = require("src.ui.menu")
local Stats = require("src.game.stats")
local Rarities = require("src.config.rarities")
local Content = require("src.content")

local Pause = { transparent = true }
Pause.__index = Pause

local lg = love.graphics

function Pause.new(game)
    local self = setmetatable({ game = game, scroll = 0 }, Pause)
    self.menu = Menu.new({
        align = "center",
        fontSize = 24,
        rowHeight = 46,
        onBack = function() State.pop() end,
        items = {
            { type = "button", label = "Resume", onActivate = function() State.pop() end },
            { type = "button", label = "Run Summary", onActivate = function() State.push(require("src.states.runsummary").new(game)) end },
            { type = "button", label = "Settings", onActivate = function() State.push(require("src.states.settings").new()) end },
            { type = "button", label = "Restart", onActivate = function() game:restart() end },
            { type = "button", label = "Main Menu", onActivate = function() State.switch(require("src.states.menu").new()) end },
        },
        rect = function()
            local w, h = lg.getDimensions()
            local mw = math.min(Theme.u(300), w - 2 * self:sideW() - Theme.u(60))
            return math.floor((w - mw) / 2), math.floor(h * 0.36), mw, Theme.u(46) * 5
        end,
    })
    return self
end

-- Width of each side panel (stats left, items right), shrinking on narrow screens.
function Pause:sideW()
    local w = lg.getWidth()
    local u = Theme.u
    return math.floor(math.max(u(200), math.min(u(320), (w - u(260) - u(60)) / 2)))
end

function Pause:enter() love.mouse.setVisible(true) end

function Pause:update(dt)
    -- Pause key also resumes (ui_back already covers Escape).
    if Input.pressed("pause") and not Input.pressed("ui_back") then State.pop() return end
    self.menu:update(dt)
end

-- One block of text per item id in the bag: name xN, stat changes (all copies), effect words.
function Pause:itemBlocks(width)
    local inv = self.game.world.player.inventory
    local InvState = require("src.states.inventory")
    local fName, fSmall = Theme.font(15, "bold"), Theme.font(14)
    local blocks = {}
    for _, id in ipairs(inv.order) do
        local def = Content.items:require(id)
        local n = inv:count(id)
        local b = { def = def, n = n, color = InvState.rarityColor(def), lines = {} }
        for _, sd in ipairs(Stats.defs) do
            local v, m = def.stats[sd.id], def.statsMult[sd.id]
            if v then
                local tot = v * n
                b.lines[#b.lines + 1] = { (tot > 0 and "+" or "") .. Stats.format(sd.id, tot) .. " " .. sd.label, (tot > 0) ~= (sd.lowerIsBetter == true) }
            end
            if m then
                local tot = m * n
                b.lines[#b.lines + 1] = { (tot > 0 and "+" or "") .. math.floor(tot * 100 + 0.5) .. "% " .. sd.label, (tot > 0) ~= (sd.lowerIsBetter == true) }
            end
        end
        local effect = def.effect or (#def.procs > 0 and def.description) or (#b.lines == 0 and def.description) or nil
        b.effect = {}
        if effect and effect ~= "" then _, b.effect = fSmall:getWrap(effect, width) end
        local lh = fSmall:getHeight() + Theme.u(1)
        b.h = fName:getHeight() + Theme.u(3) + #b.lines * lh + #b.effect * lh + Theme.u(10)
        blocks[#blocks + 1] = b
    end
    return blocks
end

function Pause:draw()
    local w, h = lg.getDimensions()
    local u = Theme.u
    lg.setColor(0.03, 0.02, 0.05, 0.72)
    lg.rectangle("fill", 0, 0, w, h)
    lg.setFont(Theme.font("title"))
    Theme.printShadow("PAUSED", 0, h * 0.36 - u(80), Theme.colors.focus, "center", w)
    self.menu:draw()

    local p = self.game.world.player
    local sideW = self:sideW()
    local top, bottom = u(70), h - u(40)
    local mx, my = love.mouse.getPosition()

    -- Left: every stat, coloured by how items changed it from the bug's base.
    local x = u(20)
    local f = Theme.font(15)
    local rowH = math.floor(f:getHeight() + u(5))
    local ph = math.min(bottom - top, u(34) + #Stats.defs * rowH)
    Theme.panel(x, top, sideW, ph)
    lg.setFont(Theme.font(16, "bold"))
    Theme.printShadow("STATS", x + u(12), top + u(8), Theme.colors.focus)
    lg.setFont(f)
    local hoverStat
    for i, sd in ipairs(Stats.defs) do
        local yy = top + u(32) + (i - 1) * rowH
        if yy + rowH > top + ph then break end
        local v, base = p.stats:get(sd.id), p.stats.base[sd.id]
        local hov = mx >= x and mx < x + sideW and my >= yy - 2 and my < yy + rowH - 2
        if hov then
            hoverStat = sd
            lg.setColor(1, 1, 1, 0.07)
            lg.rectangle("fill", x + u(4), yy - 2, sideW - u(8), rowH)
        end
        lg.setColor(Theme.colors.dim)
        lg.print(sd.label, x + u(12), yy)
        local diff = v - base
        local better = (diff > 0) ~= (sd.lowerIsBetter == true)
        lg.setColor(math.abs(diff) < 0.001 and Theme.colors.text or (better and Theme.colors.good or Theme.colors.bad))
        lg.printf(Stats.format(sd.id, v), x, yy, sideW - u(12), "right")
    end
    if not hoverStat then
        lg.setFont(Theme.font(13))
        lg.setColor(Theme.colors.dim)
        if top + ph + u(6) < bottom then lg.printf("Point at a stat to see what it does", x, top + ph + u(8), sideW, "center") end
    end

    -- Right: every item in the bag and what it does.
    local rx = w - u(20) - sideW
    Theme.panel(rx, top, sideW, bottom - top)
    lg.setFont(Theme.font(16, "bold"))
    local inv = p.inventory
    Theme.printShadow("ITEMS", rx + u(12), top + u(8), Theme.colors.focus)
    lg.setFont(Theme.font(13))
    lg.setColor(Theme.colors.dim)
    lg.printf(#inv.bag .. " in the bag  ·  " .. inv:usedCells() .. "/" .. inv.cols * inv.rows .. " cells", rx, top + u(11), sideW - u(12), "right")
    local listTop, listBottom = top + u(34), bottom - u(8)
    self.itemsRect = { x = rx, y = listTop, w = sideW, h = listBottom - listTop }
    local blocks = self:itemBlocks(sideW - u(28))
    local total = 0
    for _, b in ipairs(blocks) do total = total + b.h end
    self.maxScroll = math.max(0, total - (listBottom - listTop))
    self.scroll = math.max(0, math.min(self.scroll, self.maxScroll))
    lg.setScissor(rx, listTop, sideW, listBottom - listTop)
    local yy = listTop - self.scroll
    local fName, fSmall = Theme.font(15, "bold"), Theme.font(14)
    local lh = fSmall:getHeight() + u(1)
    if #blocks == 0 then
        lg.setFont(fSmall)
        lg.setColor(Theme.colors.dim)
        lg.printf("Nothing yet. Every cleared wave offers a pick.", rx + u(14), yy + u(4), sideW - u(28), "left")
    end
    for _, b in ipairs(blocks) do
        if yy + b.h > listTop and yy < listBottom then
            lg.setFont(fName)
            Theme.printShadow(b.def.name, rx + u(14), yy, b.color)
            lg.setFont(fSmall)
            lg.setColor(Theme.colors.dim)
            lg.printf((b.n > 1 and ("x" .. b.n .. "  ·  ") or "") .. Rarities[b.def.rarity].label, rx, yy + u(1), sideW - u(14), "right")
            local cy = yy + fName:getHeight() + u(3)
            for _, l in ipairs(b.lines) do
                lg.setColor(l[2] and Theme.colors.good or Theme.colors.bad)
                lg.print(l[1], rx + u(14), cy)
                cy = cy + lh
            end
            lg.setColor(Theme.colors.text)
            for _, l in ipairs(b.effect) do
                lg.print(l, rx + u(14), cy)
                cy = cy + lh
            end
        end
        yy = yy + b.h
    end
    lg.setScissor()
    if self.maxScroll > 0 then
        local trackH = listBottom - listTop
        local barH = math.max(u(20), trackH * trackH / (trackH + self.maxScroll))
        local barY = listTop + (trackH - barH) * (self.scroll / self.maxScroll)
        lg.setColor(1, 1, 1, 0.18)
        lg.rectangle("fill", rx + sideW - u(6), barY, u(3), barH)
    end

    if hoverStat then
        require("src.states.inventory").statTip(hoverStat, p.stats:get(hoverStat.id), p.stats.base[hoverStat.id], mx + u(16), my + u(10))
    end
    lg.setColor(1, 1, 1, 1)
end

function Pause:wheelmoved(dx, dy)
    local r = self.itemsRect
    local mx, my = love.mouse.getPosition()
    if r and mx >= r.x and mx < r.x + r.w and my >= r.y and my < r.y + r.h then
        self.scroll = math.max(0, math.min(self.maxScroll or 0, self.scroll - dy * Theme.u(40)))
    elseif self.menu.wheelmoved then
        self.menu:wheelmoved(dx, dy)
    end
end

function Pause:mousemoved(x, y) self.menu:mousemoved(x, y) end
function Pause:mousepressed(x, y, b) self.menu:mousepressed(x, y, b) end

return Pause
