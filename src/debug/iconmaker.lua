-- Game icon maker:  love . --makeicon
-- Paints the Swarmed icon with the game's own models (a bombardier beetle squaring up to a ring of
-- worker ants on a patch of dirt) and saves icon_128.png (the painting at 1 pixel per art pixel)
-- and icon_32.png (a close-up for small sizes) in the save folder, then quits.
-- tools/make_icons.py scales them to every size and builds the .ico / .icns from them.
local Sprites = require("src.gfx.sprites")

local IconMaker = { t = 0 }
IconMaker.__index = IconMaker

function IconMaker.new() return setmetatable({ t = 0 }, IconMaker) end

local function hex(h, a)
    return tonumber(h:sub(2, 3), 16) / 255, tonumber(h:sub(4, 5), 16) / 255, tonumber(h:sub(6, 7), 16) / 255, a or 1
end

-- Rounded tile of sunlit dirt with a darker rim, a little grass and pebbles.
local function tile(S, r)
    local lg = love.graphics
    lg.setColor(hex("#2a1d14"))
    lg.rectangle("fill", 0, 0, S, S, r, r)
    local rng = love.math.newRandomGenerator(7)
    -- radial light: warm centre fading to a deep earthy rim
    for i = 24, 1, -1 do
        local k = i / 24
        local c1 = { 0.30, 0.20, 0.12 }
        local c2 = { 0.90, 0.76, 0.52 }
        local m = (1 - k) ^ 0.8
        lg.setColor(c1[1] + (c2[1] - c1[1]) * m, c1[2] + (c2[2] - c1[2]) * m, c1[3] + (c2[3] - c1[3]) * m)
        local rr = S * 0.5 * (0.2 + 0.95 * k)
        lg.circle("fill", S * 0.47, S * 0.45, rr)
    end
    -- grit and pebbles
    for _ = 1, S * 2 do
        local x, y = rng:random() * S, rng:random() * S
        local v = rng:random() * 0.12
        lg.setColor(0.55 + v, 0.42 + v, 0.27 + v * 0.6, 0.45)
        lg.rectangle("fill", math.floor(x), math.floor(y), 1, 1)
    end
    for _ = 1, math.floor(S / 16) do
        local x, y = rng:random() * S, rng:random() * S
        lg.setColor(hex("#3a2c22", 0.8))
        lg.ellipse("fill", x, y + 1, 2.5, 1.6)
        lg.setColor(hex("#9a8670"))
        lg.ellipse("fill", x, y, 2, 1.3)
    end
    -- grass tufts round the edge
    for _ = 1, math.floor(S / 3) do
        local a = rng:random() * math.pi * 2
        local d = S * (0.44 + rng:random() * 0.08)
        local x, y = S / 2 + math.cos(a) * d, S / 2 + math.sin(a) * d
        local g = rng:random() * 0.2
        lg.setColor(0.30 + g, 0.52 + g, 0.20, 1)
        lg.line(x, y, x + (rng:random() - 0.5) * 3, y - 3 - rng:random() * 4)
    end
end

local function mask(S, r)
    return function() love.graphics.rectangle("fill", 0, 0, S, S, r, r) end
end

local function paint(S, close)
    local lg = love.graphics
    local canvas = lg.newCanvas(S, S)
    canvas:setFilter("nearest", "nearest")
    lg.setCanvas({ canvas, stencil = true })
    lg.clear(0, 0, 0, 0)
    local r = math.floor(S * 0.2)
    lg.stencil(mask(S, r), "replace", 1)
    lg.setStencilTest("greater", 0)
    tile(S, r)
    local ant = Sprites.get("worker_ant")
    local Content = require("src.content")
    local beetle = Content.characters:require("bombardier_beetle").model
    local cx, cy = S * 0.5, S * (close and 0.62 or 0.56)
    if not close then
        -- ants closing in from every side, facing the beetle
        local ring = {}
        for i = 1, 11 do
            local a = (i / 11) * math.pi * 2 + 0.3
            local d = 0.33 + (i % 3) * 0.035
            ring[i] = { math.cos(a) * d, math.sin(a) * d * 0.85 - 0.04 }
        end
        for i, p in ipairs(ring) do
            local x, y = cx + p[1] * S, cy + p[2] * S
            local a = math.atan2(cy - y, cx - x)
            lg.setColor(0, 0, 0, 0.3)
            lg.ellipse("fill", x, y + 2, 5, 2.5)
            lg.setColor(1, 1, 1)
            if ant then Sprites.draw(ant, i % 4 + 1, x, y, a, false, 1, 1) end
        end
    end
    local sc = close and 1 or 3
    lg.setColor(0, 0, 0, 0.35)
    lg.ellipse("fill", cx, cy + 3 * sc, 9 * sc, 4 * sc)
    lg.setColor(1, 1, 1)
    Sprites.drawModel(beetle, 1, cx, cy, -math.pi * 0.5 - 0.35, false, sc, sc, 1, { phase = 0.25, bob = 0 })
    lg.setStencilTest()
    -- a thin light rim so the tile reads on dark taskbars
    lg.setColor(1, 0.92, 0.7, 0.25)
    lg.setLineWidth(1)
    lg.rectangle("line", 0.5, 0.5, S - 1, S - 1, r, r)
    lg.setCanvas()
    return canvas
end

function IconMaker:update(dt)
    self.t = self.t + dt
    if self.t > 0.2 and not self.done then
        self.done = true
        love.filesystem.createDirectory("icon")
        paint(128, false):newImageData():encode("png", "icon/icon_128.png")
        paint(32, true):newImageData():encode("png", "icon/icon_32.png")
        print("[makeicon] saved to " .. love.filesystem.getSaveDirectory() .. "/icon")
        love.event.quit()
    end
end

function IconMaker:draw()
    love.graphics.clear(0.1, 0.1, 0.1)
end

return IconMaker
