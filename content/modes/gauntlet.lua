-- A hand-made run: ten scripted waves, the same every time. Also the example of a scripted mode:
-- `waves` lists every wave in order (the same format the Custom Waves builder saves, see
-- src/game/customwaves.lua). Each wave: groups = { { species id, how many }, ... }, and optionally
-- queen (a boss enemy id), mods (content/wavemods ids), events (content/events ids) and
-- encounter (content/bosses id). After the last wave the script starts again, tougher.
return {
    icon = "bulldog_ant",          -- the enemy sprite shown for the mode in mode select
    name = "Gauntlet",
    tagline = "Ten hand-made waves. The same run every time.",
    description = "A fixed run of ten waves built to test you: fast fire ants, a shield wall of soldiers, an ambush of bullet ants, a lawnmower, two queens. Learn it, then beat it faster.",
    order = 9,
    finalWave = 10,
    spawn = { earlyBoost = false },
    hpPerWave = 0.1,
    waves = {
        { groups = { { "worker_ant", 60 } } },
        { groups = { { "worker_ant", 30 }, { "fire_ant", 30 } }, mods = { "frenzied" } },
        { groups = { { "soldier_ant", 16 }, { "worker_ant", 30 } }, mods = { "shield_wall" } },
        { groups = { { "honey_bee", 24 }, { "yellowjacket", 10 } }, events = { "honeydew_rain" } },
        { groups = { { "fire_ant", 30 } }, queen = "queen_fire" },
        { groups = { { "bullet_ant", 14 }, { "worker_ant", 30 } }, mods = { "ambush" } },
        { groups = { { "exploding_ant", 16 }, { "fire_ant", 30 } }, events = { "lawnmower" } },
        { groups = { { "termite_worker", 40 }, { "soldier_ant", 12 } }, mods = { "undermined" } },
        { groups = { { "bullet_ant", 12 }, { "yellowjacket", 14 }, { "fire_ant", 30 } }, mods = { "armored", "pincer" } },
        { groups = { { "soldier_ant", 20 }, { "exploding_ant", 12 } }, queen = "queen_bullet", encounter = "antlion" },
    },
}
