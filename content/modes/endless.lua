-- No waves: a steady stream that keeps growing. Pick your starting items.
return {
    icon = "army_ant",          -- the enemy sprite shown for the mode in mode select
    name = "Endless",
    tagline = "No waves, no breaks. Bring your own kit.",
    description = "Choose your starting items, then hold out as long as you can. The colony never stops coming and gets stronger every level. An item choice every third level.",
    order = 8,
    finalWave = false,
    endless = { levelTime = 40, packGap = 2.4, minGap = 0.5, packSize = 0.6, rewardEvery = 3, bossEvery = 5 },
    chooseItems = { budget = 12 },
}
