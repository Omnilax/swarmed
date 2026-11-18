-- Builds one texture atlas from every sprite definition so the whole horde draws from a single
-- image. LÖVE batches consecutive draws of the same texture automatically, so hundreds of
-- enemies cost only a handful of draw calls.
--
-- For each frame we also bake a white silhouette (hit flash) so flashing needs no shader. The
-- player's own sprites skip that (they are big and there is only one player): their flash is
-- drawn with a small silhouette shader instead (Sprites.flashShader).
-- Sprites are drawn facing right and pre-rotated into DIRECTIONS angles at load, so bugs can
-- turn freely while staying crisp, chunky pixel art (no blurry runtime rotation).
local util = require("src.core.util")

local Sprites = { byId = {}, DIRECTIONS = 32 }
local ATLAS_W = 2048
local PAD = 1

-- Nearest-neighbour rotation into a square image big enough for any angle.
local function rotate(src, angle)
    local w, h = src:getWidth(), src:getHeight()
    local d = math.ceil(math.sqrt(w * w + h * h)) + 1
    if d % 2 == 0 then d = d + 1 end
    local out = love.image.newImageData(d, d)
    local c, s = math.cos(angle), math.sin(angle)
    local dc, scx, scy = (d - 1) / 2, (w - 1) / 2, (h - 1) / 2
    local floor = math.floor
    for y = 0, d - 1 do
        for x = 0, d - 1 do
            local dx, dy = x - dc, y - dc
            local sx = floor(dx * c + dy * s + scx + 0.5)
            local sy = floor(-dx * s + dy * c + scy + 0.5)
            if sx >= 0 and sx < w and sy >= 0 and sy < h then
                out:setPixel(x, y, src:getPixel(sx, sy))
            end
        end
    end
    return out
end

-- Isometric view: turn the sprite to `angle` on the ground (world radians), then project it
-- like the floor (45 degree turn, height halved). Used for parts of 3D-stacked bugs.
local ISO_SCALE = 1.25
local function rotateIso(src, angle)
    local w, h = src:getWidth(), src:getHeight()
    local d = math.ceil(math.sqrt(w * w + h * h) * ISO_SCALE * 0.75) + 1
    if d % 2 == 0 then d = d + 1 end
    local dh = math.ceil(d / 2) + 2
    if dh % 2 == 0 then dh = dh + 1 end
    local out = love.image.newImageData(d, dh)
    local b = angle + math.pi / 4
    local c, s = math.cos(b), math.sin(b)
    local dcx, dcy, scx, scy = (d - 1) / 2, (dh - 1) / 2, (w - 1) / 2, (h - 1) / 2
    local k = ISO_SCALE * 0.7071
    local floor = math.floor
    for y = 0, dh - 1 do
        for x = 0, d - 1 do
            local qx, qy = (x - dcx) / k, (y - dcy) * 2 / k
            local sx = floor(qx * c + qy * s + scx + 0.5)
            local sy = floor(-qx * s + qy * c + scy + 0.5)
            if sx >= 0 and sx < w and sy >= 0 and sy < h then
                out:setPixel(x, y, src:getPixel(sx, sy))
            end
        end
    end
    return out
end

