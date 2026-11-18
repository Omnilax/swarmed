-- The guided tutorial (src/game/lessons.lua): one lesson at a time, the colony held back.
-- Started from the main menu's Tutorial button, never listed in mode select (hidden).
return {
    icon = "worker_ant",          -- the enemy sprite shown for the mode in mode select
    name = "Tutorial",
    tagline = "Learn the basics, one step at a time.",
    description = "A guided first fight: moving, attacking, dashing, specials, nectar, level-ups, items, the bag, the shop, frenzy, elites and a queen.",
    order = 0,
    hidden = true,
    tutorial = true,
    onramp = false,
    finalWave = false,
    events = false, gambles = false, encounters = false,
    enemyHp = 0.7, enemyDamage = 0.5,
}
