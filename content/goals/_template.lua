-- TEMPLATE. Copy to content/goals/my_goal.lua. A mini-goal is an optional side task for one
-- wave (src/game/goals.lua). Some waves (src/config/rewards.lua goals) pick one at random;
-- finishing it pays `reward` (bonus skill XP through World:grantXP, and a share of a full
-- frenzy meter). Failing costs nothing. Goals never hold a wave up: the wave still ends when
-- every enemy is dead, and a goal still open then is settled by `finish` (default: failed).
--
-- goal: this wave's instance (store your state on it), goal.def = this file, goal.wave.
-- Every function may return "done" or "failed" to settle the goal there and then.
return {
    name = "My Goal",
    description = "Longer text for catalogues.",
    weight = 10, minWave = 2,
    reward = { xp = 20, frenzy = 0.25 },
    allowed = nil,                           -- function(world, wave) -> false to skip this wave
    text = function(goal, world) return "Do the thing" end,   -- the HUD line (kept short)
    start = function(goal, world) end,       -- the wave just started
    update = nil,                            -- function(goal, world, dt) -> "done" | "failed" | nil
    on = {},                                 -- world events: enemy_died = function(goal, world, e) ... end
    finish = nil,                            -- function(goal, world) when the wave is cleared
    drawWorld = nil,                         -- function(goal, world) on the ground (projected pixels)
}
