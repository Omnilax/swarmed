-- Boss encounter predators (content/bosses, src/game/director.lua): big things that eat ants
-- and bugs alike. They never spawn on their own (weight 0); every 5th wave one joins the queen,
-- and the wave lasts until it is killed. Hazards and events don't hurt them (def.encounter).
-- Each is drawn by its drawBody (o, world, sx, sy, scaleX, scaleY, flash) at full size.
local Iso = require("src.core.iso")
local Env = require("src.game.envfx")

-- Screen direction for a world angle.
local function sdir(a)
    local x, y = math.cos(a), math.sin(a)
    local sx, sy = x - y, (x + y) * 0.5
    local l = math.sqrt(sx * sx + sy * sy) + 0.0001
    return sx / l, sy / l
end

local function col(flash, r, g, b, a) if flash then love.graphics.setColor(1, 1, 1, a or 1) else love.graphics.setColor(r, g, b, a or 1) end end

local function drawAnteater(o, world, sx, sy, kx, ky, flash)
    local lg = love.graphics
    local st = o.st
    local fx, fy = sdir(st.face or 0)
    local side = fx >= 0 and 1 or -1
    local bob = (math.floor(o.anim) % 2)
    local bx, by = sx, sy - 12 - bob
    -- tail: a big bushy plume behind
    col(flash, 0.3, 0.26, 0.22)
    lg.ellipse("fill", bx - fx * 26, by - fy * 14 - 6, 14, 9)
    col(flash, 0.42, 0.37, 0.32)
    lg.ellipse("fill", bx - fx * 28, by - fy * 14 - 9, 9, 5)
    -- legs
    col(flash, 0.16, 0.13, 0.12)
    for i = -1, 1, 2 do
        local step = ((math.floor(o.anim) + (i > 0 and 1 or 0)) % 2) * 3
        lg.rectangle("fill", bx + fx * 10 * i - 2 + step * side, sy - 6, 4, 7)
        lg.rectangle("fill", bx + fx * 10 * i + 3 - step * side, sy - 5, 4, 6)
    end
    -- body
    col(flash, 0.37, 0.33, 0.3)
    lg.ellipse("fill", bx, by, 20 * kx, 11 * ky)
    col(flash, 0.52, 0.47, 0.42)
    lg.ellipse("fill", bx - 2, by - 3, 15 * kx, 6 * ky)
    -- the black-and-white shoulder band
    col(flash, 0.9, 0.88, 0.82)
    lg.polygon("fill", bx + fx * 4 - 3, by - 9, bx + fx * 12 + 3, by - 6, bx + fx * 8, by + 6, bx + fx * 2 - 5, by + 4)
    col(flash, 0.1, 0.08, 0.08)
    lg.polygon("fill", bx + fx * 6, by - 4, bx + fx * 12, by - 2, bx + fx * 9, by + 6, bx + fx * 4, by + 5)
    -- head and the long snout
    local hx, hy = bx + fx * 20, by + fy * 10 - 2
    col(flash, 0.45, 0.41, 0.37)
    lg.ellipse("fill", hx, hy, 7, 5)
    lg.setLineWidth(5)
    lg.line(hx, hy, hx + fx * 22, hy + fy * 12 + 2)
    lg.setLineWidth(3)
    col(flash, 0.55, 0.5, 0.45)
    lg.line(hx, hy - 1, hx + fx * 24, hy + fy * 12 + 1)
    lg.setLineWidth(1)
    col(flash, 0.08, 0.06, 0.06)
    lg.circle("fill", hx + fx * 25, hy + fy * 13 + 1, 1.5)
    lg.rectangle("fill", math.floor(hx + fx * 3), math.floor(hy - 2), 1, 1)
    -- the tongue, while licking
    if st.mode == "lick" then
        local k = st.t < 0.2 and st.t / 0.2 or (st.t < 0.4 and 1 or math.max(0, 1 - (st.t - 0.4) / 0.35))
        Env.tongue(st.mx0, st.my0, st.tx, st.ty, k, 3)
    end
end

local function drawAntlion(o, world, sx, sy, kx, ky, flash)
    -- painted in the bug sprites' style (src/gfx/antlion.lua)
    require("src.gfx.antlion").drawBody(o, world, sx, sy, kx, ky, flash)
end

