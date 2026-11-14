return {
    name = "Worker Ant",
    description = "The backbone of the colony. Weak alone, a flowing carpet together.",
    lore = "Workers follow each other's scent trail nose to tail. Break the column and the line behind falls apart, then regroups around you.",
    tip = "Wide sweeps cut a whole column in half.",
    sprite = "worker_ant",
    hp = 3,
    speed = 46,
    damage = 2,
    radius = 3,
    mass = 0.5,
    behavior = "column",    -- marches in follow-the-leader columns, then surrounds the player
    behaviorParams = { engageRange = 120, ringShrink = 20, orbit = 0.35, spacing = 5, gait = 0.35 },
    flock = 0,
    personalSpace = 0.75,   -- < 1 lets the swarm pack tightly
    swarmShade = 0.22,      -- dark underlay that merges the crowd into one mass
    spawn = { weight = 100, minWave = 1, groupSize = 1.5 },
    gibs = { "#120a08", "#24150f", "#4a2216", "#2a1a12" },
    splat = "#86743a",      -- hemolymph colour (splats and droplets)
    tags = { "ant", "swarm" },
}
