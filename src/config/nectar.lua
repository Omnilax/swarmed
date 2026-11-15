-- Tunables for nectar beads (src/game/nectar.lua) and ground pickups (content/pickups).
-- A game mode can override any of these with a `nectar = { ... }` field (merged one level deep).
return {
    -- Beads
    perXP = 1,              -- nectar per point of bead XP (XP itself is unchanged)
    mergeCell = 14,         -- beads that land within one cell of this size (world units) merge into one
    maxBeads = 600,         -- hard cap; past it new value is added to beads already on the ground
    collectPad = 3,         -- touched when this close to the player's body
    driftSpeed = 70,        -- a bead inside Pickup Range starts drifting at this speed...
    driftAccel = 520,       -- ...and speeds up by this much per second
    driftMax = 420,
    magnetSpeed = 220,      -- magnet (wave end or the magnet pickup): start speed
    magnetAccel = 1500,
    magnetMax = 950,
    spill = 26,             -- how far a bead pops out of the body (speed)
    chainGap = 0.45,        -- seconds between pickups that still count as one chime chain
    chainSteps = 24,        -- the chime climbs this many notes, then holds
    chimeStep = 0.045,      -- seconds between queued chime notes
    chimeQueue = 18,        -- at most this many notes waiting (a whole floor swept at once)

    -- Ground pickups (content/pickups)
    pickupLife = 25,        -- seconds before an uncollected pickup fades (blinks for the last 5)
    pickupMax = 6,          -- at most this many on the ground at once
    eliteChance = 0.3,      -- an elite kill drops a pickup marked `source = "elite"` this often
    killChance = 1 / 450,   -- any kill drops a pickup marked `source = "kill"` this often (the magnet)
    killFromWave = 2,
}
