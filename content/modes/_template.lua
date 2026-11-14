-- TEMPLATE. Copy to content/modes/my_mode.lua. A game mode is a wave structure: who comes,
-- how many, how hard, and when the run ends. Everything is optional except name; leave a
-- field out to get the standard game (content/modes/colony.lua has no overrides at all).
return {
    name = "My Mode",
    tagline = "One short line for the mode list.",
    description = "A sentence or two shown on the mode select screen.",
    order = 50,                 -- position in the mode list

    finalWave = 15,             -- the run is won after this wave (you may keep going); false = no end

    -- Overrides for the stage's wave settings (see content/stages/_template.lua and the
    -- DEFAULTS in src/game/spawner.lua): groups, groupsPerWave, group, growth, breakTime,
    -- introEvery, entries, trickle, bossEvery, maxAlive, ...
    spawn = {},

    -- Which enemies take part. families: ids from src/config/families.lua. enemies: extra ids
    -- (or the only ids, when families is left out). exclude: ids to leave out.
    families = nil,             -- e.g. { "bee", "wasp", "hornet" }
    enemies = nil,
    exclude = nil,
    queensAnyWave = false,      -- queens ignore their own minWave (for short species lists)
    bossPool = nil,             -- enemy ids to use as boss-wave bosses when no queen fits

    enemyHp = 1,                -- multiplies every enemy's health
    enemyDamage = 1,            -- multiplies every enemy's damage
    hpPerWave = 0.12,           -- extra enemy health per wave (+12% a wave)

    -- Elites: mul scales the normal chance; chance replaces it (1 = every enemy); anyWave lets
    -- every affix roll from wave 1.
    elites = nil,               -- e.g. { mul = 2 } or { chance = 1, anyWave = true }

    -- No waves: a steady, growing stream. The level (shown instead of a wave number) goes up
    -- every levelTime s and brings a new species; a queen every bossEvery levels; an item choice
    -- every rewardEvery levels (0 = never).
    endless = nil,              -- e.g. { levelTime = 40, packGap = 2.4, minGap = 0.5, packSize = 0.6, rewardEvery = 3 }

    -- Before the run, pick starting items from the whole catalogue with a point budget
    -- (cost per rarity, see src/states/loadout.lua).
    chooseItems = nil,          -- e.g. { budget = 12 }
}
