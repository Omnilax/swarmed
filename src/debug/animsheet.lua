-- Attack animation viewer:  love . --anims
-- Every character plays its attack, special and dash animations in a loop at 4x, so clips in
-- src/config/anims.lua (or a character's own `anims`) can be tuned by eye.
-- Add --shot to instead save one contact sheet per character (anims_<id>.png in the save folder:
-- each row a move, each column a moment of it) and quit.
local Content = require("src.content")
local Sprites = require("src.gfx.sprites")
local Anim = require("src.gfx.anim")
local Theme = require("src.ui.theme")

local Sheet = {}
Sheet.__index = Sheet

local SLOTS = { "attack", "secondary", "dash" }

-- A stand-in for the player that clips can read (hold checks look at these fields).
local function dummy(def)
    return { world = { time = 0 }, def = def, attack = { combo = 0 }, delayed = {}, dashT = 0, blocking = false }
end

local function moveParams(def, slot)
    if slot == "attack" then return def.attack end
    if slot == "secondary" then return def.secondary end
    return def.dash or { type = "dash" }
end

-- Start `slot`'s clip on `o`; returns the clip's length (nil if it has none).
local function start(o, slot, combo)
    local params = moveParams(o.def, slot)
    if not params then return nil end
    if slot == "attack" then o.attack.combo = combo or (o.attack.combo % 3 + 1) end
    o._anims = nil
    o.world.time = 0
    Anim.move(o, slot, params)
    local st = o._anims and o._anims[slot]
    return st and st.dur
end

function Sheet.new(opts)
    local self = setmetatable({ t = 0, shot = opts.shot, bugs = {} }, Sheet)
    local only = os.getenv("SWARMED_ANIMS_ONLY")      -- e.g. SWARMED_ANIMS_ONLY=lobster: one sheet
    for _, def in ipairs(Content.characters:all()) do
        if not only or def.id == only then self.bugs[#self.bugs + 1] = { o = dummy(def), slot = 0, t = 0, dur = 0, wait = 0 } end
    end
    return self
end

function Sheet:update(dt)
    self.t = self.t + dt
    if self.shot then
        if not self.taken then
            self.taken = true
            self:saveSheets()
        else
            love.event.quit()
        end
        return
    end
    for _, b in ipairs(self.bugs) do
        b.t = b.t + dt
        b.o.world.time = b.t
        if b.t > b.dur + 0.35 then
            -- next move with an animation (skips moves the bug doesn't have)
            for _ = 1, #SLOTS do
                b.slot = b.slot % #SLOTS + 1
                local d = start(b.o, SLOTS[b.slot])
                if d then b.dur, b.t = d, 0 break end
            end
        end
    end
end

local function drawBug(o, x, y, angle, s)
    local pose = { phase = 0, bob = 0 }
    Anim.applyTo(pose, Anim.sample(o), angle, s, s)
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.ellipse("fill", x, y + 2 * s, 16 * s, 6 * s)
    love.graphics.setColor(1, 1, 1, 1)
    Sprites.drawModel(o.def.model, 1, x, y, angle, false, s, s, 1, pose)
end

function Sheet:draw()
    if self.shot then return end
    local lg = love.graphics
    lg.clear(0.12, 0.11, 0.1)
    local W, H = lg.getDimensions()
    local cols = 4
    local rows = math.ceil(#self.bugs / cols)
    local s = math.max(1, math.floor(math.min(W / cols / 45, H / rows / 40)))
    for i, b in ipairs(self.bugs) do
        local cx, cy = (i - 1) % cols, math.floor((i - 1) / cols)
        local x, y = W / cols * (cx + 0.5), H / rows * (cy + 0.45)
        drawBug(b.o, x, y, -0.6, s)
        lg.setFont(Theme.font(14))
        local label = b.o.def.name .. "  " .. (SLOTS[b.slot] or "")
        Theme.printShadow(label, x - 120, y + 16 * s, Theme.colors.text, "center", 240)
    end
end

-- One sheet per character: rows = moves (attack combo beats each get a row), columns = moments.
function Sheet:saveSheets()
    local lg = love.graphics
    local s, cw, ch, N = 5, 260, 170, 7
    local angle = tonumber(os.getenv("ANIM_ANGLE") or "") or -0.6
    for _, b in ipairs(self.bugs) do
        local o = b.o
        local rows = {}
        for _, slot in ipairs(SLOTS) do
            local beats = (slot == "attack" and o.def.attack.type == "pinchsting") and 3 or 1
            for k = 1, beats do rows[#rows + 1] = { slot, k } end
        end
        local canvas = lg.newCanvas(cw * N + 90, ch * #rows)
        lg.setCanvas(canvas)
        lg.clear(0.16, 0.15, 0.13, 1)
        for r, row in ipairs(rows) do
            local slot = row[1]
            for c = 1, N do
                local dur = start(o, slot, row[2])
                if dur then
                    o.world.time = dur * (c - 1) / (N - 1) * 0.999
                    drawBug(o, 90 + cw * (c - 0.5), ch * (r - 0.45), angle, s)
                end
            end
            lg.setColor(1, 1, 1, 1)
            lg.print(slot, 6, ch * (r - 0.5))
        end
        lg.setCanvas()
        canvas:newImageData():encode("png", "anims_" .. o.def.id .. ".png")
    end
    print("anim sheets saved to " .. love.filesystem.getSaveDirectory())
end

return Sheet