local function drawSparrow(o, world, sx, sy, kx, ky, flash)
    local lg = love.graphics
    local st = o.st
    local fx = sdir(st.face or 0)
    local side = fx >= 0 and 1 or -1
    local h = o.z or 0
    local peck = st.peckT and st.peckT > 0 and 4 or 0
    local by = sy - 14 - h
    if st.mode == "swoop" then
        -- wings spread, gliding low
        col(flash, 0.36, 0.25, 0.15)
        lg.polygon("fill", sx - 30, by - 4, sx, by - 2, sx + 30, by - 4, sx + 6, by + 6, sx - 6, by + 6)
    end
    -- tail
    col(flash, 0.33, 0.23, 0.14)
    lg.polygon("fill", sx - side * 12, by + 2, sx - side * 26, by - 4, sx - side * 24, by + 4)
    -- legs
    col(flash, 0.35, 0.25, 0.15)
    if h < 2 then
        lg.rectangle("fill", sx - 3, sy - 6, 1, 6)
        lg.rectangle("fill", sx + 2, sy - 6, 1, 6)
    end
    -- body, belly, wing
    col(flash, 0.55, 0.38, 0.22)
    lg.ellipse("fill", sx, by, 15 * kx, 10 * ky)
    col(flash, 0.88, 0.82, 0.72)
    lg.ellipse("fill", sx + side * 3, by + 4, 9, 5)
    col(flash, 0.4, 0.27, 0.16)
    lg.ellipse("fill", sx - side * 3, by - 1, 9, 5)
    col(flash, 0.7, 0.52, 0.32)
    lg.rectangle("fill", sx - side * 8, by - 2, 2, 1)
    lg.rectangle("fill", sx - side * 4, by + 1, 2, 1)
    -- head
    local hx, hy = sx + side * 12, by - 7 + peck
    col(flash, 0.5, 0.33, 0.2)
    lg.circle("fill", hx, hy, 6)
    col(flash, 0.62, 0.62, 0.6)
    lg.circle("fill", hx - side * 1, hy - 3, 3)
    col(flash, 0.05, 0.04, 0.03)
    lg.rectangle("fill", math.floor(hx + side * 2), math.floor(hy - 1), 2, 2)
    col(flash, 0.9, 0.65, 0.2)
    lg.polygon("fill", hx + side * 5, hy - 1, hx + side * 11, hy + 1 + peck * 0.5, hx + side * 5, hy + 2)
end

local base = {
    family = "predator", encounter = true, noElites = true, noStun = true,
    spawn = { weight = 0, minWave = 99 },
    tags = { "predator", "boss" },
    flock = 0,
}

local function make(t)
    for k, v in pairs(base) do if t[k] == nil then t[k] = v end end
    return t
end

return {
    make {
        id = "anteater",
        name = "Giant Anteater",
        description = "Ambles round the arena flicking its long tongue down a lane: everything in it gets licked up, ants and you alike.",
        lore = "An anteater flicks its tongue up to 150 times a minute and eats tens of thousands of ants a day.",
        tip = "Watch the red lane under its snout. Step out of it, and lead the ants in.",
        sprite = "anteater", drawBody = drawAnteater,
        hp = 420, speed = 30, damage = 6, biteRate = 1.4, radius = 15, mass = 60, solid = true, xp = 20,
        behavior = "anteater",
        behaviorParams = { every = 3.2, warn = 1.1, reach = 175, width = 9, damage = 14, keep = 100 },
        gibs = { "#5e554c", "#857a6c", "#e8e2d4" }, splat = "#7a2a2a",
    },
    make {
        id = "antlion",
        name = "Antlion",
        description = "Digs a sand pit and waits at the bottom. The slope drags everything in; whatever reaches the jaws gets eaten, and it flicks sand at you.",
        lore = "Antlion larvae dig cone-shaped pits in loose sand and throw sand at prey to make it slide down.",
        tip = "Its pit pulls the ants in for you. Hit it from the rim, and walk out against the slide.",
        sprite = "antlion", drawBody = drawAntlion,
        hp = 340, speed = 0, damage = 0, radius = 11, mass = 999, xp = 20,
        behavior = "antlion",
        behaviorParams = { pit = 95, pull = 34, antPull = 55, bite = 12, flick = 3.2, shots = 3, shotDamage = 6 },
        gibs = { "#6a5034", "#8e6e48", "#c8a86c" }, splat = "#6a5a2a",
    },
    make {
        id = "sparrow",
        name = "Sparrow",
        description = "Circles high overhead as a shadow, then swoops down a line, snatching everything on it. It lands to peck at what's left, and that's when you can hit it.",
        lore = "House sparrows feed their chicks almost entirely on insects, and an ant swarm is a feast.",
        tip = "Dodge the swoop line, then go for it while it pecks on the ground.",
        sprite = "sparrow", drawBody = drawSparrow,
        hp = 300, speed = 60, damage = 0, radius = 12, mass = 40, xp = 20,
        behavior = "bird_swoop",
        behaviorParams = { circle = 3.4, aim = 1.0, swoop = 420, land = 3.6, peck = 0.65, damage = 14, peckDamage = 8 },
        gibs = { "#6a4a2c", "#9a7248", "#efe6d6" }, splat = "#7a2a2a",
    },
}
