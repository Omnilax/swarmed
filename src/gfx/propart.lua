-- Painted pictures for the props (content/props): acorns, pebbles, cocoons, the map gambles,
-- brood cells, the merchant beetle and the clone aphid. Painted once each with src/gfx/paint.lua
-- so they share the bug sprites' look (lit ramps, light from the upper left, soft outline)
-- instead of being flat vector shapes. Upright pictures, origin at the feet unless noted.
local Paint = require("src.gfx.paint")

local PA = {}

local hex, ramp = Paint.hex, Paint.ramp
local floor, max, min, sin, cos = math.floor, math.max, math.min, math.sin, math.cos
local hash = Paint.hash

local C = {
    nut = ramp("#4a2a10", "#6e4018", "#8f5a24", "#ad7434", "#c48e4c"),
    cap = ramp("#3a2a16", "#54401f", "#6c552c", "#86703c"),
    stone = ramp("#3e3a36", "#57524c", "#716a62", "#8c847a", "#a69e92"),
    silk = ramp("#9a978e", "#b8b5ac", "#d2cfc6", "#e8e6de", "#f6f4ee"),
    leaf = ramp("#1e3a16", "#2c5220", "#3e6c2a", "#548836", "#6ea244"),
    vein = hex("#8ab85a"),
    stem = ramp("#1e3814", "#2e5020", "#44682c"),
    bell = ramp("#2a3270", "#3c4a9a", "#5466c0", "#7486dc", "#a0b0f0"),
    bellDone = ramp("#3e3c46", "#55525e", "#6e6a78", "#8a8694"),
    gold = ramp("#7a5410", "#a87818", "#d4a028", "#f0c850", "#fde488"),
    wax = ramp("#6a420c", "#8e5c14", "#b47a20", "#d49a34", "#ecbc58"),
    waxCap = ramp("#b48a3a", "#d0a650", "#e6c06c", "#f6d88c", "#fff0b8"),
    shell = ramp("#0c2422", "#14403a", "#1e5a50", "#2e7a68", "#4aa088"),
    pack = ramp("#4a2e14", "#68431e", "#86592a", "#a4743a"),
    strap = hex("#2a1a0c"),
    aphid = ramp("#24481a", "#346626", "#4a8434", "#64a046", "#86bc62"),
    eye = hex("#7a1414"),
    legDark = hex("#1a1210"),
    legGreen = hex("#2a4a1a"),
    drop = { { 0.36, 0.62, 0.78, 0.7 }, { 0.48, 0.76, 0.9, 0.7 }, { 0.62, 0.88, 0.98, 0.72 }, { 0.8, 0.96, 1, 0.8 } },
}
PA.C = C

-- ------------------------------------------------------------------ acorn (origin: its middle)
function PA.acorn()
    return Paint.get("acorn", function()
        local p = Paint.pic(17, 21, 8, 11)
        p:blob(0, 2, 6.5, 7.5, 0, C.nut, function(u, v, i)
            if hash(u, v, 1) > 0.9 and i > 0.3 then return C.nut[max(1, floor(i * 5))] end
            return C.nut[floor(i * 5) + 1]
        end)
        p:set(0, 9, C.cap[1])                      -- the little point at the bottom
        p:blob(0, -4, 7.5, 4.2, 0, C.cap, function(u, v, i)
            -- overlapping scales: a dark fleck in each cell of a staggered grid
            local row = floor((v + 8) / 2)
            local cu = (u + 9 + (row % 2) * 1.5) % 3
            if cu < 0.8 then return C.cap[max(1, floor(i * 4))] end
            return C.cap[floor(i * 4) + 1]
        end)
        p:stroke(0, -8, 1, -10, 0.8, 0.5, C.cap)
        p:outline()
        return p
    end)
end

-- ------------------------------------------------------------------ pebbles (origin: its middle)
function PA.pebble(r, variant)
    r = max(2, floor(r + 0.5))
    variant = variant % 3
    return Paint.get("pebble" .. r .. "_" .. variant, function()
        local w = r * 3 + 4
        local p = Paint.pic(w, r * 2 + 6, floor(w / 2), r + 3)
        local ang = ({ 0, 0.3, -0.25 })[variant + 1]
        local sq = ({ 0.62, 0.7, 0.55 })[variant + 1]
        p:blob(0, 0, r * 1.35, r * 1.35 * sq + 1, ang, C.stone, function(u, v, i)
            local h = hash(u, v, variant + 2)
            if h > 0.9 then return C.stone[min(5, floor(i * 5) + 2)] end     -- light mineral flecks
            if h < 0.06 then return C.stone[max(1, floor(i * 5))] end
            return C.stone[floor(i * 5) + 1]
        end)
        p:outline()
        return p
    end)
