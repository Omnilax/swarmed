-- Animation limbs: the two claws (one per snip) opening and snapping shut.
local CLAW = { u = 3.5, v = 7, pair = true, ch = "L", chR = "R", open = "open", width = 3, color = "C", tip = "pincer", tipLen = 3,
    segs = { { 3.5, 0.6 }, { 3, -0.5 }, { 3, -0.3 } },
    strike = { { 4, 0.2 }, { 4, -0.4 }, { 3.5, -0.2 } } }

return {
    name = "Crab",
    description = "Walks sideways and snips with both claws. Right click seizes an ant and cuts it clean in two: it dies instantly and the halves go flying into the swarm. Spam it to carve through a crowd. Its dash only goes sideways.",
    lore = "A crab's claws can snap shut with many times its own weight. Most crabs walk sideways because their legs bend that way.",
    sprite = "crab",
    model = { legs = "crab_legs", body = "crab_body", height = 4, lift = 2, stride = 1.2 },
    order = 15,
    radius = 9,
    scale = 1.1,
    stats = { maxHp = 80, armor = 6, moveSpeed = 95 },
    -- walks fastest side-on: forward and back are slower (Player:update, Player:walkFacing)
    sideways = { forward = 0.6, side = 1.15 },
    attack = { type = "clawsnip", damage = 7, cooldown = 0.32, radius = 21, offset = 24, spread = 9, color = { 1, 0.6, 0.45 } },
    secondary = { type = "snipsplit", damage = 12, cooldown = 0.55, reach = 46, lift = 0.1, halves = 100, bossDamage = 16 },
    dash = { type = "scuttle", distance = 80, speed = 1.3, charges = 2, ram = 5, knockback = 140 },
    anims = {
        attack = { time = 0.2, mirror = true, limbs = { CLAW }, keys = {
            { 0 }, { 0.3, L = 0.6, open = 1, twist = -0.1 }, { 0.55, L = 1.1, open = 0, lunge = 2, twist = 0.08 }, { 1 } } },
        secondary = { time = 0.42, limbs = { CLAW }, keys = {
            { 0 }, { 0.25, L = 1.2, R = 0.3, open = 1, lunge = 3, reach = 1 },
            { 0.45, L = 0.8, R = 0.2, rear = 2, open = 0.6 }, { 0.6, L = 0.9, R = 0.9, open = 0, rear = 1, shake = 1 }, { 1 } } },
        dash = { time = 0.25, keys = { { 0 }, { 0.2, side = 2, spread = 0.3, rear = -1 }, { 0.8, side = 1, spread = 0.2 }, { 1 } } },
    },
    startingItems = {},
    tags = { "crustacean" },
}
