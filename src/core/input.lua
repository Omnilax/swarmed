-- Action-based input. Game code asks "is move_up down?" or "was dash pressed?" and never
-- looks at raw keys, so rebinding and controllers work everywhere for free.
local util = require("src.core.util")
local Settings = require("src.core.settings")

local Input = {}

-- `rebind = true` actions appear on the Controls tab. Two key slots each (primary, alt).
Input.actions = {
    { id = "move_up", label = "Move Up", keys = { "w", "up" }, pad = { "dpup" }, rebind = true },
    { id = "move_down", label = "Move Down", keys = { "s", "down" }, pad = { "dpdown" }, rebind = true },
    { id = "move_left", label = "Move Left", keys = { "a", "left" }, pad = { "dpleft" }, rebind = true },
    { id = "move_right", label = "Move Right", keys = { "d", "right" }, pad = { "dpright" }, rebind = true },
    { id = "dash", label = "Dash", keys = { "space", "lshift" }, pad = { "a", "leftshoulder" }, rebind = true },
    { id = "attack", label = "Attack (manual)", keys = { "j" }, mouse = { 1 }, pad = { "rightshoulder", "x" }, rebind = true },
    { id = "secondary", label = "Special Attack", keys = { "k" }, mouse = { 2 }, pad = { "b" }, rebind = true },
    { id = "pause", label = "Pause", keys = { "escape", "p" }, pad = { "start" }, rebind = true },
    { id = "inventory", label = "Inventory / Shop", keys = { "tab", "i" }, pad = { "y" }, rebind = true },
    { id = "frenzy", label = "Unleash Frenzy", keys = { "q", "c" }, pad = { "rightstick", "leftstick" }, rebind = true },
    { id = "next_wave", label = "Next Wave / Send Ants Early", keys = { "e", "n" }, pad = { "back" }, rebind = true },
    { id = "inventory_alt", label = "Drop Item (inventory)", keys = { "f" }, pad = { "x" }, rebind = true },
    { id = "inventory_rotate", label = "Turn Item (inventory)", keys = { "r" }, pad = { "leftshoulder" }, rebind = true },
    { id = "inventory_sort", label = "Sort Bag (inventory)", keys = { "t" }, pad = { "leftstick" }, rebind = true },
    { id = "inventory_scrap", label = "Scrap Item (inventory)", keys = { "g" }, pad = { "rightstick" }, rebind = true },
    { id = "choice_reroll", label = "Reroll (item choice)", keys = { "r" }, pad = { "x" }, rebind = true },
    { id = "choice_lock", label = "Lock Card (item choice)", keys = { "l" }, pad = { "rightshoulder" }, rebind = true },
    { id = "choice_ban", label = "Ban Card (item choice)", keys = { "x", "delete" }, pad = { "y" }, rebind = true },
    { id = "quick_restart", label = "Quick Restart (pause / defeat)", keys = { "r" }, pad = { "y" }, rebind = true },
    { id = "ui_favourite", label = "Favourite Bug (bug select)", keys = { "f" }, pad = { "x" }, rebind = true },

    { id = "ui_up", keys = { "up", "w" }, pad = { "dpup" }, repeats = true },
    { id = "ui_down", keys = { "down", "s" }, pad = { "dpdown" }, repeats = true },
    { id = "ui_left", keys = { "left", "a" }, pad = { "dpleft" }, repeats = true },
    { id = "ui_right", keys = { "right", "d" }, pad = { "dpright" }, repeats = true },
    { id = "ui_confirm", keys = { "return", "kpenter", "space" }, pad = { "a" } },
    { id = "ui_back", keys = { "escape", "backspace" }, pad = { "b", "back" } },
    { id = "ui_tab_next", keys = { "e", "tab", "pagedown" }, pad = { "rightshoulder" }, repeats = true },
    { id = "ui_tab_prev", keys = { "q", "pageup" }, pad = { "leftshoulder" }, repeats = true },
    -- bug select: danger level down / up, cycle the sort and the playstyle filter
    { id = "ui_danger_down", keys = { "z", "-", "[" }, pad = {} },
    { id = "ui_danger_up", keys = { "x", "=", "]" }, pad = { "y" } },
    { id = "ui_sort", keys = { "t" }, pad = { "leftstick" } },
    { id = "ui_style", keys = { "g" }, pad = { "rightstick" } },
}

local byId = {}
for _, a in ipairs(Input.actions) do byId[a.id] = a end

local pressed = {}
local keyToActions = {}
local captureFn = nil
Input.lastDevice = "keyboard"
Input.joystick = nil
-- On-screen touch controls (src/core/touch.lua) write here: held actions, the stick, the aim.
Input.virtualDown = {}
Input.virtualMove = nil   -- { x, y } in screen space, length <= 1
Input.virtualAim = nil    -- { x, y } unit vector in screen space

