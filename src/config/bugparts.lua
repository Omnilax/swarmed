-- The body-part kit for the Bug Painter (src/states/painter.lua): heads, middles (thorax) and
-- backs (abdomen) drawn top-down facing right, in the same few palette letters, so any head
-- goes with any middle and any back. The painter lines them up back to front, centres them and
-- puts legs on the middle.
--   o outline   a dark   b main   c light   e eyes   y stripes
local P = {}

P.palette = { o = "#1a120cb0", a = "#3a2a1a", b = "#6a4a2a", c = "#a07848", e = "#120808", y = "#e0c040", w = "#f0e8d0" }

P.heads = {
    { id = "beetle", name = "Beetle", rows = { "..oo..", ".obbo.", "obbceo", "obbbbo", "obbceo", ".obbo.", "..oo.." } },
    { id = "horned", name = "Rhino horn", rows = { "..oo....", ".obbo...", "obbceoo.", "obbbbccoo", "obbceoo.", ".obbo...", "..oo...." } },
    { id = "ant", name = "Ant", rows = { ".ooo..", "obceoo", "obbbbo", "obceoo", ".ooo.." } },
    { id = "wasp", name = "Wasp", rows = { ".ooo.", "oeebo", "oebbo", "obbbo", "oebbo", "oeebo", ".ooo." } },
    { id = "spider", name = "Spider", rows = { ".oo.", "oeeo", "obbo", "oeeo", ".oo." } },
    { id = "mantis", name = "Mantis", rows = { "o....", "oeo..", "obbo.", "obbbo", "obbo.", "oeo..", "o...." } },
    { id = "pincers", name = "Pincers", rows = { "..ooo...", ".obbboo.", "obceooco", "obbbo...", "obceooco", ".obbboo.", "..ooo..." } },
}

P.middles = {
    { id = "beetle", name = "Beetle", rows = { "..ooo..", ".obbbo.", "obbcbbo", "obbcbbo", "obbcbbo", ".obbbo.", "..ooo.." }, legs = 3 },
    { id = "ant", name = "Ant", rows = { ".oo.", "obbo", "obco", "obbo", ".oo." }, legs = 3 },
    { id = "wasp", name = "Wasp", rows = { ".ooo.", "obbbo", "obcbo", "obbbo", ".ooo." }, legs = 3 },
    { id = "spider", name = "Spider", rows = { "..oooo..", ".obbbbo.", "obbccbbo", "obccccbo", "obbccbbo", ".obbbbo.", "..oooo.." }, legs = 4 },
    { id = "mantis", name = "Mantis", rows = { ".ooooooooo.", "obbbbbbbbco", ".ooooooooo." }, legs = 3 },
    { id = "none", name = "None", rows = {}, legs = 3 },
}

P.backs = {
    { id = "beetle", name = "Beetle shell", rows = { "...oooooo..", "..obbbbbbo.", ".obcbbobcbo", "obcbbbobcbo", "obcbbbobbbo", "obbbbbobbbo",
        "obcbbbobbbo", "obcbbbobcbo", ".obcbbobcbo", "..obbbbbbo.", "...oooooo.." } },
    { id = "ant", name = "Ant gaster", rows = { "..ooo..", ".obbbo.", "obbcbbo", "obbccbo", "obbcbbo", ".obbbo.", "..ooo.." } },
    { id = "wasp", name = "Striped", rows = { ".ooooooo.", "oayyaybbo", "oayyaybco", "oayyaybco", "oayyaybbo", ".ooooooo." } },
    { id = "spider", name = "Round", rows = { "...ooo...", ".oobbboo.", ".obbcbbo.", "obbcccbbo", "obbcccbbo", "obbcccbbo", ".obbcbbo.", ".oobbboo.", "...ooo..." } },
    { id = "grub", name = "Segmented", rows = { ".oooooooooo.", "obobobobobbo", "obcbcbcbcbco", "obobobobobbo", ".oooooooooo." } },
    { id = "sting", name = "Sting", rows = { ".oooooo...", "obbbbbboo.", "obbcccbbyo", "obbbbbboo.", ".oooooo..." } },
}

