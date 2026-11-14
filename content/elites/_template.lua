-- TEMPLATE. Copy to content/elites/my_affix.lua. Elites are rare, souped-up versions of any ant
-- (like Risk of Rain's elites): same species, tinted, bigger and with a twist.
-- An enemy can also tune what an affix does to *its* species with
--   elites = { my_affix = { params = { shotSpeed = 240 }, note = "Shoots further." } }
-- in its own file (absolute behaviour params, applied after this file's multipliers).
return {
    name = "Mighty",                 -- shown in the catalogue and as a prefix ("Mighty Worker Ant")
    description = "What makes this elite different, for the catalogue.",
    color = "#ff4040",               -- tint, aura and light colour
    hp = 2, damage = 1.3, speed = 1.1, mass = 1.5, scale = 1.2,
    params = { cooldown = 0.7 },      -- multipliers for numeric behaviour params (cooldowns, ranges...)
    armor = nil,                      -- 0..1: fraction of every hit ignored
    venom = nil,                      -- { dps, time }: bites poison the player
    bonusXP = nil,                    -- killing one grants this much bonus XP (World:grantXP)
    sparkle = false,                  -- glittering particles
    weight = 10, minWave = 3,         -- how often it rolls, and from which wave
    onDeath = nil,                    -- function(world, x, y, enemy) run the frame after it dies
}
