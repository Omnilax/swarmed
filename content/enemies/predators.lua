-- Boss encounter predators (content/bosses, src/game/director.lua): big bugs that eat ants
-- and bugs alike. They never spawn on their own (weight 0); every 5th wave one may join the
-- queen, and the wave lasts until it is killed. Hazards and events don't hurt them
-- (def.encounter). Each is drawn by its drawBody (o, world, sx, sy, scaleX, scaleY, flash).
-- Animals too big to fight (the sparrow, the giant anteater) are not enemies at all: they are
-- stage hazards, written straight into content/bosses (def.hazard).
local function col(flash, r, g, b, a) if flash then love.graphics.setColor(1, 1, 1, a or 1) else love.graphics.setColor(r, g, b, a or 1) end end

local function drawAntlion(o, world, sx, sy, kx, ky, flash)
    -- painted in the bug sprites' style (src/gfx/antlion.lua)
    require("src.gfx.antlion").drawBody(o, world, sx, sy, kx, ky, flash)
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
