-- Sea firefly (an ostracod): plankton in a tiny shell that glows blue. When it dies it spills
-- a cloud of glowing slime that slows you while you stand in it.
local GLOW = { 0.35, 0.85, 1 }

local function drawGlow(z, sx, sy, fade)
    local lg = love.graphics
    local k = fade * (0.75 + 0.25 * math.sin(z.t * 9))
    lg.setColor(0.25, 0.75, 1, 0.22 * k)
    lg.ellipse("fill", sx, sy, z.r * 1.15, z.r * 0.6)
    lg.setColor(0.6, 0.95, 1, 0.35 * k)
    lg.ellipse("fill", sx, sy, z.r * 0.6, z.r * 0.32)
end

return {
    name = "Sea Firefly",
    description = "A blue speck of plankton in a tiny clam-like shell, glowing as it drifts. Pop one and it spills a cloud of glowing slime that slows you while you stand in it.",
    lore = "Sea fireflies squirt out glowing slime when a fish bites them, so the fish spits them out in a hurry. Dried ones still glow when you wet them.",
    tip = "Pop them away from the crowd, or step out of the glow right after.",
    family = "crustacean",
    sprite = "sea_firefly",
    hp = 2,
    speed = 46,
    damage = 1,
    radius = 2,
    mass = 0.3,
    behavior = "plankton_drift",
    behaviorParams = { drift = 0.45, kick = 2.2, every = { 0.8, 1.6 }, swirl = 1.3 },
    light = { radius = 12, color = "#3ad8ff", intensity = 0.55 },
    aquatic = true,
    onDeath = function(world, x, y)
        world.hazards:addZone({ kind = "glow", x = x, y = y, r = 18, life = 2.5, slow = 0.65, color = GLOW, draw = drawGlow })
        world.particles:burst(x, y, 6, { GLOW, { 0.8, 1, 1 } }, 40, 24)
    end,
    spawn = { weight = 10, minWave = 5, groupSize = 0.6, habitat = "water" },
    gibs = { "#1e4a6a", "#3ad8ff" },
    splat = "#5aa0c0",
    tags = { "crustacean", "plankton", "aquatic" },
}