end

-- ------------------------------------------------------------------ twig (lying flat; origin: middle)
-- painted along +u, L long; knot (0..1) is where its side shoot grows
function PA.twig(L, knot)
    local kq = floor(knot * 5 + 0.5)
    return Paint.get("twig" .. L .. "_" .. kq, function()
        local bark = ramp("#2e1c0e", "#4a2e16", "#664222", "#845a32", "#9c7044")
        local p = Paint.pic(L + 6, 14, floor(L / 2) + 3, 7)
        local h = L / 2
        -- the stick: a long lit cylinder with bark streaks along it, thinner at one end
        for u = -h, h do
            local t = (u + h) / L
            local r = 2.3 - t * 0.7
            for v = -3, 3 do
                if math.abs(v) <= r then
                    local i = 0.5 - v / r * 0.42 + (hash(floor(u / 3), v, 7) - 0.5) * 0.25
                    if hash(u, v, 8) > 0.93 then i = i - 0.3 end
                    p:set(u, v, bark[max(1, min(5, floor(i * 5) + 1))])
                end
            end
        end
        -- a side shoot and a broken stub
        local ku = -h + L * kq / 5
        p:stroke(ku, -1, ku + 5, -5, 1.0, 0.5, bark)
        p:stroke(h - 3, 1, h - 1, 3, 0.8, 0.5, bark)
        p:outline()
        return p
    end)
end

-- ------------------------------------------------------------------ cocoon (origin: feet)
function PA.cocoon()
    return Paint.get("cocoon", function()
        local p = Paint.pic(18, 22, 9, 20)
        p:blob(0, -8, 7, 9.5, 0, C.silk, function(u, v, i, a, b)
            -- wound silk: diagonal strands, a darker shape of the bug inside
            local strand = (u * 0.8 + v * 1.0) % 3
            local inner = (a / 3.5) ^ 2 + (b / 5.5) ^ 2 < 1
            local k = floor(i * 5) + 1
            if inner then k = max(1, k - 2) end
            if strand < 0.9 then k = min(5, k + 1) end
            return C.silk[k]
        end)
        p:stroke(-6, -1, 7, 0, 0.5, 0.5, C.silk[2])  -- loose threads tying it to the ground
        p:stroke(-4, -16, -8, -19, 0.4, 0.4, C.silk[4])
        p:outline()
        return p
    end)
end

-- ------------------------------------------------------------------ leaves and stalks
local function leafPaint(p, cu, cv, ra, rb, ang)
    local c, s = cos(ang), sin(ang)
    p:blob(cu, cv, ra, rb, ang, C.leaf, function(u, v, i, a, b)
        if math.abs(b) < 0.6 and math.abs(a) < ra * 0.85 then return C.vein end
        -- side veins slanting toward the tip
        if math.abs(b) > 1 and math.abs(((a - math.abs(b) * 1.2) % 4)) < 0.7 and i > 0.3 then return C.leaf[min(5, floor(i * 5) + 2)] end
        return C.leaf[floor(i * 5) + 1]
    end)
end

-- the dewdrop shrine's leaf, lying flat (origin: its middle)
function PA.shrineLeaf()
    return Paint.get("shrine_leaf", function()
        local p = Paint.pic(34, 16, 17, 8)
        leafPaint(p, 0, 0, 15.5, 5.5, 0)
        p:stroke(15, 0, 17, -1, 0.6, 0.4, C.stem)
        p:outline()
        return p
    end)
end

-- a dew drop of radius r (origin: its bottom)
function PA.drop(r)
    r = max(2, min(12, floor(r + 0.5)))
    return Paint.get("drop" .. r, function()
        local p = Paint.pic(r * 2 + 4, r * 2 + 4, r + 2, r * 2 + 2)
        p:blob(0, -r, r, r, 0, C.drop, function(u, v, i, a, b)
            -- light comes through and gathers on the lower right; a hard glint top left
            local d = (a / r + 0.4) ^ 2 + (b / r + 0.4) ^ 2
            if d < 0.08 then return { 1, 1, 1, 0.95 } end
            local k = floor((1 - i) * 3) + 1
            if a > r * 0.35 and b > r * 0.35 then k = 4 end
            return C.drop[k]
        end)
        p:outline({ 0.12, 0.3, 0.42, 0.75 })
        return p
    end)
end

-- the gamble flower's stem and two leaves (origin: feet; the flower head sits at 1, -22)
function PA.flowerStem()
    return Paint.get("flower_stem", function()
        local p = Paint.pic(22, 26, 10, 24)
        p:stroke(0, 0, 0.5, -10, 1.1, 1.0, C.stem)
        p:stroke(0.5, -10, 1, -20, 1.0, 0.9, C.stem)
        leafPaint(p, 5, -8, 5, 2, -0.45)
        leafPaint(p, -4, -4, 4, 1.6, 0.5 + math.pi)
        p:outline()
        return p
    end)
