-- TEMPLATE. Copy to content/bosses/my_boss.lua. A boss encounter: on every 5th wave (not the
-- run's final wave) a big predator joins the queen (src/game/director.lua, Settings "Boss
-- Encounters"). It is a real enemy from content/enemies (give it `encounter = true` and spawn
-- weight 0, see content/enemies/predators.lua), so the wave lasts until it is killed; its own
-- behaviour does the fighting. Dev console: `encounter <id>`.
return {
    name = "The Anteater",              -- banner title (and its health bar unless `title`)
    description = "Banner line under it.",
    enemy = "anteater",                 -- id from content/enemies
    weight = 10, minWave = 5,           -- picked by weight, ones not met yet first
    -- arrive = 5,                      -- seconds into the wave it comes in
    -- entry = function(world) return x, y end,     -- where it appears (default: well away from the player)
    xp = 25,                            -- bonus XP when it falls
    -- slain = "ANTEATER DRIVEN OFF",   -- popup when it falls
    -- start = function(world, e, enc) end, update = function(world, e, enc, dt) end, finish = function(world, enc) end,
    -- drawGround / drawAir = function(world, e, enc) end,
}
