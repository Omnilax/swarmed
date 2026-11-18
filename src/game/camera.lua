-- Follows a point in projected screen space, with smoothing, lookahead and trauma shake.
local Settings = require("src.core.settings")
local util = require("src.core.util")

local Camera = {}
Camera.__index = Camera

-- The zoom the player last chose, kept from run to run.
Camera.lastZoom = 1
local ZOOM_MIN, ZOOM_MAX, ZOOM_STEP = 0.6, 2, 1.12

function Camera.new(x, y)
    return setmetatable({ x = x or 0, y = y or 0, tx = x or 0, ty = y or 0, trauma = 0, t = 0, sx = 0, sy = 0,
        zoom = Camera.lastZoom, targetZoom = Camera.lastZoom, kick = 0,
        auto = 1, autoTarget = 1, sizeMul = 1, frameX = 0, frameY = 0, shakeX = 0, shakeY = 0 }, Camera)
end

-- Back to the plain 1x zoom (keyboard 0).
function Camera:resetZoom()
    self.targetZoom = 1
    Camera.lastZoom = 1
end

-- Smart Auto-Zoom (setting Off / Subtle / Full): the world sets how crowded it is (0..1) and
-- whether a boss is about; the camera eases out for them and back in when it's calm.
function Camera:setCrowd(crowd, boss)
    local mode = Settings.get("autoZoom")
    if mode == "off" then self.autoTarget = 1 return end
    local depth = mode == "full" and 0.3 or 0.15
    self.autoTarget = 1 - depth * math.min(1, crowd) - (boss and depth * 0.5 or 0)
end

-- Boss Intro Camera: glance at (x, y) for `time` seconds, then come back.
function Camera:glance(x, y, time)
    self.focus = { x = x, y = y, t = 0, life = time or 1.6 }
end

-- Scroll-wheel notches (positive zooms in) or a pinch's scale factor (`factor`).
function Camera:zoomBy(notches, factor)
    local z = self.targetZoom * (factor or ZOOM_STEP ^ notches)
    -- snap back to exactly 1 when passing it, so the default pixel scale is easy to return to
    if not factor and (self.targetZoom - 1) * (z - 1) < 0 then z = 1 end
    self.targetZoom = util.clamp(z, ZOOM_MIN, ZOOM_MAX)
    Camera.lastZoom = self.targetZoom
end

function Camera:follow(x, y, lookX, lookY)
    if Settings.get("cameraLookahead") and lookX then
        x, y = x + lookX * 24, y + lookY * 14
    end
    -- Horde Framing: lean towards the side the ants are coming from
    x, y = x + self.frameX, y + self.frameY
    local f = self.focus
    if f then
        local k = math.sin(math.min(1, f.t / f.life) * math.pi)
        k = math.min(1, k * 1.6) * 0.75
        x, y = x + (f.x - x) * k, y + (f.y - y) * k
    end
    self.tx, self.ty = x, y
end

function Camera:snap()
    self.x, self.y = self.tx, self.ty
end

-- dx, dy (optional): the direction of the hit; with Shake Style "Directional" the shake runs
-- along it and is shorter.
function Camera:shake(amount, dx, dy)
    self.trauma = math.min(1, self.trauma + amount * Settings.get("screenShake") / 100)
    if dx and Settings.get("shakeStyle") == "directional" then
        local l = math.sqrt(dx * dx + dy * dy)
        if l > 0 then self.shakeX, self.shakeY = dx / l, dy / l * 0.5 end
    else
        self.shakeX, self.shakeY = 0, 0
    end
end

-- A quick zoom-in that springs back (big multi-kills, a queen falling, the frenzy move).
-- Setting "Camera Punch" scales it on its own, apart from Screen Shake.
function Camera:punch(amount)
    local k = Settings.get("cameraPunch") / 100
    if k <= 0 then return end
    self.kick = math.min(0.3, math.max(self.kick, amount * k))
end

-- The zoom to draw with this frame: the chosen zoom plus any punch, the auto-zoom and the
-- bug-size zoom. (Photo mode sets photoZoom directly.)
function Camera:viewZoom()
    if self.photoZoom then return self.photoZoom end
    local z = self.zoom * (1 + self.kick) * self.auto * self.sizeMul
    if self.focus then z = z * (1 + 0.12 * math.sin(math.min(1, self.focus.t / self.focus.life) * math.pi)) end
    return math.max(0.6, math.min(2.2, z))
end

function Camera:update(dt)
    local smooth = Settings.get("cameraSmoothing") / 100
    if smooth <= 0 then
        self:snap()
    else
        local k = util.damp(4 + (1 - smooth) * 20, dt)
        self.x = self.x + (self.tx - self.x) * k
        self.y = self.y + (self.ty - self.y) * k
    end
    self.zoom = self.zoom + (self.targetZoom - self.zoom) * util.damp(Settings.get("smoothZoom") and 6 or 14, dt)
    self.auto = self.auto + (self.autoTarget - self.auto) * util.damp(1.2, dt)
    if self.focus then
        self.focus.t = self.focus.t + dt
        if self.focus.t >= self.focus.life then self.focus = nil end
    end
    if math.abs(self.zoom - self.targetZoom) < 0.002 then self.zoom = self.targetZoom end
    self.kick = math.max(0, self.kick - dt * (0.6 + self.kick * 6))
    self.t = self.t + dt
    self.trauma = math.max(0, self.trauma - dt * 1.8)
    local s = self.trauma * self.trauma * 8
    if self.shakeX ~= 0 or self.shakeY ~= 0 then
        -- directional: a quick back-and-forth along the hit, fading faster
        self.trauma = math.max(0, self.trauma - dt * 1.5)
        local w = (love.math.noise(self.t * 30, 3) * 2 - 1) * s * 1.3
        self.sx, self.sy = self.shakeX * w, self.shakeY * w
    else
        self.sx = (love.math.noise(self.t * 25, 0) * 2 - 1) * s
        self.sy = (love.math.noise(0, self.t * 25) * 2 - 1) * s
    end
end

-- Top-left of the view in projected space, snapped to whole pixels to avoid shimmer.
function Camera:origin(vw, vh)
    return math.floor(self.x - vw / 2 + self.sx), math.floor(self.y - vh / 2 + self.sy)
end

return Camera