-- Keys for an action, honouring user overrides stored in settings.binds[id] = {primary, alt}.
function Input.getKeys(id)
    local a = byId[id]
    local bind = Settings.get("binds") and Settings.get("binds")[id]
    if a.rebind and bind then
        local keys = {}
        if bind[1] and bind[1] ~= "" then keys[#keys + 1] = bind[1] end
        if bind[2] and bind[2] ~= "" then keys[#keys + 1] = bind[2] end
        return keys
    end
    return a.keys
end

function Input.getBind(id, slot)
    local keys = Input.getKeys(id)
    local bind = Settings.get("binds")[id]
    if bind then return bind[slot] ~= "" and bind[slot] or nil end
    return keys[slot]
end

function Input.setBind(id, slot, key)
    local binds = Settings.get("binds")
    local cur = binds[id] or { Input.getBind(id, 1) or "", Input.getBind(id, 2) or "" }
    cur[slot] = key or ""
    binds[id] = cur
    Input.rebuild()
end

function Input.rebuild()
    keyToActions = {}
    for _, a in ipairs(Input.actions) do
        for _, k in ipairs(Input.getKeys(a.id)) do
            keyToActions[k] = keyToActions[k] or {}
            table.insert(keyToActions[k], a)
        end
    end
end

function Input.init()
    Input.rebuild()
    Settings.onChange(function(key) if key == "binds" then Input.rebuild() end end)
    love.keyboard.setKeyRepeat(true)
    for _, j in ipairs(love.joystick.getJoysticks()) do
        if j:isGamepad() then Input.joystick = j break end
    end
end

-- The next key press goes to fn(key) instead of game actions (used for rebinding).
function Input.captureNext(fn) captureFn = fn end
function Input.isCapturing() return captureFn ~= nil end

function Input.keypressed(key, isrepeat)
    if captureFn then
        local fn = captureFn
        captureFn = nil
        fn(key)
        return
    end
    Input.lastDevice = "keyboard"
    local list = keyToActions[key]
    if not list then return end
    for _, a in ipairs(list) do
        if not isrepeat or a.repeats then pressed[a.id] = true end
    end
end

function Input.mousepressed(button)
    Input.lastDevice = "mouse"
    for _, a in ipairs(Input.actions) do
        if a.mouse and util.contains(a.mouse, button) then pressed[a.id] = true end
    end
end

function Input.gamepadpressed(joystick, button)
    Input.joystick = joystick
    Input.lastDevice = "gamepad"
    for _, a in ipairs(Input.actions) do
        if a.pad and util.contains(a.pad, button) then pressed[a.id] = true end
    end
end

function Input.joystickadded(j)
    if not Input.joystick and j:isGamepad() then Input.joystick = j end
end

function Input.joystickremoved(j)
    if Input.joystick == j then Input.joystick = nil end
end

function Input.pressed(id) return pressed[id] == true end

-- Fire an action as if its key were pressed (touch buttons).
function Input.press(id) pressed[id] = true end

function Input.consume(id) pressed[id] = nil end

function Input.down(id)
    if Input.virtualDown[id] then return true end
    local a = byId[id]
    local keys = Input.getKeys(id)
    if #keys > 0 and love.keyboard.isDown(keys) then return true end
    if a.mouse then
        for _, b in ipairs(a.mouse) do if love.mouse.isDown(b) then return true end end
    end
    local j = Input.joystick
    if j and a.pad then
        for _, b in ipairs(a.pad) do if j:isGamepadDown(b) then return true end end
    end
    return false
end

local function stick(axisX, axisY)
    local j = Input.joystick
    if not j then return 0, 0 end
    local x, y = j:getGamepadAxis(axisX), j:getGamepadAxis(axisY)
    local l = util.len(x, y)
    local dz = Settings.get("deadzone") / 100
    if l < dz then return 0, 0 end
    local s = math.min(1, (l - dz) / (1 - dz)) / l
    return x * s, y * s
end

-- Movement in *screen* space, length <= 1.
function Input.moveVector()
    local x, y = 0, 0
    if Input.down("move_left") then x = x - 1 end
    if Input.down("move_right") then x = x + 1 end
    if Input.down("move_up") then y = y - 1 end
    if Input.down("move_down") then y = y + 1 end
    local vm = Input.virtualMove
    if vm then x, y = x + vm.x, y + vm.y end
    local sx, sy = stick("leftx", "lefty")
    if sx ~= 0 or sy ~= 0 then
        Input.lastDevice = "gamepad"
        x, y = x + sx, y + sy
    end
    local l = util.len(x, y)
    if l > 1 then x, y = x / l, y / l end
    return x, y
end

-- Right stick aim in screen space, or nil.
function Input.aimStick()
    local va = Input.virtualAim
    if va then return va.x, va.y end
    local x, y = stick("rightx", "righty")
    if x == 0 and y == 0 then return nil end
    Input.lastDevice = "gamepad"
    return x, y
end

function Input.vibrate(strength, duration)
    local j = Input.joystick
    if j and Settings.get("vibration") and j:isVibrationSupported() then
        j:setVibration(strength, strength, duration)
    end
end

-- What to press for an action on the device in use right now, for prompts and key caps:
-- { pad = "a" } (a controller button, drawn as an icon by Theme), { mouse = 1 }, or { key = "SPACE" }.
-- Touch has no keys: those prompts name the on-screen button instead (see Tutorial.key).
local PAD_FALLBACK = { ui_confirm = "a", ui_back = "b" }
function Input.glyph(id)
    local a = byId[id]
    if not a then return { key = tostring(id):upper() } end
    if Input.lastDevice == "gamepad" then
        local b = (a.pad and a.pad[1]) or PAD_FALLBACK[id]
        if b then return { pad = b } end
    end
    if a.mouse and id ~= "attack" and Input.lastDevice ~= "gamepad" then return { mouse = a.mouse[1] } end
    local k = Input.getKeys(id)[1]
    return { key = k and Input.keyName(k) or "?" }
end

local KEY_NAMES = { ["return"] = "ENTER", escape = "ESC", lshift = "SHIFT", rshift = "SHIFT", space = "SPACE",
    backspace = "BKSP", lctrl = "CTRL", rctrl = "CTRL", lalt = "ALT", ralt = "ALT", pagedown = "PG DN", pageup = "PG UP",
    kpenter = "ENTER", up = "UP", down = "DOWN", left = "LEFT", right = "RIGHT", tab = "TAB" }
function Input.keyName(k) return KEY_NAMES[k] or k:upper() end

function Input.endFrame()
    for k in pairs(pressed) do pressed[k] = nil end
end

return Input
