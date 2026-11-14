-- Animation limbs: the curved rostrum (beak) folded under the head, driven straight out to stab.
local ROSTRUM = { u = 12.5, v = 0, z = 2, ch = "stab", width = 1, color = "w", tip = "sting", tipLen = 2,
    segs = { { 2.5, 0, -0.5 }, { 2, 0.2, -0.4 } }, strike = { { 6, 0, 0 }, { 6, 0, 0 } } }

return {
    name = "Assassin Bug",
    description = "A stalker. Quick little beak stabs that each drink a bit of life back. Right click shoves the ants in front of you away. Hold Shift to turn invisible: the ants lose you, and every stab and shove from the shadows hits far harder.",
    lore = "Assassin bugs inject saliva that turns their prey's insides to soup, then suck it up through their beak.",
    sprite = "assassin_bug",
    model = { legs = "assassin_bug_legs", body = "assassin_bug_body", height = 3, lift = 3, kneeUp = 1 },
    order = 13,
    radius = 7,
    stats = { maxHp = 50, moveSpeed = 108, critChance = 8 },
    attack = { type = "rostrum", damage = 7, cooldown = 0.3, reach = 34, width = 4, pierce = 1, leech = 0.2, color = { 1, 0.35, 0.3 } },
    secondary = { type = "shove", damage = 4, cooldown = 1.4, radius = 40, arc = 1.7, knockback = 380, stun = 0.3 },
    dash = { type = "stealth", stamina = 4, regen = 0.8, speed = 1.15, bonus = 2.5, strikeCost = 0.3 },
    anims = {
        attack = { time = 0.22, limbs = { ROSTRUM }, keys = {
            { 0 }, { 0.3, lunge = -1.5, rear = 0.5, stab = -0.2 }, { 0.5, lunge = 4, stretch = 0.12, stab = 1 }, { 1 } } },
        -- shoulder-check: crouch back, then throw the whole body forward
        secondary = { time = 0.28, keys = {
            { 0 }, { 0.3, lunge = -2, rear = -1, stretch = -0.1, spread = 0.2 }, { 0.5, lunge = 5, stretch = 0.15, shake = 0.6 }, { 1 } } },
        -- held while invisible: low and flat, legs spread, creeping
        dash = { time = 0.3, holdAt = 0.5, hold = function(p) return p.holdMode ~= nil end, keys = {
            { 0 }, { 0.5, rear = -1.5, spread = 0.3, stretch = 0.08 }, { 1 } } },
    },
    startingItems = {},
    tags = { "insect", "true bug" },
}
