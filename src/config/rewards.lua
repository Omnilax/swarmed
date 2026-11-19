-- Tunables for combat feel and in-run rewards: the frenzy meter, kill-streak buffs, hitstop /
-- slow-mo / camera punch, mini-goals, the treasure ant, route gates and proc snowballing.
-- The pieces themselves are content (content/frenzies, streaks, goals, routes); this file holds
-- the numbers that tie them into a run. Game modes can override any table here with a
-- `rewards = { frenzy = { perKill = 2 }, ... }` field (merged one level deep).
return {
    -- Frenzy meter (src/game/frenzy.lua): kills fill it, a full meter unleashes a super move.
    frenzy = {
        max = 140,              -- charge for a full meter (an ordinary kill = 1)
        perKill = 1,            -- charge per kill (times the enemy's `xp`)
        elite = 6,              -- extra charge for an elite kill
        boss = 40,              -- extra charge for a queen
        treasure = 0.5,         -- share of a full meter a caught treasure ant gives
        default = "quake",      -- content/frenzies id when the character names none (`frenzy = "id"`)
    },

    -- Kill-streak buffs (src/game/streaks.lua): every `every` kills in one combo, a short buff.
    streaks = { every = 50 },

    -- Big moments: freeze frames, slow motion and a camera zoom punch. Kept rare on purpose:
    -- a freeze is a reward for a really big hit, not something that happens every few seconds.
    feel = {
        stopKills = 15,         -- kills in one frame before the action freezes for a beat
        stopMin = 0.02, stopPerKill = 0.0015, stopMax = 0.045,   -- freeze length for a multi-kill
        stopCooldown = 4,       -- seconds before another multi-kill can freeze the action
        stopScale = 0.6,        -- every other freeze (big punches, molts, encounters) is this much shorter
        bigKill = 30,           -- kills in one frame that count as a big multi-kill (slow motion)
        bigSlow = 0.55, bigSlowTime = 0.22, bigPunch = 0.05,
        queenStop = 0.08, queenSlow = 0.35, queenSlowTime = 0.6, queenPunch = 0.14,
        frenzySlow = 0.3, frenzySlowTime = 0.3, frenzyPunch = 0.18,
        cooldown = 10,          -- seconds between two big-kill slow-mos
    },

    -- Optional mini-goals (src/game/goals.lua, content/goals): one per wave, sometimes.
    goals = { fromWave = 2, chance = 0.6 },

    -- Treasure ant: a gilded runner that flees and burrows away if you don't catch it.
    treasure = { enemy = "treasure_ant", fromWave = 3, chance = 0.35, delay = { 6, 18 }, xp = 30 },

    -- Route gates (src/game/routes.lua, content/routes): after a wave, two tunnels appear near
    -- the player; walk into one to start the next wave that way. Ignoring them = a normal wave.
    routes = { fromWave = 2, minBreak = 5, offset = 105, radius = 14 },

    -- Proc snowball: item proc chances grow every wave, and from `deepFrom` procs can set off
    -- one more link of procs (chain lightning off an explosion off a kill...).
    procs = { perWave = 0.07, maxMul = 2.2, depth = 2, deepFrom = 8, deepDepth = 3 },
}