-- Line parts up back to front: rows of one drawing, plus a leg rig on the middle.
function P.compose(headI, middleI, backI)
    local parts = { P.backs[backI], P.middles[middleI], P.heads[headI] }
    local H = 0
    for _, p in ipairs(parts) do H = math.max(H, #p.rows) end
    if H % 2 == 0 then H = H + 1 end
    local rows = {}
    for y = 1, H do rows[y] = "" end
    local midStart, midW = 0, 0
    for k, p in ipairs(parts) do
        local w = 0
        for _, r in ipairs(p.rows) do w = math.max(w, #r) end
        local off = math.floor((H - #p.rows) / 2)
        if k == 2 then midStart, midW = #rows[1], w end
        for y = 1, H do
            local r = p.rows[y - off] or ""
            rows[y] = rows[y] .. r .. string.rep(".", w - #r)
        end
    end
    -- trim empty columns at the ends
    local W = #rows[1]
    local x0, x1 = W + 1, 0
    for _, r in ipairs(rows) do
        for x = 1, W do
            if r:sub(x, x) ~= "." then x0, x1 = math.min(x0, x), math.max(x1, x) end
        end
    end
    if x1 == 0 then return { "." }, {} end
    for y, r in ipairs(rows) do rows[y] = r:sub(x0, x1) end
    W = x1 - x0 + 1
    midStart = midStart - (x0 - 1)
    -- legs: spread along the middle (or the middle of the drawing), reaching out and down
    local n = parts[2].legs or 3
    local cx = (W + 1) / 2
    local m0 = midW > 0 and (midStart + 1) or math.floor(W * 0.35)
    local m1 = midW > 0 and (midStart + midW) or math.floor(W * 0.65)
    local legs = {}
    local half = math.floor(H / 2)
    for i = 1, n do
        local k = n == 1 and 0.5 or (i - 1) / (n - 1)
        local hx = m1 - (m1 - m0) * k
        local u = math.floor(hx - cx + 0.5)
        local fwd = (0.5 - k) * 2          -- front legs reach forward, back legs back
        legs[i] = { u, -1, u + math.floor(fwd * 4 + 0.5), -(half + 3), u + math.floor(fwd * 9 + 0.5), -(half + 6) }
    end
    return rows, legs
end

-- Ready limbs for the limb editor: claws, tails, horns, wings, feelers...
P.limbs = {
    { id = "pincer", name = "Pincer claw", limb = { segs = { { 4, 0.6, 0 }, { 4, -0.5, 0 } }, tip = "pincer", tipLen = 3, width = 2, restOpen = 0.3 } },
    { id = "crusher", name = "Crusher claw", limb = { segs = { { 4, 0.7, 0 }, { 4, -0.4, 0 } }, tip = "crusher", tipLen = 5, width = 3 } },
    { id = "blade", name = "Mantis blade", limb = { segs = { { 5, 0.3, 0.4 }, { 5, -1.2, 0 } }, tip = "blade", tipLen = 4, width = 2 } },
    { id = "fang", name = "Fangs", limb = { segs = { { 2, 0.3, -0.3 } }, tip = "fang", tipLen = 2, width = 1 } },
    { id = "horn", name = "Horn", limb = { side = 1, v = 0, segs = { { 4, 0, 0.6 }, { 3, 0, 0.5 } }, width = 2 } },
    { id = "antenna", name = "Feelers", limb = { segs = { { 4, 0.5, 0.5 }, { 4, -0.2, -0.3 } }, width = 1, sway = 0.25 } },
    { id = "tail", name = "Sting tail", limb = { side = 1, v = 0, segs = { { 4, 3.14, 0.5 }, { 4, 0, 0.6 }, { 3, 0, 0.6 } }, tip = "sting", tipLen = 3, width = 2, sway = 0.15 } },
    { id = "club", name = "Club tail", limb = { side = 1, v = 0, segs = { { 5, 3.14, 0.2 }, { 4, 0, 0.1 } }, tip = "club", tipLen = 3, width = 2, sway = 0.1 } },
    { id = "wing", name = "Wings", limb = { segs = { { 1.5, 2.3, 0.5 } }, tip = "wing", tipLen = 5, width = 1, depth = "far", flap = 24 } },
}
P.TIPS = { "none", "pincer", "crusher", "blade", "sting", "fang", "club", "wing" }

return P