end

-- one petal in a colour (origin: its middle)
function PA.petal(c, lit)
    local key = ("petal%.2f_%.2f_%.2f_%s"):format(c[1], c[2], c[3], lit and 1 or 0)
    return Paint.get(key, function()
        local p = Paint.pic(11, 9, 5, 4)
        local m = lit and 1 or 0.72
        local base = { c[1] * m, c[2] * m, c[3] * m, 1 }
        local rp = Paint.rampOf(base, 4)
        p:blob(0, 0, lit and 4 or 3.2, lit and 2.8 or 2.2, 0, rp)
        p:outline(lit and { 1, 1, 0.9, 0.9 } or nil)
        return p
    end)
end

function PA.flowerHeart()
    return Paint.get("flower_heart", function()
        local p = Paint.pic(9, 9, 4, 4)
        p:blob(0, 0, 3.4, 3.2, 0, C.gold, function(u, v, i)
            if hash(u, v, 6) > 0.75 then return C.gold[max(1, floor(i * 5))] end     -- pollen grains
            return C.gold[floor(i * 5) + 1]
        end)
        p:outline()
        return p
    end)
end

-- the challenge bell's bending stalk (origin: feet; the bell hangs from 6, -28)
function PA.bellStalk()
    return Paint.get("bell_stalk", function()
        local p = Paint.pic(24, 34, 12, 32)
        local pts = { { -2, 0 }, { -3, -9 }, { -3, -16 }, { -1, -23 }, { 2, -27 }, { 6, -28.5 } }
        for i = 1, #pts - 1 do p:stroke(pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2], 1.1, 0.9, C.stem) end
        leafPaint(p, -7, -9, 5, 1.8, 0.6 + math.pi)
        p:outline()
        return p
    end)
end

