-- Wave rewards (src/game/rewardflow.lua): the reward bloom that sprouts when a wave is cleared,
-- and the pickups that fly from it into your bug. Settings "Wave Rewards" can skip the walk
-- (Open at Once); the sandbox and demo runs always open at once.
return {
    distance = 72,        -- how far from the player the bloom sprouts (towards the arena's middle)
    edge = 60,            -- ...but never closer than this to the arena's edge
    driftAfter = 5,       -- seconds before an unopened bloom starts rolling to you by itself
    driftSpeed = 50,      -- its speed when it starts rolling (it speeds up as it goes)
    driftAccel = 220,
    pullSpeed = 320,      -- Next Wave (E) while it waits: it rushes to you at this speed
    openDelay = 0.45,     -- the bloom bursts, then the reward screens open this long after
    flight = 0.6,         -- seconds a reward takes to fly from the bloom into your bug
    flightGap = 0.35,     -- several rewards: one after another
    toastLife = 4.5,      -- seconds a "NEW ITEM" card stays on the left of the screen
    toasts = 4,           -- at most this many at once
}
