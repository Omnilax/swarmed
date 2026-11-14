return {
    name = "Backyard Patio",
    description = "A cracked concrete patio at dusk, ringed by overgrown lawn. The colony is under the slabs.",
    size = 760,
    seed = 7,
    patioInset = 0.16,      -- lawn border width as a fraction of the arena
    jointSpacing = 128,     -- concrete expansion joints, world units
    cracks = 30,
    leaves = 50,
    edgeGrass = 22,         -- max height of the tall grass along the back edges, pixels
    cliffDepth = 24,
    palette = {
        concrete = "#b3aa9a", concreteDark = "#6f675c", concreteLight = "#cdc6b8", joint = "#5d564d", crack = "#4a443c",
        grass1 = "#1f3a1c", grass2 = "#2c5226", grass3 = "#3c6a2f", grass4 = "#558a3c", flower = "#d8d070",
        blade1 = "#3f7a30", blade2 = "#5a9a3e", blade3 = "#2e5e26", bladeTip = "#a8d070",
        soil1 = "#3b2a1e", soil2 = "#4a3424", soil3 = "#2e2018", pebble = "#77706a",
        leafA = "#6a4426", leafB = "#8a5a2a", leafVein = "#3e2816",
    },
    -- Lighting: ambient colour multiplies the whole scene; lights brighten it.
    ambient = "#7a8090",
    -- Waves: `groups` columns in wave 1, +groupsPerWave each wave, `group` ants per column
    -- (scaled by the enemy's groupSize and +growth per wave), released groupGap seconds apart.
    spawn = { groups = 3, groupsPerWave = 1, group = { 14, 22 }, groupGap = 3, breakTime = 4, firstBreak = 2,
        maxAlive = 900, growth = 0.15,
        -- a new species every introEvery waves; ants enter from entries[1] points in wave 1,
        -- up to entries[2]; stray packs slip in from other sides every ~trickle s
        introEvery = 1, entries = { 2, 6 }, trickle = 6 },
}
