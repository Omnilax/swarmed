-- TEMPLATE. Copy to content/wavemods/my_modifier.lua. A wave modifier changes one wave: it is
-- rolled ahead from the run's seed (src/game/pacing.lua), shown on the wave banner, and never
-- lands on a queen's wave or the final wave. Every field but name is optional.
return {
    name = "My Modifier",
    description = "One line for the banner and the next-wave preview.",
    color = { 1, 0.8, 0.4 },    -- banner colour
    weight = 10,                -- how often it is picked (0 = never)
    minWave = 3,                -- earliest wave it can roll on (maxWave: latest)
    modes = nil,                -- only in these game modes (ids), e.g. { "colony" }

    groupSize = 1,              -- x ants per group
    hp = 1,                     -- x enemy health
    speed = 1,                  -- x enemy speed
    damage = 1,                 -- x enemy damage
    elites = 1,                 -- x elite chance
    formation = nil,            -- "wall" (groups arrive at once in ranks) | "pincer" (each group splits to opposite sides)
    ambush = false,             -- half the groups burst up in a ring around the player at once
    entryStyles = nil,          -- per-way overrides of src/game/entries.lua, e.g. { burrow = { chance = 0.8, minWave = 1 } }
}