-- the bell flower (origin: where it hangs from)
function PA.bell(done)
    return Paint.get(done and "bell_done" or "bell", function()
        local rp = done and C.bellDone or C.bell
        local p = Paint.pic(15, 16, 7, 1)
        -- a bell: narrow at the top, flaring to a lip
        for v = 0, 11 do
            local hw = 1.5 + v * 0.32 + (v > 8 and (v - 8) * 0.7 or 0)
            for u = -floor(hw + 0.5), floor(hw + 0.5) do
                local nu = u / (hw + 0.5)
                local i = 0.5 - nu * 0.45 + (1 - nu * nu) * 0.25 - v * 0.02 + (hash(u, v, 9) - 0.5) * 0.1
                if v >= 10 then i = i - 0.25 end              -- the shaded inside of the lip
                p:set(u, v, rp[max(1, min(#rp, floor(i * #rp) + 1))])
            end
        end
        p:set(0, -1, C.stem[2])
        p:outline()
        return p
    end)
end

-- ------------------------------------------------------------------ brood cell (origin: feet)
function PA.broodCell(royal)
    return Paint.get(royal and "brood_royal" or "brood", function()
        local s = royal and 1.15 or 0.9
        local R = 9 * s
        local p = Paint.pic(floor(R * 2 + 6), floor(R * 2 + 10), floor(R + 3), floor(R * 2 + 6))
        -- a hexagonal wax prism seen from above-front: walls, then the domed cap
        local function inHex(u, v, cx, cy, r)
            local x, y = math.abs(u - cx), math.abs((v - cy) / 0.6)
            return y <= r * 0.866 and x * 0.866 + y * 0.5 <= r * 0.866
        end
        local top = -8 * s - 4
        for v = floor(top - R), 2 do
            for u = floor(-R - 1), floor(R + 1) do
                local wall = inHex(u, v, 0, top + 4 * s, R) or (math.abs(u) <= R * 0.98 and v > top and v <= top + 4 * s)
                if inHex(u, v, 0, top, R) then
                    local cap = inHex(u, v, 0, top - 1, 6.5 * s)
                    local i = 0.55 - u / R * 0.25 - (v - top) / R * 0.3 + (hash(u, v, 4) - 0.5) * 0.12
                    if cap then
                        local d = ((u + 1.5 * s) / (6.5 * s)) ^ 2 + ((v - top + 1.5) / (4 * s)) ^ 2
                        i = 0.9 - d * 0.45
                        p:set(u, v, C.waxCap[max(1, min(5, floor(i * 5) + 1))])
                    else
                        p:set(u, v, C.wax[max(1, min(5, floor(i * 5) + 2))])
                    end
                elseif wall then
                    local i = 0.45 - u / R * 0.35 + (hash(u, v, 5) - 0.5) * 0.1
                    if math.abs(math.abs(u) - R * 0.5) < 0.6 then i = i - 0.2 end   -- the prism's edges
                    p:set(u, v, C.wax[max(1, min(5, floor(i * 5) + 1))])
                end
            end
        end
        if royal then
            for k = -1, 1 do p:stroke(k * 3, top - 5 * s, k * 3, top - 8 * s, 1, 0.4, C.gold) end
        end
        p:outline()
        return p
    end)
end

-- ------------------------------------------------------------------ the merchant beetle
-- facing right (drawn mirrored to face left), two walking frames; origin: feet
function PA.merchant(frame)
    return Paint.get("merchant" .. frame, function()
        local p = Paint.pic(34, 30, 16, 27)
        -- legs first, behind the body
        for i = -1, 1 do
            local k = ((frame + i) % 2) * 2 - 1
            p:stroke(i * 5, -3, i * 6 - 3, 1 + k, 0.6, 0.5, C.legDark)
            p:stroke(i * 5 + 1, -3, i * 6 + 3, 1 - k, 0.6, 0.5, C.legDark)
        end
        -- an iridescent shell: teal with a green-gold sheen where the light hits
        p:blob(0, -6, 11, 6, 0, C.shell, function(u, v, i)
            if i > 0.82 then return hex("#9ad08a") end
            if math.abs(u + 1) < 0.6 and v < -4 then return C.shell[1] end      -- wing seam
            return C.shell[floor(i * 5) + 1]
        end)
        -- the head and antennae
        p:blob(10, -5, 3.5, 3, 0, C.shell, nil, -0.1)
        p:stroke(12, -7, 15, -12, 0.4, 0.4, C.legDark)
        p:stroke(11, -7, 13, -13, 0.4, 0.4, C.legDark)
        -- the big pack on its back, lashed on with a strap
        for v = -19, -9 do
            for u = -6, 6 do
                local i = 0.6 - u * 0.03 - (v + 19) * 0.03 + (hash(u, v, 3) - 0.5) * 0.12
                if v <= -17 then i = i + 0.25 end            -- the top catches the light
                if u == 6 then i = i - 0.2 end
                p:set(u, v, C.pack[max(1, min(4, floor(i * 4) + 1))])
            end
        end
        for v = -19, -8 do p:set(-1, v, C.strap) end
        for u = -6, 6 do p:set(u, -12, C.strap) end
        p:set(-1, -12, C.gold[4])
        p:outline()
        return p
    end)
end

-- ------------------------------------------------------------------ the clone aphid
function PA.aphid(frame)
    return Paint.get("aphid" .. frame, function()
        local p = Paint.pic(34, 28, 16, 25)
        for i = -1, 1 do
            local k = ((frame + i) % 2) * 2 - 1
            p:stroke(i * 5, -2, i * 6 - 3, 2 + k, 0.5, 0.5, C.legGreen)
            p:stroke(i * 5, -2, i * 6 + 3, 2 - k, 0.5, 0.5, C.legGreen)
        end
        -- a plump pear-shaped body, the head and its red eye
        p:blob(-2, -7, 11, 8, 0, C.aphid, function(u, v, i)
            if i > 0.9 then return hex("#c8eca0") end
            if (hash(floor(u / 2), floor(v / 2), 2) > 0.85) then return C.aphid[max(1, floor(i * 5))] end
            return C.aphid[floor(i * 5) + 1]
        end)
        p:blob(9, -6, 4, 3.6, 0, C.aphid, nil, -0.1)
        p:set(11, -7, C.eye); p:set(11, -8, C.eye)
        -- the two cornicles sticking up off its back end
        p:stroke(-9, -11, -12, -15, 0.7, 0.5, C.stem)
        p:stroke(-7, -12, -9, -16, 0.7, 0.5, C.stem)
        p:outline()
        return p
    end)
end

-- Draws a painted picture lying flat on the iso floor at world (x, y), turned to world `angle`,
-- z pixels up (twigs).
local tf
function PA.drawFlat(pic, x, y, angle, z, alpha)
    local Iso = require("src.core.iso")
    local c, s = cos(angle), sin(angle)
    tf = tf or love.math.newTransform()
    local tx, ty = Iso.toScreen(x, y, z or 0)
    tf:setMatrix(c - s, -s - c, 0, tx, (c + s) * 0.5, (c - s) * 0.5, 0, ty, 0, 0, 1, 0, 0, 0, 0, 1)
    local lg = love.graphics
    lg.push()
    lg.applyTransform(tf)
    if type(alpha) == "table" then lg.setColor(alpha) else lg.setColor(1, 1, 1, alpha or 1) end
    lg.draw(pic.image, -pic.ox, -pic.oy)
    lg.pop()
end

return PA
