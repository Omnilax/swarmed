-- Green ant: stays at range and sprays fans of acid.
return {
    name = "Green Ant",
    description = "Keeps its distance and sprays fans of acid at you.",
    lore = "Green tree ants spray formic acid from their gaster when threatened. Their bright green tails are a warning.",
    tip = "The glow means a spray is coming. Close the distance; they are weak up close.",
    sprite = "green_ant",
    hp = 5,
    speed = 40,
    damage = 1,
    radius = 3.5,
    mass = 1,
    behavior = "spitter",
    behaviorParams = { keep = 130, cooldown = 2.4, windup = 0.5, shots = 5, spread = 0.6, shotSpeed = 150, shotDamage = 4 },
    swarmShade = 0.12,
    light = { radius = 8, color = "#80ff60", intensity = 0.25 },
    spawn = { weight = 14, minWave = 4, groupSize = 0.3 },
    gibs = { "#1e5a22", "#48aa3e", "#d0802a" },
    splat = "#78c040",
    tags = { "ant", "ranged" },
    -- Elite variants of this species: the red Aggressive green ant sprays a wider fan of
    -- burning red acid that flies faster and further.
    elites = {
        aggressive = { params = { shots = 7, spread = 0.85, shotSpeed = 235, shotLife = 1.7, cooldown = 1.4, keep = 175, shotColor = "#ff5a2a" },
            note = "Sprays a wider fan of red acid that flies faster and further." },
        venomous = { params = { shotColor = "#c070ff" }, note = "Its violet acid poisons you." },
    },
}
