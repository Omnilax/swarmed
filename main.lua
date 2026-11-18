-- Swarmed entry point: boots core systems and forwards LÖVE callbacks to the state stack.
--
-- Launch options:  love . --dev        force developer mode on
--                  love . --sandbox    jump straight into the sandbox
--                  love . --roster     model viewer (every character walking in place)
--                  love . --anims      attack animation viewer (--shot saves contact sheets)
--                  love . --touch      show the phone touch controls (the mouse presses them)
--                  love . --balance    bot plays runs with several bugs, prints how far each gets
love.graphics.setDefaultFilter("nearest", "nearest")

local Settings = require("src.core.settings")
local Input = require("src.core.input")
local Audio = require("src.core.audio")
local Screen = require("src.core.screen")
local State = require("src.core.state")
local Content = require("src.content")
local Sprites = require("src.gfx.sprites")
local Dev = require("src.debug.dev")
local Touch = require("src.core.touch")
local Records = require("src.game.records")
local Music = require("src.core.music")
local Feedback = require("src.game.feedback")
local Presence = require("src.game.presence")

local selftest

function love.load(args)
    local flags = {}
    for _, a in ipairs(args or {}) do flags[a] = true end

    Settings.load()
    if flags["--dev"] then Settings.set("devMode", true) end
    Screen.applyVideoSettings()
    Screen.init()
    Input.init()
    Touch.init(flags)
    Audio.init()
    Content.load()
    Records.load()
    require("src.game.cosmetics").load()
    Records.regrant()     -- re-apply cosmetic rewards of achievements already earned
    -- test runs must not touch the player's save
    Records.noSave = flags["--selftest"] or flags["--profile"] or false
    -- the player's own bugs from the Bug Creator (tests and the bot never see them)
    local CustomBugs = require("src.game.custombugs")
    if Records.noSave or flags["--balance"] then
        CustomBugs.dir, CustomBugs.noSave = "selftest_custom_bugs", true
    else
        local okC, errC = pcall(CustomBugs.loadAll)
        if not okC then print("[custombugs] " .. tostring(errC)) end
    end
    require("src.game.tutorial").load()
    require("src.game.prefs").noSave = Records.noSave or flags["--balance"] or false
    require("src.game.runsave").noSave = Records.noSave or flags["--balance"] or false
    -- tests and the balance bot see every bug and item (src/game/unlocks.lua); --locked keeps the locks
    require("src.game.unlocks").free = (Records.noSave or flags["--balance"] or false) and not flags["--locked"]
    -- tests and the balance bot run without hints (the polish selftest turns them on itself)
    require("src.game.tutorial").noSave = Records.noSave
    require("src.game.tutorial").off = Records.noSave or flags["--balance"] or false
    Music.init()
    Presence.init(flags)  -- Discord status (src/game/presence.lua)
    Sprites.build(Content.sprites)

    Settings.onChange(function(key)
        local s = Settings.byKey[key]
        if s and s.window then Screen.applyVideoSettings() end
        if key == "pixelPerfect" then Screen.updateScale() end
        if key == "renderResolution" then Screen.setResolution(Settings.get(key)) end
    end)

    if flags["--sandbox"] then
        State.switch(require("src.states.game").new({ mode = "sandbox" }))
    else
        State.switch(require("src.states.menu").new())
    end

    if flags["--anims"] then
        State.switch(require("src.debug.animsheet").new({ shot = flags["--shot"] }))
        return
    end
    if flags["--roster"] then
        State.switch(require("src.debug.roster").new({ shot = flags["--shot"], t = 0.3 }))
        return
    end
    if flags["--makeicon"] then State.switch(require("src.debug.iconmaker").new()) return end
    if flags["--profile"] then require("src.debug.profile").start(flags) return end
    if flags["--balance"] then require("src.debug.balance").start() return end
    if flags["--selftest"] then
        selftest = require("src.debug.selftest")
        selftest.start(flags)
    end
end

function love.update(dt)
    dt = math.min(dt, 1 / 20)
    Dev.update(dt)
    if selftest then selftest.update(dt) end
    State.update(dt)
    Feedback.update(dt)
    Music.update(dt)
    Records.update(dt)
    Presence.update(dt)
    Input.endFrame()
    Touch.endFrame()
