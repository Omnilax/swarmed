-- Fire bee: darts like a spark, bites burn, and it bursts into a caustic puddle when it dies.
return {
    name = "Fire Bee",
    description = "Flies in sharp darts like a jumping spark. Its bite burns, and when it dies it bursts into a puddle of caustic acid, so don't kill them on top of yourself.",
    lore = "Oxytrigona has no sting, but its jaws drip formic acid that blisters skin. In Brazil it's called caga-fogo: fire-shitter.",
    tip = "Kill them at arm's length, then step off the acid.",
    family = "bee",
    sprite = "fire_bee",
    hp = 2,
    speed = 60,
    damage = 2,
    radius = 2.5,
    mass = 0.5,
    behavior = "bee_dart",
    behaviorParams = { hop = 0.22, pause = 0.12, dart = 2.2, height = 6 },
    venom = { dps = 3, time = 2 },
    biteRate = 0.7,
    light = { radius = 5, color = "#ff8a2a", intensity = 0.2 },
    spawn = { weight = 16, minWave = 7, groupSize = 0.9 },
    gibs = { "#2a0a04", "#d0501a", "#ffb040" },
    splat = "#f08a2a",
    tags = { "bee", "flying", "acid" },
    -- Dies in a puddle of caustic acid that burns you while you stand in it.
    onDeath = function(world, x, y)
        world.hazards:addZone({ kind = "acid", x = x, y = y, r = 11, life = 3.5, damage = 6, color = { 0.95, 0.6, 0.15 } })
    end,
}
