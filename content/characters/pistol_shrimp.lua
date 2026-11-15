-- Pistol shrimp: a sniper. Its big claw machine-guns pellets of water, snaps a cavitation
-- jet across the arena as its special, and it can cloak itself invisible.
local CLAW = { u = 8, v = -4, ch = "snap", open = "open", width = 3, color = "C", tip = "pincer", tipLen = 3,
    segs = { { 3, -0.4, 0 }, { 4, 0.2, 0 } }, strike = { { 4, -0.1, 0.1 }, { 5, 0, 0 } } }

return {
    name = "Pistol Shrimp",
    description = "Fires quick pellets of water (every 6th pops and splashes). Hold right click to aim the claw, let go to snap a cavitation jet: a sniper shot that pierces a whole line and bursts where it ends. Shift: cloak; the ants lose track of you, and a snap shot from the cloak hits twice as hard.",
    lore = "Its claw snaps shut so fast it shoots out a bubble that collapses at about 4,700 C, nearly as hot as the surface of the sun, loud enough to stun fish.",
    sprite = "pistol_shrimp",
    model = { legs = "pistol_shrimp_legs", body = "pistol_shrimp_body", height = 3, lift = 2, stride = 1.3 },
    order = 25,
    playstyle = "ranged",          -- src/config/playstyles.lua
    tip = "Hold {secondary} to aim, let go to fire a sniper jet through a whole line. Shots from the cloak ({dash}) hit twice as hard.",
    radius = 5,
    scale = 0.8,
    stats = { maxHp = 34, moveSpeed = 118, critChance = 15, critDamage = 200 },
    attack = { type = "waterjet", damage = 4, cooldown = 0.2, range = 135, spread = 0.1, popEvery = 6, popRadius = 14, color = { 0.6, 0.85, 1 } },
    secondary = { type = "snapshot", damage = 50, cooldown = 2, aim = 0.5, range = 300, width = 5, radius = 28, cloakMult = 2 },
    dash = { type = "cloak", time = 2.2, speed = 1.3, distance = 40 },
    anims = {
        attack = { time = 0.1, limbs = { CLAW }, keys = { { 0, open = 0.6, snap = 0.5 }, { 0.5, snap = 0.8, lunge = -1 }, { 1 } } },
        secondary = { time = 0.4, limbs = { CLAW }, keys = {
            { 0, open = 1, snap = 1, rear = 1 }, { 0.15, open = 0, snap = 1, lunge = -4, shake = 1.5 }, { 0.6, snap = 0.5, lunge = -2 }, { 1 } } },
        dash = { time = 0.3, keys = { { 0, stretch = -0.2, rear = -1 }, { 0.5, stretch = 0.1 }, { 1 } } },
    },
    startingItems = {},
    tags = { "crustacean" },
}
