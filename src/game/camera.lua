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
        zoom = Camera.lastZoom, targetZoom = Camera.lastZoom }, Camera)
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
    self.tx, self.ty = x, y
end

function Camera:snap()
    self.x, self.y = self.tx, self.ty
end

function Camera:shake(amount)
    self.trauma = math.min(1, self.trauma + amount * Settings.get("screenShake") / 100)
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
    self.zoom = self.zoom + (self.targetZoom - self.zoom) * util.damp(14, dt)
    if math.abs(self.zoom - self.targetZoom) < 0.002 then self.zoom = self.targetZoom end
    self.t = self.t + dt
    self.trauma = math.max(0, self.trauma - dt * 1.8)
    local s = self.trauma * self.trauma * 8
    self.sx = (love.math.noise(self.t * 25, 0) * 2 - 1) * s
    self.sy = (love.math.noise(0, self.t * 25) * 2 - 1) * s
end

-- Top-left of the view in projected space, snapped to whole pixels to avoid shimmer.
function Camera:origin(vw, vh)
    return math.floor(self.x - vw / 2 + self.sx), math.floor(self.y - vh / 2 + self.sy)
end

return Camera
