-- TEMPLATE. Copy to content/enemies/my_ant.lua and it will spawn in runs and the sandbox.
-- Every field except name and sprite is optional (defaults live in src/content.lua).
return {
    name = "My Ant",
    description = "",
    lore = "",                      -- optional longer flavour text for the Bug Catalogue
    tip = "",                       -- optional how-to-beat-it hint for the Bug Catalogue
    family = "ant",                 -- ant | bee | wasp | termite (src/config/families.lua): groups it in menus
    sprite = "worker_ant",          -- id from content/sprites
    scale = 1,                      -- draw scale
    hp = 10,                        -- scaled by difficulty and wave
    speed = 40,                     -- world units per second
    damage = 5,                     -- contact damage
    radius = 5,                     -- collision radius
    mass = 1,                       -- heavier = less knockback, pushes others aside
    behavior = "chase",             -- id from content/behaviors: chase, charge, column (marching columns that surround the player)
    behaviorParams = {},            -- passed to the behaviour
    flock = 0,                      -- 0..1 copy neighbours' heading (swarm streams)
    personalSpace = 1,              -- < 1 packs tighter, > 1 spreads out
    swarmShade = nil,               -- e.g. 0.2: dark underlay that merges crowds into one mass
    light = nil,                    -- e.g. { radius = 10, color = "#ff6a2a", intensity = 0.4 }
    biteRate = 0.9,                 -- seconds between bites while touching the player (every ant bites)
    -- shred = { armor = 2, time = 4, max = 10 },  -- optional: every bite cracks the player's armor (stacks to max, src/config/defense.lua)
    -- solid = true,                -- the player can't walk through it (dashing still can)
    -- shield = { block = 0.75, width = 2.2 },  -- soaks hits aimed at ants behind it
    -- boss = true,                 -- a queen/boss: shows a boss bar; spawned by boss waves, not normally
    -- onDeath = function(world, x, y, def, info) end,  -- runs the frame after it dies
    -- spawn.escort = { "worker_ant", 10 } makes that many follow this ant in its column
    spawn = {
        weight = 10,                -- relative spawn chance (0 = never spawns naturally)
        minWave = 1,                -- first wave it can appear in
        groupSize = 1,              -- multiplier on horde size
        -- entries = { "burrow", "edge" },  -- ways it may arrive (edge, burrow, drop), first = most
                                            -- likely; default: "flying" tag drops, "burrower" digs
    },
    gibs = { "#6b2f2a", "#a04b38" },-- body-bit colours on death (they land and stay on the floor)
    splat = "#c9b45a",              -- hemolymph colour: the pool, spray and droplets
    tags = { "ant" },               -- free-form, for items/events to filter on
}
