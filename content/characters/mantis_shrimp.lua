-- Peacock mantis shrimp: a boxer. Every click is a punch that hits like a bullet (plus the
-- cavitation bubble's second blast); the special is a flurry of jabs, and the dash is a held,
-- charged punch so strong the recoil throws it backwards.
local CLUB = { u = 8, v = 2, ch = "punch", ch2 = "cock", width = 3, color = "C", tip = "club", tipLen = 2.5,
    segs = { { 3, 0.8, 0 }, { 3, -2.2, 0 } }, strike = { { 4, 0.1, 0.1 }, { 6, -0.05, 0 } },
    alt = { { 3, 1.4, 0.4 }, { 3, -2.6, 0.2 } } }
local CLUBS = { u = 8, v = 2, pair = true, ch = "R", chR = "L", width = 3, color = "C", tip = "club", tipLen = 2.5,
    segs = CLUB.segs, strike = CLUB.strike }

return {
    name = "Mantis Shrimp",
    description = "Every click is a club punch, and every punch leaves a cavitation bubble that bursts a beat later. Right click: a flurry of 10 jabs. Hold Shift to wind up a huge punch and let go: the longer you charge, the harder it hits and the further the recoil launches you backwards.",
    lore = "Its club accelerates as fast as a .22 bullet. The water boils behind it into a bubble that collapses with a flash of light and a second blow.",
    sprite = "mantis_shrimp",
    model = { legs = "mantis_shrimp_legs", body = "mantis_shrimp_body", height = 3, lift = 2, stride = 1.4 },
    order = 24,
    radius = 7,
    stats = { maxHp = 55, armor = 2, moveSpeed = 108, knockback = 20 },
    attack = { type = "clubpunch", damage = 13, cooldown = 0.32, reach = 36, bubble = 0.5, radius = 28, knockback = 260, color = { 1, 0.45, 0.4 } },
    secondary = { type = "flurry", damage = 5, cooldown = 3, punches = 10, time = 0.7, reach = 28, finisher = 3, color = { 1, 0.5, 0.4 } },
    dash = { type = "recoilpunch", damage = 24, reach = 36, distance = 90, charge = 0.8, maxMult = 3, launchMult = 1.2 },
    anims = {
        attack = { time = 0.24, limbs = { CLUB }, keys = {
            { 0 }, { 0.2, cock = 0.6, lunge = -1, twist = -0.15 },
            { 0.4, punch = 1.2, lunge = 4, twist = 0.15, stretch = 0.1 }, { 0.75, punch = 0.5, lunge = 1 }, { 1 } } },
        secondary = { time = 0.75, limbs = { CLUBS }, keys = {
            { 0 }, { 0.1, R = 1, lunge = 2 }, { 0.2, L = 1, lunge = 1 }, { 0.3, R = 1, lunge = 2 }, { 0.4, L = 1, lunge = 1 },
            { 0.5, R = 1, lunge = 2 }, { 0.6, L = 1, lunge = 1 }, { 0.7, R = 1, lunge = 2 }, { 0.8, L = 1, lunge = 1 },
            { 0.92, R = 1.3, L = 1.3, lunge = 4, rear = 2 }, { 1 } } },
        -- held wind-up (shakes harder the longer it's held), then the punch and the recoil
        dash = { time = 0.6, holdAt = 0.35, hold = function(p) return p.recoil ~= nil end, limbs = { CLUB }, keys = {
            { 0 }, { 0.35, cock = 1, rear = 1, lunge = -3, twist = -0.3, shake = 0.8, spread = 0.3 },
            { 0.45, punch = 1.3, lunge = 5, twist = 0.2, stretch = 0.15 }, { 0.7, punch = 0.4, lunge = -3, rear = 2 }, { 1 } } },
    },
    startingItems = {},
    tags = { "crustacean" },
}
