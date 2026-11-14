-- Animation limbs: the long hind legs that kick the ball away.
local HIND = { u = -6, v = 6, pair = true, ch = "kick", width = 1, color = "l",
    segs = { { 4, math.pi - 0.9, 0 }, { 4, 0.3, 0 } }, strike = { { 5, math.pi - 0.2, 0.3 }, { 5, 0, 0 } } }

return {
    name = "Dung Beetle",
    description = "Always rolling a dung ball that grows as you push it around and as it squashes ants. The bigger it gets, the harder it hits, but the slower you walk and bash. Right click kicks it off to bowl through the ants (big balls burst at the end; the bigger the ball, the longer before the next one). Once the ball is bigger than you, hold Shift to climb on and ride it.",
    lore = "Dung beetles can roll balls many times their own weight and steer home by the light of the Milky Way.",
    sprite = "dung_beetle",
    model = { legs = "dung_beetle_legs", body = "dung_beetle_body", height = 5, lift = 2 },
    order = 17,
    radius = 8,
    scale = 1.05,
    stats = { maxHp = 90, armor = 4, moveSpeed = 88, knockback = 30 },
    attack = { type = "dungbash", damage = 11, cooldown = 0.55, perSize = 0.16, killGrow = 0.45, knockback = 140, sizeSlow = 1 },
    secondary = { type = "dungthrow", damage = 16, cooldown = 1.2, perSize = 0.24, speed = 340, burstSize = 9, minSize = 4, maxSize = 20, grow = 0.011, knockback = 180, slowMax = 0.45, sizeCooldown = 0.12 },
    dash = { type = "dungride", stamina = 2.2, regen = 0.9, speed = 1.5, damage = 6, knockback = 190, minBall = 1 },
    anims = {
        attack = { time = 0.28, keys = { { 0 }, { 0.3, lunge = -2, rear = -1, spread = 0.3 }, { 0.5, lunge = 4, reach = 2, stretch = 0.1 }, { 1 } } },
        -- the kick: head down, hind legs lash out at the ball
        secondary = { time = 0.4, limbs = { HIND }, keys = {
            { 0 }, { 0.3, rear = -2, lunge = 2, kick = 0, stretch = -0.1 }, { 0.5, kick = 1.2, lunge = 3, rear = 1, reach = 2 }, { 1 } } },
        -- riding the ball: legs braced wide, treading it along
        dash = { time = 0.4, holdAt = 0.3, hold = function(p) return p.holdMode ~= nil end, keys = {
            { 0 }, { 0.3, rear = 1, spread = 0.45, reach = 1.5, shake = 0.2 }, { 1 } } },
    },
    startingItems = {},
    tags = { "beetle", "insect" },
}
