-- Achievement schema. A file returns one achievement or a list of them; ids must be unique.
-- They are checked a couple of times a second during a run, at every wave clear and when a run
-- ends, and unlock once value(...) >= goal. Unlocked ones are kept in the save (records.lua).
--
-- value(profile, run) -> number (or true/false). `profile` is the all-time record (see
-- blankProfile in src/game/records.lua: kills, killsBy[enemyId], killsByFamily[family],
-- elitesBy[eliteId], queens, wavesCleared, flawlessWaves, bestWave, bestCombo, wins, runs,
-- deaths, playTime, itemsTaken, itemsEaten, characters[id] = {runs, wins, kills, bestWave},
-- modes[id] = {runs, wins, bestWave}, history). `run` is the current run, or nil between runs
-- (character, mode, kills, killsBy, killsByFamily, elites, queens, wave, wavesCleared,
-- flawlessWaves, damageTaken, itemsTaken, itemsEaten, time, won, world).
return {
    id = "example",
    name = "Example",                 -- short, shown on the unlock card
    description = "What to do.",      -- one line
    category = "Slaughter",           -- groups the list on the Records screen
    goal = 1,                         -- number, or function() -> number (e.g. count of species)
    hidden = false,                   -- shows as ??? until unlocked
    order = 0,
    unlocks = nil,                    -- id (or list) of locked cosmetics it reveals, e.g. "gilded" (content/skins)                        -- list order within the category
    value = function(profile, run) return 0 end,
}
