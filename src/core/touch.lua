-- On-screen touch controls for phones and tablets: a thumb stick on the left half, action
-- buttons on the right, and tap / drag-to-scroll for every menu.
--
-- Touch writes into Input (virtualDown, virtualMove, virtualAim, Input.press) so game code
-- keeps asking Input about actions and never knows a finger was involved.
--
-- Which buttons show depends on the top state's `touchControls` field:
--   "game"      stick, Special, Dash, Attack (when Auto Attack is off), Bag, Pause
--               (Touch Layout = Left Handed mirrors it: stick on the right, buttons on the left)
--   "inventory" Turn, Eat, Close (taps on the bag are clicks)
--   "menu"      Close only (the skills and shop tabs; taps are clicks)
--   nil         none: taps are clicks, vertical drags scroll (mouse wheel)
-- The game state can offer `touchStatus()` (cooldowns, sandbox panel) to the buttons.
--
-- Settings > Controls > Touch Controls = Always also lets the left mouse button press the
-- on-screen controls, so the layout can be tried on a PC (`love . --touch`).
local Settings = require("src.core.settings")
local Input = require("src.core.input")
local State = require("src.core.state")
local Theme = require("src.ui.theme")
local util = require("src.core.util")

local Touch = { active = false, touches = {} }

local MOUSE = "mouse"            -- touch id used when the mouse stands in for a finger
local TAP_SLOP = 12              -- pixels a finger can wander and still count as a tap
local AIM_DEAD = 0.3             -- fraction of a button's radius to drag before it aims

local mobileOS = { Android = true, iOS = true }

function Touch.init(flags)
    Touch.forced = flags and flags["--touch"] or false
    -- phones: native Android / iOS, or the web build on a touch screen (index.html passes --mobile)
    if mobileOS[love.system.getOS()] or (flags and flags["--mobile"]) then
        Touch.active = true
        Touch.mobile = true
        Theme.refHeight = 480
        love.window.setDisplaySleepEnabled(false)
    end
end

-- Are the on-screen controls showing?
function Touch.enabled()
    local mode = Settings.get("touchControls")
    if mode == "off" then return false end
    return mode == "on" or Touch.forced or Touch.active
end

-- The mouse presses the on-screen controls (Touch Controls = Always, or `--touch`).
local function mouseIsFinger()
    return Touch.forced or Settings.get("touchControls") == "on"
end

-- A real key or mouse click (not one made up from a touch) hides the controls again in Auto.
function Touch.otherInput()
    if not Touch.mobile then Touch.active = false end
end

----------------------------------------------------------------------------------------------
-- Layout

local function unit()
    local w, h = love.graphics.getDimensions()
    return math.min(w, h) / 6 * Settings.get("touchSize") / 100
end

-- Left Handed (Settings > Controls > Touch Layout) mirrors the whole layout.
local function lefty() return Settings.get("touchLayout") == "left" end
Touch.lefty = lefty

-- Is a point on the stick's half of the screen?
local function onStickSide(x)
    local w = love.graphics.getWidth()
    if lefty() then return x > w * 0.5 end
    return x < w * 0.5
end
Touch.onStickSide = onStickSide

local function status()
    local top = State.top()
    return top and top.touchStatus and top:touchStatus() or {}
end