local function rasterize(def, rows)
    local h = #rows
    local w = 0
    for _, r in ipairs(rows) do w = math.max(w, #r) end
    local img = love.image.newImageData(w, h)
    local flash = love.image.newImageData(w, h)
    local pal = {}
    for k, v in pairs(def.palette) do pal[k] = util.hex(v) end
    for y = 1, h do
        local row = rows[y]
        for x = 1, #row do
            local ch = row:sub(x, x)
            if ch ~= "." and ch ~= " " then
                local c = pal[ch]
                if not c then error(("sprite '%s': unknown palette char '%s'"):format(def.id, ch)) end
                img:setPixel(x - 1, y - 1, c[1], c[2], c[3], c[4])
                flash:setPixel(x - 1, y - 1, 1, 1, 1, 1)
            end
        end
    end
    return img, flash
end

local function ellipse(w, h, alpha)
    local img = love.image.newImageData(w, h)
    local cx, cy = (w - 1) / 2, (h - 1) / 2
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local dx, dy = (x - cx) / (w / 2), (y - cy) / (h / 2)
            if dx * dx + dy * dy <= 1 then img:setPixel(x, y, 0, 0, 0, alpha) end
        end
    end
    return img
end

-- registry: Content.sprites. Builds the atlas and quads.
-- Sprites only the player uses: flat character sprites and model parts. Enemies never use them.
local function playerOnlySprites()
    local ok, Content = pcall(require, "src.content")
    local set = {}
    if not ok or not Content.characters then return set end
    for _, c in ipairs(Content.characters:all()) do
        if c.sprite then set[c.sprite] = true end
        local m = c.model
        if m then
            for _, k in ipairs({ "legs", "body", "head", "segment", "segment2", "tail" }) do
                if type(m[k]) == "string" then set[m[k]] = true end
            end
        end
    end
    if Content.enemies then
        for _, e in ipairs(Content.enemies:all()) do if e.sprite then set[e.sprite] = nil end end
    end
    return set
end

-- One sprite definition -> its entry, with every frame (and turn) as a piece from addPiece.
local function makeEntry(def, addPiece, playerOnly)
    local dirs = def.rotate == false and 1 or def.directions or Sprites.DIRECTIONS
    -- Rigged legs are drawn as lines from the rig (drawLegs), never from these pixels, so
    -- only one unturned frame is kept. Turning all of them cost a third of the atlas.
    local frameDefs = def.frames
    if def.rig then dirs, frameDefs = 1, { def.frames[1] } end
    local entry = { id = def.id, frames = {}, flash = (not playerOnly[def.id]) and {} or nil, fps = def.fps or 8, dirs = dirs }
    for dir = 1, dirs do
        entry.frames[dir] = {}
        if entry.flash then entry.flash[dir] = {} end
    end
    for i, rows in ipairs(frameDefs) do
        local img, fl = rasterize(def, rows)
        entry.w, entry.h = img:getWidth(), img:getHeight()
        for dir = 1, dirs do
            local a = (dir - 1) / dirs * math.pi * 2
            local ri, rf = img, fl
            if def.iso then ri, rf = rotateIso(img, a), rotateIso(fl, a)
            elseif dirs > 1 then ri, rf = rotate(img, a), rotate(fl, a) end
            entry.frames[dir][i] = addPiece(ri)
            if entry.flash then entry.flash[dir][i] = addPiece(rf) end
            entry.size, entry.sizeH = ri:getWidth(), ri:getHeight()
        end
    end
    -- Sprites are drawn centred on their position (bugs lie flat on the ground).
    entry.iso = def.iso
    entry.rig, entry.palette = def.rig, def.palette
    if dirs > 1 then
        entry.ox, entry.oy = (entry.size - 1) / 2, (entry.sizeH - 1) / 2
    else
        entry.ox, entry.oy = def.anchorX or math.floor(entry.w / 2), def.anchorY or math.floor(entry.h / 2)
    end
    return entry
end

function Sprites.build(registry)
    local t0 = love.timer.getTime()
    local playerOnly = playerOnlySprites()
    local pieces = {}
    local function addPiece(data) pieces[#pieces + 1] = { data = data } return pieces[#pieces] end

    for _, def in ipairs(registry:all()) do
        if not def.ownImage then Sprites.byId[def.id] = makeEntry(def, addPiece, playerOnly) end
    end

    local pixelData = love.image.newImageData(2, 2)
    pixelData:mapPixel(function() return 1, 1, 1, 1 end)
    local pixel = addPiece(pixelData)
    local shadows = {}
    for _, size in ipairs({ 6, 10, 14, 18, 24, 32, 48 }) do
        shadows[#shadows + 1] = { size = size, piece = addPiece(ellipse(size, math.max(3, math.floor(size / 2.4)), 0.32)) }
    end
    local glowData = love.image.newImageData(16, 16)
    glowData:mapPixel(function(x, y)
        local dx, dy = (x - 7.5) / 8, (y - 7.5) / 8
        local d = math.sqrt(dx * dx + dy * dy)
        local a = math.max(0, 1 - d)
        return 1, 1, 1, a * a
    end)
    local glowPiece = addPiece(glowData)
    local ring = love.image.newImageData(20, 9)
    local ringOuter = ellipse(20, 9, 1)
    local ringInner = ellipse(16, 7, 1)
    ringOuter:mapPixel(function(x, y, r, g, b, a)
        local ix, iy = x - 2, y - 1
        if ix >= 0 and ix < 16 and iy >= 0 and iy < 7 then
            local _, _, _, ia = ringInner:getPixel(ix, iy)
            if ia > 0 then return 0, 0, 0, 0 end
        end
        if a > 0 then return 1, 1, 1, 1 end
        return 0, 0, 0, 0
    end)
    ring:paste(ringOuter, 0, 0, 0, 0, 20, 9)
    local ringPiece = addPiece(ring)

    -- Splat blobs: lumpy wet pools already squashed onto the iso floor, grey-shaded (darker
    -- rim, lighter core, a glossy fleck) so a single tinted draw paints a whole puddle.
    local blobPieces = {}
    local rng = love.math.newRandomGenerator(7)
    for b = 1, 8 do
        local w, h = 18, 10
        local img = love.image.newImageData(w, h)
        local lumps = {}
        for l = 1, 4 do
            lumps[l] = { (rng:random() - 0.5) * 7, (rng:random() - 0.5) * 3.5, 2.5 + rng:random() * 3 }
        end
        for y = 0, h - 1 do
            for x = 0, w - 1 do
                local best = 0
                for _, l in ipairs(lumps) do
                    local dx, dy = (x - (w - 1) / 2 - l[1]) / l[3], (y - (h - 1) / 2 - l[2]) / (l[3] * 0.5)
                    best = math.max(best, 1 - (dx * dx + dy * dy))
                end
                if best > 0.08 * rng:random() then
                    local v = best > 0.45 and 0.92 or 0.62
                    img:setPixel(x, y, v, v, v, best > 0.45 and 0.8 or 0.65)
                end
            end
        end
        local hx, hy = math.floor(w / 2 - 2), math.floor(h / 2 - 1)
        img:setPixel(hx, hy, 1, 1, 1, 0.9)
        img:setPixel(hx + 1, hy, 1, 1, 1, 0.7)
        blobPieces[b] = addPiece(img)
    end

    -- Shelf packing, tallest first.
    local order = {}
    for i, p in ipairs(pieces) do order[i] = p end
    table.sort(order, function(a, b) return a.data:getHeight() > b.data:getHeight() end)
    -- Widen the atlas until it is no taller than the GPU allows (phones and browsers often
    -- cap textures at 4096 or 8192 pixels a side).
    local maxSide = love.graphics.getSystemLimits().texturesize
    local atlasW, atlasH = ATLAS_W, 0
    while true do
        local x, y, shelfH = PAD, PAD, 0
        for _, p in ipairs(order) do
            local w, h = p.data:getWidth(), p.data:getHeight()
            if x + w + PAD > atlasW then
                x, y = PAD, y + shelfH + PAD
                shelfH = 0
            end
            p.x, p.y = x, y
            x = x + w + PAD
            shelfH = math.max(shelfH, h)
        end
        atlasH = y + shelfH + PAD
        if atlasH <= maxSide or atlasW >= maxSide then break end
        atlasW = math.min(maxSide, atlasW * 2)
    end
    local atlasData = love.image.newImageData(atlasW, atlasH)
    for _, p in ipairs(pieces) do
        atlasData:paste(p.data, p.x, p.y, 0, 0, p.data:getWidth(), p.data:getHeight())
    end
    Sprites.atlas = love.graphics.newImage(atlasData)
    Sprites.flashShader = love.graphics.newShader([[
        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) { return vec4(color.rgb, color.a * Texel(tex, uv).a); }
    ]])
    Sprites.atlas:setFilter("nearest", "nearest")

    local aw, ah = atlasW, atlasH
    local function quad(p) return love.graphics.newQuad(p.x, p.y, p.data:getWidth(), p.data:getHeight(), aw, ah) end
    for _, entry in pairs(Sprites.byId) do
        -- (custom bug art built earlier has its own image and quads already)
        if not entry.image then for dir = 1, entry.dirs do
            for i = 1, #entry.frames[dir] do
                entry.frames[dir][i] = quad(entry.frames[dir][i])
                if entry.flash then entry.flash[dir][i] = quad(entry.flash[dir][i]) end
            end
        end end
    end
    Sprites.glow = quad(glowPiece)

    -- Smooth light falloff for the lighting pass (separate, linearly filtered texture).
    local lightData = love.image.newImageData(128, 128)
    lightData:mapPixel(function(x, y)
        local dx, dy = (x - 63.5) / 64, (y - 63.5) / 64
        local a = math.max(0, 1 - math.sqrt(dx * dx + dy * dy))
        return 1, 1, 1, a * a * (3 - 2 * a)
    end)
    Sprites.light = love.graphics.newImage(lightData)
    Sprites.light:setFilter("linear", "linear")
    Sprites.pixel = love.graphics.newQuad(pixel.x, pixel.y, 1, 1, aw, ah)
    Sprites.shadows = {}
    for _, s in ipairs(shadows) do
        Sprites.shadows[#Sprites.shadows + 1] = { size = s.size, quad = quad(s.piece), w = s.piece.data:getWidth(), h = s.piece.data:getHeight() }
    end
    Sprites.ring = quad(ringPiece)
    Sprites.blobs = {}
    for i, p in ipairs(blobPieces) do Sprites.blobs[i] = quad(p) end
    print(("[sprites] atlas %dx%d, %d pieces, built in %.0f ms"):format(atlasW, atlasH, #pieces, (love.timer.getTime() - t0) * 1000))
end

-- Sprites added after the atlas was built (custom bugs from the Bug Creator): they get a small
-- image of their own instead of a rebuilt atlas. Draw code uses `sprite.image or Sprites.atlas`.
function Sprites.buildSet(defs)
    local pieces = {}
    local function addPiece(data) pieces[#pieces + 1] = { data = data } return pieces[#pieces] end
    local entries = {}
    local noFlash = setmetatable({}, { __index = function() return true end })   -- flashed with the shader
    for _, def in ipairs(defs) do entries[#entries + 1] = makeEntry(def, addPiece, noFlash) end
    local order = {}
    for i, p in ipairs(pieces) do order[i] = p end
    table.sort(order, function(a, b) return a.data:getHeight() > b.data:getHeight() end)
    local W = 512
    local x, y, shelfH = PAD, PAD, 0
    for _, p in ipairs(order) do
        local w, h = p.data:getWidth(), p.data:getHeight()
        if x + w + PAD > W then x, y, shelfH = PAD, y + shelfH + PAD, 0 end
        p.x, p.y = x, y
        x = x + w + PAD
        shelfH = math.max(shelfH, h)
    end
    local H = math.max(1, y + shelfH + PAD)
    local data = love.image.newImageData(W, H)
    for _, p in ipairs(pieces) do data:paste(p.data, p.x, p.y, 0, 0, p.data:getWidth(), p.data:getHeight()) end
    local img = love.graphics.newImage(data)
    img:setFilter("nearest", "nearest")
    for _, entry in ipairs(entries) do
        entry.image = img
        for dir = 1, entry.dirs do
            for i = 1, #entry.frames[dir] do
                local p = entry.frames[dir][i]
                entry.frames[dir][i] = love.graphics.newQuad(p.x, p.y, p.data:getWidth(), p.data:getHeight(), W, H)
            end
        end
        entry.flash = nil
        Sprites.byId[entry.id] = entry
    end
    return entries
end

function Sprites.get(id)
    local s = Sprites.byId[id]
    if not s then error("unknown sprite '" .. tostring(id) .. "'") end
    return s
end

-- Pick the smallest baked shadow at least `diameter` wide.
function Sprites.shadowFor(diameter)
    for _, s in ipairs(Sprites.shadows) do
        if s.size >= diameter then return s end
    end
    return Sprites.shadows[#Sprites.shadows]
end

-- Draw a sprite centred at (x, y) in projected space, turned to `angle` (screen radians).
-- sx/sy scale it (squash and stretch); sy defaults to sx.
function Sprites.draw(sprite, frame, x, y, angle, flash, sx, sy)
    local dirs = sprite.dirs
    local dir = 1
    if dirs > 1 then dir = math.floor((angle or 0) / (math.pi * 2) * dirs + 0.5) % dirs + 1 end
    local quads = (flash and sprite.flash or sprite.frames)[dir]
    local q = quads[((frame - 1) % #quads) + 1]
    sx = sx or 1
    if flash and not sprite.flash then return Sprites.drawFlash(q, math.floor(x), math.floor(y), sx, sy or sx, sprite.ox, sprite.oy, sprite.image) end
    love.graphics.draw(sprite.image or Sprites.atlas, q, math.floor(x), math.floor(y), 0, sx, sy or sx, sprite.ox, sprite.oy)
end

-- White silhouette of a quad from a sprite without baked flash frames.
function Sprites.drawFlash(q, x, y, sx, sy, ox, oy, image)
    local lg = love.graphics
    local prev = lg.getShader()
    lg.setShader(Sprites.flashShader)
    lg.draw(image or Sprites.atlas, q, x, y, 0, sx, sy, ox, oy)
    lg.setShader(prev)
end

-- Model-space point -> screen offset. Model space is the top-down sprite's pixel grid (u forward,
-- v to the right side), turned to `angle` on the ground and projected like the iso parts are.
local ISO_K = ISO_SCALE * 0.7071
-- (rotateIso bakes the body turned by angle + 45 degrees, so points get the same extra turn.)
local R45 = 0.70710678
local function project(u, v, z, c, s, sx, sy)
    local qx, qy = u * c - v * s, u * s + v * c
    qx, qy = (qx - qy) * R45, (qx + qy) * R45
    return qx * ISO_K * sx, (qy * ISO_K / 2) * sy - z * sy
end

-- Stacked body: one layer per screen pixel of height, darker and a little narrower lower down,
-- so it reads as a raised, rounded shell.
local function drawStack(body, q, qf, x, y, h, lift, sx, sy, tr, tg, tb, alpha)
    local lg = love.graphics
    local steps = math.max(1, math.floor(h * sy + 0.5))
    local img = body.image or Sprites.atlas
    for i = 0, steps - 1 do
        local t = (i + 1) / steps
        local v = 0.2 + 0.45 * t
        local k = 0.8 + 0.2 * math.sqrt(t)
        lg.setColor(v * tr, v * 0.96 * tg, v * 0.92 * tb, alpha)
        lg.draw(img, q, x, y - lift * sy - i, 0, sx * k, sy * k, body.ox, body.oy)
    end
    lg.setColor(tr, tg, tb, alpha)
    if qf == true then return Sprites.drawFlash(q, x, y - lift * sy - steps, sx, sy, body.ox, body.oy, body.image) end
    lg.draw(img, qf or q, x, y - lift * sy - steps, 0, sx, sy, body.ox, body.oy)
end

local function hexColor(h)
    local r, g, b = tonumber(h:sub(2, 3), 16) / 255, tonumber(h:sub(4, 5), 16) / 255, tonumber(h:sub(6, 7), 16) / 255
    return { r, g, b }
end

-- Jointed 3D legs from a rig (joint points of each leg on one side, mirrored for the other).
-- Each foot stays planted for 60% of the step cycle while the body moves over it, then lifts,
-- swings forward and plants again; neighbouring legs alternate (tripod gait). The hip sits
-- under the body, the knee rises above it and the foot touches the ground.
-- part: "far" (legs on the far side, drawn before the body) or "near" (after it).
local legPts = {}
local spread = 1.15
local function drawLegs(rig, phase, x, y, angle, sx, sy, lift, height, col, alpha, part, stride, kneeUp, tint, gu, gv, reach, wide)
    gu, gv = gu or 1, gv or 0
    reach = reach or 0
    local spread = spread * (1 + (wide or 0))
    local lg = love.graphics
    local c, s = math.cos(angle), math.sin(angle)
    local tr, tg, tb = tint[1], tint[2], tint[3]
    lg.setLineStyle("rough")
    -- no mitred joints: at sharp knees and zoomed in (menus) they shoot out long spikes
    local join = lg.getLineJoin()
    lg.setLineJoin("none")
    lg.setLineWidth(math.max(1, math.floor(sx + 0.5)))
    for i, leg in ipairs(rig) do
        for side = 0, 1 do
            local m = side == 0 and 1 or -1
            -- which side is further from the camera: compare the hip's screen depth
            local _, hy = project(leg[1], leg[2] * m, 0, c, s, 1, 1)
            local far = hy < 0
            if (part == "far") == far then
                local t = (phase + (((i - 1) % 2) ~= side and 0.5 or 0)) % 1
                local off, up
                if t < 0.6 then
                    off, up = stride - 2 * stride * (t / 0.6), 0
                else
                    local k = (t - 0.6) / 0.4
                    off, up = -stride + 2 * stride * (k * k * (3 - 2 * k)), math.sin(k * math.pi) * (1 + stride * 0.6)
                end
                local n = #leg / 2
                -- attack poses: the front pair reaches out (and lifts) ahead of the body
                if i == 1 and reach ~= 0 then off, up = off + reach, up + math.abs(reach) * 0.35 end
                for j = 1, n do
                    local u, v = leg[j * 2 - 1], leg[j * 2] * m
                    local z
                    if j == 1 then z = lift + height * 0.4
                    elseif j == n then z = up; u, v = u + off * gu, v * spread + off * gv
                    elseif j == n - 1 and n > 3 then z = 1 + up * 0.8; u, v = u + off * gu * 0.9, v * spread + off * gv * 0.9
                    else z = lift + height * 0.5 + kneeUp + up * 0.5; u, v = u + off * gu * 0.4, v * spread + off * gv * 0.4 end
                    local px, py = project(u, v, z, c, s, sx, sy)
                    legPts[j * 2 - 1], legPts[j * 2] = math.floor(x + px) + 0.5, math.floor(y + py) + 0.5
                end
                for j = n * 2 + 1, #legPts do legPts[j] = nil end
                local shade = far and 0.6 or 0.9
                lg.setColor(col[1] * shade * tr, col[2] * shade * tg, col[3] * shade * tb, alpha)
                lg.line(legPts)
                -- planted feet press a darker claw into the ground
                if up < 0.2 then
                    lg.setColor(col[1] * 0.4, col[2] * 0.4, col[3] * 0.4, alpha)
                    lg.rectangle("fill", legPts[n * 2 - 1] - 0.5, legPts[n * 2] - 0.5, math.max(1, sx), math.max(1, sy))
                end
            end
        end
    end
    lg.setLineWidth(1)
    lg.setLineJoin(join)
end

-- A long, segmented body (centipede) drawn as a chain. pose.chain = list of { dx, dy, angle }:
-- screen offsets of each segment from the head and its facing. Without it the chain lies straight.
local straight = {}
local drawLimbs
function Sprites.drawChain(model, phase, x, y, angle, flash, sx, sy, alpha, pose)
    local lg = love.graphics
    local head, segA, segB = Sprites.get(model.head), Sprites.get(model.segment), Sprites.get(model.segment2 or model.segment)
    local n = model.segments or 12
    local chain = pose and pose.chain
    if not chain then
        chain = straight
        for i = 1, n do
            local d = i * (model.spacing or 3)
            local wx, wy = -math.cos(angle) * d, -math.sin(angle) * d
            chain[i] = chain[i] or {}
            chain[i][1], chain[i][2], chain[i][3] = (wx - wy) * sx, (wx + wy) / 2 * sy, angle
        end
    end
    local tr, tg, tb = 1, 1, 1
    if pose and pose.tint then tr, tg, tb = pose.tint[1], pose.tint[2], pose.tint[3] end
    local tint = { tr, tg, tb }
    model._legCol = model._legCol or hexColor(model.legColor or "#e0a030")
    local h, lift = model.height or 3, (model.lift or 2) + (pose and pose.bob or 0)
    local leg = model.leg
    local function pick(sprite, a, fl)
        local dir = math.floor(a / (math.pi * 2) * sprite.dirs + 0.5) % sprite.dirs + 1
        if fl and not sprite.flash then return true end     -- drawStack flashes it with the shader
        return (fl and sprite.flash or sprite.frames)[dir][1]
    end
    -- back to front: segments further up the screen first
    model._order = model._order or {}
    local order = model._order
    for i = 0, n do order[i + 1] = i end
    for i = n + 2, #order do order[i] = nil end
    table.sort(order, function(a, b)
        local ya = a == 0 and 0 or chain[a][2]
        local yb = b == 0 and 0 or chain[b][2]
        return ya < yb
    end)
    x, y = math.floor(x), math.floor(y)
    -- three passes so far legs stay behind every segment and near legs in front of them
    for pass = 1, 3 do
        for _, i in ipairs(order) do
            local px, py, a = x, y, angle
            if i > 0 then px, py, a = x + chain[i][1], y + chain[i][2], chain[i][3]
            elseif pose then px, py, a = x + (pose.bx or 0), y + (pose.by or 0), angle + (pose.twist or 0) end
            px, py = math.floor(px + 0.5), math.floor(py + 0.5)
            -- a metachronal wave: each pair of legs a little behind the one in front
            local ph = phase - i * (model.wave or 0.09)
            if pass == 2 then
                local spr = i == 0 and head or (i % 2 == 0 and segA or segB)
                local q = pick(spr, a)
                drawStack(spr, q, flash and pick(spr, a, true) or q, px, py, h, lift, sx, sy, tr, tg, tb, alpha)
            elseif leg and i > 0 then
                drawLegs(leg, ph, px, py, a, sx, sy, lift, h, model._legCol, alpha, pass == 1 and "far" or "near", 1.1, 0, tint)
            end
        end
    end
    if pose and pose.limbs then
        drawLimbs(model, head, pose.limbs, "far", x + (pose.bx or 0), y + (pose.by or 0), angle + (pose.twist or 0), sx, sy, lift + h, tr, tg, tb, alpha)
        drawLimbs(model, head, pose.limbs, "near", x + (pose.bx or 0), y + (pose.by or 0), angle + (pose.twist or 0), sx, sy, lift + h, tr, tg, tb, alpha)
    end
end

-- Attack limbs (src/gfx/anim.lua): jointed claws, tails, forelegs and fangs drawn as thick
-- lines in 3D, blended from a rest pose to a strike pose. part: "far" (behind the body) or "near".
local limbPts, tipPts = {}, {}
local function limbColor(model, body, limb)
    local key = limb.color or "D"
    model._limbCol = model._limbCol or {}
    local c = model._limbCol[key]
    if not c then
        local hex = key:sub(1, 1) == "#" and key or (body.palette and body.palette[key]) or "#806040"
        c = hexColor(hex)
        model._limbCol[key] = c
    end
    return c
end

function drawLimbs(model, body, limbs, part, x, y, angle, sx, sy, ztop, tr, tg, tb, alpha)
    local lg = love.graphics
    local c, s = math.cos(angle), math.sin(angle)
    lg.setLineStyle("rough")
    local join = lg.getLineJoin()
    lg.setLineJoin("none")
    for _, e in ipairs(limbs) do
        local limb, m, k = e.limb, e.side, e.k
        local u, v, z = limb.u or 0, (limb.v or 0) * m, limb.z or ztop
        local _, hy = project(u, v, 0, c, s, 1, 1)
        -- forward limbs sit in front of the body unless the bug faces away from the camera
        local far = limb.depth == "far" or (limb.depth ~= "near" and hy < -1.5)
        if (part == "far") == far then
            local px, py = project(u, v, z, c, s, sx, sy)
            limbPts[1], limbPts[2] = x + px, y + py
            local yaw, pitch, n = 0, 0, 2
            local rest, strike, alt, k2 = limb.segs, limb.strike or limb.segs, limb.alt, e.k2 or 0
            for i, sg in ipairs(rest) do
                local st = strike[i] or sg
                local p0 = sg[3] or 0
                local len = sg[1] + (st[1] - sg[1]) * k
                local ya = sg[2] + ((st[2] or 0) - sg[2]) * k
                local pa = p0 + ((st[3] or 0) - p0) * k
                if alt and k2 ~= 0 then
                    local al = alt[i] or sg
                    len, ya, pa = len + (al[1] - sg[1]) * k2, ya + ((al[2] or 0) - sg[2]) * k2, pa + ((al[3] or 0) - p0) * k2
                end
                -- flapping wings, swaying feelers and tails (custom bugs: limb.wave)
                local wv = limb.wave
                if wv then
                    local fall = i == 1 and 1 or (wv.follow or 0.5)
                    local ph = love.timer.getTime() * wv.speed + (wv.phase or 0) - (i - 1) * (wv.lag or 0.6)
                    local sn = math.sin(ph)
                    ya, pa = ya + sn * wv.yaw * fall, pa + sn * wv.pitch * fall
                end
                yaw = yaw + ya * m
                pitch = pitch + pa
                local cp = math.cos(pitch)
                u, v, z = u + cp * math.cos(yaw) * len, v + cp * math.sin(yaw) * len, z + math.sin(pitch) * len
                px, py = project(u, v, z, c, s, sx, sy)
                limbPts[n + 1], limbPts[n + 2] = x + px, y + py
                n = n + 2
            end
            for j = n + 1, #limbPts do limbPts[j] = nil end
            local col = limbColor(model, body, limb)
            local a = alpha * e.alpha
            local w = math.max(1, math.floor((limb.width or 2) * sx + 0.5))
            -- dark rim, then the shell colour, then a sliver of gloss along the top
            lg.setColor(col[1] * 0.25 * tr, col[2] * 0.25 * tg, col[3] * 0.25 * tb, a * 0.8)
            lg.setLineWidth(w + 2)
            lg.line(limbPts)
            lg.setColor(col[1] * tr, col[2] * tg, col[3] * tb, a)
            lg.setLineWidth(w)
            lg.line(limbPts)
            if w >= 2 then
                lg.setColor(math.min(1, col[1] * 1.5 + 0.1) * tr, math.min(1, col[2] * 1.5 + 0.1) * tg, math.min(1, col[3] * 1.5 + 0.1) * tb, a * 0.7)
                lg.setLineWidth(1)
                for j = 1, n - 2, 2 do
                    lg.line(limbPts[j], limbPts[j + 1] - 1, limbPts[j + 2], limbPts[j + 3] - 1)
                end
            end
            -- the business end
            local tip = limb.tip
            if tip then
                local ex, ey = limbPts[n - 1], limbPts[n]
                local tl = (limb.tipLen or 3)
                lg.setLineWidth(math.max(1, w - 1))
                if tip == "wing" then
                    -- a see-through membrane fanned along the last segment
                    local L, W = tl * 2.2, tl * 0.9 * (limb.tipW or 1)
                    local cy, sy2 = math.cos(yaw), math.sin(yaw)
                    local pts = {}
                    for i2 = 0, 10 do
                        local t2 = i2 / 10 * math.pi * 2
                        local du, dv = (1 - math.cos(t2)) * 0.5 * L, math.sin(t2) * W * m
                        local qx, qy = project(u - cy * L * 0.15 + cy * du - sy2 * dv, v - sy2 * L * 0.15 + sy2 * du + cy * dv, z, c, s, sx, sy)
                        pts[#pts + 1], pts[#pts + 2] = x + qx, y + qy
                    end
                    lg.setColor(math.min(1, col[1] * 1.2 + 0.2) * tr, math.min(1, col[2] * 1.2 + 0.2) * tg, math.min(1, col[3] * 1.2 + 0.2) * tb, a * 0.4)
                    local ok, tris = pcall(love.math.triangulate, pts)
                    if ok then for _, tri in ipairs(tris) do lg.polygon("fill", tri) end end
                    lg.setColor(col[1] * tr, col[2] * tg, col[3] * tb, a * 0.8)
                    lg.setLineWidth(1)
                    lg.line(pts)
                elseif tip == "pincer" then
                    local op = 0.15 + e.open * 0.75
                    for side = -1, 1, 2 do
                        local ya = yaw + op * side
                        local u2, v2 = u + math.cos(ya) * tl, v + math.sin(ya) * tl
                        local u3, v3 = u2 + math.cos(yaw - op * side * 0.8) * tl * 0.8, v2 + math.sin(yaw - op * side * 0.8) * tl * 0.8
                        local x2, y2 = project(u2, v2, z, c, s, sx, sy)
                        local x3, y3 = project(u3, v3, z, c, s, sx, sy)
                        tipPts[1], tipPts[2], tipPts[3], tipPts[4], tipPts[5], tipPts[6] = ex, ey, x + x2, y + y2, x + x3, y + y3
                        for j = 7, #tipPts do tipPts[j] = nil end
                        lg.setColor(col[1] * 0.25, col[2] * 0.25, col[3] * 0.25, a * 0.8)
                        lg.setLineWidth(math.max(1, w - 1) + 2)
                        lg.line(tipPts)
                        lg.setColor(col[1] * tr, col[2] * tg, col[3] * tb, a)
                        lg.setLineWidth(math.max(1, w - 1))
                        lg.line(tipPts)
                    end
                elseif tip == "crusher" then
                    -- a solid lobster claw: a fat palm built up in shaded layers, a fixed finger
                    -- and a hinged dactyl that swings open (e.open); limb.tipW slims it (cutter)
                    local cy, sy2 = math.cos(yaw), math.sin(yaw)
                    local function P(du, dv, dz)
                        local qx, qy = project(u + cy * du - sy2 * dv, v + sy2 * du + cy * dv, z + (dz or 0), c, s, sx, sy)
                        return x + qx, y + qy
                    end
                    local L, W = tl * 1.15, tl * 0.62 * (limb.tipW or 1)
                    local rimR, rimG, rimB = col[1] * 0.25 * tr, col[2] * 0.25 * tg, col[3] * 0.25 * tb
                    local op = e.open or 0
                    local function palmAt(dz, grow)
                        local pts = {}
                        for i = 0, 9 do
                            local t = i / 9 * math.pi * 2
                            local px2, py2 = P(L * 0.5 + math.cos(t) * L * 0.55 * grow, math.sin(t) * W * grow * (math.cos(t) > 0 and 1 or 0.8), dz)
                            pts[#pts + 1], pts[#pts + 2] = px2, py2
                        end
                        return pts
                    end
                    -- fingers: fixed one on the outer side, dactyl hinged on the inner side
                    local function finger(side, ang, dz)
                        local bu, bv = L * 0.92, side * W * 0.45
                        local fl = tl * 1.05
                        local ca, sa = math.cos(ang), math.sin(ang)
                        local ax2, ay2 = P(bu - sa * W * 0.38, bv + ca * W * 0.38, dz)
                        local bx2, by2 = P(bu + sa * W * 0.38, bv - ca * W * 0.38, dz)
                        local tx2, ty2 = P(bu + ca * fl, bv + sa * fl, dz)
                        local mx2, my2 = P(bu + ca * fl * 0.5 + sa * W * 0.3 * side, bv + sa * fl * 0.5 - ca * W * 0.3 * side, dz)
                        return { ax2, ay2, mx2, my2, tx2, ty2, bx2, by2 }, tx2, ty2
                    end
                    local thick = math.max(1, math.floor(W * 0.7 * sy + 0.5))
                    local fixA, dacA = -0.12, 0.1 + op * 0.95
                    -- outline under everything, then the claw built up in layers (dark belly to lit top)
                    lg.setColor(rimR, rimG, rimB, a * 0.85)
                    lg.setLineWidth(2)
                    lg.polygon("line", palmAt(0, 1))
                    lg.polygon("line", (finger(1, fixA, 0)))
                    lg.polygon("line", (finger(-1, dacA, 0)))
                    lg.setLineWidth(1)
                    local fx1, fy1, dx1, dy1
                    for i = 0, thick do
                        local dz = i / sy
                        local k = 0.55 + 0.45 * (i / thick)
                        local f1, f2
                        f1, fx1, fy1 = finger(1, fixA, dz * 0.6)
                        f2, dx1, dy1 = finger(-1, dacA, dz * 0.6)
                        lg.setColor(col[1] * 0.85 * k * tr, col[2] * 0.85 * k * tg, col[3] * 0.85 * k * tb, a)
                        lg.polygon("fill", f1)
                        lg.polygon("fill", f2)
                        lg.setColor(col[1] * k * tr, col[2] * k * tg, col[3] * k * tb, a)
                        lg.polygon("fill", palmAt(dz, 1))
                    end
                    -- gloss on the top of the palm, pale tips
                    local tz = thick / sy
                    local g1x, g1y = P(L * 0.2, -W * 0.3, tz)
                    local g2x, g2y = P(L * 0.8, -W * 0.35, tz)
                    lg.setColor(math.min(1, col[1] * 1.6 + 0.15) * tr, math.min(1, col[2] * 1.6 + 0.15) * tg, math.min(1, col[3] * 1.6 + 0.15) * tb, a * 0.8)
                    lg.line(g1x, g1y, g2x, g2y)
                    lg.setColor(math.min(1, col[1] * 1.3 + 0.35), math.min(1, col[2] * 1.3 + 0.3), math.min(1, col[3] * 1.3 + 0.25), a)
                    lg.points(math.floor(fx1) + 0.5, math.floor(fy1) + 0.5, math.floor(dx1) + 0.5, math.floor(dy1) + 0.5)
                elseif tip == "blade" or tip == "fang" then
                    -- a hooked spike folding back inwards (mantis scythe, spider fang)
                    local hook = tip == "fang" and -1.2 or 2.6
                    local ya = yaw + hook * -m
                    local u2, v2 = u + math.cos(ya) * tl, v + math.sin(ya) * tl
                    local z2 = tip == "fang" and z - tl or z
                    local x2, y2 = project(u2, v2, z2, c, s, sx, sy)
                    lg.setColor(math.min(1, col[1] * 1.6 + 0.2), math.min(1, col[2] * 1.6 + 0.2), math.min(1, col[3] * 1.6 + 0.2), a)
                    lg.line(ex, ey, x + x2, y + y2)
                elseif tip == "sting" then
                    local u2, v2 = u + math.cos(yaw) * tl, v + math.sin(yaw) * tl
                    local x2, y2 = project(u2, v2, z - tl * 0.6, c, s, sx, sy)
                    local g = limb.glow or { 0.85, 1, 0.45 }
                    lg.setColor(g[1], g[2], g[3], a)
                    lg.line(ex, ey, x + x2, y + y2)
                    lg.setBlendMode("add")
                    lg.setColor(g[1], g[2], g[3], a * 0.5)
                    lg.circle("fill", x + x2, y + y2, 1.5 * sx)
                    lg.setBlendMode("alpha")
                elseif tip == "club" then
                    lg.setColor(col[1] * 0.25, col[2] * 0.25, col[3] * 0.25, a * 0.8)
                    lg.circle("fill", ex, ey, (tl + 1) * sx)
                    lg.setColor(col[1] * tr, col[2] * tg, col[3] * tb, a)
                    lg.circle("fill", ex, ey - 0.5, tl * sx)
                end
            end
        end
    end
    lg.setLineWidth(1)
    lg.setLineJoin(join)
end

-- A 3D-looking bug (see a character's `model`): jointed legs that step on the ground and a body
-- stacked `height` layers deep and raised `lift`, darker at the bottom, so it reads as a solid
-- shell seen from above at an angle. `angle` is the facing on the ground (world radians).
-- pose (optional): bob (extra body height, px), bx/by (body offset from the legs, px: lunges),
--   tint ({r,g,b} multiply, e.g. for ghosts), phase (0..1 step cycle; defaults from frame),
--   gu/gv (direction the bug is walking, relative to its facing: feet swing that way),
--   chain (segment positions for chain models).
function Sprites.drawModel(model, frame, x, y, angle, flash, sx, sy, alpha, pose)
    local lg = love.graphics
    alpha = alpha or 1
    sx = sx or 1
    sy = sy or sx
    local phase = (pose and pose.phase) or ((frame - 1) / 8)
    if model.kind == "chain" then return Sprites.drawChain(model, phase, x, y, angle, flash, sx, sy, alpha, pose) end
    local legs, body = model._legs, model._body
    if not legs then
        legs, body = Sprites.get(model.legs), Sprites.get(model.body)
        model._legs, model._body = legs, body
    end
    local function pick(sprite, fl)
        local dir = math.floor(angle / (math.pi * 2) * sprite.dirs + 0.5) % sprite.dirs + 1
        if fl and not sprite.flash then return true end     -- drawStack flashes it with the shader
        local quads = (fl and sprite.flash or sprite.frames)[dir]
        return quads[((frame - 1) % #quads) + 1]
    end
    x, y = math.floor(x), math.floor(y)
    local tr, tg, tb = 1, 1, 1
    if pose and pose.tint then tr, tg, tb = pose.tint[1], pose.tint[2], pose.tint[3] end
    local h, lift = model.height or 4, math.max(0, (model.lift or 2) + (pose and pose.bob or 0))
    local rig = legs.rig
    if pose and pose.spin then angle = angle + pose.spin end
    local reach, wide = pose and pose.reach, pose and pose.spread
    local bx, by = x, y
    if pose then bx, by = math.floor(x + (pose.bx or 0) + 0.5), math.floor(y + (pose.by or 0) + 0.5) end
    local col
    if rig then
        model._legCol = model._legCol or hexColor(legs.palette.l or "#302820")
        col = model._legCol
        model._tint = model._tint or {}
        model._tint[1], model._tint[2], model._tint[3] = tr, tg, tb
        drawLegs(rig, phase, x, y, angle, sx, sy, lift, h, col, alpha, "far", model.stride or 1.6, model.kneeUp or 0, model._tint, pose and pose.gu, pose and pose.gv, reach, wide)
    else
        lg.setColor(0.8 * tr, 0.8 * tg, 0.8 * tb, alpha)
        lg.draw(legs.image or Sprites.atlas, pick(legs), x, y - sy, 0, sx, sy, legs.ox, legs.oy)
    end
    -- attack poses: the body twists on its planted legs and squashes or stretches
    local legAngle = angle
    if pose and pose.twist then angle = angle + pose.twist end
    local bsx, bsy = sx, sy
    if pose and pose.stretch and pose.stretch ~= 0 then bsx, bsy = sx * (1 + pose.stretch), sy * (1 - pose.stretch * 0.5) end
    local limbs = pose and pose.limbs
    if not limbs and model.restLimbs then
        -- no animation running (menus, portraits): the always-there limbs at rest
        limbs = model._restList
        if not limbs then
            limbs = {}
            for _, limb in ipairs(model.restLimbs) do
                for sd = 1, -1, -2 do
                    if not limb.side or limb.side == sd then
                        limbs[#limbs + 1] = { limb = limb, side = sd, k = 0, k2 = 0, open = limb.restOpen or 0, alpha = 1 }
                    end
                end
            end
            model._restList = limbs
        end
    end
    if limbs then drawLimbs(model, body, limbs, "far", bx, by, angle, sx, sy, lift + h, tr, tg, tb, alpha) end
    local q = pick(body)
    drawStack(body, q, flash and pick(body, true) or q, bx, by, h, lift, bsx, bsy, tr, tg, tb, alpha)
    if rig then drawLegs(rig, phase, x, y, legAngle, sx, sy, lift, h, col, alpha, "near", model.stride or 1.6, model.kneeUp or 0, model._tint, pose and pose.gu, pose and pose.gv, reach, wide) end
    if limbs then drawLimbs(model, body, limbs, "near", bx, by, angle, sx, sy, lift + h, tr, tg, tb, alpha) end
end

return Sprites
