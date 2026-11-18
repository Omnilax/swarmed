-- Low-resolution world canvas, scaling to the window, and the post-process pass
-- (brightness and colour filters).
local Settings = require("src.core.settings")

local Screen = { VW = 640, VH = 360, scale = 2, ox = 0, oy = 0, zoom = 1 }

-- Camera zoom (scroll wheel, pinch): the world is drawn into a canvas region of VW/zoom x
-- VH/zoom pixels that is stretched over the screen, so pixel art stays crisp at any zoom and
-- zooming out shows more of the arena. The canvases are made big enough for the widest zoom.
Screen.ZOOM_MIN, Screen.ZOOM_MAX = 0.6, 2
Screen.LIGHT_DIV = 2     -- the light map is this many times smaller than the world canvas

local POST = [[
extern number brightness;
extern number cbOn;
extern mat3 cb;
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec4 c = Texel(tex, tc) * color;
    vec3 rgb = c.rgb;
    if (cbOn > 0.5) {
        vec3 sim = cb * rgb;
        vec3 err = rgb - sim;
        rgb = clamp(rgb + vec3(0.0, err.r * 0.7 + err.g, err.r * 0.7 + err.b), 0.0, 1.0);
    }
    return vec4(rgb * brightness, c.a);
}
]]

-- Colour-deficiency simulation matrices (row-major) used to daltonise the image.
local CB = {
    protanopia = { { 0.567, 0.433, 0 }, { 0.558, 0.442, 0 }, { 0, 0.242, 0.758 } },
    deuteranopia = { { 0.625, 0.375, 0 }, { 0.7, 0.3, 0 }, { 0, 0.3, 0.7 } },
    tritanopia = { { 0.95, 0.05, 0 }, { 0, 0.433, 0.567 }, { 0, 0.475, 0.525 } },
}

function Screen.init()
    Screen.post = love.graphics.newShader(POST)
    Screen.setResolution(Settings.get("renderResolution"))
end

-- (Re)creates the world canvases for a "WxH" pixel resolution.
function Screen.setResolution(res)
    local w, h = res:match("(%d+)x(%d+)")
    Screen.baseW, Screen.baseH = tonumber(w), tonumber(h)
    Screen.VW = nil
    Screen.updateScale()
end

-- The canvas keeps the chosen pixel height (or width) but stretches to the window's shape, so
-- wide phones and tall tablets fill the screen instead of getting black bars.
local function fitCanvas()
    if not Screen.baseW then return end
    local w, h = love.graphics.getDimensions()
    local bw, bh = Screen.baseW, Screen.baseH
    local vw, vh = bw, bh
    if w / h > bw / bh then vw = math.min(math.floor(bw * 1.6), math.floor(bh * w / h + 0.5))
    else vh = math.min(math.floor(bh * 1.6), math.floor(bw * h / w + 0.5)) end
    if vw == Screen.VW and vh == Screen.VH then return end
    Screen.VW, Screen.VH = vw, vh
    local cw, ch = math.ceil(vw / Screen.ZOOM_MIN), math.ceil(vh / Screen.ZOOM_MIN / 0.88)
    Screen.canvas = love.graphics.newCanvas(cw, ch)
    -- The light map is soft blobs only, so it is drawn at half resolution and smoothly
    -- stretched over the scene: a quarter of the pixels to fill for the same look.
    Screen.light = love.graphics.newCanvas(math.ceil(cw / Screen.LIGHT_DIV), math.ceil(ch / Screen.LIGHT_DIV))
    Screen.light:setFilter("linear", "linear")
    Screen.lightQuad = love.graphics.newQuad(0, 0, 1, 1, Screen.light:getDimensions())
    Screen.quad = love.graphics.newQuad(0, 0, vw, vh, cw, ch)
    Screen.setZoom(Screen.zoom)
end

function Screen.applyVideoSettings()
    local w, h = Settings.get("windowSize"):match("(%d+)x(%d+)")
    w, h = tonumber(w), tonumber(h)
    local dw, dh = love.window.getDesktopDimensions()
    w, h = math.min(w, dw), math.min(h, dh)
    local os = love.system.getOS()
    love.window.setMode(w, h, {
        fullscreen = Settings.get("fullscreen") or os == "Android" or os == "iOS",   -- phones: hide the status bar
        fullscreentype = Settings.get("fullscreenType"),
        vsync = Settings.get("vsync"),
        resizable = true,
        minwidth = 640,
        minheight = 360,
    })
    Screen.updateScale()
end

function Screen.updateScale()
    fitCanvas()
    local w, h = love.graphics.getDimensions()
    local s = math.min(w / Screen.VW, h / Screen.VH)
    if Settings.get("pixelPerfect") and s >= 2 then s = math.floor(s) end
    Screen.scale = s
    Screen.ox = math.floor((w - Screen.VW * s) / 2)
    Screen.oy = math.floor((h - Screen.VH * s) / 2)
end

