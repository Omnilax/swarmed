return {
    name = "Centipede",
    description = "Ripples along on dozens of legs and stabs with its venom claws in a blur of rapid jabs. Its special whips the tail end round and stabs backwards with the hooked rear pincers. Hold Shift to swing round and aim your rear end (your jabs come out of the tail), let go to flip back over, hitting and shoving everything around you.",
    lore = "A centipede's first pair of legs became venom claws. Despite the name, none have exactly a hundred legs.",
    sprite = "centipede",
    -- drawn as a chain of segments that follow the head's path, one pair of legs each
    model = { kind = "chain", legs = "centipede_legs", head = "centipede_head", segment = "centipede_seg", segment2 = "centipede_seg2",
        segments = 15, spacing = 2.3, height = 2, lift = 1.5, legColor = "#e0a030", wave = 0.11,
        leg = { { 0, -1.5, -0.4, -4.2, -1.6, -6.2 } } },
    order = 8,
    radius = 6,
    scale = 1.0,
    stats = { maxHp = 55, moveSpeed = 145, attackSpeed = 20 },
    attack = { type = "jabs", damage = 3, cooldown = 0.13, reach = 30, width = 5, poison = { 2, 2 }, color = { 0.9, 1, 0.5 } },
    secondary = { type = "tailstab", damage = 18, cooldown = 1.6, range = 60, width = 7, knockback = 140, poison = { 8, 4 }, color = { 0.75, 1, 0.3 } },
    dash = { type = "flip", damage = 14, radius = 36, knockback = 260, distance = 30, slow = 0.85 },
    -- the flip: a quick crouch and whip
    anims = { dash = { time = 0.25, keys = { { 0, rear = -1 }, { 0.4, rear = 2, stretch = 0.15 }, { 1 } } } },
    startingItems = {},
    tags = { "myriapod" },
}
