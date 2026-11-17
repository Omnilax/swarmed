-- The inventory window's tabs: BAG (src/states/inventory.lua), SKILLS (src/states/skilltree.lua)
-- and SHOP (src/states/shop.lua). They are three screens of one window: switching swaps them
-- without unpausing. TAB / I (pad Y) opens and closes the window; E / Q (pad RB / LB, PageUp /
-- PageDown) or a click on a tab switch between them. SHOP is there in real runs with the nectar
-- economy on (src/game/economy.lua).
local State = require("src.core.state")
local Input = require("src.core.input")
local Audio = require("src.core.audio")
local Theme = require("src.ui.theme")

local Tabs = {}

local LABEL = { bag = "BAG", skills = "SKILLS", shop = "SHOP" }
local MODULE = { bag = "src.states.inventory", skills = "src.states.skilltree", shop = "src.states.shop" }

-- The tabs this run has, in order.
function Tabs.ids(game)
    local out = { "bag", "skills" }
    if require("src.game.economy").open(game.world) then out[#out + 1] = "shop" end
    return out
end

-- Tab rects from (x, y), height h: { { id, x, y, w, h }, ... }.
function Tabs.layout(game, x, y, h)
    local f = Theme.font(18, "bold")
    local u = Theme.u
    local out = {}
    for _, id in ipairs(Tabs.ids(game)) do
        local w = f:getWidth(LABEL[id]) + u(20)
        out[#out + 1] = { id = id, x = x, y = y, w = w, h = h }
        x = x + w + u(6)
    end
    return out
end

function Tabs.hit(tabs, x, y)
    for _, t in ipairs(tabs or {}) do
        if x >= t.x and x < t.x + t.w and y >= t.y and y < t.y + t.h then return t.id end
    end
end

-- Swap the screen `from` (one of the three) for tab id. Not while an item is held in the bag.
function Tabs.open(from, id, opts)
    if from.held then Audio.play("ui_back") return false end
    State.pop()
    State.push(require(MODULE[id]).new(from.game, opts))
    Audio.play("ui_move")
    return true
end

-- E / Q: the next or previous tab. In the bag, pad LB also turns the held item, so it doesn't
-- switch there.
function Tabs.cycle(from, current)
    local dir = 0
    if Input.pressed("ui_tab_next") then dir = 1
    elseif Input.pressed("ui_tab_prev") and not (current == "bag" and Input.pressed("inventory_rotate")) then dir = -1 end
    if dir == 0 then return false end
    local ids = Tabs.ids(from.game)
    local k = 1
    for i, id in ipairs(ids) do if id == current then k = i end end
    return Tabs.open(from, ids[(k - 1 + dir) % #ids + 1])
end

-- The window closes on TAB / I (pad Y), Esc / pad B, or Pause.
function Tabs.closing()
    if Input.pressed("inventory") or Input.pressed("ui_back") or Input.pressed("pause") then
        Input.consume("pause")
        return true
    end
    return false
end

-- Draw the tabs; badges show waiting skill points and fresh shop stock.
function Tabs.draw(tabs, active, game)
    local lg = love.graphics
    local COL = require("src.states.inventory").COL
    local u = Theme.u
    local sk = game and game.world.player.skills
    local points = sk and sk.points or 0
    local shop = game and game.world.economy and game.world.economy.shop
    for _, tab in ipairs(tabs) do
        local on = tab.id == active
        lg.setColor(on and COL.frameHi or COL.frameLo)
        lg.rectangle("fill", tab.x, tab.y, tab.w, tab.h)
        lg.setColor(on and COL.inner or COL.frame)
        lg.rectangle("fill", tab.x + 2, tab.y + 2, tab.w - 4, tab.h - 2)
        lg.setFont(Theme.font(18, "bold"))
        local col = on and COL.label or COL.dim
        if tab.id == "shop" then col = on and { 1, 0.85, 0.4 } or { 0.8, 0.62, 0.3 } end
        Theme.printShadow(LABEL[tab.id], tab.x, tab.y + u(3), col, "center", tab.w)
        local badge, bcol, btext = false, nil, nil
        if tab.id == "skills" and points > 0 then badge, bcol, btext = true, { 0.35, 0.8, 1 }, tostring(points) end
        if tab.id == "shop" and shop and not shop.seen and active ~= "shop" then badge, bcol, btext = true, { 1, 0.75, 0.25 }, "!" end
        if badge then
            local r = u(8)
            local bx, by = tab.x + tab.w - u(2), tab.y + u(2)
            lg.setColor(bcol[1], bcol[2], bcol[3], 0.9 + 0.1 * math.sin(love.timer.getTime() * 6))
            lg.circle("fill", bx, by, r)
            lg.setFont(Theme.font(12, "bold"))
            lg.setColor(0.05, 0.1, 0.15)
            lg.printf(btext, bx - r, by - u(7), r * 2, "center")
        end
    end
    lg.setColor(1, 1, 1, 1)
end

return Tabs
