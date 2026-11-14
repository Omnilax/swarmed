-- Tailless whip scorpion (amblypygid): all reach. Left click lashes the left spiny palp across
-- a long arc, right click whips the right one out and slams its tip down on one ant. The bug
-- stays back while the palps do the work.
local LEFT = { u = 6, v = 3, ch = "L", width = 2, color = "B", tip = "blade", tipLen = 3,
    segs = { { 5, 1.2, 0.3 }, { 5, -2.2, 0 } }, strike = { { 8, 0.5, 0.3 }, { 11, -0.2, 0 } } }
local RIGHT = { u = 6, v = -3, ch = "R", width = 2, color = "B", tip = "blade", tipLen = 3,
    segs = { { 5, -1.2, 0.3 }, { 5, 2.2, 0 } }, strike = { { 9, -0.1, 0.2 }, { 13, 0, 0 } } }

return {
    name = "Whip Scorpion",
    description = "Tailless whip scorpion. Left click: the left palp rakes a long arc. Right click: the right palp whips out and slams its tip down, a small blast that crushes the ant under it. Only the tip hits, so keep your distance. Shift: crack your feelers out like a whip grapple. Catch an ant to lash it and zip over for a whip crack, or catch ground to haul yourself there.",
    lore = "Neither a scorpion nor a spider. Its first pair of legs are whip-thin feelers longer than its body, and its spiny palps snap shut on prey like a cage.",
    sprite = "whip_scorpion",
    model = { legs = "whip_scorpion_legs", body = "whip_scorpion_body", height = 2, lift = 2, stride = 1.6, kneeUp = 2 },
    order = 22,
    radius = 8,
    stats = { maxHp = 52, moveSpeed = 105, critChance = 10 },
    attack = { type = "palpstrike", hand = "left", feelers = true, damage = 10, cooldown = 0.5, reach = 76, arc = 1.9, color = { 1, 0.85, 0.6 } },
    secondary = { type = "palpstrike", hand = "right", damage = 34, cooldown = 0.9, reach = 100, radius = 14, splash = 0.35, stun = 0.4, color = { 1, 0.8, 0.55 } },
    dash = { type = "feelerpull", range = 140, speed = 1.6, charges = 2, damage = 8, crack = 14, radius = 26 },
    anims = {
        attack = { time = 0.3, limbs = { LEFT }, keys = { { 0 }, { 0.3, L = 1, twist = -0.25, lunge = 1 }, { 0.6, L = 0.6, twist = 0.2 }, { 1 } } },
        secondary = { time = 0.34, limbs = { RIGHT }, keys = { { 0, rear = 1 }, { 0.25, R = 1, rear = 2 }, { 0.45, R = 1, rear = -1.5, lunge = 1, shake = 1 }, { 1 } } },
        dash = { time = 0.25, keys = { { 0, stretch = -0.1, rear = 1 }, { 0.3, stretch = 0.15, lunge = 2 }, { 1 } } },
    },
    startingItems = {},
    tags = { "arachnid" },
}
