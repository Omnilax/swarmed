-- TEMPLATE. Copy to content/streaks/my_streak.lua. Every 50 kills in one combo (the number is
-- src/config/rewards.lua streaks.every) the player gets one of these at random, for a few
-- seconds. Stats are flat (stats) or multipliers (statsMult: 0.2 = +20%), ids from
-- src/config/stats.lua.
return {
    name = "Bloodrush",
    description = "Shown under the frenzy meter while it lasts.",
    color = "#ff7050",
    stats = { moveSpeed = 30 },
    statsMult = {},
    time = 5,
    weight = 10,                  -- how often it is picked
    minCombo = nil,               -- only from this combo on (e.g. 100 for a stronger one)
}
