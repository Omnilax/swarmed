-- Gentle Start (src/game/onramp.lua): a new player meets the game's systems one at a time over
-- their first runs instead of all at once.
--
-- Each system below stays out of a run until both:
--   run  = the player's nth real run (1 = the very first one), and
--   wave = the earliest wave of that run it may first show up on.
-- The first time it does show up, a short "NEW" card explains it, and from then on it follows
-- its normal rules in every run. Setting "Gentle Start" off (Gameplay) skips all of this.
-- Practice, the daily run, custom waves and modes with `onramp = false` are never held back.
return {
    systems = {
        elites    = { run = 1, wave = 4 },   -- glowing elite ants
        treasure  = { run = 1, wave = 3 },   -- the gilded treasure ant
        shop      = { run = 1, wave = 3 },   -- the SHOP tab and the nectar counter
        goals     = { run = 2, wave = 3 },   -- optional mini-goals
        wavemods  = { run = 2, wave = 4 },   -- wave modifiers (ambush, armored...)
        events    = { run = 2, wave = 4 },   -- mid-wave events (flood, boot stomp...)
        gambles   = { run = 2, wave = 5 },   -- dewdrop shrines, challenge bells, gamble flowers
        routes    = { run = 3, wave = 3 },   -- safe / hard route tunnels after a wave
        encounters = { run = 3, wave = 5 },  -- boss encounters and stage hazards
    },
    -- Until this run, at most one mid-wave event a wave, and never an event in the same wave
    -- as a boss encounter.
    calmUntilRun = 4,
    -- A save with this many runs already in it counts as a veteran's: nothing is held back.
    veteranRuns = 6,
    -- The "NEW" card for each system: a title and one or two short sentences.
    cards = {
        elites    = { "Elite ants", "Glowing ants are elites: tougher, with a trick of their own. They spill more nectar." },
        treasure  = { "Treasure ant", "A golden ant! Catch it before it burrows away for a pile of XP." },
        shop      = { "Nectar shop", "Ants spill nectar. Spend it in the SHOP tab of your bag ({inventory})." },
        goals     = { "Mini-goals", "This wave has an optional task, shown on the right. Finish it for bonus XP." },
        wavemods  = { "Wave twists", "Some waves have a twist, named on the wave banner." },
        events    = { "Garden events", "Sometimes the garden joins the fight. Read the banner and use it against the ants." },
        gambles   = { "Map gambles", "Shrines, bells and flowers pop up mid-wave. Risky, but they pay well." },
        routes    = { "Route tunnels", "Walk into the safe tunnel or the hard one. Hard pays more. Ignore both for a normal wave." },
        encounters = { "Big visitors", "Something huge has arrived. What it does hurts ants too, so lead the swarm into it." },
    },
}
