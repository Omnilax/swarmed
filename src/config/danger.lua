-- Danger levels: a climb of difficulty per bug. Danger 0 is the normal game; each level adds
-- one rule on top of the ones below it. Winning a run at a level opens the next one for that
-- bug (Settings > Gameplay > "Unlock Everything" opens them all). Records keep the highest
-- level won per bug, shown as mastery stars on the bug select screen.
--
-- rules (all optional, multiplied together across levels; extraQueens adds up):
--   hpMul, damageMul, speedMul  enemy health / damage / move speed
--   eliteMul                    chance of elite ants
--   healMul                     healing after each wave and queen
--   groupMul                    size of every ant group
--   extraQueens                 more crowned queens in the final wave
return {
    { name = "Restless", description = "Elite ants come twice as often.", color = "#e8c070",
        rules = { eliteMul = 2 } },
    { name = "Hungry", description = "Half the healing after each wave.", color = "#e8a060",
        rules = { healMul = 0.5 } },
    { name = "Frantic", description = "Ants move 12% faster.", color = "#e08050",
        rules = { speedMul = 1.12 } },
    { name = "Swollen", description = "Ants have 25% more health and bite 15% harder.", color = "#d86048",
        rules = { hpMul = 1.25, damageMul = 1.15 } },
    { name = "Endless", description = "Bigger groups, and one more crowned queen in the final wave.", color = "#c84040",
        rules = { groupMul = 1.2, extraQueens = 1 } },
}