-- Buttons for the current screen: { id, x, y, r, label, action, kind = "tap" | "hold" | "aim" }
function Touch.buttons()
    local top = State.top()
    local mode = top and top.touchControls
    if not mode or not Touch.enabled() then return {} end
    local w, h = love.graphics.getDimensions()
    local s = unit()
    local pad = s * 0.35
    local list = {}
    local function add(b) list[#list + 1] = b return b end
    if mode == "game" then
        local st = status()
        local r3 = s * 0.34
        if st.sandbox then
            -- sandbox: MENU shows / hides the panel; while it is open it gets the right side
            add { id = "panel", x = w / 2, y = pad + r3, r = r3, label = "MENU", kind = "tap",
                onTap = function() st.sandbox.visible = not st.sandbox.visible end }
            if st.sandbox.visible then return list end
        end
        local r1 = s * 0.62
        local cx, cy = w - pad - r1 - s * 0.15, h - pad - r1
        add { id = "special", x = cx, y = cy, r = r1, label = "SPECIAL", action = "secondary", kind = "aim",
            fireOnRelease = Settings.get("touchAimSpecial") == "drag" and not st.specialHold, cooldown = st.special }
        local r2 = s * 0.46
        add { id = "dash", x = cx - r1 - r2 - s * 0.3, y = cy + r1 - r2, r = r2, label = "DASH", action = "dash",
            kind = "hold", cooldown = st.dash, charges = st.dashCharges }
        if st.manualAttack then
            add { id = "attack", x = cx - r1 * 0.35, y = cy - r1 - r2 - s * 0.3, r = r2, label = "ATTACK", action = "attack", kind = "aim" }
        end
        local x3, y3 = w - pad - r3, h * 0.3
        add { id = "pause", x = x3, y = y3, r = r3, label = "II", action = "pause", kind = "tap" }
        add { id = "bag", x = x3, y = y3 + r3 * 2.6, r = r3, label = "BAG", action = "inventory", kind = "tap" }
        -- the frenzy meter is full: a big button over the special to set it off
        if st.frenzyReady then
            add { id = "frenzy", x = cx - r1 * 0.2, y = cy - r1 - r2 * 2.6 - s * 0.3, r = r2, label = "FRENZY", action = "frenzy", kind = "tap" }
        end
    elseif mode == "inventory" then
        local r = s * 0.42
        local x = w - pad - r
        add { id = "close", x = x, y = h * 0.3, r = r, label = "CLOSE", action = "inventory", kind = "tap" }
        add { id = "turn", x = x, y = h - pad - r * 3.6, r = r, label = "TURN", action = "inventory_rotate", kind = "tap" }
        add { id = "eat", x = x, y = h - pad - r, r = r, label = "EAT", action = "inventory_alt", kind = "tap" }
        add { id = "scrap", x = x, y = h - pad - r * 6.2, r = r, label = "SCRAP", action = "inventory_scrap", kind = "tap" }
    elseif mode == "menu" then
        -- the other tabs of the inventory window (skills, shop): taps are clicks, CLOSE closes
        local r = s * 0.42
        add { id = "close", x = w - pad - r, y = h * 0.3, r = r, label = "CLOSE", action = "inventory", kind = "tap" }
    end
    if lefty() then
        for _, b in ipairs(list) do if b.id ~= "panel" then b.x = w - b.x end end
    end
    return list
end

local function stickHome()
    local w, h = love.graphics.getDimensions()
    local s = unit()
    local x = s * 0.35 + s * 1.05
    if lefty() then x = w - x end
    return x, h - s * 0.35 - s * 1.05, s * 0.8
end

local function buttonAt(x, y)
    for _, b in ipairs(Touch.buttons()) do
        if util.len(x - b.x, y - b.y) <= b.r * 1.25 then return b end
    end
end

----------------------------------------------------------------------------------------------
-- Touch events (ids are LÖVE touch ids, or MOUSE)

-- Synthesised clicks so menus, cards and the bag work with taps.
local function click(x, y)
    pcall(love.mouse.setPosition, x, y)
    local top = State.top()
    State.call("mousepressed", x, y, 1, true, 1)
    -- (a tap that opened a new screen must not also hover whatever lies under it there)
    if State.top() ~= top then return end
    State.call("mousereleased", x, y, 1, true, 1)
    State.call("mousemoved", x, y, 0, 0, true)
end

function Touch.pressed(id, x, y)
    if id ~= MOUSE then Touch.active = true end
    Input.lastDevice = "touch"
    local t = { x0 = x, y0 = y, x = x, y = y, time = love.timer.getTime() }
    Touch.touches[id] = t
    local b = buttonAt(x, y)
    local top = State.top()
    local st = top and top.touchControls == "game" and status() or {}
    if b then
        t.kind, t.button = "button", b
        if b.onTap then b.onTap()
        elseif b.kind == "tap" or b.kind == "hold" or (b.kind == "aim" and not b.fireOnRelease) then
            Input.press(b.action)
        end
    elseif top and top.touchControls == "game" and Touch.enabled() and onStickSide(x)
        and not (st.blocked and st.blocked(x, y)) then
        t.kind = "stick"
        if Settings.get("touchStick") == "fixed" then t.x0, t.y0 = stickHome() end
    else
        t.kind = "ui"
        pcall(love.mouse.setPosition, x, y)
    end
    Touch.refresh()
end

function Touch.moved(id, x, y)
    local t = Touch.touches[id]
    if not t then return end
    local top = State.top()
    if t.kind == "ui" and top and top.pinch then
        -- two fingers on open ground: pinch to zoom (the state's pinch(factor))
        local other
        for oid, o in pairs(Touch.touches) do if oid ~= id and o.kind == "ui" then other = o end end
        if other then
            local before = util.len(t.x - other.x, t.y - other.y)
            local after = util.len(x - other.x, y - other.y)
            if before > 8 and after > 8 then top:pinch(after / before) end
            t.pinching, other.pinching = true, true
            t.x, t.y = x, y
            return
        end
    end
    if t.kind == "ui" then
        if not t.scrolling and math.abs(y - t.y0) > TAP_SLOP and not (State.top() or {}).noTouchScroll then
            t.scrolling = true
        end
        if t.scrolling then
            Touch.dragging = true
            State.call("wheelmoved", 0, (y - t.y) / Theme.u(38))
            Touch.dragging = false
        else
            pcall(love.mouse.setPosition, x, y)
        end
    end
    t.x, t.y = x, y
    Touch.refresh()
end

function Touch.released(id, x, y)
    local t = Touch.touches[id]
    if not t then return end
    Touch.touches[id] = nil
    t.x, t.y = x, y
    if t.kind == "ui" and not t.scrolling and not t.pinching and util.len(x - t.x0, y - t.y0) <= TAP_SLOP * 2 then
        click(x, y)
    elseif t.kind == "button" and t.button.kind == "aim" and t.button.fireOnRelease then
        -- drag-to-aim special: the aim from the drag stays for this frame, then it fires
        Touch.releaseAim = Touch.aimOf(t)
        Input.press(t.button.action)
    end
    Touch.refresh()
end

-- The drag direction off an aim button, or nil while still near its centre.
function Touch.aimOf(t)
    local dx, dy = t.x - t.x0, t.y - t.y0
    local l = util.len(dx, dy)
    if l < t.button.r * AIM_DEAD then return nil end
    return { x = dx / l, y = dy / l }
end

-- Rebuild Input's virtual state from the fingers down right now.
function Touch.refresh()
    local down, move, aim = {}, nil, Touch.releaseAim
    for _, t in pairs(Touch.touches) do
        if t.kind == "stick" then
            local _, _, R = stickHome()
            local dx, dy = t.x - t.x0, t.y - t.y0
            local l = util.len(dx, dy)
            if l > R * 0.12 then
                local k = math.min(1, l / R) / l
                move = { x = dx * k, y = dy * k }
            end
            -- a floating stick drags its base along when the thumb runs past the rim
            if l > R and Settings.get("touchStick") ~= "fixed" then
                t.x0, t.y0 = t.x - dx / l * R, t.y - dy / l * R
            end
        elseif t.kind == "button" then
            local b = t.button
            if b.action and (b.kind == "hold" or (b.kind == "aim" and not b.fireOnRelease)) then down[b.action] = true end
            if b.kind == "aim" then aim = Touch.aimOf(t) or aim end
        end
    end
    Input.virtualDown, Input.virtualMove, Input.virtualAim = down, move, aim
end

function Touch.endFrame()
    if Touch.releaseAim then
        Touch.releaseAim = nil
        Touch.refresh()
    end
end

-- Leaving a screen drops fingers held on its buttons (the next screen has other buttons).
function Touch.reset()
    for id, t in pairs(Touch.touches) do
        if t.kind ~= "ui" then Touch.touches[id] = nil end
    end
    Touch.refresh()
end

----------------------------------------------------------------------------------------------
-- LÖVE callbacks (from main.lua). Return true when the event was handled here.

function Touch.touchpressed(id, x, y) Touch.pressed(id, x, y) end
function Touch.touchmoved(id, x, y) Touch.moved(id, x, y) end
function Touch.touchreleased(id, x, y) Touch.released(id, x, y) end

-- With Touch Controls = Always the left mouse button acts as a finger on the controls.
function Touch.mousepressed(x, y, b)
    if b ~= 1 or not mouseIsFinger() then return false end
    local top = State.top()
    if not (top and top.touchControls) then return false end
    local st = top.touchControls == "game" and status() or {}
    local onUi = st.blocked and st.blocked(x, y)
    if not buttonAt(x, y) and (top.touchControls ~= "game" or onUi or not onStickSide(x)) then return false end
    Touch.pressed(MOUSE, x, y)
    return true
end

function Touch.mousemoved(x, y)
    if Touch.touches[MOUSE] then Touch.moved(MOUSE, x, y) return true end
    return false
end

function Touch.mousereleased(x, y)
    if Touch.touches[MOUSE] then Touch.released(MOUSE, x, y) return true end
    return false
end

----------------------------------------------------------------------------------------------
-- Drawing

local lg = love.graphics

local function disc(x, y, r, alpha, lit)
    lg.setColor(0.05, 0.04, 0.035, 0.55 * alpha)
    lg.circle("fill", x, y, r)
    lg.setLineWidth(math.max(2, r * 0.07))
    if lit then lg.setColor(0.98, 0.74, 0.27, 0.95 * alpha) else lg.setColor(0.86, 0.74, 0.55, 0.6 * alpha) end
    lg.circle("line", x, y, r)
    lg.setLineWidth(1)
end

function Touch.draw()
    if not Touch.enabled() then return end
    local top = State.top()
    if not (top and top.touchControls) then return end
    local alpha = Settings.get("touchOpacity") / 100
    local held = {}
    for _, t in pairs(Touch.touches) do if t.button then held[t.button.id] = t end end

    -- stick: dim at home until a thumb lands, then base + knob under the thumb
    if top.touchControls == "game" then
        local stick
        for _, t in pairs(Touch.touches) do if t.kind == "stick" then stick = t end end
        local hx, hy, R = stickHome()
        local bx, by = hx, hy
        if stick then bx, by = stick.x0, stick.y0 end
        disc(bx, by, R, stick and alpha or alpha * 0.45, false)
        local kx, ky = bx, by
        if stick then
            local dx, dy = stick.x - bx, stick.y - by
            local l = util.len(dx, dy)
            if l > R then dx, dy = dx / l * R, dy / l * R end
            kx, ky = bx + dx, by + dy
        end
        lg.setColor(0.86, 0.74, 0.55, (stick and 0.7 or 0.3) * alpha)
        lg.circle("fill", kx, ky, R * 0.42)
    end

    for _, b in ipairs(Touch.buttons()) do
        local t = held[b.id]
        disc(b.x, b.y, b.r, alpha, t ~= nil)
        -- cooldown: a dark wedge that shrinks as it comes back
        if b.cooldown and b.cooldown > 0 then
            lg.setColor(0, 0, 0, 0.5 * alpha)
            lg.arc("fill", b.x, b.y, b.r * 0.92, -math.pi / 2, -math.pi / 2 + math.pi * 2 * math.min(1, b.cooldown))
        end
        local f = Theme.font(math.max(9, b.r / Theme.u(1) * 0.32), "bold")
        lg.setFont(f)
        lg.setColor(0.96, 0.93, 0.86, 0.9 * alpha)
        lg.printf(b.label, b.x - b.r, b.y - f:getHeight() / 2, b.r * 2, "center")
        if b.charges and b.charges > 1 then
            lg.setFont(Theme.font(math.max(8, b.r / Theme.u(1) * 0.24)))
            lg.printf("x" .. b.charges, b.x - b.r, b.y + b.r * 0.35, b.r * 2, "center")
        end
        -- aim buttons show the drag as a nub at the rim
        if t and b.kind == "aim" then
            local a = Touch.aimOf(t)
            if a then
                lg.setColor(0.98, 0.74, 0.27, 0.9 * alpha)
                lg.circle("fill", b.x + a.x * b.r, b.y + a.y * b.r, b.r * 0.22)
            end
        end
    end
    lg.setColor(1, 1, 1, 1)
end

return Touch
