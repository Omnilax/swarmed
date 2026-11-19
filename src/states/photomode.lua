-- Photo Mode (Pause > Photo Mode, setting "Photo Mode"): the run stands still while you move the
-- camera freely, zoom, change the time of day and weather, hide the HUD and save screenshots.
--   WASD / arrows / right-drag: move   wheel or + / -: zoom   T: time of day   W: weather
--   H: show / hide the HUD and hints   F12 or Enter: save a screenshot   Esc: back
local State = require("src.core.state")
local Settings = require("src.core.settings")
local Screen = require("src.core.screen")
local Theme = require("src.ui.theme")
local Content = require("src.content")

local PhotoMode = { photo = true }
PhotoMode.__index = PhotoMode

local TIMES = { "day", "sunset", "evening", "night", "dawn" }

function PhotoMode.new(game)
    local cam = game.world.camera
    local self = setmetatable({ game = game, hud = false, hints = true, zoom = cam:viewZoom(),
        saved = { x = cam.x, y = cam.y, sx = cam.sx, sy = cam.sy, time = Settings.get("timeOfDay") }, msg = nil, msgT = 0 }, PhotoMode)
    cam.sx, cam.sy = 0, 0
    self.ti = 1
    for i, t in ipairs(TIMES) do if t == self.saved.time then self.ti = i end end
    return self
end

function PhotoMode:enter() love.mouse.setVisible(true) end

function PhotoMode:leave()
    local cam = self.game.world.camera
    cam.x, cam.y, cam.photoZoom = self.saved.x, self.saved.y, nil
    Settings.set("timeOfDay", self.saved.time)
end

function PhotoMode:update(dt)
    local cam = self.game.world.camera
    local k = love.keyboard.isDown
    local sp = 220 * dt / self.zoom
    if k("a") or k("left") then cam.x = cam.x - sp end
    if k("d") or k("right") then cam.x = cam.x + sp end
    if k("w") or k("up") then cam.y = cam.y - sp end
    if k("s") or k("down") then cam.y = cam.y + sp end
    cam.photoZoom = self.zoom
    self.msgT = math.max(0, self.msgT - dt)
    -- the world's weather and particles keep moving gently, everything else stands still
    self.game.world.weather:update(dt)
end

function PhotoMode:mousemoved(x, y, dx, dy)
    if love.mouse.isDown(2) or love.mouse.isDown(1) then
        local cam = self.game.world.camera
        local s = Screen.viewW / love.graphics.getWidth()
        cam.x, cam.y = cam.x - dx * s, cam.y - dy * s
    end
end

function PhotoMode:wheelmoved(_, y)
    self.zoom = math.max(0.6, math.min(2.2, self.zoom * 1.1 ^ y))
end

function PhotoMode:say(text)
    self.msg, self.msgT = text, 2
end

function PhotoMode:keypressed(key)
    if key == "escape" or key == "backspace" then State.pop() return end
    if key == "=" or key == "kp+" then self:wheelmoved(0, 1) end
    if key == "-" or key == "kp-" then self:wheelmoved(0, -1) end
    if key == "h" then
        self.hints = not self.hints
        self.hud = not self.hints and false or self.hud
    end
    if key == "u" then self.hud = not self.hud end
    if key == "t" then
        self.ti = self.ti % #TIMES + 1
        Settings.set("timeOfDay", TIMES[self.ti])
        self:say("Time of day: " .. TIMES[self.ti])
    end
    if key == "q" then
        local all = Content.weather:all()
        local w = self.game.world.weather
        local idx = 1
        for i, d in ipairs(all) do if d == w.def then idx = i end end
        local def = all[idx % #all + 1]
        w:set(def)
        w.k = 1
        self:say("Weather: " .. (def.name or def.id))
    end
    if key == "f12" or key == "return" then
        local hints = self.hints
        self.hints = false
        self.shotPending = hints
        PhotoMode.screenshot()
        self:say("Screenshot saved")
    end
end

-- Saves a PNG of the window into the save folder (also the global F12 key, see main.lua).
function PhotoMode.screenshot()
    local name = os.date("swarmed_%Y-%m-%d_%H%M%S") .. ".png"
    love.graphics.captureScreenshot(name)
    return name
end

function PhotoMode:draw()
    local game = self.game
    game.world:flushDecals()
    Screen.beginWorld({ 0.09, 0.08, 0.12, 1 }, self.zoom, true)
    Screen.gradeWorld = game.world
    game.world:draw()
    Screen.endWorld()
    if self.hud then
        Theme.pushZoom(Theme.hudZoom())
        require("src.ui.hud").draw(game, true)
        Theme.popZoom()
    end
    if self.shotPending ~= nil then
        -- the screenshot is taken at the end of this frame; hints come back on the next
        self.hints, self.shotPending = self.shotPending, nil
        return
    end
    local lg = love.graphics
    local w, h = lg.getDimensions()
    if self.hints then
        lg.setFont(Theme.font("label"))
        local txt = "PHOTO MODE   Move: WASD / drag   Zoom: wheel   T: time of day   Q: weather   U: HUD   H: hide hints   F12: save   Esc: back"
        lg.setColor(0, 0, 0, 0.6)
        lg.rectangle("fill", 0, h - Theme.u(34), w, Theme.u(34))
        lg.setColor(1, 0.93, 0.8, 1)
        lg.printf(txt, Theme.u(10), h - Theme.u(26), w - Theme.u(20), "center")
    end
    if self.msgT > 0 then
        lg.setFont(Theme.font("body"))
        lg.setColor(1, 0.9, 0.6, math.min(1, self.msgT))
        lg.printf(self.msg, 0, Theme.u(30), w, "center")
    end
    lg.setColor(1, 1, 1, 1)
end

return PhotoMode
