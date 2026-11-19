-- Driver ant (siafu): a river of ants whose jaws lock on and won't let go.
return {
    name = "Driver Ant",
    description = "Pours in as a living river. Each one that reaches you locks its jaws on, hangs on and keeps biting, and the more hang on, the slower you go.",
    lore = "Siafu soldiers bite so hard their jaws stay locked even after death. In East Africa they were once used to stitch wounds closed.",
    tip = "Dash to shake every one of them off at once. Don't let a river catch you standing still. A crowd of them cracks your armor fast.",
    sprite = "driver_ant",
    hp = 4,
    speed = 50,
    damage = 1.5,
    shred = { armor = 1, time = 3, max = 8 },   -- bites crack your armor (src/config/defense.lua)
    radius = 3.5,
    mass = 0.9,
    behavior = "latcher",
    behaviorParams = { hold = 6, slowPer = 0.07, minSlow = 0.35, wobble = 0.5 },
    biteRate = 0.8,
    flock = 0.35,
    personalSpace = 0.75,
    swarmShade = 0.18,
    spawn = { weight = 16, minWave = 6, groupSize = 1.4 },
    gibs = { "#3a120a", "#a83a1c", "#e8b888" },
    splat = "#7a5a2a",
    tags = { "ant", "swarm", "grabber" },
}
