-- Boss encounter predators (content/bosses, src/game/director.lua): big bugs that eat ants
-- and bugs alike. They never spawn on their own (weight 0); every 5th wave one may join the
-- queen, and the wave lasts until it is killed. Hazards and events don't hurt them
-- (def.encounter). Each is drawn by its drawBody (o, world, sx, sy, scaleX, scaleY, flash).
-- Animals too big to fight (the sparrow, the giant anteater) are not enemies at all: they are
-- stage hazards, written straight into content/bosses (def.hazard).
local function col(flash, r, g, b, a) if flash then love.graphics.setColor(1, 1, 1, a or 1) else love.graphics.setColor(r, g, b, a or 1) end end

local function drawAntlion(o, world, sx, sy, kx, ky, flash)
    local lg = love.graphics
    local st = o.st
    local open = st.snap and (0.2 + 0.8 * math.max(0, 1 - st.snap / 0.25)) or (0.6 + 0.4 * math.sin(world.time * 3))
    -- a bristly head just above the sand, two long curved jaws
    col(flash, 0.42, 0.3, 0.18)
    lg.ellipse("fill", sx, sy - 3, 9 * kx, 5 * ky)
    col(flash, 0.58, 0.44, 0.27)
    lg.ellipse("fill", sx - 1, sy - 5, 6 * kx, 3 * ky)
    col(flash, 0.22, 0.14, 0.08)
    lg.setLineWidth(2)
    for s = -1, 1, 2 do
        local a = -math.pi / 2 + s * (0.25 + open * 0.55)
        local x1, y1 = sx + s * 4, sy - 6
        local x2, y2 = x1 + math.cos(a) * 12, y1 + math.sin(a) * 9
        local x3, y3 = x2 - s * 5, y2 - 2
        lg.line(x1, y1, x2, y2, x3, y3)
    end
    lg.setLineWidth(1)
    col(flash, 0.05, 0.03, 0.02)
    lg.rectangle("fill", sx - 3, sy - 7, 1, 1)
    lg.rectangle("fill", sx + 2, sy - 7, 1, 1)
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
}