end

function love.draw()
    State.draw()
    Records.drawToasts()
    Touch.draw()
    Dev.draw()
    if selftest then selftest.draw() end
end

function love.keypressed(key, scancode, isrepeat)
    Touch.otherInput()
    -- a text editor on top (Bug Creator script editor) gets every key itself
    local top = State.top()
    if top and top.wantsText then
        Input.lastDevice = "keyboard"
        State.call("keypressed", key, scancode, isrepeat)
        return
    end
    if not Input.isCapturing() and Dev.keypressed(key) then return end
    Input.keypressed(key, isrepeat)
    State.call("keypressed", key, scancode, isrepeat)
end

function love.textinput(t)
    if Dev.textinput(t) then return end
    State.call("textinput", t)
end

-- A file dropped on the window (desktop): the Bug Creator imports .lua bug scripts.
function love.filedropped(file)
    local top = State.top()
    if top and type(top.filedropped) == "function" then
        top:filedropped(file)
    elseif top and getmetatable(top) == require("src.states.menu") then
        State.push(require("src.states.creator").new()):filedropped(file)
    end
end

-- Mouse events made up from touches are dropped: src/core/touch.lua turns touches into
-- stick and button input, taps into clicks and drags into scrolling.
function love.mousepressed(x, y, b, istouch)
    if istouch then return end
    if Touch.mousepressed(x, y, b) then return end
    Touch.otherInput()
    Input.mousepressed(b)
    State.call("mousepressed", x, y, b)
end

function love.mousereleased(x, y, b, istouch)
    if istouch or Touch.mousereleased(x, y) then return end
    State.call("mousereleased", x, y, b)
end

function love.mousemoved(x, y, dx, dy, istouch)
    if istouch or Touch.mousemoved(x, y) then return end
    State.call("mousemoved", x, y, dx, dy)
end

function love.touchpressed(id, x, y) Touch.touchpressed(id, x, y) end
function love.touchmoved(id, x, y) Touch.touchmoved(id, x, y) end
function love.touchreleased(id, x, y) Touch.touchreleased(id, x, y) end
function love.wheelmoved(x, y) State.call("wheelmoved", x, y) end

function love.gamepadpressed(j, b) Input.gamepadpressed(j, b) end
function love.joystickadded(j) Input.joystickadded(j) end
function love.joystickremoved(j)
    local wasActive = Input.joystick == j
    Input.joystickremoved(j)
    State.call("joystickremoved", j, wasActive)
end

function love.resize() Screen.updateScale() end

function love.focus(f)
    Audio.setFocused(f)
    Music.setFocused(f)
    State.call("focus", f)
end

function love.visible(v) State.call("visible", v) end

function love.quit()
    Settings.save()
    -- closing mid-run keeps the run to resume (src/game/runsave.lua)
    local game = State.find(require("src.states.game"))
    if game and game.closing then game:closing() end
    Records.quit()
    Presence.quit()
end

-- Default LÖVE loop plus an optional frame cap (used when VSync is off).
function love.run()
    love.load(love.arg.parseGameArguments(arg), arg)
    love.timer.step()
    local dt = 0
    return function()
        local frameStart = love.timer.getTime()
        love.event.pump()
        for name, a, b, c, d, e, f in love.event.poll() do
            if name == "quit" then
                if not love.quit or not love.quit() then return a or 0 end
            end
            love.handlers[name](a, b, c, d, e, f)
        end
        dt = love.timer.step()
        love.update(dt)
        if love.graphics.isActive() then
            love.graphics.origin()
            love.graphics.clear(love.graphics.getBackgroundColor())
            love.draw()
            love.graphics.present()
        end
        local cap = Settings.get("fpsCap")
        if cap and cap > 0 and Settings.get("vsync") == 0 then
            local remaining = 1 / cap - (love.timer.getTime() - frameStart)
            if remaining > 0 then love.timer.sleep(remaining) end
        else
            love.timer.sleep(0.001)
        end
    end
end
