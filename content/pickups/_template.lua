-- TEMPLATE. Copy to content/pickups/my_pickup.lua. A pickup is a small glowing token that
-- lies on the ground for a while (src/game/nectar.lua, numbers in src/config/nectar.lua).
-- It drifts to the player inside Pickup Range like nectar beads do, and `collect` runs when
-- the player touches it. Pickups are never items: they act at once and never go in the bag.
--
-- Drops: an elite kill rolls `eliteChance` for a pickup with source = "elite", any kill rolls
-- `killChance` for one with source = "kill" (weighted by `weight`). source = nil: never drops
-- by itself (World:dropPickup(id, x, y) can still place one, e.g. from a shrine or an event).
return {
    name = "My Pickup",
    description = "Longer text for catalogues and the sandbox.",
    color = "#ffffff",                 -- the token's glow and ring
    icon = "magnet",                   -- drawn symbol: "magnet" | "freeze" | "frenzy" | "star"
    source = nil,                      -- "elite" | "kill" | nil
    weight = 10, minWave = 1,
    allowed = nil,                     -- function(world) -> false to skip it this time (re-rolled)
    collect = function(world, player, pickup) end,
}