-- Size of the visible world region in canvas pixels (viewW x viewH) for a zoom level.
local HEIGHT = { low = 0.9, normal = 1, high = 1.08 }
function Screen.heightK()
    return Screen.worldView and HEIGHT[Settings.get("cameraHeight")] or 1
end

function Screen.setZoom(z)
    z = math.max(Screen.ZOOM_MIN, math.min(Screen.ZOOM_MAX, z or 1))
    Screen.zoom = z
    Screen.viewW = math.min(Screen.canvas:getWidth(), math.floor(Screen.VW / z + 0.5))
    -- Camera Height: Low shows more ground rows squashed (a lower, grazing angle), High fewer
    -- rows stretched (looking down more steeply)
    local hk = Screen.heightK()
    Screen.viewH = math.min(Screen.canvas:getHeight(), math.floor(Screen.VH / z / hk + 0.5))
    Screen.quad:setViewport(0, 0, Screen.viewW, Screen.viewH)
    local lw, lh = Screen.light:getDimensions()
    Screen.lightQuad:setViewport(0, 0, math.min(lw, math.ceil(Screen.viewW / Screen.LIGHT_DIV)),
        math.min(lh, math.ceil(Screen.viewH / Screen.LIGHT_DIV)))
end

-- zoom: the camera's zoom (omit for 1, e.g. the title screen's demo arena)
-- world (optional): true for a run's arena, so Camera Height applies (not menus' demo arenas)
function Screen.beginWorld(bg, zoom, world)
    local wv = world and true or false
    if (zoom or 1) ~= Screen.zoom or not Screen.viewW or wv ~= Screen.worldView or Screen._hk ~= Screen.heightK() then
        Screen.worldView = wv
        Screen.setZoom(zoom or 1)
        Screen._hk = Screen.heightK()
    end
    love.graphics.setCanvas(Screen.canvas)
    -- the canvas is sized for the widest zoom; only the visible part needs clearing
    love.graphics.setScissor(0, 0, Screen.viewW, Screen.viewH)
    love.graphics.clear(bg or { 0.08, 0.07, 0.1, 1 })
    love.graphics.setScissor()
end

function Screen.endWorld()
    love.graphics.setCanvas()
    love.graphics.clear(0, 0, 0, 1)
    local mode = Settings.get("colorblindMode")
    Screen.post:send("brightness", Settings.get("brightness") / 100)
    Screen.post:send("cbOn", CB[mode] and 1 or 0)
    Screen.post:send("cb", CB[mode] or CB.protanopia)
    love.graphics.setShader(Screen.post)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(Screen.canvas, Screen.quad, Screen.ox, Screen.oy, 0,
        Screen.VW * Screen.scale / Screen.viewW, Screen.VH * Screen.scale / Screen.viewH)
    love.graphics.setShader()
end

-- Like endWorld, but shows only a srcW x srcH patch from the middle of the world view, stretched
-- into a box on screen (the character select move preview). Doesn't clear the screen.
function Screen.endWorldInto(x, y, w, h, srcW, srcH)
    love.graphics.setCanvas()
    srcW, srcH = math.min(srcW, Screen.viewW), math.min(srcH, Screen.viewH)
    Screen.boxQuad = Screen.boxQuad or love.graphics.newQuad(0, 0, 1, 1, 1, 1)
    local cw, ch = Screen.canvas:getDimensions()
    Screen.boxQuad:setViewport(math.floor((Screen.viewW - srcW) / 2), math.floor((Screen.viewH - srcH) / 2), srcW, srcH, cw, ch)
    local mode = Settings.get("colorblindMode")
    Screen.post:send("brightness", Settings.get("brightness") / 100)
    Screen.post:send("cbOn", CB[mode] and 1 or 0)
    Screen.post:send("cb", CB[mode] or CB.protanopia)
    love.graphics.setShader(Screen.post)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(Screen.canvas, Screen.boxQuad, x, y, 0, w / srcW, h / srcH)
    love.graphics.setShader()
end

function Screen.toVirtual(wx, wy)
    return (wx - Screen.ox) / Screen.scale, (wy - Screen.oy) / Screen.scale
end

function Screen.toWindow(vx, vy)
    -- Window pixels <-> pixels of the visible (zoomed) world region.
function Screen.toView(wx, wy)
    local vx, vy = Screen.toVirtual(wx, wy)
    return vx * Screen.viewW / Screen.VW, vy * Screen.viewH / Screen.VH
end

function Screen.fromView(vx, vy)
    return Screen.toWindow(vx * Screen.VW / Screen.viewW, vy * Screen.VH / Screen.viewH)
end

return Screen.ox + vx * Screen.scale, Screen.oy + vy * Screen.scale
end

-- Window pixels <-> pixels of the visible (zoomed) world region.
function Screen.toView(wx, wy)
    local vx, vy = Screen.toVirtual(wx, wy)
    return vx * Screen.viewW / Screen.VW, vy * Screen.viewH / Screen.VH
end

function Screen.fromView(vx, vy)
    return Screen.toWindow(vx * Screen.VW / Screen.viewW, vy * Screen.VH / Screen.viewH)
end

return Screen
