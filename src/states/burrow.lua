-- The Burrow: spend amber (src/game/amber.lua) on new things to find. Shelves of item packs,
-- maps, modes and artifacts from src/config/amber.lua. Press once to look, twice to buy; a
-- bought thing gets its moment with a fanfare. Main menu.
local State = require("src.core.state")
local Theme = require("src.ui.theme")
local Menu = require("src.ui.menu")
local Audio = require("src.core.audio")
local Content = require("src.content")
local Amber = require("src.game.amber")

local Burrow = {}
Burrow.__index = Burrow

function Burrow.new()
    local self = setmetatable({ t = 0 }, Burrow)
    self.menu = Menu.new({
        items = {},
        onBack = function() State.pop() end,
        rect = function()
            local w, h = love.graphics.getDimensions()
            return Theme.u(60), Theme.u(120), math.min(Theme.u(340), w * 0.34), h - Theme.u(200)
        end,
    })
    self:build()
    return self
end

function Burrow:build()
    local items = {}
    for _, shelf in ipairs(Amber.shelves()) do
        if #shelf.list > 0 then
            items[#items + 1] = { type = "header", label = shelf.name }
            for _, u in ipairs(shelf.list) do
                items[#items + 1] = { type = "button", label = Amber.name(u), unlock = u,
                    value = function()
                        if Amber.open(u) then return "owned" end
                        return u.cost .. " amber"
                    end,
                    onActivate = function() self:press(u) end }
            end
        end
    end
    items[#items + 1] = { type = "button", label = "Back", onActivate = function() State.pop() end }
    self.menu:setItems(items, true)
end

-- First press asks, the second buys.
function Burrow:press(u)
    if Amber.open(u) then Audio.play("ui_back") return end
    if Amber.balance() < u.cost then
        Audio.play("ui_back")
        self.short = { u = u, t = 0 }
        return
    end
    if self.confirm ~= u then
        self.confirm = u
        Audio.play("ui_move")
        return
    end
    if Amber.buy(u.id) then
        self.confirm = nil
        self.bought = { u = u, t = 0 }
        Audio.play("level_up")
        Audio.play("chime", { pitch = 1.3 })
    end
end

function Burrow:update(dt)
    self.t = self.t + dt
    self.menu:update(dt)
    local it = self.menu:focused()
    if self.confirm and not (it and it.unlock == self.confirm) then self.confirm = nil end
    if self.bought then self.bought.t = self.bought.t + dt end
    if self.short then
        self.short.t = self.short.t + dt
        if self.short.t > 1.5 then self.short = nil end
    end
end

-- What an unlock holds, as lines.
local function contents(u)
    local out = {}
    if u.kind == "items" then
        for _, id in ipairs(u.items) do
            local d = Content.items:get(id)
            if d then out[#out + 1] = d.name end
        end
    end
    return out
end

local function amberBead(x, y, r, a)
    local lg = love.graphics
    lg.setColor(0.55, 0.28, 0.05, a)
    lg.circle("fill", x, y, r + 1.5, 16)
    lg.setColor(0.95, 0.6, 0.15, a)
    lg.circle("fill", x, y, r, 16)
    lg.setColor(1, 0.9, 0.6, a)
    lg.circle("fill", x - r * 0.35, y - r * 0.35, r * 0.3, 8)
end
Burrow.amberBead = amberBead

function Burrow:draw()
    local lg = love.graphics
    local u, c = Theme.u, Theme.colors
    local w, h = lg.getDimensions()
    lg.clear(c.bg)
    Theme.title("The Burrow")
    Theme.navFooter("Buy")
    -- the balance, top right
    lg.setFont(Theme.font("heading", "bold"))
    local bal = tostring(Amber.balance())
    local bw = lg.getFont():getWidth(bal)
    amberBead(w - u(70) - bw - u(16), u(66), u(9), 1)
    Theme.printShadow(bal, w - u(70) - bw, u(52), { 1, 0.75, 0.3 })
    lg.setFont(Theme.font("label"))
    lg.setColor(c.dim)
    lg.printf("amber", w - u(200), u(84), u(130), "right")
    self.menu:draw()

    local it = self.menu:focused()
    local un = it and it.unlock
    local px = math.min(u(340), w * 0.34) + u(100)
    local pw, ph = w - px - u(60), h - u(200)
    Theme.panel(px, u(120), pw, ph)
    local x, y, iw = px + u(32), u(150), pw - u(64)
    if not un then
        lg.setFont(Theme.font("body"))
        lg.setColor(c.text)
        lg.printf("Every run pays amber, won or lost: waves cleared, queens slain and more. Spend it here on new things to find. Nothing here makes your bug stronger; it gives you more to discover.", x, y, iw)
        return
    end
    lg.setFont(Theme.font("title", "bold"))
    Theme.printShadow(Amber.name(un):upper(), x, y, c.focus)
    y = y + lg.getFont():getHeight() + u(10)
    lg.setFont(Theme.font("label"))
    lg.setColor(c.accent)
    local kind = ({ items = "ITEM PACK", stage = "MAP", mode = "MODE", artifact = "ARTIFACT", keepsake = "KEEPSAKE" })[un.kind] or ""
    lg.print(kind, x, y)
    y = y + u(28)
    lg.setFont(Theme.font("body"))
    lg.setColor(c.text)
    local desc = Amber.description(un)
    local _, dl = lg.getFont():getWrap(desc, iw)
    lg.printf(desc, x, y, iw)
    y = y + #dl * lg.getFont():getHeight() + u(18)
    local list = contents(un)
    if #list > 0 then
        lg.setFont(Theme.font("label"))
        lg.setColor(c.dim)
        lg.print("ADDS TO THE ITEM POOL", x, y)
        y = y + u(24)
        lg.setFont(Theme.font("body"))
        lg.setColor(c.text)
        for _, n in ipairs(list) do
            lg.print("·  " .. n, x, y)
            y = y + lg.getFont():getHeight() + u(2)
        end
    end
    -- the bottom line: owned / cost / confirm
    local by = u(120) + ph - u(54)
    lg.setFont(Theme.font("heading", "bold"))
    if Amber.open(un) then
        Theme.printShadow("OWNED", x, by, { 0.55, 0.9, 0.5 })
    elseif self.confirm == un then
        Theme.printShadow(("Press again to buy for %d amber"):format(un.cost), x, by, c.focus)
    elseif self.short and self.short.u == un then
        Theme.printShadow(("Not enough amber: %d more to go"):format(un.cost - Amber.balance()), x, by, c.bad)
    else
        amberBead(x + u(10), by + u(16), u(9), 1)
        Theme.printShadow(tostring(un.cost), x + u(28), by, { 1, 0.75, 0.3 })
    end
    -- just bought: its moment
    local b = self.bought
    if b and b.t < 2.2 then
        local k = math.min(1, b.t / 0.25)
        local fade = b.t > 1.7 and (1 - (b.t - 1.7) / 0.5) or 1
        lg.setColor(0, 0, 0, 0.55 * fade)
        lg.rectangle("fill", 0, 0, w, h)
        lg.setFont(Theme.font("banner"))
        local s = 0.6 + 0.4 * k
        lg.push()
        lg.translate(w / 2, h * 0.42)
        lg.scale(s, s)
        Theme.printShadow("UNLOCKED", -w / 2, -u(30), { 1, 0.8, 0.3, fade }, "center", w)
        lg.pop()
        lg.setFont(Theme.font("heading", "bold"))
        Theme.printShadow(Amber.name(b.u), 0, h * 0.42 + u(50), { 1, 1, 1, fade }, "center", w)
    end
    lg.setColor(1, 1, 1, 1)
end

function Burrow:mousemoved(x, y) self.menu:mousemoved(x, y) end
function Burrow:mousepressed(x, y, b) self.menu:mousepressed(x, y, b) end
function Burrow:wheelmoved(x, y) self.menu:wheelmoved(x, y) end

return Burrow
